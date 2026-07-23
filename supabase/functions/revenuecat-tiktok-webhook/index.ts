// RevenueCat webhook -> TikTok Events API bridge.
//
// Reports the REAL paid-conversion moments (which happen server-side, days after a trial starts
// and often with the app closed, so the client SDK can't see them) to TikTok so its algorithm can
// optimize toward actual payers, not just trial-starters.
//
// Forwarded events (money actually moved):
//   • TRIAL_CONVERSION  — a free trial converted to a paid subscription  ← the key one
//   • RENEWAL           — a recurring paid renewal (recurring revenue / LTV)
// NOT forwarded here:
//   • INITIAL_PURCHASE / trial start — the client already reports StartTrial / Subscribe, so
//     sending them here too would double-count.
//
// Everything fails SAFE: we always return 200 so RevenueCat doesn't retry-storm; errors are logged.
//
// Required function secrets (supabase secrets set ...):
//   REVENUECAT_WEBHOOK_SECRET  — the Authorization header value you set in the RevenueCat dashboard
//   TIKTOK_ACCESS_TOKEN        — Events API access token (TikTok Events Manager → Settings)
//   TIKTOK_APP_ID              — your TikTok app id (event_source_id for app events)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const TIKTOK_ACCESS_TOKEN = Deno.env.get("TIKTOK_ACCESS_TOKEN") ?? "";
const TIKTOK_APP_ID = Deno.env.get("TIKTOK_APP_ID") ?? "";

const TIKTOK_EVENTS_URL = "https://business-api.tiktok.com/open_api/v1.3/event/track/";

// RevenueCat event types that represent real money changing hands.
const PAID_EVENTS = new Set(["TRIAL_CONVERSION", "RENEWAL"]);

async function sha256(input: string): Promise<string> {
  const data = new TextEncoder().encode(input.trim().toLowerCase());
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Pull a reserved subscriber attribute (e.g. "$idfv", "$idfa") from the RC event. */
function attr(event: Record<string, unknown>, key: string): string | undefined {
  const attrs = event?.subscriber_attributes as Record<string, { value?: string }> | undefined;
  const v = attrs?.[key]?.value;
  return v && v.length > 0 ? v : undefined;
}

serve(async (req) => {
  // Always answer 200 so RevenueCat never retry-storms us; we log problems instead.
  const done = () => new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });

  try {
    // 1) Verify the shared secret RevenueCat sends as the Authorization header.
    const auth = req.headers.get("authorization") ?? "";
    if (!REVENUECAT_WEBHOOK_SECRET || auth !== REVENUECAT_WEBHOOK_SECRET) {
      console.warn("RC->TikTok: rejected webhook (bad/missing Authorization)");
      return done();
    }

    const body = await req.json();
    const event = body?.event ?? {};
    const type: string = event?.type ?? "";

    if (!PAID_EVENTS.has(type)) {
      // Not a paid-money event — ignore (trial starts / immediate buys are handled client-side).
      return done();
    }

    // 2) Value + currency (use the price actually charged).
    const value = Number(event.price_in_purchased_currency ?? event.price ?? 0);
    const currency = String(event.currency ?? "USD");

    // 3) Identifiers for TikTok matching. Without ATT there's no IDFA, so we lean on IDFV +
    //    a hashed app-user id. Matching is best-effort (weaker than IDFA) — see notes.
    const idfa = attr(event, "$idfa");
    const idfv = attr(event, "$idfv");
    const appUserId: string | undefined = event.app_user_id ?? event.original_app_user_id;

    const user: Record<string, unknown> = {};
    if (idfa) user.idfa = idfa;
    if (idfv) user.idfv = idfv;
    if (appUserId) user.external_id = [await sha256(appUserId)];

    const payload = {
      event_source: "app",
      event_source_id: TIKTOK_APP_ID,
      data: [
        {
          event: "Subscribe",                              // standard TikTok event
          event_time: Math.floor(Date.now() / 1000),
          event_id: String(event.id ?? `${appUserId}-${type}-${event.event_timestamp_ms ?? Date.now()}`),
          user,
          properties: {
            value,
            currency,
            content_type: "product",
            contents: [{ content_id: String(event.product_id ?? "subscription"), price: value }],
          },
        },
      ],
    };

    if (!TIKTOK_ACCESS_TOKEN || !TIKTOK_APP_ID) {
      console.warn("RC->TikTok: missing TIKTOK_ACCESS_TOKEN / TIKTOK_APP_ID — not forwarding");
      return done();
    }

    const res = await fetch(TIKTOK_EVENTS_URL, {
      method: "POST",
      headers: {
        "Access-Token": TIKTOK_ACCESS_TOKEN,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const resText = await res.text();
    console.log(`RC->TikTok: type=${type} value=${value}${currency} tiktokStatus=${res.status} resp=${resText}`);

    return done();
  } catch (e) {
    console.error("RC->TikTok: error", e);
    return done(); // fail safe
  }
});
