import Foundation

/// Generates personalized affirmations via Claude Haiku through a Supabase Edge Function.
/// Falls back to the local AffirmationService if the AI call fails or times out.
class AIAffirmationService {
    static let shared = AIAffirmationService()
    private init() {}

    private let edgeFunctionURL = "\(Secrets.supabaseURL)/functions/v1/generate-affirmations"
    private let supabaseKey = Secrets.supabaseAnonKey
    private let timeoutSeconds: TimeInterval = 5

    /// Generate personalized affirmations based on mood and user profile.
    /// Returns AI-generated affirmations, or nil if the call fails (caller should fall back).
    func generateAffirmations(
        mood: String,
        feeling: String?,
        name: String?,
        religion: String?,
        count: Int = 3
    ) async -> [String]? {
        guard let url = URL(string: edgeFunctionURL) else { return nil }

        var body: [String: Any] = [
            "mood": mood,
            "count": count
        ]
        if let feeling = feeling, !feeling.isEmpty { body["feeling"] = feeling }
        if let name = name, !name.isEmpty { body["name"] = name }
        if let religion = religion, !religion.isEmpty, religion != "general" { body["religion"] = religion }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = timeoutSeconds

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("⚠️ AI AFFIRMATION: Server returned non-200")
                return nil
            }

            let decoded = try JSONDecoder().decode(AIAffirmationResponse.self, from: data)
            print("✅ AI AFFIRMATION: Generated \(decoded.affirmations.count) affirmations")
            return decoded.affirmations
        } catch {
            print("⚠️ AI AFFIRMATION: Failed — \(error.localizedDescription)")
            return nil
        }
    }
}

private struct AIAffirmationResponse: Codable {
    let affirmations: [String]
}
