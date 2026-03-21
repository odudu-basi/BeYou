# BeYou - Send Unlock Push Notification

Edge Function that sends APNs push notifications when user taps "Continue" on shield.

## Setup

### 1. Get APNs Credentials from Apple Developer Portal

1. Go to [developer.apple.com/account](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Keys** in the sidebar
4. Click the **"+" button** to create a new key
5. **Name:** BeYou APNs Key
6. **Check:** Apple Push Notifications service (APNs)
7. Click **Continue**, then **Register**
8. **Download the .p8 file** (you can only download once!)
9. **Note the Key ID** (shows on the confirmation page)
10. **Note your Team ID** (top right corner of developer portal)

### 2. Link Supabase Project

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF
```

Your project ref is in your Supabase project URL:
`https://YOUR_PROJECT_REF.supabase.co`

### 3. Set Secrets

```bash
# Set APNs Key ID (from step 1)
supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"

# Set APNs Team ID (from step 1)
supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"

# Set APNs Private Key (from the .p8 file)
# This command reads the entire .p8 file and sets it as a secret
supabase secrets set APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXX.p8)"

# Set environment (development or production)
supabase secrets set APNS_ENVIRONMENT="development"
```

**Important:** For production, change `APNS_ENVIRONMENT` to `"production"`

### 4. Deploy the Function

```bash
supabase functions deploy send-unlock-push
```

### 5. Test the Function

```bash
# Get your function URL from Supabase dashboard:
# https://YOUR_PROJECT.supabase.co/functions/v1/send-unlock-push

curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/send-unlock-push' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "deviceToken": "YOUR_DEVICE_TOKEN",
    "appName": "Instagram",
    "userID": "test-user"
  }'
```

## How It Works

1. **ShieldAction extension** detects "Continue" button tap
2. **Sends Darwin notification** to wake main app
3. **Main app calls this Edge Function** with device token
4. **Edge Function generates APNs JWT** using your private key
5. **Sends push notification** via Apple's APNs servers
6. **User receives notification** and taps it
7. **BeYou app opens** to intervention flow

## Troubleshooting

### "Invalid device token"
- Make sure you're using the correct APNS_ENVIRONMENT (development vs production)
- Development tokens only work with sandbox APNs
- Production tokens only work with production APNs

### "BadDeviceToken"
- Device token might be expired
- Make sure the bundle ID matches: `com.odudu.BeYou`

### "No response from APNs"
- Check that all secrets are set correctly
- Verify the .p8 file was read correctly (should start with `-----BEGIN PRIVATE KEY-----`)

### View Logs
```bash
supabase functions logs send-unlock-push
```
