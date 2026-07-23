import Foundation
import TikTokBusinessSDK

@available(iOS 16.0, *)
class TikTokManager {
    static let shared = TikTokManager()

    private init() {}

    // MARK: - Configuration

    func configure() {
        guard let config = TikTokConfig(
            accessToken: Secrets.tiktokAppSecret,
            appId: Secrets.tiktokAppID,
            tiktokAppId: Secrets.tiktokTikTokAppID
        ) else {
            print("❌ TIKTOK: Failed to create config")
            return
        }

        TikTokBusiness.initializeSdk(config) { success, error in
            if success {
                print("📱 TIKTOK: SDK initialized successfully")
            } else {
                print("❌ TIKTOK: SDK initialization failed: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }

    // MARK: - Event Tracking

    func trackAppOpen() {
        TikTokBusiness.trackTTEvent(TikTokBaseEvent(eventName: "LaunchAPP"))
    }

    func trackOnboardingComplete() {
        // "Registration" is TikTok's standard event (TTEventNameRegistration).
        TikTokBusiness.trackTTEvent(TikTokBaseEvent(eventName: "Registration"))
    }

    /// Fired when a FREE TRIAL begins (no money yet) — TikTok's standard `StartTrial`.
    /// Intentionally carries no `value`, so a trial start doesn't inflate reported revenue.
    func trackTrialStarted() {
        TikTokBusiness.trackTTEvent(TikTokBaseEvent(eventName: "StartTrial"))
    }

    /// Fired on a real subscription purchase with money changing hands (immediate, no-trial buy).
    /// The trial→paid conversion is reported server-side (RevenueCat webhook → TikTok Events API).
    func trackSubscriptionPurchased(value: Double, currency: String = "USD") {
        let event = TikTokBaseEvent(eventName: "Subscribe")
        event.addProperty(withKey: "value", value: NSNumber(value: value))
        event.addProperty(withKey: "currency", value: currency as NSString)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackPurchase(value: Double, currency: String = "USD") {
        // "Purchase" is TikTok's standard event (TTContentsEventNamePurchase).
        let event = TikTokBaseEvent(eventName: "Purchase")
        event.addProperty(withKey: "value", value: NSNumber(value: value))
        event.addProperty(withKey: "currency", value: currency as NSString)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackViewContent(contentName: String) {
        let event = TikTokBaseEvent(eventName: "ViewContent")
        event.addProperty(withKey: "content_name", value: contentName as NSString)
        TikTokBusiness.trackTTEvent(event)
    }
}
