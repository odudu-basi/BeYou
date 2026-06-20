import Foundation
import FamilyControls

/// Persistence for the App Block feature: block every app except a user-picked
/// allow-list, engaged when an alarm fires, and only lifted via the unblock flow.
enum AppBlockStore {
    private static let enabledKey = "appBlockEnabled"        // feature armed
    private static let activeKey = "appBlockActive"          // currently blocking right now
    private static let allowedKey = "appBlockAllowedSelection"
    private static let denyDeletionKey = "appBlockDenyDeletion"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: activeKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
    }

    static var denyDeletion: Bool {
        get { UserDefaults.standard.bool(forKey: denyDeletionKey) }
        set { UserDefaults.standard.set(newValue, forKey: denyDeletionKey) }
    }

    /// The apps that stay usable during the block.
    static var allowedSelection: FamilyActivitySelection {
        get {
            guard let data = UserDefaults.standard.data(forKey: allowedKey),
                  let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
                return FamilyActivitySelection()
            }
            return selection
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: allowedKey)
            }
        }
    }
}
