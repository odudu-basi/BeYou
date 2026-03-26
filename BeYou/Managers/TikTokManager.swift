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
        TikTokBusiness.trackTTEvent(TikTokBaseEvent(eventName: "CompleteRegistration"))
    }

    func trackSubscriptionPurchased(value: Double, currency: String = "USD") {
        let event = TikTokBaseEvent(eventName: "Subscribe")
        event.addProperty(withKey: "value", value: NSNumber(value: value))
        event.addProperty(withKey: "currency", value: currency as NSString)
        TikTokBusiness.trackTTEvent(event)
    }

    func trackPurchase(value: Double, currency: String = "USD") {
        let event = TikTokBaseEvent(eventName: "CompletePurchase")
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
