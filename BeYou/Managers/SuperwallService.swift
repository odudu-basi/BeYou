import SuperwallKit
import RevenueCat
import StoreKit

enum PurchasingError: LocalizedError {
    case sk2ProductNotFound

    var errorDescription: String? {
        switch self {
        case .sk2ProductNotFound:
            return "Superwall didn't pass a StoreKit 2 product to purchase."
        }
    }
}

/// Bridges Superwall paywall UI with RevenueCat purchase logic.
@available(iOS 16.0, *)
final class RCPurchaseController: PurchaseController {

    // MARK: - Subscription Status Sync

    func syncSubscriptionStatus() {
        guard Purchases.isConfigured else {
            print("⚠️ SUPERWALL: RevenueCat not configured yet, retrying in 1s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.syncSubscriptionStatus()
            }
            return
        }
        Task {
            for await customerInfo in Purchases.shared.customerInfoStream {
                let superwallEntitlements = customerInfo.entitlements.activeInCurrentEnvironment.keys.map {
                    Entitlement(id: $0)
                }
                await MainActor.run { [superwallEntitlements] in
                    if superwallEntitlements.isEmpty {
                        Superwall.shared.subscriptionStatus = .inactive
                    } else {
                        Superwall.shared.subscriptionStatus = .active(Set(superwallEntitlements))
                    }
                    // SubscriptionManager sync handled by its own PurchasesDelegate — no duplicate here
                }
            }
        }
    }

    // MARK: - PurchaseController

    @MainActor
    func purchase(product: SuperwallKit.StoreProduct) async -> PurchaseResult {
        do {
            guard let sk2Product = product.sk2Product else {
                throw PurchasingError.sk2ProductNotFound
            }
            let storeProduct = RevenueCat.StoreProduct(sk2Product: sk2Product)
            let result = try await Purchases.shared.purchase(product: storeProduct)
            if result.userCancelled {
                return .cancelled
            } else {
                // AppsFlyer conversion signal (forwarded to TikTok via the AppsFlyer integration).
                // If this purchase started a FREE TRIAL, report a (value-less) af_start_trial — no
                // money yet. If it's an immediate paid buy, report af_purchase with the real price.
                // The actual trial→paid conversion is reported server-side later via the
                // RevenueCat → AppsFlyer integration, since it happens days later, often with the
                // app closed.
                let startedTrial = result.customerInfo.entitlements.active.values.contains {
                    $0.periodType == .trial || $0.periodType == .intro
                }
                if startedTrial {
                    AppsFlyerManager.shared.trackTrialStarted()
                } else {
                    let value = NSDecimalNumber(decimal: storeProduct.price).doubleValue
                    let currency = storeProduct.currencyCode ?? "USD"
                    AppsFlyerManager.shared.trackSubscriptionPurchased(value: value, currency: currency)
                }
                return .purchased
            }
        } catch let error as ErrorCode {
            if error == .paymentPendingError {
                return .pending
            } else {
                return .failed(error)
            }
        } catch {
            return .failed(error)
        }
    }

    @MainActor
    func restorePurchases() async -> RestorationResult {
        do {
            _ = try await Purchases.shared.restorePurchases()
            return .restored
        } catch {
            return .failed(error)
        }
    }
}

// MARK: - Superwall Configuration

@available(iOS 16.0, *)
enum SuperwallService {
    static let purchaseController = RCPurchaseController()

    static func configure() {
        Superwall.configure(
            apiKey: Secrets.superwallAPIKey,
            purchaseController: purchaseController
        )

        // Never leave the status as .unknown — Superwall won't present a paywall until the
        // status is known, which on a FRESH install (RevenueCat's customerInfo stream hasn't
        // emitted yet) hangs the onboarding paywall on a blank screen. Default to .inactive;
        // the customerInfo stream upgrades it to .active if the user is actually subscribed.
        Superwall.shared.subscriptionStatus = .inactive

        purchaseController.syncSubscriptionStatus()
    }
}
