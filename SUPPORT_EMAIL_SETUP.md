# Support Email Setup Guide

This guide explains how to deploy the support email system using Resend and Supabase Edge Functions.

## ✅ What's Been Created

1. **SupportEmailView** (`BeYou/Views/Main/SupportEmailView.swift`)
   - Beautiful UI for users to compose support emails
   - Includes validation and error handling
   - Shows success confirmation after sending

2. **Supabase Edge Function** (`supabase/functions/send-support-email/index.ts`)
   - Securely stores your Resend API key on the server
   - Sends formatted HTML emails to your support inbox
   - Includes user context (name, email, user ID)

3. **SettingsView Integration**
   - "Help & Support", "Feature requests", and "Contact us" buttons now open the email form

## 🔐 Security

✅ **Your Resend API key is ONLY stored on the server** (Supabase Edge Function)
✅ **Never exposed in the iOS app**
✅ **Cannot be extracted by users**

## 📧 Resend Setup (IMPORTANT)

Before deploying, you need to verify your sender domain in Resend:

1. Go to [Resend Dashboard](https://resend.com/domains)
2. Click "Add Domain"
3. Add a domain you own (e.g., `beyou-app.com`)
4. Follow Resend's instructions to add DNS records
5. Once verified, update line 37 in the Edge Function:
   ```typescript
   from: 'BeYou Support <support@beyou-app.com>',
   ```
   Replace `beyou-app.com` with your verified domain

### Alternative: Use Resend's Test Email (Temporary)

If you don't have a domain yet, you can use Resend's test functionality:
- Change `from` to: `'onboarding@resend.dev'`
- **WARNING**: This only works during testing and has limitations

## 🚀 Deployment Steps

### 1. Install Supabase CLI (if not already installed)

```bash
brew install supabase/tap/supabase
```

### 2. Navigate to your project

```bash
cd /Users/oduduabasivictor/Downloads/BeYou/BeYou/BeYou
```

### 3. Deploy the Edge Function

```bash
supabase functions deploy send-support-email --project-ref cwrcyejpqcdsclwflfki
```

When prompted for credentials, use:
- Project ref: `cwrcyejpqcdsclwflfki`
- Use the same credentials you use for Supabase dashboard

### 4. Test the Function

After deployment, test it:

```bash
curl -i --location --request POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-support-email' \
  --header 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --data '{
    "email": "test@example.com",
    "subject": "Test Support Request",
    "message": "This is a test message",
    "userName": "Test User",
    "userId": "test-123"
  }'
```

You should receive:
- HTTP 200 status
- Email in your inbox at `oduduabasiav@gmail.com`

## 📱 Testing in the App

1. Build and run the app
2. Go to Settings tab
3. Tap "Help & Support" or "Contact us"
4. Fill out the form:
   - Your Email: (enter your email)
   - Subject: "Test from iOS App"
   - Message: "Testing the support system"
5. Tap "Send"
6. You should see a success message
7. Check `oduduabasiav@gmail.com` for the email

## 🎨 Email Format

The emails you receive will be beautifully formatted with:
- Professional header with gradient
- User information box (name, email, user ID)
- The user's message in a clean format
- Reply-to set to the user's email (so you can reply directly)

## 🔧 Customization

### Change Support Email Address

Edit `supabase/functions/send-support-email/index.ts` line 8:
```typescript
const SUPPORT_EMAIL = "your-new-email@example.com"
```

Then redeploy:
```bash
supabase functions deploy send-support-email --project-ref cwrcyejpqcdsclwflfki
```

### Update Resend API Key

If you need to rotate your API key:

1. Generate new key in [Resend Dashboard](https://resend.com/api-keys)
2. Update line 7 in `supabase/functions/send-support-email/index.ts`
3. Redeploy the function

## ⚠️ Important Notes

1. **Never commit your Resend API key to git** - It's safe in the Edge Function on Supabase's servers
2. **Verify your domain in Resend** before going to production
3. **Test thoroughly** before launching to users
4. **Monitor your Resend usage** - Free tier has limits
5. **Set up email notifications** in Resend dashboard to know when emails are sent

## 🐛 Troubleshooting

### "Failed to send email" error

- Check Supabase function logs: `supabase functions logs send-support-email --project-ref cwrcyejpqcdsclwflfki`
- Verify your Resend API key is correct
- Make sure your sender domain is verified in Resend

### User reports email not sending

- Check that internet connection is available
- Verify the Supabase Edge Function is deployed
- Check app logs for error messages

### Emails going to spam

- Verify your domain in Resend
- Set up SPF, DKIM, and DMARC DNS records
- Use a professional sender address (not a free email provider)

## 📊 Resend Dashboard

Monitor your emails at: https://resend.com/emails

You can see:
- Sent emails
- Delivery status
- Opens and clicks (if tracking enabled)
- Bounces and complaints

## ✅ Ready to Go!

Once you've deployed the Edge Function and verified your domain in Resend, your support email system is fully functional and secure!

Users can contact you directly from the app, and you'll receive beautiful, professional emails at `oduduabasiav@gmail.com`.
