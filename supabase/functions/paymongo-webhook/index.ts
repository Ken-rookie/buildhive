import { createClient } from "npm:@supabase/supabase-js@2";
import { isValidPaymongoSignature } from "./signature.js";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  const webhookSecret = Deno.env.get("PAYMONGO_WEBHOOK_SECRET");
  const signature = request.headers.get("Paymongo-Signature");
  const configuredMode = Deno.env.get("PAYMONGO_MODE")?.toLowerCase();
  if (!webhookSecret || !signature) return jsonResponse({ error: "Invalid signature." }, 401);
  if (configuredMode !== "test" && configuredMode !== "live") {
    console.error("Missing or invalid PayMongo mode.");
    return jsonResponse({ error: "Webhook is not configured." }, 500);
  }

  const rawBody = await request.text();
  if (!(await isValidPaymongoSignature(rawBody, webhookSecret, signature, configuredMode))) {
    return jsonResponse({ error: "Invalid signature." }, 401);
  }

  let payload: any;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: "Invalid JSON." }, 400);
  }

  const event = payload?.data?.attributes;
  if (event?.type !== "checkout_session.payment.paid") {
    return jsonResponse({ received: true, ignored: true });
  }
  if (
    !["test", "live"].includes(configuredMode ?? "") ||
    event.livemode !== (configuredMode === "live")
  ) {
    console.error("PayMongo webhook event does not match configured mode.");
    return jsonResponse({ received: true, ignored: true });
  }

  const session = event.data;
  const attributes = session?.attributes;
  const orderId = attributes?.metadata?.order_id ?? attributes?.reference_number;
  const sessionId = session?.id;
  const paidPayment = attributes?.payments?.find((payment: any) =>
    payment?.attributes?.status === "paid"
  );
  const paymentAttributes = paidPayment?.attributes;
  if (
    typeof orderId !== "string" ||
    typeof sessionId !== "string" ||
    !paymentAttributes ||
    paymentAttributes.currency !== "PHP" ||
    !Number.isSafeInteger(paymentAttributes.amount)
  ) {
    return jsonResponse({ error: "Invalid payment event." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = getServiceRoleKey();
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing webhook database secrets.");
    return jsonResponse({ error: "Webhook is not configured." }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: result, error: paymentError } = await supabase.rpc(
    "record_paymongo_payment",
    {
      p_order_id: orderId,
      p_session_id: sessionId,
      p_amount: paymentAttributes.amount,
      p_currency: paymentAttributes.currency,
    },
  );
  if (paymentError) {
    console.error("Could not record PayMongo payment.", paymentError.message);
    return jsonResponse({ error: "Could not process payment." }, 500);
  }
  if (result === "late_payment_review") {
    console.error("Payment arrived after stock was released; manual review is required.", orderId);
    return jsonResponse({ received: true, manual_review_required: true });
  }
  if (result === "session_mismatch" || result === "not_paymongo_order") {
    console.error("Webhook session did not match a PayMongo order.", orderId);
    return jsonResponse({ received: true, ignored: true });
  }

  return jsonResponse({ received: true });
});