import SwiftUI
import Combine
import StoreKit
import RevenueCat

@available(iOS 16.0, *)
class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = SubscriptionManager()

    @Published var isProUser: Bool = false
    @Published var customerInfo: RevenueCat.CustomerInfo?
    /// False until RevenueCat has resolved entitlements at least once. The reactive gate uses this
    /// so it never flashes the paywall at a real subscriber before their status is known on launch.
    @Published private(set) var hasResolvedEntitlements = false

    /// RevenueCat anonymous user ID — stable across sessions, persists until app delete
    var revenueCatUserId: String {
        Purchases.shared.appUserID
    }

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    func configure() {
        // Configure RevenueCat
        #if DEBUG
        Purchases.logLevel = .warn
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)

        // Listen for ALL entitlement changes — including purchases/restores
        // that happen outside the paywall (e.g., App Store review, direct StoreKit)
        Purchases.shared.delegate = self

        // Fetch initial entitlements
        Task {
            await refreshEntitlements()
        }
    }

    // MARK: - RevenueCat Delegate

    /// Called whenever RevenueCat detects an entitlement change — this covers:
    /// - Direct App Store purchases (Apple review environment)
    /// - Restores triggered outside the paywall
    /// - Subscription renewals, expirations, cancellations
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: RevenueCat.CustomerInfo) {
        print("💰 SUBS DELEGATE: Received updated customer info")
        DispatchQueue.main.async { [weak self] in
            self?.syncEntitlementStatus(from: customerInfo)
        }
    }

    // MARK: - Entitlement Syncing

    /// Single source of truth for updating subscription state.
    @MainActor
    func syncEntitlementStatus(from info: RevenueCat.CustomerInfo) {
        self.customerInfo = info
        let wasProUser = self.isProUser
        self.isProUser = info.entitlements["BeYou_Pro"]?.isActive == true

        // Identify user in Mixpanel with RevenueCat ID
        let rcId = revenueCatUserId
        AnalyticsManager.shared.identify(userId: rcId)
        AnalyticsManager.shared.setUserProperties([
            "revenuecat_id": rcId,
            "is_subscribed": isProUser,
            "subscription_product": info.entitlements["BeYou_Pro"]?.productIdentifier ?? "",
            "is_trial": info.entitlements["BeYou_Pro"]?.periodType == .trial
        ])

        // Store RevenueCat ID in SharedDataManager for emails
        SharedDataManager.shared.saveUserID(rcId)

        // Sync to Supabase
        UserProfileService.shared.syncSubscriptionStatus(
            revenueCatId: rcId,
            isSubscribed: isProUser,
            isTrial: info.entitlements["BeYou_Pro"]?.periodType == .trial,
            productId: info.entitlements["BeYou_Pro"]?.productIdentifier
        )

        if !hasResolvedEntitlements {
            hasResolvedEntitlements = true
            print("💰 SUBS: Initial sync — isProUser: \(isProUser), rcId: \(rcId)")
        } else if !wasProUser && isProUser {
            print("💰 SUBS: User became Pro")
            AnalyticsManager.shared.trackSubscriptionPurchased()
        } else if wasProUser && !isProUser {
            print("💰 SUBS: Pro status expired/revoked")
        }
    }

    // MARK: - Entitlement Checking

    @MainActor
    func refreshEntitlements() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            syncEntitlementStatus(from: info)
        } catch {
            print("❌ SUBS: Failed to fetch customer info: \(error)")
        }
    }

    @MainActor
    func restorePurchases() async -> Bool {
        do {
            let info = try await Purchases.shared.restorePurchases()
            syncEntitlementStatus(from: info)
            if isProUser {
                AnalyticsManager.shared.trackSubscriptionRestored()
            }
            return isProUser
        } catch {
            print("❌ SUBS: Failed to restore purchases: \(error)")
            return false
        }
    }
}
