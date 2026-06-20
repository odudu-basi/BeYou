import Foundation
import AVFoundation
import Combine

class TTSService: ObservableObject {
    static let shared = TTSService()
    private init() {
        configureAudioSession()
    }

    private let edgeFunctionURL = "\(Secrets.supabaseURL)/functions/v1/text-to-speech"
    private let supabaseKey = Secrets.supabaseAnonKey
    private var audioPlayer: AVAudioPlayer?
    private var prefetchedAudio: [Int: Data] = [:]
    private var prefetchTasks: [Int: Task<Void, Never>] = [:]

    @Published var isPlaying = false
    @Published var isLoading = false

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("TTS: Failed to configure audio session: \(error)")
        }
    }

    /// Fetch audio for an affirmation from ElevenLabs via Supabase Edge Function
    func fetchAudio(text: String, voiceId: String?) async -> Data? {
        guard let url = URL(string: edgeFunctionURL) else { return nil }

        var body: [String: Any] = ["text": text]
        if let voiceId = voiceId, !voiceId.isEmpty {
            body["voice_id"] = voiceId
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("TTS: Server returned non-200")
                return nil
            }
            return data
        } catch {
            print("TTS: Failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Play audio data
    func play(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
            isPlaying = true

            // Monitor playback completion
            Task { @MainActor in
                while audioPlayer?.isPlaying == true {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                isPlaying = false
            }
        } catch {
            print("TTS: Playback failed — \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// Stop current playback
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }

    /// Pre-fetch audio for a specific affirmation index
    func prefetch(text: String, voiceId: String?, index: Int) {
        // Don't re-fetch if already cached
        guard prefetchedAudio[index] == nil else { return }

        prefetchTasks[index]?.cancel()
        prefetchTasks[index] = Task {
            if let data = await fetchAudio(text: text, voiceId: voiceId) {
                await MainActor.run {
                    prefetchedAudio[index] = data
                }
            }
        }
    }

    /// Get pre-fetched audio for an index, or fetch it now
    func getAudio(text: String, voiceId: String?, index: Int) async -> Data? {
        if let cached = prefetchedAudio[index] {
            return cached
        }
        let data = await fetchAudio(text: text, voiceId: voiceId)
        if let data = data {
            await MainActor.run {
                prefetchedAudio[index] = data
            }
        }
        return data
    }

    /// Clear all pre-fetched audio
    func clearCache() {
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
        prefetchedAudio.removeAll()
        stop()
    }
}
