# BeYou - Publishing to App Store Checklist

This guide covers all the steps needed to publish BeYou to the Apple App Store.

---

## ⚠️ CRITICAL: APNs Environment Configuration

**Before publishing to TestFlight or App Store, you MUST update the APNs environment.**

### Current Setup (Development):
```bash
# Currently set for testing from Xcode
APNS_ENVIRONMENT="development"
```
This uses APNs Sandbox server and ONLY works with development device tokens.

### Change to Production:

**Run these commands before submitting to App Store Connect:**

```bash
# Navigate to project directory
cd /Users/oduduabasivictor/Downloads/BeYou/BeYou/BeYou

# Update Supabase secret to production
supabase secrets set APNS_ENVIRONMENT="production"

# Redeploy the Edge Function with production environment
supabase functions deploy send-unlock-push --no-verify-jwt
```

**Verify it worked:**
```bash
supabase secrets list
# Should show APNS_ENVIRONMENT = "production"
```

---

## Pre-Publishing Checklist

### 1. App Configuration

- [ ] **Update version and build numbers**
  - In Xcode: Select BeYou target → General → Identity
  - Version: `1.0.0` (or your version)
  - Build: Increment for each submission

- [ ] **Update display name** (if needed)
  - Target → Info → Bundle display name

- [ ] **Verify bundle identifier**
  - Should be: `com.odudu.BeYou`

### 2. App Icons & Assets

- [ ] **App Icon** - All required sizes (1024x1024 for App Store)
  - Location: `BeYou/Assets.xcassets/AppIcon.appiconset/`

- [ ] **Launch Screen** configured properly

- [ ] **Screenshots** prepared (required for App Store listing)
  - iPhone 6.7" display (iPhone 14 Pro Max or 15 Pro Max)
  - iPhone 6.5" display (iPhone 11 Pro Max, XS Max)
  - iPhone 5.5" display (optional, for older devices)

### 3. Permissions & Privacy

- [ ] **Update Privacy Policy URL** (required for Screen Time API)
  - Add to App Store Connect

- [ ] **App Store Privacy Nutrition Labels**
  - List data collection:
    - Usage data (app usage tracking for screen time features)
    - Identifiers (device tokens for push notifications)

- [ ] **Verify all permission descriptions** in Info.plist:
  - `NSUserTrackingUsageDescription` (if using tracking)
  - `NSFamilyControlsUsageDescription` - Already set
  - `NSUserNotificationsUsageDescription` - Should be set

### 4. Code Signing & Provisioning

- [ ] **Create App Store Distribution Profile**
  - Go to: [developer.apple.com/account](https://developer.apple.com/account)
  - Certificates, Identifiers & Profiles → Profiles
  - Create: App Store Distribution profile for `com.odudu.BeYou`

- [ ] **Download and install the profile** in Xcode

- [ ] **Select correct signing**
  - In Xcode: Target → Signing & Capabilities
  - Automatically manage signing: ✅ Enabled
  - Team: Select your team (9U7ZFP4X2B)
  - OR manually select App Store Distribution profile

- [ ] **Verify all 4 targets are properly signed:**
  - ✅ BeYou (main app)
  - ✅ BeYouShieldAction
  - ✅ BeYouShieldConfiguration
  - ✅ BeYouDeviceActivityMonitor

### 5. App Store Connect Setup

- [ ] **Create app record** in App Store Connect
  - Go to: [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
  - My Apps → + → New App
  - Platforms: iOS
  - Bundle ID: com.odudu.BeYou

- [ ] **Fill out app information:**
  - App name
  - Subtitle (optional)
  - Primary/Secondary categories: Health & Fitness, Productivity
  - App description (explain mindful screen time features)
  - Keywords (for App Store search)
  - Support URL
  - Marketing URL (optional)

- [ ] **Upload screenshots** (prepared in step 2)

- [ ] **Set age rating** (likely 4+, but answer questionnaire)

- [ ] **App Review Information:**
  - Contact email
  - Phone number
  - Demo account (if needed for review)
  - **Important:** Add notes explaining Screen Time API usage

### 6. Family Controls / Screen Time API Review

**⚠️ CRITICAL: Apple manually reviews Screen Time API usage**

- [ ] **Explain your usage** in App Review Notes:
  ```
  BeYou uses the Screen Time API (FamilyControls framework) to help users
  manage their screen time mindfully. The app:

  1. Allows users to select apps they want to limit
  2. Shows custom shield screens with motivational content
  3. Implements an intervention flow (affirmations) before unlocking apps
  4. Tracks usage statistics to help users stay accountable

  This is a self-management tool for adult users to reduce screen time
  and build healthier digital habits.
  ```

- [ ] **Provide test instructions** if needed

- [ ] **Ensure Privacy Policy** clearly explains Screen Time data usage

### 7. Testing Before Submission

- [ ] **Test on real device** (not simulator)
  - All primary features work
  - Shield screens appear correctly
  - Push notifications work
  - Intervention flow completes successfully

- [ ] **Test all extensions:**
  - ShieldConfiguration shows custom UI
  - ShieldAction handles button taps
  - DeviceActivityMonitor tracks activity

- [ ] **Test App Groups data sharing** works correctly

- [ ] **Run in Release mode** to test performance:
  ```
  Product → Scheme → Edit Scheme → Run → Build Configuration → Release
  ```

### 8. Archive & Upload

- [ ] **Clean build folder**
  ```
  Product → Clean Build Folder (⌘⇧K)
  ```

- [ ] **Archive the app**
  ```
  Product → Archive
  ```
  - Make sure "Any iOS Device (arm64)" is selected (not simulator)

- [ ] **Validate the archive**
  - Window → Organizer → Archives
  - Select your archive
  - Click "Validate App"
  - Fix any errors

- [ ] **Upload to App Store Connect**
  - Click "Distribute App"
  - Choose "App Store Connect"
  - Follow prompts
  - Wait for processing (10-30 minutes)

### 9. Submit for Review

- [ ] **In App Store Connect:**
  - Select your app
  - Go to version you want to submit
  - Fill out "What's New in This Version"
  - Click "Submit for Review"

- [ ] **Answer App Review questions:**
  - Does app use encryption? Usually "No" for standard HTTPS
  - Does app use third-party content? Depends on your content

- [ ] **Wait for review** (typically 1-3 days)

### 10. After Approval

- [ ] **Release to App Store**
  - Can be automatic or manual

- [ ] **Monitor crash reports** in App Store Connect

- [ ] **Monitor reviews** and respond to user feedback

- [ ] **Verify push notifications work** for production users

---

## Common Rejection Reasons & How to Avoid

### 1. Screen Time API Justification
**Issue:** Apple requires clear justification for Screen Time API usage.

**Solution:**
- Clearly explain in App Review Notes (see step 6)
- Make sure in-app explanation is clear
- Privacy Policy must address this

### 2. Missing Privacy Policy
**Issue:** Screen Time API requires a Privacy Policy.

**Solution:**
- Create a privacy policy (can use templates online)
- Host it publicly (GitHub Pages, your website, etc.)
- Add URL to App Store Connect

### 3. Incomplete Metadata
**Issue:** Missing screenshots, descriptions, or keywords.

**Solution:**
- Complete ALL required fields in App Store Connect
- Provide screenshots for all required device sizes

### 4. Push Notifications Not Working
**Issue:** APNs environment mismatch.

**Solution:**
- ✅ Already handled! Make sure you ran the commands at the top of this file

### 5. Crash on Launch
**Issue:** Missing frameworks or incorrect entitlements.

**Solution:**
- Test in Release mode before submitting
- Verify all 4 targets have correct entitlements
- Check that extensions are embedded correctly

---

## Post-Launch Maintenance

### Updating the App

**For each update:**

1. **Increment build number** (or version if major changes)
2. **Test thoroughly** on real device
3. **Archive and upload** to App Store Connect
4. **Fill out "What's New"** section
5. **Submit for review**

**No need to change APNs environment again** - once set to production, leave it!

### Monitoring

- **App Store Connect Analytics** - Track downloads, usage
- **Crash Reports** - Fix critical issues quickly
- **User Reviews** - Respond and iterate based on feedback
- **Supabase Logs** - Monitor Edge Function for errors:
  ```
  https://supabase.com/dashboard/project/cwrcyejpqcdsclwflfki/functions/send-unlock-push/logs
  ```

---

## Quick Reference

### Important URLs

- **Apple Developer Portal:** https://developer.apple.com/account
- **App Store Connect:** https://appstoreconnect.apple.com
- **Supabase Dashboard:** https://supabase.com/dashboard/project/cwrcyejpqcdsclwflfki
- **Edge Function Logs:** https://supabase.com/dashboard/project/cwrcyejpqcdsclwflfki/functions/send-unlock-push/logs

### Important IDs

- **Bundle ID:** `com.odudu.BeYou`
- **Team ID:** `9U7ZFP4X2B`
- **APNs Key ID:** `5DUA97YQTH`
- **Supabase Project:** `cwrcyejpqcdsclwflfki`
- **App Group:** `group.com.odudu.BeYou`

### Key Commands

```bash
# Change to production (before App Store submission)
supabase secrets set APNS_ENVIRONMENT="production"
supabase functions deploy send-unlock-push --no-verify-jwt

# Change back to development (for testing updates)
supabase secrets set APNS_ENVIRONMENT="development"
supabase functions deploy send-unlock-push --no-verify-jwt

# View Edge Function logs (in browser)
open https://supabase.com/dashboard/project/cwrcyejpqcdsclwflfki/functions/send-unlock-push/logs
```

---

## Support & Resources

- **Apple Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Screen Time API Docs:** https://developer.apple.com/documentation/familycontrols
- **Supabase Edge Functions:** https://supabase.com/docs/guides/functions
- **APNs Documentation:** https://developer.apple.com/documentation/usernotifications

---

**Good luck with your launch! 🚀**
