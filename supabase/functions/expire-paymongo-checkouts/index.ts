import { createClient } from "npm:@supabase/supabase-js@2";

const holdDurationMs = 60 * 60 * 1000;

function constantTimeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  if (leftBytes.length !== rightBytes.length) return false;
  let difference = 0;
  for (let index = 0; index < leftBytes.length; index++) {
    difference |= leftBytes[index] ^ rightBytes[index];
  }
  return difference === 0;
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

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  const cleanupSecret = Deno.env.get("PAYMONGO_CLEANUP_SECRET");
  const suppliedSecret = request.headers.get("x-paymongo-cleanup-secret");
  if (!cleanupSecret || !suppliedSecret || !constantTimeEqual(cleanupSecret, suppliedSecret)) {
    return jsonResponse({ error: "Unauthorized." }, 401);
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
    console.error("Missing cleanup function secrets.");
    return jsonResponse({ error: "Cleanup is not configured." }, 500);
  }
  const expectedKeyPrefix = paymongoMode === "test" ? "sk_test_" : "sk_live_";
  if (!paymongoSecretKey.startsWith(expectedKeyPrefix)) {
    console.error("PayMongo key does not match configured mode.");
    return jsonResponse({ error: "Cleanup is not configured." }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const expireBefore = new Date(Date.now() - holdDurationMs).toISOString();
  const { data: orders, error: queryError } = await supabase
    .from("orders")
    .select("id, paymongo_checkout_session_id")
    .eq("payment_method", "paymongo")
    .eq("payment_status", "unpaid")
    .eq("status", "pending")
    .not("paymongo_checkout_session_id", "is", null)
    .lt("paymongo_checkout_created_at", expireBefore)
    .order("paymongo_checkout_created_at", { ascending: true })
    .limit(10);

  if (queryError) {
    console.error("Could not load expired checkout candidates.", queryError.message);
    return jsonResponse({ error: "Could not load checkout candidates." }, 500);
  }

  const credentials = btoa(`${paymongoSecretKey}:`);
  let expired = 0;
  let stillActive = 0;
  let failed = 0;

  for (const order of orders ?? []) {
    const sessionId = order.paymongo_checkout_session_id as string;
    const { data: claimed, error: claimError } = await supabase.rpc(
      "claim_paymongo_checkout_expiry",
      {
        p_order_id: order.id,
        p_session_id: sessionId,
        p_before: expireBefore,
      },
    );
    if (claimError) {
      console.error("Could not claim checkout expiry.", order.id, claimError.message);
      failed++;
      continue;
    }
    if (claimed !== true) continue;

    const sessionUrl = `https://api.paymongo.com/v1/checkout_sessions/${encodeURIComponent(sessionId)}`;
    try {
      const expireResponse = await fetch(`${sessionUrl}/expire`, {
        method: "POST",
        headers: { Authorization: `Basic ${credentials}` },
      });
      if (!expireResponse.ok) {
        console.warn("PayMongo session expiration was not accepted.", order.id, expireResponse.status);
      }

      const sessionResponse = await fetch(sessionUrl, {
        headers: { Authorization: `Basic ${credentials}` },
      });
      const sessionBody = await sessionResponse.json().catch(() => null);
      const session = sessionBody?.data;
      const attributes = session?.attributes;
      if (!sessionResponse.ok || !attributes) {
        throw new Error(`Could not verify session state (${sessionResponse.status}).`);
      }
      if (attributes.livemode !== (paymongoMode === "live")) {
        throw new Error("Session mode does not match configured mode.");
      }

      const paidPayment = (attributes.payments ?? []).find((payment: any) =>
        payment?.attributes?.status === "paid"
      );
      if (paidPayment) {
        const paymentAttributes = paidPayment.attributes;
        const { error: paymentError } = await supabase.rpc("record_paymongo_payment", {
          p_order_id: order.id,
          p_session_id: session.id,
          p_amount: paymentAttributes.amount,
          p_currency: paymentAttributes.currency,
        });
        if (paymentError) throw new Error(`Could not reconcile paid session: ${paymentError.message}`);
        continue;
      }

      if (attributes.status === "expired") {
        const { data: didExpire, error: expireError } = await supabase.rpc(
          "expire_paymongo_order",
          { p_order_id: order.id, p_session_id: session.id },
        );
        if (expireError) throw new Error(`Could not release expired order: ${expireError.message}`);
        if (didExpire) expired++;
        continue;
      }

      await supabase.rpc("release_paymongo_checkout_lock", {
        p_order_id: order.id,
        p_request_key: null,
      });
      stillActive++;
    } catch (error) {
      await supabase.rpc("release_paymongo_checkout_lock", {
        p_order_id: order.id,
        p_request_key: null,
      });
      console.error("Could not expire PayMongo checkout.", order.id, error);
      failed++;
    }
  }

  return jsonResponse({ received: true, expired, still_active: stillActive, failed });
});