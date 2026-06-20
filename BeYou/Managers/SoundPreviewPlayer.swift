import AVFoundation
import Combine

/// Plays the bundled alarm `.caf` files for previewing in the sound pickers.
/// `playingSound` lets the UI show a play/stop state per row.
final class SoundPreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = SoundPreviewPlayer()

    @Published private(set) var playingSound: String?

    private var player: AVAudioPlayer?

    /// UI sound name → bundled file base name (all `.caf`). Mirrors AlarmService.alertSound.
    /// "Default" has no preview file (it's the system alarm sound).
    private static let fileNames: [String: String] = [
        "Annoying": "alarm_annoying",
        "Beeping": "alarm_beeping",
        "Zen": "alarm_zen",
        "Nature": "Animals in nature",
        "Rooster": "rooster",
        "Kalimba": "kalimba",
        "Guitar": "Guitar",
        "Jazz": "Jazz",
        "Lofi Piano": "Lofi Piano",
        "Melodic": "Melodic",
        "Loud Bell": "Loud bell",
        "Buzzer": "loud buzzer",
        "Loud Impact": "Loud impact alarm",
        "Fighter Jet": "Fighter jet",
        "Navy": "Navy loud",
        "Raid": "Raid",
    ]

    private override init() { super.init() }

    /// Whether a given sound can be previewed (has a bundled file).
    static func canPreview(_ sound: String) -> Bool {
        fileNames[sound] != nil
    }

    /// Play the sound, or stop it if it's already the one playing.
    func toggle(_ sound: String) {
        if playingSound == sound {
            stop()
        } else {
            play(sound)
        }
    }

    func play(_ sound: String) {
        stop()
        guard let base = Self.fileNames[sound],
              let url = Bundle.main.url(forResource: base, withExtension: "caf") else {
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            player = newPlayer
            newPlayer.play()
            playingSound = sound
        } catch {
            print("🔊 Sound preview error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingSound = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        playingSound = nil
    }
}
