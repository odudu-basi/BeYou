# BeYou Notification System Guide

## Overview
BeYou uses a comprehensive notification system to keep users informed about their app usage, streaks, discipline score, and scheduled disconnect times.

## Notification Types

### 1. Disconnect Time Warnings
**When:** 10 minutes before a scheduled disconnect time starts
**Trigger:** Scheduled automatically when user sets up disconnect times

**Examples:**
- "Morning Focus Starting Soon - Your morning disconnect time starts in 10 minutes"
- "Bedtime Focus Starting Soon - Your bedtime disconnect time starts in 10 minutes"
- "Work Focus Starting Soon - Your work disconnect time starts in 10 minutes"

**Implementation:** `NotificationManager.scheduleDisconnectWarning(type:startTime:)`

### 2. Disconnect Time Started
**When:** When a scheduled disconnect time begins
**Trigger:** DeviceActivityMonitor `intervalDidStart`

**Examples:**
- "🌅 Morning Focus Active - Your morning disconnect time has started"
- "🌙 Bedtime Focus Active - Time to wind down for the night"
- "💼 Work Focus Active - Stay productive during work hours"

**Implementation:** DeviceActivityMonitorExtension

### 3. Disconnect Time Ended
**When:** When a scheduled disconnect time ends (and user is still within daily limit)
**Trigger:** DeviceActivityMonitor `intervalDidEnd`

**Examples:**
- "Morning Focus Complete - Great job starting your day mindfully!"
- "Bedtime Focus Complete - Hope you had a restful night!"
- "Work Focus Complete - Productive session complete!"

**Implementation:** DeviceActivityMonitorExtension

### 4. App Limit Warnings
**When:** User approaches their daily app intention limit
**Trigger:** When user opens apps (at 8/10, 9/10, 10/10)

**Examples:**
- At 8/10: "Almost at Your Limit - You've opened Instagram 8/10 times today"
- At 9/10: "Last Chance - One more open left for Instagram today"
- At 10/10: "Daily Limit Reached - You've reached your limit for Instagram today"

**Implementation:** `NotificationManager.scheduleAppLimitWarning(currentOpens:limit:appName:)`

### 5. Session Expiry Warning
**When:** 1 minute before an unlocked app session expires
**Trigger:** When user unlocks an app after breakthrough

**Example:**
- "Instagram Session Ending Soon - You have 1 minute left in your Instagram session"

**Implementation:** `NotificationManager.scheduleSessionExpiryWarning(appName:expiryTime:)`

### 6. Streak Notifications
**When:** At midnight (12:01 AM) after daily reset
**Trigger:** Daily reset in `AppState.checkDailyReset()`

**Examples:**
- New streak: "🔥 Streak Started! - Great job! You stayed within your limit yesterday. Keep it going!"
- Continuing: "🔥 7 Day Streak! - Amazing! You've maintained your streak for 7 days"
- Broken: "Streak Reset - You exceeded your limit yesterday. Start fresh today!"

**Implementation:** `NotificationManager.scheduleStreakNotification(streakDays:didMaintainStreak:)`

### 7. Discipline Score Updates
**When:** When discipline score changes significantly
**Trigger:** After "Nevermind" (+2) or breakthrough (-1)

**Examples:**
- Increase: "💪 Discipline Score +2 - Your discipline score is now 52. Keep making mindful choices!"
- Milestone: "🌟 75 Discipline Score! - You're building incredible self-control. Keep going!"
- Perfect: "🏆 Perfect Score! - Amazing! You've reached 100 discipline score!"

**Implementation:** `NotificationManager.showDisciplineScoreUpdate(score:change:)`

### 8. Midnight Reset
**When:** Daily at midnight (12:00 AM)
**Trigger:** Recurring notification

**Example:**
- "Daily Reset - Your app limits have been reset. Make today count!"

**Implementation:** `NotificationManager.scheduleMidnightReset()`

### 9. Daily Reminder
**When:** Daily at noon (12:00 PM)
**Trigger:** Recurring notification

**Example:**
- "How's Your Day Going? - Check your progress and stay mindful of your goals"

**Implementation:** `NotificationManager.scheduleDailyReminder()`

## Permission Request

### When Requested
Notifications are requested on first app launch in `BeYouSwiftApp.swift` via the `.task` modifier.

### Implementation
```swift
private func requestNotificationPermission() async {
    let granted = await notificationManager.requestAuthorization()
    if granted {
        print("Notification permission granted")
    } else {
        print("Notification permission denied")
    }
}
```

### User Flow
1. User opens BeYou for the first time
2. iOS shows notification permission dialog
3. If granted: All notifications are enabled
4. If denied: Notifications won't be delivered (app still works)

## Testing Notifications

### Test 1: Disconnect Time Warnings
1. Set up a disconnect time (e.g., "Before Bed" 9 PM - 7 AM)
2. Wait until 8:50 PM (10 minutes before)
3. Should receive: "Bedtime Focus Starting Soon"
4. At 9:00 PM should receive: "🌙 Bedtime Focus Active"
5. At 7:00 AM should receive: "Bedtime Focus Complete"

### Test 2: App Limit Warnings
1. Set app intention to 10 times/day
2. Open blocked app 8 times → "Almost at Your Limit"
3. Open 9th time → "Last Chance"
4. Open 10th time → "Daily Limit Reached"

### Test 3: Session Expiry
1. Breakthrough to unlock an app (5 min session)
2. After 4 minutes → "Instagram Session Ending Soon"
3. After 5 minutes → App re-blocks

### Test 4: Streak Notifications
1. Stay within daily limit
2. At midnight → "🔥 Streak Started!" or "🔥 X Day Streak!"
3. Exceed daily limit
4. At midnight → "Streak Reset"

### Test 5: Discipline Score
1. Click "Nevermind" on intervention screen
2. Immediately receive: "💪 Discipline Score +2"
3. Breakthrough to unlock app
4. Receive: "Discipline Score -1"

## Notification Settings

### Checking Authorization Status
```swift
NotificationManager.shared.checkAuthorizationStatus()
// Updates isAuthorized published property
```

### Canceling Notifications
```swift
// Cancel specific notification
NotificationManager.shared.cancelNotification(identifier: .sessionExpiry)

// Cancel disconnect warning
NotificationManager.shared.cancelDisconnectWarning(type: "Morning")

// Cancel all notifications
NotificationManager.shared.cancelAllNotifications()
```

### Clearing Badge
```swift
NotificationManager.shared.clearBadge()
```

### Getting Pending Notifications
```swift
let pending = await NotificationManager.shared.getPendingNotifications()
print("Pending notifications: \(pending.count)")
```

## Integration Points

### 1. BeYouSwiftApp.swift
- Requests notification permission on launch
- Schedules recurring notifications (midnight reset, daily reminder)
- Schedules disconnect warnings based on user settings

### 2. AppState.swift
- `checkDailyReset()` → Streak notifications
- `recordNevermind()` → Discipline score +2 notification
- `recordBreakthrough()` → App limit warnings + discipline score -1
- `unlockApp()` → Session expiry warning

### 3. ScreenTimeManager.swift
- `setupDisconnectSchedule()` → Disconnect warning notifications
- `stopAllSchedules()` → Cancel disconnect warnings

### 4. DeviceActivityMonitorExtension
- `intervalWillStartWarning()` → 10 min before disconnect starts
- `intervalDidStart()` → Disconnect time started
- `intervalWillEndWarning()` → 5 min before disconnect ends
- `intervalDidEnd()` → Disconnect time ended
- `eventWillReachThresholdWarning()` → Approaching app limit
- `eventDidReachThreshold()` → Daily limit reached

## Notification Identifiers

All notifications use specific identifiers for management:

```swift
enum NotificationIdentifier: String {
    case disconnectWarning = "disconnect_warning"
    case appLimitWarning = "app_limit_warning"
    case sessionExpiry = "session_expiry"
    case streakUpdate = "streak_update"
    case midnightReset = "midnight_reset"
    case disciplineScore = "discipline_score"
    case dailyReminder = "daily_reminder"
}
```

## Troubleshooting

### Notifications not showing
1. Check notification permission: Settings → BeYou → Notifications
2. Verify `isAuthorized = true` in NotificationManager
3. Check Console for "Failed to schedule..." errors
4. Ensure notification content and trigger are valid

### Disconnect warnings not firing
1. Verify disconnect schedule is saved to App Groups
2. Check that time is in the future (not past)
3. Ensure notification permission is granted
4. Test with `getPendingNotifications()` to see if scheduled

### Session expiry not working
1. Verify `unlockApp()` is called after breakthrough
2. Check that `expiryTime` is set correctly
3. Ensure session duration is > 1 minute (for warning)

### Streak notifications not appearing
1. Verify `checkDailyReset()` is called at midnight
2. Check that `lastResetDate` is updating correctly
3. Ensure streak calculation logic is working

## Best Practices

1. **Always check authorization** before scheduling notifications
2. **Use specific identifiers** for each notification type
3. **Cancel old notifications** before scheduling new ones
4. **Test on physical device** (notifications don't work reliably in simulator)
5. **Handle permission denial** gracefully (app should work without notifications)
6. **Clear badges** when user opens the app
7. **Use meaningful titles and bodies** that help user understand the notification
8. **Schedule recurring notifications** on app launch (not every time)

## Future Enhancements

Potential additions for Phase 2:
- [ ] Interactive notifications (e.g., "Extend session by 5 min")
- [ ] Notification categories for better organization
- [ ] Rich notifications with images/progress bars
- [ ] Weekly summary notifications
- [ ] Achievement notifications (e.g., "7 day streak milestone!")
- [ ] Custom notification sounds
- [ ] Critical alerts for important notifications
- [ ] Notification actions (e.g., "View Stats", "Start Focus")
