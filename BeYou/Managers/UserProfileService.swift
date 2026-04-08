import Foundation
import UIKit

/// Saves user onboarding data to Supabase user_profiles table.
class UserProfileService {
    static let shared = UserProfileService()
    private init() {}

    private let supabaseURL = Secrets.supabaseURL
    private let supabaseKey = Secrets.supabaseAnonKey

    /// Device-based ID that persists until app is deleted.
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    /// Upsert user profile after onboarding completes. Fire-and-forget — failures are silent.
    func saveOnboardingProfile(_ data: OnboardingData) {
        Task {
            await upsertProfile(data)
        }
    }

    private func upsertProfile(_ data: OnboardingData) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/user_profiles?on_conflict=device_id") else { return }

        // Build payload — only include non-nil / non-empty values
        var body: [String: Any] = [
            "device_id": deviceId
        ]

        if let referral = data.referral, !referral.isEmpty { body["referral"] = referral }
        if let name = data.name, !name.isEmpty { body["name"] = name }
        if let gender = data.gender, !gender.isEmpty { body["gender"] = gender }
        if let age = data.age { body["age"] = age }
        if !data.goals.isEmpty { body["goals"] = data.goals }
        if let currentScreenTime = data.currentScreenTime { body["current_screen_time"] = currentScreenTime }
        if let goalTime = data.goalTime { body["goal_time"] = goalTime }
        if !data.timeWasterApps.isEmpty { body["time_waster_apps"] = data.timeWasterApps }
        if !data.hardToQuitReasons.isEmpty { body["hard_to_quit_reasons"] = data.hardToQuitReasons }
        if !data.feelings.isEmpty { body["feelings"] = data.feelings }
        if !data.triedBefore.isEmpty { body["tried_before"] = data.triedBefore }
        if let relationship = data.relationship, !relationship.isEmpty { body["relationship"] = relationship }
        if let religion = data.religion, !religion.isEmpty { body["religion"] = religion }
        if !data.beliefs.isEmpty { body["beliefs"] = data.beliefs }
        if let familiarity = data.affirmationFamiliarity, !familiarity.isEmpty { body["affirmation_familiarity"] = familiarity }
        if let mood = data.currentMood, !mood.isEmpty { body["current_mood"] = mood }
        if !data.improveMethods.isEmpty { body["improve_methods"] = data.improveMethods }
        if let clearVision = data.clearVision, !clearVision.isEmpty { body["clear_vision"] = clearVision }
        if let believe = data.believeManifestation, !believe.isEmpty { body["believe_manifestation"] = believe }
        if let thoughts = data.thoughtsShapeReality, !thoughts.isEmpty { body["thoughts_shape_reality"] = thoughts }
        if !data.categories.isEmpty { body["categories"] = data.categories }
        if let iconStyle = data.iconStyle, !iconStyle.isEmpty { body["icon_style"] = iconStyle }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        // Upsert on device_id conflict — updates existing row if user re-onboards
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    print("✅ PROFILE: Saved to Supabase")
                } else {
                    print("⚠️ PROFILE: Supabase returned \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("⚠️ PROFILE: Failed to save — \(error.localizedDescription)")
        }
    }

    // MARK: - Subscription Status Sync

    /// Updates RevenueCat ID and subscription status in Supabase. Fire-and-forget.
    func syncSubscriptionStatus(revenueCatId: String, isSubscribed: Bool, isTrial: Bool, productId: String?) {
        Task {
            await upsertSubscriptionStatus(revenueCatId: revenueCatId, isSubscribed: isSubscribed, isTrial: isTrial, productId: productId)
        }
    }

    private func upsertSubscriptionStatus(revenueCatId: String, isSubscribed: Bool, isTrial: Bool, productId: String?) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/user_profiles?on_conflict=device_id") else { return }

        var body: [String: Any] = [
            "device_id": deviceId,
            "revenuecat_id": revenueCatId,
            "is_subscribed": isSubscribed,
            "is_trial": isTrial
        ]
        if let productId = productId { body["product_id"] = productId }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    print("✅ PROFILE: Subscription status synced to Supabase")
                } else {
                    print("⚠️ PROFILE: Supabase sub sync returned \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("⚠️ PROFILE: Failed to sync subscription — \(error.localizedDescription)")
        }
    }
}
