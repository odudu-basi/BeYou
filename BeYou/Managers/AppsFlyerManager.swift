import Foundation
import AppsFlyerLib

@available(iOS 16.0, *)
class AppsFlyerManager: NSObject {
    static let shared = AppsFlyerManager()

    private override init() {}

    // MARK: - Configuration

    /// Configures and starts the AppsFlyer SDK. `customerUserID` is set BEFORE `start()` so the
    /// install event is associated with it (setting it after start() would miss that event).
    func configure(customerUserID: String? = nil) {
        #if DEBUG
        AppsFlyerLib.shared().isDebug = true
        #endif

        AppsFlyerLib.shared().initialize(devKey: Secrets.appsFlyerDevKey, appId: Secrets.appsFlyerAppleAppID)

        if let customerUserID {
            AppsFlyerLib.shared().customerUserID = customerUserID
        }

        AppsFlyerLib.shared().start { dictionary, error in
            if let error {
                print("❌ APPSFLYER: start failed: \(error.localizedDescription)")
                return
            }
            print("📱 APPSFLYER: start success: \(dictionary ?? [:])")
        }
    }

    // MARK: - Event Tracking

    func trackOnboardingComplete() {
        AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: [:])
    }

    /// Fired when a FREE TRIAL begins (no money yet) — AppsFlyer's standard `af_start_trial`.
    /// Intentionally carries no revenue value, so a trial start doesn't inflate reported revenue.
    func trackTrialStarted() {
        AppsFlyerLib.shared().logEvent(AFEventStartTrial, withValues: [:])
    }

    /// Fired on a real subscription purchase with money changing hands (immediate, no-trial buy).
    /// The trial→paid conversion is reported server-side via the RevenueCat → AppsFlyer integration.
    func trackSubscriptionPurchased(value: Double, currency: String = "USD") {
        AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: [
            AFEventParamRevenue: value,
            AFEventParamCurrency: currency
        ])
    }
}
