# AppsFlyer (MMP) Migration Plan

Status: **Not started — planning only.** Come back to this when ready.

Goal: adopt **AppsFlyer** as the app's MMP (single source of truth for attribution), with
**TikTok connected *through* AppsFlyer** — not running as a second, independent attribution SDK.

Context at time of writing: we are **actively running TikTok ads on the TikTok Business SDK**, so
this must be a **staged cutover**, never an abrupt SDK removal.

---

## The one hard rule
- **Never run two attribution SDKs managing SKAdNetwork (SKAN) at the same time in production.**
  iOS allows only one conversion-value update per postback window; TikTok SDK + AppsFlyer both try
  to own SKAN and will overwrite each other → corrupted attribution.
- **Never leave TikTok with no event source.** TikTok campaign optimization depends on receiving
  conversion events. The switch from "TikTok SDK sends events" → "AppsFlyer sends events to TikTok"
  must be continuous.
- Therefore: the SDK swap happens as **one prepared cutover**, not "add AppsFlyer now, remove TikTok
  later."

## Target architecture
- **AppsFlyer SDK** = the ONE attribution SDK. Owns install attribution, in-app event tracking, and
  **SKAN**.
- **TikTok** = an **integrated partner inside the AppsFlyer dashboard** (server-to-server postbacks).
  AppsFlyer forwards conversion events to TikTok so ad optimization keeps working — no TikTok SDK
  needed for attribution.
- **TikTok Business SDK = removed** (or at minimum, its SKAN/attribution neutralized so AppsFlyer is
  the sole SKAN authority).

Mental model: don't add AppsFlyer *next to* TikTok — put AppsFlyer *in the middle*, and TikTok
becomes one channel feeding into it.

---

## Phase 1 — Dashboard setup FIRST (no app change, zero risk to live ads)
1. Create the app in **AppsFlyer**; get the **dev key** + **App ID**.
2. In AppsFlyer, connect **TikTok as an integrated partner** (link the TikTok Ads account). This
   builds the pipe so TikTok receives events *from AppsFlyer* via S2S.
3. **Map events** in that integration so TikTok keeps optimizing for the same signals (see mapping
   table below). Critical: the current "onboarding complete = registration" signal must be
   preserved.
4. Configure the **SKAN conversion-value schema** in AppsFlyer (AppsFlyer will own SKAN going
   forward).

At this point nothing in the app has changed — TikTok still gets SDK data, ads run normally.

## Phase 2 — One app update that performs the cutover
5. Add the **AppsFlyer SDK** (init with dev key + App ID; handle ATT prompt; attribution/deep-link
   callbacks). AppsFlyer takes over attribution + SKAN + events.
6. **Migrate current TikTok events to fire as AppsFlyer events** (AppsFlyer forwards them to TikTok).
7. **Remove the TikTok Business SDK in the SAME build** — no parallel-SKAN window. Also clean up the
   redundant integration (TikTok SDK is currently added via BOTH CocoaPods and SPM — see
   `memory/build-command.md`).
8. Ship the update.

After rollout, TikTok receives events via AppsFlyer postbacks instead of the SDK — same signals,
different pipe.

---

## Event mapping to fill in (Phase 1, step 3)
Current TikTok events live in `BeYou/Managers/TikTokManager.swift` (e.g. `trackAppOpen`,
`trackOnboardingComplete`). Map each to an AppsFlyer event, then map that AppsFlyer event to the
TikTok event in the AppsFlyer partner config so campaigns keep optimizing.

| App action | Current TikTok event | AppsFlyer event (af_*) | TikTok event (via AF) |
|---|---|---|---|
| App open | (trackAppOpen) | af_app_opened (or session) | — |
| Onboarding complete | (trackOnboardingComplete, "registration") | `af_complete_registration` | CompleteRegistration |
| Purchase / trial start | (RevenueCat) | `af_purchase` / `af_start_trial` | (Subscribe / StartTrial) |

(Confirm exact current TikTok event names in `TikTokManager.swift` when we start.)

## Things to plan around
- **Short re-learning period** when the event source changes (SDK → AppsFlyer S2S) — TikTok
  optimization may wobble for a few days. Consider not launching big new campaigns right at the
  switch, or lowering budgets temporarily.
- **Gradual rollout** — users update over days; for a while both old-SDK and new-AppsFlyer users
  report. AppsFlyer + TikTok dedupe on their side. Normal.
- **Verify event parity** after the build is live: confirm install, onboarding-complete/registration,
  and purchase events arrive via AppsFlyer in both AppsFlyer and TikTok Ads Manager before trusting
  it / scaling spend.

## Prereqs to gather before Phase 2
- [ ] AppsFlyer **dev key** + **App ID**
- [ ] TikTok linked as a partner in AppsFlyer (Phase 1 done)
- [ ] Event mapping confirmed
- [ ] Decision: fully remove TikTok SDK vs. neutralize its SKAN/attribution
- [ ] Timing chosen (avoid switching during a critical campaign push)

## Relevant code touchpoints (for Phase 2)
- `BeYou/Managers/TikTokManager.swift` — current TikTok SDK config + event calls (to migrate/remove)
- `BeYou/BeYouSwiftApp.swift` — `TikTokManager.shared.configure()` in `init()` (add AppsFlyer init here)
- Podfile / SPM — TikTok SDK is integrated twice (CocoaPods + SPM); consolidate/remove; add AppsFlyer
- ATT prompt handling — AppsFlyer attribution quality depends on the ATT flow

---

## UPDATE — 2026-07-26 · MIGRATION IS GO (context for the fresh session)

**Why now:** TikTok SDK event delivery is broken. Root cause = the TikTok SDK is integrated
**twice** (CocoaPods `pod 'TikTokBusinessSDK'` AND SPM `tiktok-business-ios-sdk`) → init and
`trackTTEvent` resolve to different SDK copies → manual events are dropped. Confirmed in TikTok
Events Manager: ~700 new users in a week but **0 Registrations**, SDK data source shows only
`LaunchApp`=144 (Install/Purchase=0); SKAN shows installs working (278) + 2 purchases, but
trials/subscribes can't be optimized. So we're moving to AppsFlyer now.

**Credentials**
- Apple App ID: `6760232059`
- AppsFlyer **Dev Key**: stored in the AppsFlyer MCP env (`DEV_KEY` in `~/.claude.json`) and the
  AppsFlyer dashboard. (Will go into the app's `Secrets`.)
- **AppsFlyer SDK MCP** (`appsFlyer-sdk-mcp`) is added to `~/.claude.json` — use its integration
  wizard after restart.

**Phase 2 — code (do in ONE build):**
1. Add AppsFlyer SDK (CocoaPods `pod 'AppsFlyerFramework'` + `pod install`, or via the MCP wizard).
2. New `AppsFlyerManager`: init with Dev Key + App ID `6760232059`, ATT handling, start.
3. Migrate events: install (auto), trial start → `af_start_trial`, straight paid → `af_purchase`,
   onboarding complete → `af_complete_registration`, app open. (Replace `TikTokManager` calls in
   `SuperwallService`, `OnboardingCoordinator2`, `BeYouSwiftApp`.)
4. **Link AppsFlyer ID ↔ RevenueCat**: pass the AppsFlyer ID to RevenueCat as a subscriber
   attribute so RevenueCat can attribute subscription events to the AppsFlyer install.
5. **Remove the TikTok SDK** — BOTH the CocoaPods pod AND the SPM package, plus `TikTokManager`.
   Fixes the double-integration bug; leaves AppsFlyer as the sole SKAN owner.

**Trial→paid conversions (server-side):** use the **RevenueCat → AppsFlyer integration** (RevenueCat
dashboard → Integrations → AppsFlyer) → AppsFlyer → TikTok. This REPLACES the RevenueCat→TikTok
webhook (`supabase/functions/revenuecat-tiktok-webhook`). **Disable/remove that webhook** so TikTok
doesn't double-count the conversion. (AppsFlyer SDK alone can't see off-device conversions.)

**Dashboard (user):** AppsFlyer → connect TikTok as integrated partner, map events, configure the
**SKAN conversion schema to include the trial event** (so iOS can attribute trials). RevenueCat →
enable the AppsFlyer integration.

**Then:** ship a new build (App Store review) → verify events land in AppsFlyer + TikTok → start the
TikTok **trial campaign** optimizing for the trial event.

**Uncommitted local work** (built, NOT committed): streak celebration feature +
`isProUser`→`activeInCurrentEnvironment` alignment fix. Last pushed checkpoint = commit `05e3806`.
