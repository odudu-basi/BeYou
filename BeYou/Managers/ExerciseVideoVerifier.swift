import UIKit

/// Sends sampled frames from an exercise recording (Push Ups / Squats) to the
/// `verify-exercise-video` edge function for AI verification. Everything fails OPEN —
/// any network/parse/error returns `pass = true` so a groggy user is never locked out.
enum ExerciseVideoVerifier {

    struct Result {
        let pass: Bool
        let reason: String
    }

    static func praise() -> String {
        ["Nice work!", "Strong!", "Let's go!", "Great set!", "Crushed it!"].randomElement() ?? "Nice!"
    }

    static func friendlyRejection(exercise: String) -> String {
        let openers = ["Hmm", "Not quite", "Almost"]
        let name = exercise == "Squats" ? "squats" : "push-ups"
        return "\(openers.randomElement() ?? "Hmm") — I couldn't see clear \(name). Try again!"
    }

    /// Verifies a set of sampled frames. `exercise` is "Push Ups" or "Squats".
    static func verify(frames: [UIImage], exercise: String) async -> Result {
        let base64Frames = frames.compactMap { downscaledJPEGBase64($0) }
        guard !base64Frames.isEmpty,
              let url = URL(string: "\(Secrets.supabaseURL)/functions/v1/verify-exercise-video") else {
            return Result(pass: true, reason: "") // fail open (no camera / no frames)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")

        let payload: [String: Any] = ["mission": exercise, "framesBase64": base64Frames]
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

    /// Downscale each frame to ~512px + JPEG — keeps the upload small and the vision call cheap.
    private static func downscaledJPEGBase64(_ image: UIImage, maxDimension: CGFloat = 512) -> String? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.5)?.base64EncodedString()
    }
}
