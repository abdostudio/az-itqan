import Foundation
import AVFoundation
import AppKit

/// Bundled adhan clips (short parts of the adhan, faded out) + an optional spoken announcement.
/// Recordings from Wikimedia Commons — see `credits`.
final class AdhanPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = AdhanPlayer()

    struct Voice { let id: String; let name: String; let clips: [String] }
    static let voices: [Voice] = [
        Voice(id: "adhan-1", name: tr("أذان ١ — مغاربي"), clips: ["v1-open"]),
        Voice(id: "adhan-2", name: tr("أذان ٢ — هادي"), clips: ["v2-open", "v2-hayya", "v2-close"]),
        Voice(id: "adhan-3", name: tr("أذان ٣ — المسجد النبوي"), clips: ["v3-open", "v3-hayya", "v3-close"]),
    ]
    static let systemSounds = ["Glass", "Hero", "Submarine", "Purr", "Ping", "Blow", "Bottle", "Funk", "Pop", "Tink"]
    static let credits = tr("أصوات الأذان من Wikimedia Commons: أذان ١ ملكية عامة (B9)، أذان ٢ Atcovi ‏(CC BY-SA 4.0)، أذان ٣ ejaz215 ‏(CC BY 3.0). اتقصّ منها أجزاء قصيرة.")

    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var nsSound: NSSound?
    private let speech = AVSpeechSynthesizer()
    private var pendingAnnouncement: String?
    private var lastClip: String?

    override init() {
        super.init()
        speech.delegate = self
    }

    /// Plays the chosen sound for `prayer` (nil = preview). "Varied" picks a random voice and part each time.
    func play(_ s: AppSettings, prayer: Prayer?) {
        guard s.soundEnabled else { return }
        stop()
        // The synthesized spoken announcement was removed (it sounded robotic) — real adhan recordings only.
        let announcement: String? = nil

        if let clip = clipName(for: s.soundName), let url = Bundle.main.url(forResource: clip, withExtension: "m4a", subdirectory: "adhan")
            ?? Bundle.main.url(forResource: clip, withExtension: "m4a") {
            lastClip = clip
            // Variety: sometimes the announcement comes first, sometimes after the adhan.
            if let a = announcement, Bool.random() {
                pendingAnnouncement = nil
                speak(a, then: url, volume: s.adhanVolume)
            } else {
                pendingAnnouncement = announcement
                startClip(url, volume: s.adhanVolume)
            }
            return
        }
        // System sound or the user's own file
        if s.soundName == "custom", !s.customSoundPath.isEmpty,
           let snd = NSSound(contentsOfFile: s.customSoundPath, byReference: true) {
            nsSound = snd
        } else {
            nsSound = NSSound(named: NSSound.Name(s.soundName))
        }
        nsSound?.volume = Float(s.adhanVolume)
        nsSound?.play()
        isPlaying = nsSound != nil
        if let a = announcement {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.speak(a, then: nil, volume: s.adhanVolume) }
        }
    }

    func stop() {
        player?.stop(); player = nil
        nsSound?.stop(); nsSound = nil
        if speech.isSpeaking { speech.stopSpeaking(at: .immediate) }
        pendingAnnouncement = nil
        nextAfterSpeech = nil
        isPlaying = false
    }

    // MARK: internals

    private func clipName(for soundName: String) -> String? {
        let pool: [String]
        if soundName == "adhan-mix" {
            pool = Self.voices.flatMap(\.clips)
        } else if let v = Self.voices.first(where: { $0.id == soundName }) {
            pool = v.clips
        } else {
            return nil
        }
        let fresh = pool.filter { $0 != lastClip }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }

    private func startClip(_ url: URL, volume: Double) {
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.volume = Float(volume)
        p.play()
        player = p
        isPlaying = true
    }

    private var nextAfterSpeech: (URL, Double)?

    private func speak(_ text: String, then url: URL?, volume: Double) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "ar-SA") ?? AVSpeechSynthesisVoice(language: "ar")
        u.rate = 0.42
        u.volume = Float(volume)
        nextAfterSpeech = url.map { ($0, volume) }
        isPlaying = true
        speech.speak(u)
    }

    static func announcement(for prayer: Prayer?) -> String? {
        let name = (prayer ?? .asr).arabic()
        return [
            trf("حان الآن موعد صلاة %@", name),
            trf("حيّ على الصلاة… حان وقت صلاة %@", name),
            trf("قد حان وقت صلاة %@", name),
            trf("صلاة %@… قوموا إلى صلاتكم", name),
        ].randomElement()
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully flag: Bool) {
        player = nil
        if let a = pendingAnnouncement {
            pendingAnnouncement = nil
            speak(a, then: nil, volume: Double(p.volume))
        } else {
            isPlaying = false
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        if let (url, vol) = nextAfterSpeech {
            nextAfterSpeech = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.startClip(url, volume: vol) }
        } else if player == nil && nsSound?.isPlaying != true {
            isPlaying = false
        }
    }
}

/// Kept for existing call sites.
enum SoundPlayer {
    static func play(_ s: AppSettings, prayer: Prayer? = nil) { AdhanPlayer.shared.play(s, prayer: prayer) }
    static func stop() { AdhanPlayer.shared.stop() }
}
