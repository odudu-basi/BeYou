import Foundation
import AVFoundation

/// Plays the alarm sound on a continuous loop while a mission is on screen, so there are no
/// gaps between the system's AlarmKit bursts. Uses the .playback category so it rings even
/// when the phone's mute switch is on (it's an alarm).
///
/// Activating the audio session can fail transiently while AlarmKit still owns audio
/// ("cannotStartPlaying"), so start() RETRIES until it actually plays, and only then fires its
/// `onStarted` callback — the caller silences the system alarm there, guaranteeing we never
/// hand off into silence.
final class MissionAlarmAudio {
    static let shared = MissionAlarmAudio()
    private var player: AVAudioPlayer?
    private init() {}

    var isPlaying: Bool { player?.isPlaying == true }

    private func fileName(for sound: String) -> String {
        switch sound {
        case "Annoying":    return "alarm_annoying.caf"
        case "Beeping":     return "alarm_beeping.caf"
        case "Zen":         return "alarm_zen.caf"
        case "Nature":      return "Animals in nature.caf"
        case "Rooster":     return "rooster.caf"
        case "Kalimba":     return "kalimba.caf"
        case "Guitar":      return "Guitar.caf"
        case "Jazz":        return "Jazz.caf"
        case "Lofi Piano":  return "Lofi Piano.caf"
        case "Melodic":     return "Melodic.caf"
        case "Loud Bell":   return "Loud bell.caf"
        case "Buzzer":      return "loud buzzer.caf"
        case "Loud Impact": return "Loud impact alarm.caf"
        case "Fighter Jet": return "Fighter jet.caf"
        case "Navy":        return "Navy loud.caf"
        case "Raid":        return "Raid.caf"
        default:            return "alarm_beeping.caf"
        }
    }

    /// Starts (or resumes) the continuous loop. `onStarted` fires the moment audio is actually
    /// playing — use it to silence the system alarm so only the loop plays.
    func start(sound: String, onStarted: (() -> Void)? = nil) {
        if isPlaying { onStarted?(); return }
        attempt(sound: sound, retriesLeft: 8, onStarted: onStarted)
    }

    private func attempt(sound: String, retriesLeft: Int, onStarted: (() -> Void)?) {
        if isPlaying { onStarted?(); return }

        let name = fileName(for: sound)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext) else {
            print("🔊 MissionAlarmAudio: missing \(name)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            player = p
            onStarted?()
        } catch {
            print("🔊 MissionAlarmAudio: start failed (\(retriesLeft) left) — \(error.localizedDescription)")
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.attempt(sound: sound, retriesLeft: retriesLeft - 1, onStarted: onStarted)
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
