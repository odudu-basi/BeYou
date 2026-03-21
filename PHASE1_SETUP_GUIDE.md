# Phase 1: App Blocking Setup Guide

## Overview
This guide explains how to set up the Device Activity and Shield Configuration extensions to enable app blocking in BeYou.

## ✅ What's Already Implemented

### 1. Core Blocking Logic
- ✅ `ScreenTimeManager.swift` - Manages app blocking and schedules
- ✅ `SharedDataManager.swift` - Shares data between app and extensions
- ✅ `AppState.swift` - Tracks usage stats, streaks, discipline score
- ✅ `AppInterventionView.swift` - Custom intervention screen
- ✅ Extension code templates available in:
  - `EXTENSION_TEMPLATES.md` (contains full code for both extensions)

### 2. Data Models
- ✅ `AppIntention` - Times/day and minutes/session limits
- ✅ `AppUsageStats` - Breakthroughs, streaks, unlock status
- ✅ `DisciplineScore` - Score tracking with nevermind/breakthrough counts
- ✅ `DisconnectSchedule` - Morning/Bed/Work time blocks

### 3. UI Flows
- ✅ Onboarding collects app intentions and disconnect schedules
- ✅ Motivation view tracks affirmation swipes (unlock after 3)
- ✅ Intervention screen shows before app opens

## 🔧 Manual Setup Required in Xcode

### Step 1: Enable App Groups

1. Open `BeYou.xcodeproj` in Xcode
2. Select the **BeYou** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability** → Add **App Groups**
5. Click **+** and add: `group.com.beyou.app`
6. Repeat for all extension targets (once created)

###  Step 2: Create DeviceActivity Monitor Extension

1. In Xcode: **File** → **New** → **Target**
2. Select **iOS** → **Device Activity Monitor Extension**
3. Name it: `BeYouDeviceActivityMonitor`
4. **Do NOT** check "Activate scheme"
5. Open `EXTENSION_TEMPLATES.md` and copy the `DeviceActivityMonitorExtension.swift` code into the generated extension file
6. In target settings:
   - Add **App Groups** capability with `group.com.beyou.app`
   - Set **Deployment Target** to iOS 16.0+
   - In **Build Phases** → **Link Binary With Libraries**, add:
     - `DeviceActivity.framework`
     - `ManagedSettings.framework`
     - `FamilyControls.framework`

### Step 3: Create ShieldConfiguration Extension

1. In Xcode: **File** → **New** → **Target**
2. Select **iOS** → **Shield Configuration Extension**
3. Name it: `BeYouShieldConfiguration`
4. **Do NOT** check "Activate scheme"
5. Open `EXTENSION_TEMPLATES.md` and copy the `ShieldConfigurationExtension.swift` code into the generated extension file
6. In target settings:
   - Add **App Groups** capability with `group.com.beyou.app`
   - Set **Deployment Target** to iOS 16.0+
   - In **Build Phases** → **Link Binary With Libraries**, add:
     - `ManagedSettings.framework`
     - `ManagedSettingsUI.framework`
     - `FamilyControls.framework`

### Step 4: Update Info.plist

**Main App (BeYou/Info.plist):**
```xml
<key>NSFamilyControlsUsageDescription</key>
<string>BeYou needs access to Screen Time to help you manage app usage and build healthy habits</string>
```

### Step 5: Build and Run

1. Select **BeYou** scheme
2. Build project (Cmd+B)
3. Fix any remaining actor isolation warnings if needed
4. Run on physical device (extensions require real device, not simulator)

## 🎯 Testing the Setup

### Test 1: Screen Time Authorization
1. Complete onboarding
2. Grant Screen Time permission when prompted
3. Select apps to block (e.g., Instagram)

### Test 2: Basic Blocking
1. Exit BeYou
2. Try to open Instagram
3. Should see iOS shield with BeYou branding

### Test 3: Intervention Flow
1. Open Instagram → See intervention screen
2. Click "Nevermind" → Instagram stays closed
3. Open Instagram again → Click "Open Instagram"
4. BeYou app opens → Swipe through 3 affirmations
5. Instagram unlocks for session duration

### Test 4: Scheduled Blocking
1. Set "Before Bed" schedule (e.g., 9 PM - 7 AM)
2. At 9 PM, apps should automatically block
3. At 7 AM, apps should unblock (if within daily limit)

## 📊 How the Blocking Logic Works

### Daily Intention Limit
```
User sets: 10 opens/day, 5 minutes each
- Opens 1-9: App works normally
- Open 10: Warning shown, but still allowed
- Open 11+: Hard blocked for rest of day
```

### Session Duration
```
User opens Instagram (within limit):
- Timer starts: 5 minutes
- At 5:00: Shield applies
- User must close app
- Next open counts toward daily limit
```

### Breakthrough Flow
```
1. User tries to open blocked app
2. Intervention screen appears
3. Options:
   a) "Nevermind" → App stays closed (+2 discipline score)
   b) "Open Instagram" → BeYou opens
4. If "Open Instagram":
   - Must swipe 3 affirmations
   - App unlocks for session duration
   - Breakthrough counted (-1 discipline score)
   - Still counts toward daily limit
```

### Midnight Reset
```
Every midnight:
- Check if user stayed within limit
  - YES → Streak++
  - NO → Streak = 0
- Reset breakthroughsToday = 0
- Clear unlock status
```

## 🐛 Troubleshooting

### "Extensions not working"
- Ensure you're testing on **physical device** (not simulator)
- Verify App Groups are enabled on all targets
- Check that extension targets are embedded in main app

### "Shield not appearing"
- Verify Screen Time authorization granted
- Check that `activitySelection` has apps selected
- Ensure `blockSelectedApps()` was called

### "Data not persisting"
- Verify App Group identifier is identical across targets
- Check SharedDataManager is being called
- Test with UserDefaults debugging

### "Build errors with extensions"
- Ensure all extension methods are `nonisolated`
- Verify frameworks are linked in extension targets
- Check deployment target is iOS 16.0+

## 📝 Next Steps (Phase 2)

Once Phase 1 is working:
- [ ] Implement full DeviceActivity monitoring
- [x] Add notification support ✅ **COMPLETE**
- [ ] Enhance discipline score algorithm
- [ ] Add widget support
- [ ] Implement analytics/insights

## 🔔 Notification System (IMPLEMENTED)

The notification system is now fully implemented! See `NOTIFICATIONS_GUIDE.md` for complete documentation.

### What's Included:
- ✅ Disconnect time warnings (10 min before)
- ✅ Disconnect time start/end notifications
- ✅ App limit warnings (8/10, 9/10, 10/10)
- ✅ Session expiry warnings
- ✅ Streak notifications (midnight)
- ✅ Discipline score updates
- ✅ Midnight reset notifications
- ✅ Daily reminders (noon)

### Setup:
1. Notification permission is requested automatically on first launch
2. All notifications are scheduled automatically based on user settings
3. See `NOTIFICATIONS_GUIDE.md` for testing and troubleshooting

## 🎓 Resources

- [Apple: Screen Time API](https://developer.apple.com/documentation/deviceactivity)
- [Apple: Family Controls](https://developer.apple.com/documentation/familycontrols)
- [Apple: App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
