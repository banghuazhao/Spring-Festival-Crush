import SwiftUI

/// Shared observable preferences; every screen and active scene reacts immediately.
@MainActor
final class SettingModel: ObservableObject {
    @Published var isPlayBackgroundMusic: Bool = UserDefaults.standard.object(forKey: "isPlayBackgroundMusic") == nil
        ? true : UserDefaults.standard.bool(forKey: "isPlayBackgroundMusic") {
        didSet { UserDefaults.standard.set(isPlayBackgroundMusic, forKey: "isPlayBackgroundMusic") }
    }
    #if DEBUG
    @Published var unlockAllLevels: Bool = UserDefaults.standard.object(forKey: "unlockAllLevels") == nil
        ? false : UserDefaults.standard.bool(forKey: "unlockAllLevels") {
        didSet { UserDefaults.standard.set(unlockAllLevels, forKey: "unlockAllLevels") }
    }
    #else
    /// Unlocking every level is a debug tool; release builds always follow progression,
    /// even if an earlier version left the stored flag on.
    let unlockAllLevels = false
    #endif
    @Published var playSoundEffect: Bool = UserDefaults.standard.object(forKey: "playSoundEffect") == nil
        ? true : UserDefaults.standard.bool(forKey: "playSoundEffect") {
        didSet { UserDefaults.standard.set(playSoundEffect, forKey: "playSoundEffect") }
    }
    @Published var musicVolume: Double = UserDefaults.standard.object(forKey: "musicVolume") == nil
        ? 0.7 : UserDefaults.standard.double(forKey: "musicVolume") {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "musicVolume") }
    }
    @Published var soundEffectsVolume: Double = UserDefaults.standard.object(forKey: "soundEffectsVolume") == nil
        ? 0.8 : UserDefaults.standard.double(forKey: "soundEffectsVolume") {
        didSet { UserDefaults.standard.set(soundEffectsVolume, forKey: "soundEffectsVolume") }
    }
    @Published var hapticsEnabled: Bool = UserDefaults.standard.object(forKey: "hapticsEnabled") == nil
        ? true : UserDefaults.standard.bool(forKey: "hapticsEnabled") {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }
    @Published var screenShakeEnabled: Bool = UserDefaults.standard.object(forKey: "screenShakeEnabled") == nil
        ? true : UserDefaults.standard.bool(forKey: "screenShakeEnabled") {
        didSet { UserDefaults.standard.set(screenShakeEnabled, forKey: "screenShakeEnabled") }
    }
    @Published var reducedEffects: Bool = UserDefaults.standard.object(forKey: "reducedEffects") == nil
        ? false : UserDefaults.standard.bool(forKey: "reducedEffects") {
        didSet { UserDefaults.standard.set(reducedEffects, forKey: "reducedEffects") }
    }
    @Published var idleHintsEnabled: Bool = UserDefaults.standard.object(forKey: "idleHintsEnabled") == nil
        ? true : UserDefaults.standard.bool(forKey: "idleHintsEnabled") {
        didSet { UserDefaults.standard.set(idleHintsEnabled, forKey: "idleHintsEnabled") }
    }
}
