# Per-App Intentions Guide

## Overview
BeYou now supports **per-app intentions**, allowing users to set different limits for each blocked app instead of one global limit for all apps.

## How It Works

### User Flow

**1. Select Apps to Block (Onboarding Step 12)**
- User selects time waster apps: Instagram, TikTok, YouTube, etc.
- These apps are saved to `selectedAppsForBlocking`

**2. Set Individual App Intentions (Onboarding Step 10)**
- User sees a new screen: "Set App Intentions"
- Shows one app at a time with progress dots
- For each app, user sets:
  - **Times per day**: 10-20 opens
  - **Minutes per session**: 5, 10, 15, 20, 25, 30, 35, or 45 minutes
- Option to "Set same for all apps" for convenience

**Example:**
```
Instagram: 10 times/day, 5 min each
TikTok: 15 times/day, 10 min each
YouTube: 20 times/day, 15 min each
```

**3. App Blocking with Per-App Tracking**
- All selected apps are blocked together using iOS Screen Time API
- Per-app stats are tracked separately:
  - Breakthroughs per app
  - Streaks per app
  - Unlock status per app

**4. Intervention Screen (App-Specific)**
When user tries to open Instagram:
```
Open Instagram?
Don't open this app more than 10 times today

8/10 Opens Today
3 Day Streak 🔥

[Nevermind] [Open Instagram]
```

When user tries to open TikTok (different app):
```
Open TikTok?
Don't open this app more than 15 times today

12/15 Opens Today
5 Day Streak 🔥

[Nevermind] [Open TikTok]
```

**5. Session Duration (Per-App)**
- Instagram unlocked for 5 minutes
- TikTok unlocked for 10 minutes
- Each app tracks its own unlock expiry

## Data Structure

### AppIntention
```swift
struct AppIntention {
    var timesPerDay: Int = 10 // Legacy: backward compatibility
    var minutesPerSession: Int = 5 // Legacy: backward compatibility
    var perAppIntentions: [String: IndividualAppIntention] = [:]
}

struct IndividualAppIntention: Codable {
    var appName: String
    var bundleIdentifier: String?
    var timesPerDay: Int
    var minutesPerSession: Int
}
```

### AppUsageStats (Per-App Tracking)
```swift
struct AppUsageStats {
    var breakthroughsToday: Int = 0 // Legacy: total across all apps
    var breakthroughsByApp: [String: Int] = [:] // New: per-app tracking

    var currentStreak: Int = 0 // Legacy: overall streak
    var currentStreakByApp: [String: Int] = [:] // New: per-app streaks
    var longestStreakByApp: [String: Int] = [:] // New: per-app longest streaks

    var unlockedApps: Set<String> = [] // Which apps are currently unlocked
    var unlockExpiryByApp: [String: Date] = [:] // Expiry time for each app
}
```

## API Methods

### AppState Methods

**Get App-Specific Data:**
```swift
appState.getAppBreakthroughs("Instagram") // Returns 8
appState.getAppLimit("Instagram") // Returns 10
appState.getAppStreak("Instagram") // Returns 3
appState.isAppUnlocked("Instagram") // Returns true/false
```

**Record App-Specific Events:**
```swift
appState.recordBreakthrough(for: "Instagram")
appState.unlockApp(appName: "Instagram")
appState.checkIfUnlockExpired(for: "Instagram")
```

### ScreenTimeManager Methods

**Per-App Blocking:**
```swift
screenTimeManager.checkAndApplyBlocking(appState: appState, for: "Instagram")
screenTimeManager.hasAnyUnlockedApps(appState: appState)
screenTimeManager.getAppsToBlock(appState: appState) // ["Instagram", "TikTok"]
```

## Streak Tracking

### Per-App Streaks
Each app maintains its own streak:
- **Instagram streak**: 3 days (stayed within 10 opens/day)
- **TikTok streak**: 0 days (exceeded 15 opens/day yesterday)
- **YouTube streak**: 7 days (stayed within 20 opens/day)

### Overall Streak
The overall streak is maintained if **ALL apps** stay within their limits:
- If user stays within limits for all apps → Overall streak continues
- If user exceeds limit for ANY app → Overall streak resets to 0

### Daily Reset (Midnight)
```swift
func checkDailyReset() {
    for (appName, yesterdayBreakthroughs) in breakthroughsByApp {
        let limit = getAppLimit(appName)

        if yesterdayBreakthroughs <= limit {
            // Increase streak for this app
            currentStreakByApp[appName] += 1
        } else {
            // Reset streak for this app
            currentStreakByApp[appName] = 0
        }
    }

    // Reset daily breakthrough counters
    breakthroughsByApp.removeAll()
}
```

## Notifications (App-Specific)

All notifications now show app-specific stats:

**App Limit Warnings:**
```
"Almost at Your Limit"
"You've opened Instagram 8/10 times today"

"Last Chance"
"One more open left for TikTok today"

"Daily Limit Reached"
"You've reached your limit for YouTube today"
```

**Session Expiry:**
```
"Instagram Session Ending Soon"
"You have 1 minute left in your Instagram session"
```

**Streak Notifications:**
```
"Instagram: 3 Day Streak! 🔥"
"You maintained your Instagram streak"

"TikTok: Streak Reset"
"You exceeded your TikTok limit yesterday"
```

## Data Persistence (App Groups)

Per-app data is saved to App Groups for sharing between main app and extensions:

```swift
// Save per-app intentions
if let encoded = try? JSONEncoder().encode(intention.perAppIntentions) {
    sharedDefaults?.set(encoded, forKey: "perAppIntentions")
}

// Save per-app breakthroughs
if let encoded = try? JSONEncoder().encode(stats.breakthroughsByApp) {
    sharedDefaults?.set(encoded, forKey: "breakthroughsByApp")
}

// Save per-app streaks
if let encoded = try? JSONEncoder().encode(stats.currentStreakByApp) {
    sharedDefaults?.set(encoded, forKey: "currentStreakByApp")
}

// Save unlocked apps
let unlockedArray = Array(stats.unlockedApps)
if let encoded = try? JSONEncoder().encode(unlockedArray) {
    sharedDefaults?.set(encoded, forKey: "unlockedApps")
}

// Save per-app unlock expiry times
if let encoded = try? JSONEncoder().encode(stats.unlockExpiryByApp) {
    sharedDefaults?.set(encoded, forKey: "unlockExpiryByApp")
}
```

## UI Components

### OnboardingPerAppIntentionView
- Shows progress dots for each app
- Displays app icon placeholder
- Shows intention card with dynamic values
- Wheel pickers for times/day and minutes/session
- "Set same for all apps" quick action
- Previous/Next navigation

### AppInterventionView (Updated)
- Automatically pulls app-specific data using helper methods
- Shows app name in title
- Displays app-specific breakthrough count
- Shows app-specific daily limit
- Displays app-specific streak

## Testing

### Test 1: Different Limits Per App
1. Set Instagram: 10 times/day, 5 min
2. Set TikTok: 15 times/day, 10 min
3. Open Instagram 10 times → Blocked
4. Open TikTok 10 times → Still allowed (limit is 15)
5. Check intervention screens show different stats

### Test 2: Per-App Streaks
1. Day 1: Stay within limit for Instagram, exceed for TikTok
2. Midnight: Instagram streak = 1, TikTok streak = 0
3. Day 2: Stay within limits for both
4. Midnight: Instagram streak = 2, TikTok streak = 1

### Test 3: Per-App Unlock
1. Breakthrough Instagram (5 min session)
2. Instagram unlocked for 5 minutes
3. Try to open TikTok → Still blocked (different app)
4. Breakthrough TikTok (10 min session)
5. Both apps now unlocked with different expiry times

### Test 4: Set All Apps Feature
1. Click "Set same for all apps"
2. Set 12 times/day, 10 min
3. All apps should have same intention
4. Verify in onboarding data

## Migration from Global Intentions

The system maintains backward compatibility:

**Legacy Fields (Deprecated):**
- `AppIntention.timesPerDay` (kept for old code)
- `AppIntention.minutesPerSession` (kept for old code)
- `AppUsageStats.breakthroughsToday` (total across all apps)
- `AppUsageStats.currentStreak` (overall streak)

**New Fields (Per-App):**
- `AppIntention.perAppIntentions` (dictionary of per-app settings)
- `AppUsageStats.breakthroughsByApp` (per-app counts)
- `AppUsageStats.currentStreakByApp` (per-app streaks)
- `AppUsageStats.unlockedApps` (set of unlocked app names)

When per-app intentions are set, the first app's values are copied to legacy fields for backward compatibility.

## Benefits

1. **More Flexible**: Different limits for different apps based on how problematic they are
2. **Better Tracking**: See exactly which apps you're struggling with
3. **Fairer Streaks**: Don't lose your Instagram streak because of TikTok usage
4. **Personalized**: Heavy TikTok user? Set higher limit. Light Instagram user? Set lower limit.
5. **Accurate Stats**: Intervention screens show relevant data for each app

## Future Enhancements

Potential additions for Phase 2:
- [ ] Bulk edit intentions (select multiple apps, set same limit)
- [ ] Preset profiles (Strict: 10/5, Moderate: 15/10, Relaxed: 20/15)
- [ ] App-specific scheduling (block Instagram only at night, TikTok only during work)
- [ ] Insights per app (which app breaks streak most often)
- [ ] Export per-app stats to CSV
- [ ] Visual graphs per app
