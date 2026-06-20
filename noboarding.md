# Onboarding Integration (Noboarding SDK)

This file is a reference for AI coding assistants and developers working on this project.
It describes how the Noboarding onboarding SDK is integrated and how to use the data it collects.

## What is Noboarding?

Noboarding is a server-driven onboarding SDK for React Native / Expo. Onboarding screens are designed
in a web dashboard (https://noboarding.com) and rendered natively by the SDK — no app update needed
to change screens, copy, images, or flow order.

## SDK Setup

- **Package:** `noboarding` (+ peer dep `@react-native-async-storage/async-storage`)
- **Entry point:** `App.tsx` (or wherever `<OnboardingFlow />` is rendered)
- **Test Key:** `nb_test_...` (used automatically when `__DEV__ === true`)
- **Production Key:** `nb_live_...` (used automatically in production builds)
- **Dashboard:** https://noboarding.com → Settings for API keys

```tsx
import { OnboardingFlow } from 'noboarding';

<OnboardingFlow
  testKey="nb_test_..."
  productionKey="nb_live_..."
  initialVariables={{
    // Pass any data you already know about the user
    userName: user.name,
    platform: Platform.OS,
  }}
  customComponents={{
    // Register custom screen components (keys must match dashboard names exactly)
    PaywallScreen: PaywallScreen,
    NotificationScreen: NotificationScreen,
  }}
  onUserIdGenerated={(userId) => {
    // Sync with RevenueCat or your analytics (if applicable)
    Purchases.logIn(userId);
  }}
  onComplete={(userData) => {
    // Called when user finishes onboarding — see "Using Onboarding Data" below
    handleOnboardingComplete(userData);
  }}
  onSkip={() => {
    // Called when user skips/dismisses the onboarding
  }}
/>
```

## Screen Types

There are two types of screens in a Noboarding flow:

1. **AI Screens (noboard_screen)** — Designed in the dashboard using the AI Builder or Layout tab.
   These screens can set variables via `set_variable` actions (e.g., button taps that save user choices).

2. **Custom Screens (custom_screen)** — React Native components you build and register with the SDK.
   Used for native features the dashboard can't handle (paywalls, permissions, sign-in, etc.).

## Custom Screen Props

Every custom screen component receives these props:

```tsx
interface CustomScreenProps {
  analytics: { track: (event: string, properties?: Record<string, any>) => void };
  onNext: () => void;                                    // Navigate to next screen
  onBack?: () => void;                                   // Navigate to previous screen
  onSkip?: () => void;                                   // Skip entire onboarding
  preview?: boolean;                                     // true in dashboard preview mode
  data?: Record<string, any>;                            // All data from previous screens
  onDataUpdate?: (data: Record<string, any>) => void;    // Pass data to next screens
}
```

**The `data` prop contains everything collected so far** — both variables from AI screens (`set_variable`)
and data from other custom screens (`onDataUpdate`). You can read any variable by name:

```tsx
function MyScreen({ data, onDataUpdate, onNext }: CustomScreenProps) {
  // Read a variable set by an AI screen
  const userGoal = data?.goal;          // e.g. "fitness"
  const userName = data?.userName;      // e.g. "Sarah" (from initialVariables)

  const handleSubmit = () => {
    // Set new data for subsequent screens
    onDataUpdate?.({ selectedPlan: 'pro', completedSurvey: true });
    onNext();
  };
}
```

## Custom Screens in This Project

| Component Name | File | Purpose |
|----------------|------|---------|
| (fill in your custom screen name) | (file path) | (what it does) |

## Onboarding Variables

These variables are set during the onboarding flow and available directly on `userData` (flat, no nesting):

| Variable Name | Set By | Example Value | Used For |
|---------------|--------|---------------|----------|
| (fill in) | AI screen / Custom screen | (example) | (how your app uses it) |

## Using Onboarding Data in Your App

When onboarding completes, the `onComplete` callback receives a flat `userData` object with everything merged.

**Recommended: Save the entire object as JSON.** This way, new variables added in the Noboarding dashboard
are saved automatically — no code changes needed.

```tsx
onComplete={async (userData) => {
  // userData = { goal: 'fitness', experience: 'beginner', premium: true, userName: 'Sarah', ... }

  // Save to database as a JSON column
  await supabase.from('users').update({
    onboarding_data: userData,
  }).eq('id', currentUserId);

  // Also save locally for quick offline access
  await AsyncStorage.setItem('onboarding_data', JSON.stringify(userData));
}}
```

### Data Flow Diagram

```
initialVariables (from your app)
    ↓
AI Screen 1 → set_variable: goal = "fitness"
    ↓
Custom Screen → reads data.goal ("fitness"), sets onDataUpdate({ premium: true })
    ↓
AI Screen 2 → reads {goal} in text templates
    ↓
onComplete → userData = { goal: "fitness", premium: true, userName: "Sarah", ... }
    ↓
Save as JSON → database (onboarding_data column) + AsyncStorage
    ↓
Your App → const onboarding = useOnboardingData(); onboarding.goal → "fitness"
```

### Accessing Data Anywhere in Your App

Create a helper hook so any screen in your app can read onboarding data:

```tsx
// hooks/useOnboardingData.ts
import { useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

export function useOnboardingData() {
  const [data, setData] = useState<Record<string, any>>({});
  useEffect(() => {
    AsyncStorage.getItem('onboarding_data').then(raw => {
      if (raw) setData(JSON.parse(raw));
    });
  }, []);
  return data;
}
```

```tsx
// Usage in any screen:
import { useOnboardingData } from './hooks/useOnboardingData';

function HomeScreen() {
  const onboarding = useOnboardingData();

  if (onboarding.goal === 'fitness') {
    // Show fitness content
  }

  return <Text>Welcome, {onboarding.userName}!</Text>;
}
```

```tsx
// Or read from your database:
const { data } = await supabase.from('users').select('onboarding_data').eq('id', userId).single();
const onboarding = data.onboarding_data;
const goal = onboarding.goal; // "fitness"
```

## Data Storage in This Project

- **Database column:** `onboarding_data` (JSONB) on the users table — stores the full userData object
- **AsyncStorage key:** `onboarding_data` — JSON string for quick local access
- **Helper hook:** `useOnboardingData()` — reads from AsyncStorage, returns the parsed object

## RevenueCat Integration (If Applicable)

- RevenueCat SDK: `react-native-purchases`
- iOS API Key: `appl_...`
- Android API Key: `goog_...`
- User ID sync: `onUserIdGenerated` callback passes Noboarding user ID to `Purchases.logIn()`
- Webhook URL: configured in RevenueCat dashboard → Integrations → Webhooks

## Modifying the Onboarding Flow

1. Log in to https://noboarding.com
2. Open your flow in the editor
3. Use the AI Builder or Layout tab to make changes
4. Click **Publish → Publish for Testing** (for dev builds)
5. Click **Publish → Publish to Production** (for live builds)
6. No app update needed — the SDK picks up changes automatically

## Analytics Events (Automatic)

The SDK tracks these events automatically:

| Event | When |
|-------|------|
| onboarding_started | Flow loads and first screen appears |
| screen_viewed | User navigates to a new screen |
| screen_completed | User completes a screen |
| onboarding_completed | User reaches the end of the flow |
| onboarding_abandoned | User skips/dismisses the flow |

## Updating This File

Keep this file up to date whenever you:
- Add or remove custom screen components
- Change which variables are set in the dashboard
- Change how onboarding data is saved or used in the app
- Modify RevenueCat or webhook configuration
