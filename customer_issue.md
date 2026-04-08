# Customer Issue: Intervention Sheet Not Showing After Shield "Continue"

## Problem
Users tap "Continue" on the shield UI, then open the BeYou app, but the intervention sheet does not appear. They have notification permissions enabled.

## Root Cause
Cross-process UserDefaults sync delay. The shield extension writes `isInterventionActive = true` to the App Group, but when the user quickly switches to the BeYou app, `checkForPendingIntervention()` reads the App Group before the data has synced across processes — so it reads `false` and doesn't show the sheet.

## Where It Happens
- **Shield writes:** `ShieldActionExtension` → `sharedData.saveInterventionActive(true)` + `synchronize()`
- **App reads:** `MainAppView.checkForPendingIntervention()` → `sharedData.loadInterventionActive()`
- **Timing gap:** UserDefaults `synchronize()` across processes is not instant

## Proposed Fix
Add a retry mechanism to `checkForPendingIntervention()`:
1. Check immediately (works if data already synced)
2. If not found, check again after 0.5s delay (catches the sync delay)
3. Optionally check a third time after 1.5s as a safety net

## Files to Modify
- `BeYou/Views/MainAppView.swift` — `checkForPendingIntervention()` function (line ~68)

## Notes
- Darwin notification works when app is in foreground (not applicable here — app is backgrounded/killed)
- Local push notification is sent as fallback, but user may tap app icon instead of notification
- The notification tap path works fine via `setupNotificationListener()` → `ShowInterventionSheet` NSNotification
- The issue is specifically when user opens app manually via icon after tapping Continue
