import SuperwallKit

/// Maps a Superwall `PaywallResult` to a short analytics-friendly string.
func paywallResultName(_ result: PaywallResult) -> String {
    switch result {
    case .purchased: return "purchased"
    case .restored: return "restored"
    default: return "declined"
    }
}
