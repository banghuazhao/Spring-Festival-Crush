//
// Centralized haptic feedback so tactile cues (tile selection, matches, combos,
// win/lose) stay consistent across the game instead of ad-hoc generator calls.
//

import CoreHaptics
import UIKit

enum HapticManager {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") == nil || UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    private static let selection = UISelectionFeedbackGenerator()
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        guard isEnabled else { return }
        selection.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        FestivalHaptics.shared.prepare()
    }

    /// Tapping/selecting a tile.
    static func tileSelected() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// A valid swap that starts resolving.
    static func swap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    /// A swap that bounces back because it made no match.
    static func invalidSwap() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// A normal 3-in-a-row style match.
    static func match() {
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// A bigger chain (4+, L/T-shape) or a special tile activating.
    static func bigMatch() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }

    /// Enhanced/lightning/five explosion — the biggest single event on the board.
    static func explosion() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.explosion) { heavyImpact.impactOccurred() }
    }

    /// Lightning and firecracker blasts: a crackling string of sharp taps.
    static func firecracker() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.firecracker) { mediumImpact.impactOccurred() }
    }

    /// A cascade step. Deeper cascades land harder and brighter.
    static func cascade(depth: Int) {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.cascade(depth)) { lightImpact.impactOccurred(intensity: 0.8) }
    }

    /// The guardian takes damage; `damage` scales the thud.
    static func bossHit(damage: Int) {
        guard isEnabled else { return }
        let strength = Float(min(1, max(0.2, Double(damage) / 12)))
        if !FestivalHaptics.shared.play(.bossHit(strength)) { heavyImpact.impactOccurred(intensity: CGFloat(strength)) }
    }

    /// The guardian's raid: a rising rumble that lands on a heavy blow.
    static func bossAttack() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.bossAttack) { notification.notificationOccurred(.warning) }
    }

    /// Opening an envelope or chest, or buying a continue.
    static func rewardOpen() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.rewardOpen) { notification.notificationOccurred(.success) }
    }

    /// One firework bursting during the level finale.
    static func fireworkBurst() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.firework) { lightImpact.impactOccurred() }
    }

    /// Out of moves with the goal almost done: two soft knocks, not an error buzz.
    static func nearMiss() {
        guard isEnabled else { return }
        if !FestivalHaptics.shared.play(.nearMiss) { mediumImpact.impactOccurred(intensity: 0.6) }
    }

    static func levelWin() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    static func levelLose() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    static func buttonTap() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }

    static func locked() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    static func unavailable() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.65)
    }
}

/// Custom Core Haptics patterns. Every call reports whether it played, so callers can fall
/// back to the stock UIKit generators on devices without a Taptic Engine.
final class FestivalHaptics {
    static let shared = FestivalHaptics()

    enum Pattern {
        case explosion, firecracker, bossAttack, rewardOpen, nearMiss, firework
        case cascade(Int)
        case bossHit(Float)

        var events: [CHHapticEvent] {
            switch self {
            case .explosion:
                return [Self.transient(0, 1, 0.55),
                        Self.continuous(0.01, 0.12, 0.7, 0.25),
                        Self.continuous(0.13, 0.16, 0.35, 0.1)]
            case .firecracker:
                let times: [TimeInterval] = [0, 0.035, 0.07, 0.11, 0.145, 0.19, 0.24]
                return times.enumerated().map { index, time in
                    Self.transient(time, 0.95 - Float(index) * 0.08, 0.9)
                }
            case let .cascade(depth):
                let tier = Float(min(5, max(1, depth)))
                return [Self.transient(0, min(1, 0.4 + tier * 0.1), min(1, 0.25 + tier * 0.13))]
            case let .bossHit(strength):
                return [Self.transient(0, min(1, 0.55 + strength * 0.45), 0.3),
                        Self.continuous(0, 0.14, strength * 0.55, 0.08)]
            case .bossAttack:
                return [Self.continuous(0, 0.3, 0.35, 0.05),
                        Self.continuous(0.3, 0.12, 0.7, 0.12),
                        Self.transient(0.42, 1, 0.2)]
            case .rewardOpen:
                return [Self.continuous(0, 0.26, 0.3, 0.4),
                        Self.transient(0.28, 0.85, 0.75),
                        Self.transient(0.36, 0.6, 0.9),
                        Self.transient(0.44, 0.45, 1)]
            case .nearMiss:
                return [Self.transient(0, 0.5, 0.2), Self.transient(0.16, 0.35, 0.2)]
            case .firework:
                return [Self.transient(0, 0.7, 0.35)]
                    + (1...4).map { Self.transient(0.06 + Double($0) * 0.05, 0.28, 1) }
            }
        }

        private static func transient(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, min(1, intensity))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, min(1, sharpness)))
            ], relativeTime: time)
        }

        private static func continuous(_ time: TimeInterval, _ duration: TimeInterval,
                                       _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0, min(1, intensity))),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0, min(1, sharpness)))
            ], relativeTime: time, duration: duration)
        }
    }

    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var needsStart = true

    func prepare() {
        _ = runningEngine()
    }

    @discardableResult
    func play(_ pattern: Pattern) -> Bool {
        guard let engine = runningEngine() else { return false }
        do {
            let player = try engine.makePlayer(with: CHHapticPattern(events: pattern.events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            needsStart = true
            return false
        }
    }

    private func runningEngine() -> CHHapticEngine? {
        guard supportsHaptics else { return nil }
        do {
            if engine == nil {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                // The system stops the engine on interruptions and idle timeouts; restart lazily.
                engine.stoppedHandler = { [weak self] _ in
                    DispatchQueue.main.async { self?.needsStart = true }
                }
                engine.resetHandler = { [weak self] in
                    DispatchQueue.main.async { self?.needsStart = true }
                }
                self.engine = engine
                needsStart = true
            }
            if needsStart {
                try engine?.start()
                needsStart = false
            }
            return engine
        } catch {
            engine = nil
            return nil
        }
    }
}
