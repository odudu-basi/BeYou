# TikTok + AppsFlyer Campaign Setup Checklist

Order matters — doing these out of sequence is the usual way attribution breaks. Work top to bottom.
App Store ID: `6760232059` · AppsFlyer Dev Key: in the AppsFlyer dashboard / `appsFlyer-sdk-mcp` env.

---

## ⚠️ Gate 0 — ship the AppsFlyer build FIRST
Nothing below produces real data until the app **with the AppsFlyer SDK is live** (App Store) and
users are on it. Configure dashboards now, but **do NOT start spending** until the build is live and
events are verified (Gate 4).

- [ ] New build (AppsFlyer SDK in, TikTok SDK removed) submitted to App Store
- [ ] Build approved + live
- [ ] (before submit) appex `CFBundleShortVersionString` matches the app version, version/build bumped

## Step 1 — AppsFlyer: connect TikTok as an integrated partner
AppsFlyer → **Configuration → Integrated Partners** → search **"TikTok For Business"**
- [ ] Toggle **Activate partner**
- [ ] Integration tab: enable **install postbacks**
- [ ] Integration tab: enable **in-app event postbacks**
- [ ] Link the **TikTok Ads account** (OAuth / advertiser ID) so TikTok sees AppsFlyer as the MMP

## Step 2 — Map events (AppsFlyer → TikTok)
TikTok partner config → **In-app events** tab:
- [ ] `af_start_trial` → TikTok **Start Trial**
- [ ] `af_purchase` → TikTok **Subscribe** (include **value + currency**)
- [ ] `af_complete_registration` → TikTok **Complete Registration**
- [ ] Confirm revenue value is passed on `af_purchase`

## Step 3 — SKAN setup (critical for iOS — this is how trials get attributed on iOS)
AppsFlyer → **Configuration → SKAN / Conversion Studio**
- [ ] AppsFlyer is the **single SKAN owner** (TikTok SDK removed — verify)
- [ ] Build a conversion model mapping the funnel: **install → trial start → purchase**
- [ ] **Trial start is in the SKAN schema** (or iOS can't attribute trials)
- [ ] Enable **SKAN postbacks to TikTok**

## Step 4 — RevenueCat → AppsFlyer (trial→paid conversions; replaces the old webhook)
RevenueCat dashboard → **Integrations → AppsFlyer**
- [ ] Enable, enter AppsFlyer **Dev Key + App ID `6760232059`**
- [ ] Confirm app links AppsFlyer ID → RevenueCat (already in code: `setAppsflyerID` in `BeYouSwiftApp`)
- [ ] **DISABLE / remove the old RevenueCat → TikTok webhook** (`revenuecat-tiktok-webhook`)
      — otherwise TikTok double-counts trial→paid conversions

## Gate 4 — VERIFY before spending (do NOT skip)
- [ ] Register a **test device** in AppsFlyer
- [ ] Fire install + `af_start_trial` + `af_purchase`; confirm they appear in **AppsFlyer**
- [ ] Confirm they **forward to TikTok** — TikTok Events Manager with **AppsFlyer as the data source**
      (not "App Events SDK"); events move toward **Ready**
- [ ] (App-side SDK verification: use the `appsFlyer-sdk-mcp` wizard)

## Step 5 — TikTok Ads Manager: create the campaign
- [ ] Objective: **App Promotion**
- [ ] App shows **"Measured by AppsFlyer"**
- [ ] **iOS: create a dedicated iOS campaign** (SKAN-based; separate from Android)
- [ ] Optimization event = TikTok **Start Trial** (mapped from `af_start_trial`) — must show **Ready**
- [ ] Start with a **modest budget**; scale only after the event is Ready + conversions show

---

## Mistakes to specifically avoid
1. **Spending before the AppsFlyer build is live** → no attribution, wasted money.
2. **Leaving the RevenueCat→TikTok webhook ON** alongside RC→AppsFlyer → double-counted conversions.
3. **Trial not in the SKAN schema** → iOS can't attribute trials no matter what.
4. **Optimizing for an event that isn't "Ready"** → campaign can't deliver; let events/volume build.
5. **No iOS-dedicated campaign** → SKAN limits bite you.
6. **SKAN needs volume** (Apple "crowd anonymity") — low-volume conversions are suppressed; expect a
   ramp before trial data is reliable on iOS.

## Suggested timeline
Submit build → (meanwhile) do Steps 1–4 → build goes live → Gate 4 verify → Step 5 launch (small) →
verify conversions → scale.
