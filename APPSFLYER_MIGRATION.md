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
