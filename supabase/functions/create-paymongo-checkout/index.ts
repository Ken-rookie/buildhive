import { createClient } from "npm:@supabase/supabase-js@2";
import { normalizePaymongoPaymentMethods } from "./payment-methods.js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function checkoutReturnUrl(result: "success" | "cancelled", orderId: string): string {
  const url = new URL("buildhive://payment-return");
  url.searchParams.set("payment_return", result);
  url.searchParams.set("order_id", orderId);
  return url.toString();
}

function getServiceRoleKey(): string | null {
  const legacyKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacyKey) return legacyKey;

  try {
    const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    return secretKeys.default ?? null;
  } catch {
    return null;
  }
}

async function releaseCheckoutLock(
  supabase: any,
  orderId: string,
  requestKey: string,
): Promise<void> {
  await supabase.rpc("release_paymongo_checkout_lock", {
    p_order_id: orderId,
    p_request_key: requestKey,
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  const authorization = request.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "");
  const orderId = (await request.json().catch(() => null))?.order_id;
  if (!token || typeof orderId !== "string") {
    return jsonResponse({ error: "Authentication and order_id are required." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = getServiceRoleKey();
  const paymongoSecretKey = Deno.env.get("PAYMONGO_SECRET_KEY");
  const paymongoMode = Deno.env.get("PAYMONGO_MODE")?.toLowerCase();
  if (
    !supabaseUrl ||
    !serviceRoleKey ||
    !paymongoSecretKey ||
    !paymongoMode ||
    !["test", "live"].includes(paymongoMode)
  ) {
    console.error("Missing checkout function secrets.");
    return jsonResponse({ error: "Checkout is not configured." }, 500);
  }
  const expectedKeyPrefix = paymongoMode === "test" ? "sk_test_" : "sk_live_";
  if (!paymongoSecretKey.startsWith(expectedKeyPrefix)) {
    console.error("PayMongo key does not match configured mode.");
    return jsonResponse({ error: "Checkout is not configured." }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) return jsonResponse({ error: "Unauthorized." }, 401);

  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select("id, customer_id, payment_method, payment_status, total, delivery_fee, order_items(product_name, unit_price, quantity)")
    .eq("id", orderId)
    .eq("customer_id", authData.user.id)
    .maybeSingle();

  if (orderError) {
    console.error("Could not load checkout order.", orderError.message);
    return jsonResponse({ error: "Could not load this order." }, 500);
  }
  if (!order || order.payment_method !== "paymongo" || order.payment_status !== "unpaid") {
    return jsonResponse({ error: "This order is not eligible for payment." }, 404);
  }

  const lineItems = (order.order_items ?? []).map((item: {
    product_name: string;
    unit_price: number;
    quantity: number;
  }) => ({
    name: item.product_name,
    amount: Math.round(Number(item.unit_price) * 100),
    currency: "PHP",
    quantity: Number(item.quantity),
  }));

  const deliveryFee = Math.round(Number(order.delivery_fee ?? 0) * 100);
  if (deliveryFee > 0) {
    lineItems.push({
      name: "Delivery fee",
      amount: deliveryFee,
      currency: "PHP",
      quantity: 1,
    });
  }

  const expectedAmount = Math.round(Number(order.total) * 100);
  const calculatedAmount = lineItems.reduce(
    (sum: number, item: { amount: number; quantity: number }) => sum + item.amount * item.quantity,
    0,
  );
  if (lineItems.length === 0 || calculatedAmount !== expectedAmount) {
    console.error("Order line items do not match the stored total.", order.id);
    return jsonResponse({ error: "The order total could not be verified." }, 409);
  }

  const { data: claimData, error: claimError } = await supabase.rpc(
    "begin_paymongo_checkout",
    { p_order_id: order.id },
  );
  if (claimError) {
    console.error("Could not claim checkout creation.", claimError.message);
    return jsonResponse({ error: "Could not start checkout." }, 500);
  }

  const claim = Array.isArray(claimData) ? claimData[0] : claimData;
  if (claim?.result_code === "busy") {
    return jsonResponse({ error: "Checkout is already being prepared. Try again shortly." }, 409);
  }
  if (claim?.result_code === "not_payable") {
    return jsonResponse({ error: "This order is no longer payable." }, 409);
  }

  const credentials = btoa(`${paymongoSecretKey}:`);
  if (claim?.result_code === "existing" && typeof claim.session_id === "string") {
    const sessionResponse = await fetch(
      `https://api.paymongo.com/v1/checkout_sessions/${encodeURIComponent(claim.session_id)}`,
      { headers: { Authorization: `Basic ${credentials}` } },
    );
    const sessionBody = await sessionResponse.json().catch(() => null);
    const session = sessionBody?.data;
    const attributes = session?.attributes;
    if (!sessionResponse.ok || !attributes) {
      console.error("Could not retrieve the existing PayMongo session.", sessionResponse.status);
      return jsonResponse({ error: "Could not resume this checkout." }, 502);
    }
    if (attributes.livemode !== (paymongoMode === "live")) {
      console.error("Existing PayMongo session does not match configured mode.");
      return jsonResponse({ error: "Checkout is not configured." }, 500);
    }
    if ((attributes.payments ?? []).some((payment: any) => payment?.attributes?.status === "paid")) {
      return jsonResponse({ error: "Payment is processing. Check your order shortly." }, 409);
    }
    if (attributes.status === "active" && typeof attributes.checkout_url === "string") {
      return jsonResponse({ checkout_url: attributes.checkout_url });
    }
    if (attributes.status === "expired") {
      const { data: orderExpired, error: expireError } = await supabase.rpc("expire_paymongo_order", {
        p_order_id: order.id,
        p_session_id: session.id,
      });
      if (expireError) {
        console.error("Could not release expired order stock.", expireError.message);
        return jsonResponse({ error: "Could not finish checkout expiration." }, 500);
      }
      return orderExpired === true
        ? jsonResponse({ error: "This checkout expired. Place a new order to try again." }, 409)
        : jsonResponse({ error: "Payment status changed. Check your order before retrying." }, 409);
    }
    return jsonResponse({ error: "This checkout is not available." }, 409);
  }

  if (claim?.result_code !== "create" || typeof claim.request_key !== "string") {
    console.error("Unexpected checkout claim response.");
    return jsonResponse({ error: "Could not start checkout." }, 500);
  }

  const paymentMethodTypes = normalizePaymongoPaymentMethods(
    Deno.env.get("PAYMONGO_PAYMENT_METHOD_TYPES"),
  );
  if (paymentMethodTypes.length === 0) {
    await releaseCheckoutLock(supabase, order.id, claim.request_key);
    return jsonResponse({ error: "No PayMongo payment methods are configured." }, 500);
  }

  try {
    const paymongoResponse = await fetch("https://api.paymongo.com/v2/checkout_sessions", {
      method: "POST",
      headers: {
        Authorization: `Basic ${credentials}`,
        "Content-Type": "application/json",
        "Idempotency-Key": `buildhive-${claim.request_key}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            line_items: lineItems,
            payment_method_types: paymentMethodTypes,
            success_url: checkoutReturnUrl("success", order.id),
            cancel_url: checkoutReturnUrl("cancelled", order.id),
            reference_number: order.id,
            metadata: { order_id: order.id },
          },
        },
      }),
    });

    const paymongoBody = await paymongoResponse.json().catch(() => null);
    const session = paymongoBody?.data;
    const checkoutUrl = session?.attributes?.checkout_url;
    if (
      !paymongoResponse.ok ||
      typeof session?.id !== "string" ||
      typeof checkoutUrl !== "string" ||
      session.attributes.livemode !== (paymongoMode === "live")
    ) {
      console.error("PayMongo did not create a valid checkout session.", paymongoResponse.status);
      await releaseCheckoutLock(supabase, order.id, claim.request_key);
      return jsonResponse({ error: "PayMongo could not start checkout." }, 502);
    }

    const { data: saved, error: saveError } = await supabase.rpc(
      "save_paymongo_checkout_session",
      {
        p_order_id: order.id,
        p_request_key: claim.request_key,
        p_session_id: session.id,
      },
    );
    if (saveError || saved !== true) {
      console.error("Could not save PayMongo checkout session.", saveError?.message);
      await releaseCheckoutLock(supabase, order.id, claim.request_key);
      return jsonResponse({ error: "Could not save checkout. Please retry." }, 500);
    }

    return jsonResponse({ checkout_url: checkoutUrl });
  } catch (error) {
    await releaseCheckoutLock(supabase, order.id, claim.request_key);
    console.error("PayMongo checkout request failed.", error);
    return jsonResponse({ error: "PayMongo could not start checkout." }, 502);
  }
});