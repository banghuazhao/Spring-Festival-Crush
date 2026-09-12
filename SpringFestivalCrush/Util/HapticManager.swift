//
// Centralized haptic feedback so tactile cues (tile selection, matches, combos,
// win/lose) stay consistent across the game instead of ad-hoc generator calls.
//

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
        heavyImpact.impactOccurred()
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
