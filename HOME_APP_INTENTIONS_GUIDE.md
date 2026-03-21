# Home Screen App Intentions Guide

## Overview
The Home screen now features a dynamic **App Intentions Section** that allows users to manage their per-app intentions directly from the home screen.

## Features Implemented

### 1. **App Intentions Section Component**
**Location:** `Views/Home/AppIntentionsSection.swift`

Shows all current app intentions with:
- Header with refresh button
- Empty state when no intentions set
- List of app intention cards
- "+ Add App Intention" button

### 2. **Individual App Intention Cards**
**Location:** `Views/Home/AppIntentionCard.swift`

Each card displays:
- App icon (first letter in colored circle)
- App name
- Times per day limit (e.g., "10x/day")
- Minutes per session (e.g., "5 min")
- Edit button (pencil icon)
- Delete button (trash icon)

**Visual Design:**
- White background with subtle shadow
- Clean, compact layout
- Action buttons with colored backgrounds
- Edit: Light gray background
- Delete: Light red background

### 3. **Add/Edit App Intention Modal**
**Location:** `Views/Home/AddAppIntentionModal.swift`

**Features:**
- Beautiful gradient background
- App selection dropdown with common apps:
  - Instagram, TikTok, YouTube, Twitter/X, Facebook
  - Snapchat, Reddit, Discord, Netflix, Twitch
  - "Custom..." option for any other app
- Live preview of intention:
  - "no more than [X] times a day"
  - "for [Y] min each time"
- Wheel pickers for both values
- Times per day: 10-20
- Minutes per session: 5, 10, 15, 20, 25, 30, 35, 45
- Save button (disabled until app selected)
- Cancel button

**Modes:**
- **Add Mode**: Select new app and set intention
- **Edit Mode**: Modify existing app's intention (app name not editable)

### 4. **Empty State**
Shows when no intentions are set:
- Target icon in blue circle
- "No App Intentions Yet" title
- Subtitle explaining feature
- Prominent "Add App Intention" button

## User Flow

### Adding a New Intention

1. User opens Home screen
2. Sees "App Intentions" section
3. **If empty:**
   - Sees empty state illustration
   - Clicks "Add App Intention" button
4. **If has intentions:**
   - Sees list of existing app cards
   - Clicks "+ Add App Intention" button at bottom

5. Modal appears:
   - Selects app from dropdown
   - Adjusts times per day (wheel picker)
   - Adjusts minutes per session (wheel picker)
   - Sees live preview update
   - Clicks "Set App Intention"

6. Modal closes, new card appears in list

### Editing an Intention

1. User sees app intention card
2. Clicks pencil (edit) button
3. Modal appears with current values
4. Adjusts values using pickers
5. Clicks "Update Intention"
6. Card updates with new values

### Deleting an Intention

1. User clicks trash (delete) button on card
2. Confirmation dialog appears:
   - Title: "Delete [App] Intention?"
   - Message: "This will remove the intention for [app]. You can always add it back later."
   - Red "Delete" button
   - "Cancel" button
3. If confirmed:
   - Card disappears
   - App removed from blocked list
   - All stats cleaned up

## Integration with AppState

**When adding/updating:**
```swift
// Save to per-app intentions
appState.onboardingData.appIntention.perAppIntentions[appName] = intention

// Add to blocked apps list
appState.onboardingData.selectedAppsForBlocking.append(appName)

// Initialize stats
appState.appUsageStats.breakthroughsByApp[appName] = 0
appState.appUsageStats.currentStreakByApp[appName] = 0
```

**When deleting:**
```swift
// Remove from intentions
appState.onboardingData.appIntention.perAppIntentions.removeValue(forKey: appName)

// Remove from blocked list
appState.onboardingData.selectedAppsForBlocking.remove(appName)

// Clean up all stats
appState.appUsageStats.breakthroughsByApp.removeValue(forKey: appName)
appState.appUsageStats.currentStreakByApp.removeValue(forKey: appName)
appState.appUsageStats.unlockedApps.remove(appName)
// etc.
```

## Visual Design Details

### Colors Used
- **Primary Blue:** `#3B82F6` (buttons, icons)
- **Background:** `#F8FAFC` (section background)
- **Card Background:** White
- **Text Primary:** `#1E293B`
- **Text Secondary:** `#64748B`
- **Border:** `#E2E8F0`
- **Delete Red:** `#EF4444`
- **Delete Background:** `#FEE2E2`

### Layout
- Section padding: 20px
- Card spacing: 12px between cards
- Card padding: 12px
- Border radius: 12px (cards), 16px (section)
- Icon size: 44x44
- Action buttons: 32x32

### Typography
- Section title: 18pt semibold
- Card app name: 15pt semibold
- Card stats: 13pt regular
- Modal title: 24pt bold
- Modal body: 16pt regular

## Build Error Fix

**Issue:** Template files causing build errors:
```
Unexpected input file: DeviceActivityMonitorExtension.swift.template
Unexpected input file: ShieldConfigurationExtension.swift.template
```

**Solution:**
Moved template files to documentation folder:
```
BeYou/Extensions/ToBeConfigured/*.template
→ BeYou/Documentation/ExtensionTemplates/
```

These files are now:
- Excluded from the build
- Available as reference for manual extension setup
- Still accessible in the project

## Testing

### Test 1: Empty State
1. Start with no intentions set
2. Open Home screen
3. Should see:
   - Target icon illustration
   - "No App Intentions Yet"
   - "Add App Intention" button

### Test 2: Add First Intention
1. Click "Add App Intention"
2. Modal opens
3. Select "Instagram" from dropdown
4. Set 12 times/day, 10 min
5. Click "Set App Intention"
6. Card appears with Instagram info

### Test 3: Add Multiple Intentions
1. Click "+ Add App Intention" at bottom
2. Add "TikTok" with different limits
3. Both cards visible
4. Sorted alphabetically

### Test 4: Edit Intention
1. Click pencil on Instagram card
2. Modal shows current values
3. Change to 15 times/day
4. Click "Update Intention"
5. Card updates immediately

### Test 5: Delete Intention
1. Click trash on TikTok card
2. Confirmation appears
3. Click "Delete"
4. Card disappears
5. TikTok removed from blocked apps

### Test 6: Custom App
1. Click "+ Add App Intention"
2. Select "Custom..." from dropdown
3. Enter "Slack"
4. Set limits
5. Save
6. "Slack" card appears

## Integration with Existing Features

### Onboarding Flow
- Onboarding still sets initial intentions
- User can modify them later on Home screen
- Changes persist to App Groups

### Intervention Screen
- Uses the per-app limits set here
- Shows correct stats for each app
- "8/10 Opens Today" for Instagram
- "12/15 Opens Today" for TikTok (different limits!)

### Notifications
- All notifications use per-app limits
- "You've opened Instagram 8/10 times today"
- Session expiry based on per-app duration

### Screen Time Blocking
- Respects per-app limits
- Instagram blocked at 10, TikTok still allowed
- Each app blocks independently

## Next Steps

Potential enhancements:
- [ ] Bulk actions (select multiple, delete all)
- [ ] Search/filter app list
- [ ] Quick presets (Strict, Moderate, Relaxed)
- [ ] App usage graphs on card
- [ ] Reorder cards (drag & drop)
- [ ] App categories (Social, Entertainment, etc.)
- [ ] Import/export intentions
- [ ] Suggestions based on usage patterns
