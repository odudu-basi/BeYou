import UIKit

/// Sends a captured mission photo to the `verify-mission-photo` edge function for
/// AI verification (OpenAI vision). Everything fails OPEN — any network/parse/error
/// returns `pass = true` so a groggy user is never locked out by a flaky check.
enum MissionPhotoVerifier {

    struct Result {
        let pass: Bool
        let reason: String
    }

    /// A warm, on-brand "try again" line for a rejected photo. We use our own copy rather
    /// than the AI's raw reason so the tone stays consistently friendly.
    static func friendlyRejection(mission: String, target: String?) -> String {
        let phrase: String
        switch mission {
        case "Make Your Bed": phrase = "a made bed"
        case "Picture of Sky": phrase = "the sky"
        case "Touch Grass": phrase = "grass"
        case "Item Search": phrase = "a \(target?.lowercased() ?? "match")"
        default: phrase = "the right thing"
        }
        let openers = ["Oops", "Hmm", "Not quite"]
        return "\(openers.randomElement() ?? "Oops") — I don't think that's \(phrase). Try again!"
    }

    /// A quick positive line shown when a photo passes, before advancing.
    static func praise() -> String {
        ["Great!", "Nice!", "Perfect!", "Got it!", "Awesome!"].randomElement() ?? "Great!"
    }

    static func verify(image: UIImage, mission: String, target: String?) async -> Result {
        guard let base64 = downscaledJPEGBase64(image),
              let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/verify-mission-photo") else {
            return Result(pass: true, reason: "")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let payload: [String: Any] = [
            "mission": mission,
            "target": target ?? "",
            "imageBase64": base64
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Result(pass: true, reason: "") // fail open
            }
            let pass = (json["pass"] as? Bool) ?? true
            let reason = (json["reason"] as? String) ?? ""
            return Result(pass: pass, reason: reason)
        } catch {
            return Result(pass: true, reason: "") // fail open on network error
        }
    }

    /// Downscale to ~512px on the long edge + JPEG — keeps the upload small and the
    /// vision call cheap/fast.
    private static func downscaledJPEGBase64(_ image: UIImage, maxDimension: CGFloat = 512) -> String? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.6)?.base64EncodedString()
    }
}
