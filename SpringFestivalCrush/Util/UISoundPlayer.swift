import AVFoundation

/// Plays festival cues on SwiftUI screens (envelopes, chests) where there is no SpriteKit
/// scene. Honors the same sound-effects toggle and volume as the board.
@MainActor
final class UISoundPlayer {
    static let shared = UISoundPlayer()
    private var players: [GameSound: AVAudioPlayer] = [:]

    private var volume: Float {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "playSoundEffect") == nil || defaults.bool(forKey: "playSoundEffect")
        guard enabled else { return 0 }
        let level = defaults.object(forKey: "soundEffectsVolume") == nil ? 0.8 : defaults.double(forKey: "soundEffectsVolume")
        return Float(min(1, max(0, level)))
    }

    func play(_ sound: GameSound, volume scale: Float = 1) {
        let level = volume * scale
        guard level > 0 else { return }
        if players[sound] == nil,
           let url = Bundle.main.url(forResource: sound.rawValue, withExtension: nil) {
            players[sound] = try? AVAudioPlayer(contentsOf: url)
            players[sound]?.prepareToPlay()
        }
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.volume = level
        player.play()
    }
}
