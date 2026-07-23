# BeYou — Work Session Summary (context handoff)

Purpose: hand this to a new Claude session so it has accurate context on what was done and what's
pending. Written 2026-07-22.

## How to build (important)
Build the **workspace**, not the bare project (CocoaPods: TikTok SDK):
```
cd /Users/oduduabasivictor/Downloads/BeYou/BeYou/BeYou/
xcodebuild build -workspace BeYou.xcworkspace -scheme BeYou -destination 'generic/platform=iOS'
```
Every change below was built successfully with this command. This is an Xcode 16
**synchronized-folder** project, so new files added on disk are auto-included in the target.

## Key architecture facts
- **Live onboarding coordinator = `OnboardingCoordinator2`** (`BeYou/Views/Onboarding_2/`). The older
  `Coordinators/OnboardingCoordinator.swift` is **dead code** — do not edit it expecting effects.
- Flow: Splash → Welcome → Onboarding (Coordinator2) → Paywall (step 29) → Setup → Main.
- **RevenueCat** = entitlements (entitlement key: `BeYou_Pro`), `SubscriptionManager.shared.isProUser`.
- **Superwall** = paywall UI, placement **`onboarding_paywall`**, bridged to RevenueCat.
- Analytics = **Mixpanel** (`AnalyticsManager`). Also TikTok SDK for ads (see AppsFlyer plan below).
- Root routing = `ContentView.swift` (switch on `appState.currentScreen`).

---

## Work done this session

### 1. Onboarding profile save moved BEFORE paywall  ✅ in code
- Problem: Supabase `saveOnboardingProfile` ran at the FINAL onboarding step (after the paywall), so
  users who didn't pay were never saved → empty/absent rows.
- Fix: moved `UserProfileService.shared.saveOnboardingProfile(...)` to **step 28** (commitment,
  before the paywall) in `OnboardingCoordinator2.swift`; removed the duplicate call at step 31.

### 2. Re-added the review/rating onboarding screen  ✅ in code
- `Onboarding2RatingView` (existing file) was re-inserted at **step 24** in `OnboardingCoordinator2`
  (re-chained 23 → 24 → 25). It shows testimonials + fires the native `requestReview()`.

### 3. Crash fix: background/foreground after alarm completion  ✅ in code
- Symptom: rare crash when rapidly backgrounding/foregrounding AFTER an alarm completed — started
  after the post-completion "affirmation" screen was added.
- Cause: `MainAppView` scene-phase handler restarts the alarm audio loop on foreground while
  `showAlarmMission` is still true (it stays true through the completion + affirmation screens). The
  restart + retry churn on the shared `AVAudioSession` could throw an uncaught CoreAudio exception.
- Fix: added `onCompleted` callback to `AlarmDismissFlowView` (fires in `recordCompletion`), a
  `missionCompleted` flag in `MainAppView`, and gated the foreground audio restart on
  `!missionCompleted`; flag resets when a new mission opens. Files: `AlarmDismissFlowView.swift`,
  `MainAppView.swift`.

### 4. Custom push-up mission icon  ✅ in code
- SF Symbols has no push-up glyph (`figure.core.training` was wrong). Created a custom **template**
  vector asset `BeYou/Assets.xcassets/pushups.imageset/pushups.svg` and a helper view
  `BeYou/Views/MissionIcon.swift`.
- `MissionIcon` renders the custom asset for "Push Ups", SF Symbol otherwise. Supports a `twoTone`
  flag: pickers render the ORIGINAL two-tone art (white figure + faded ground) on the colored
  circle; other spots render it as a tinted template.
- Replaced `Image(systemName:)` at ALL 6 mission-icon render sites (onboarding challenge picker,
  onboarding "why it works" card, alarms list row, alarm mission selector grid, alarm editor summary,
  home mission card). NOTE: the drawn SVG is a pike/triangle pose approximation; user may want to
  refine `pushups.svg` (just replace the file, no code change).

### 5. Default affirmation theme → Ocean Gradient  ✅ in code
- Changed default from `starry-mountains` → `ocean-gradient` at 6 `@AppStorage` fallbacks (main app)
  + 2 widget spots (`BeYouWidgets/WidgetDataProvider.swift`). Only affects users who never picked a
  theme.

### 6. Sheet pull-to-dismiss fix  ✅ in code
- `MissionPickerSheet` + `SoundPickerSheet` (`AlarmsView.swift`): `NavigationView` → `NavigationStack`,
  added `.presentationDetents([.large])` + `.presentationDragIndicator(.visible)`. Fixes the sheets
  stalling halfway on drag-down.

### 7. Home mission/sound cards made non-clickable  ✅ in code
- Removed the `Button` wrapper from `missionCard` + `soundCard` in `AlarmHomeView.swift`. Left the
  now-unreachable sheet/persist code in place (harmless dead code) per user's choice.

### 8. 5-second minimum save on the home card edit  ✅ in code
- Confirmed the Alarm tab already enforces a 5s spinner floor via
  `AlarmScheduler.syncAwaiting` (`minSaveDuration = 5`). The home-card edit used the non-awaited
  `sync` (no floor). Changed it to `await AlarmScheduler.syncAwaiting(updated)` in `AlarmHomeView.swift`
  so it matches (waits until armed + 5s floor).

### 9. 4-second minimum on the "Analyzing…" overlay (camera missions)  ✅ in code
- Added `MissionAnalyzing.holdFloor(since:)` (`minimumDuration = 4`) to `AnalyzingOverlay.swift`, wired
  into all 3 camera missions right after the AI verifier returns: `ExerciseMissionView` (push-ups/
  squats), `ItemSearchMissionView`, and `PhotoMissionView` (sky/bed/grass, in `AlarmDismissFlowView`).
  Overlay now stays up for max(actual AI time, 4s).

### 10. Splash screen redesign  ✅ in code
- `SplashView.swift`: replaced the app-icon image with the **"BeYou" wordmark** (bold italic) that
  pops in and continuously bounces up/down. Removed the "BeYou Alarm" subtitle, kept "never snooze
  again".

### 11. Paywall escape hardening + reactive subscription gate  ⚠️ NEEDS TO SHIP
This was the biggest piece. Non-subscribers were reaching the app / creating alarms.

- **Hardened onboarding paywall** (`Onboarding2PaywallView.swift`): removed the fail-open escape
  routes — the timeout "give up and let in", and the "skip >3 times and let in". Bumped the
  presentation timeout 6s → **20s** (video paywall is slow to load on fresh installs). Now the only
  ways past onboarding are a real purchase/restore or an actual `isProUser` entitlement; everything
  else re-presents the paywall.
- **Guarded the Superwall feature block** — the `register(...) { onPurchased() }` trailing closure was
  still advancing UNCONDITIONALLY. Superwall runs that block on a plain dismiss when the campaign is
  **Non-Gated**, which was the real leak. Now guarded: `if SubscriptionManager.shared.isProUser {
  onPurchased() }`. Real purchases still advance via `onDismiss(.purchased)`.
- **Reactive hard gate** (`ContentView.swift`): the `.main` route now renders `SubscriptionGateView`
  instead of `MainAppView` when `subscriptions.hasResolvedEntitlements && !subscriptions.isProUser`.
  Bound to `@Published isProUser`, so it swaps AT ANY MOMENT (e.g. a mid-session lapse), not just on
  launch. Catches cancelled/lapsed subscribers.
- **`SubscriptionGateView.swift`** (new): bare presenter — plain background that presents the SAME
  `onboarding_paywall` (tagged `source: reactive_gate`), re-presents on dismiss, retries if slow.
  Unlock is automatic (isProUser flips → root swaps to app). It has NO visible UI/buttons of its own;
  the Superwall paywall (which has its own Restore link) is what the user sees. (An earlier demo
  `LockedGateView` with Unlock/Restore buttons was built then DELETED — do not resurrect it.)
- **`SubscriptionManager.swift`**: added `@Published private(set) var hasResolvedEntitlements`
  (renamed from `hasCompletedInitialSync`) so the gate doesn't flash the paywall at a real subscriber
  before RevenueCat resolves on launch.
- **Removed the OLD expired-paywall mechanism** from `BeYouSwiftApp.swift` (`showExpiredPaywall` state,
  `showExpiredPaywallFlow()`, `showPaywallIfExpired()`, the triggers). It conflicted with the new gate
  (double paywall registration). Replaced with a plain `refreshEntitlements()` on launch + foreground
  so the gate stays current. The gate is now the ONLY paywall trigger for lapsed users.
- **Analytics funnel split**: `trackPaywallShown`/`trackPaywallDismissed` gained an optional `source`
  param; onboarding paywall tags `source: "onboarding"`, the gate tags `source: "reactive_gate"`
  (both Mixpanel event + Superwall register `params`). Same `onboarding_paywall` placement for both.

**STATUS / IMPORTANT:**
- All the above is in the LOCAL codebase and builds clean, but the **currently-live App Store build
  still has the unguarded feature block** and escapes. Confirmed via Mixpanel: escape events carried
  `source: onboarding` (proves that build had the source tag + hardened paywall but NOT the feature-
  block guard). **A new build must be submitted** to get the full fix live.
- **Immediate mitigation (no app update, do on Superwall dashboard):** set the `onboarding_paywall`
  campaign (and `transaction_abandon`) **Feature Gating = Gated**. That stops Superwall from running
  the feature block on dismiss → closes the leak on the live build. VERIFY in Mixpanel that
  `is_subscribed:false` + "Alarm Created" events stop after flipping it.
- Superwall dashboard was checked: audience "All Users", 7-paywall A/B test, no holdout, weights sum
  to 100 (two 0% variants don't count). Paywalls render fine (video + 3-page). So the leak was code/
  gating, not the campaign split.

### 12. AppsFlyer MMP migration — PLANNED, NOT STARTED
- Full plan in `APPSFLYER_MIGRATION.md` (project root). Summary: adopt AppsFlyer as the MMP; connect
  TikTok as an integrated partner INSIDE AppsFlyer (S2S); remove the TikTok SDK. Must be a staged
  cutover because TikTok ads are currently live on the TikTok SDK. Never run two SKAN-managing SDKs
  in parallel.

---

## Pending / next steps
1. **Ship a new build** with the paywall fixes (item 11). Before archiving, fix the known appex
   `CFBundleShortVersionString` mismatch (extension `1.0` vs app version) or App Store Connect rejects
   the upload. Bump app version/build number.
2. **On Superwall dashboard now:** set `onboarding_paywall` + `transaction_abandon` to **Gated**
   (immediate live mitigation) and confirm escapes stop in Mixpanel.
3. **AppsFlyer migration** when ready — see `APPSFLYER_MIGRATION.md`.
4. Optional: refine `pushups.svg` art; optionally gate `.setup`/`.screenTimeConnect` routes too
   (currently only `.main` is gated — sufficient since those are only reached mid-onboarding after
   the paywall).

## Notes
- Simulator can't render Superwall paywalls (no StoreKit products) — test the gate/paywall on a REAL
  device with a sandbox account. On simulator the gate shows a plain `F8F8F8` background.
- Disk on this Mac fills up repeatedly; safe to clear Xcode DerivedData / iOS DeviceSupport / SwiftPM
  cache / app updater caches (all regenerable). Keep Xcode Archives (crash symbolication).
