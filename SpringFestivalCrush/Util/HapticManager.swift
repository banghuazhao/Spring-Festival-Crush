//
// Centralized haptic feedback so tactile cues (tile selection, matches, combos,
// win/lose) stay consistent across the game instead of ad-hoc generator calls.
//

import UIKit

enum HapticManager {
    private static let selection = UISelectionFeedbackGenerator()
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        selection.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    /// Tapping/selecting a tile.
    static func tileSelected() {
        selection.selectionChanged()
    }

    /// A valid swap that starts resolving.
    static func swap() {
        lightImpact.impactOccurred()
    }

    /// A swap that bounces back because it made no match.
    static func invalidSwap() {
        notification.notificationOccurred(.warning)
    }

    /// A normal 3-in-a-row style match.
    static func match() {
        lightImpact.impactOccurred(intensity: 0.7)
    }

    /// A bigger chain (4+, L/T-shape) or a special tile activating.
    static func bigMatch() {
        mediumImpact.impactOccurred()
    }

    /// Enhanced/lightning/five explosion — the biggest single event on the board.
    static func explosion() {
        heavyImpact.impactOccurred()
    }

    static func levelWin() {
        notification.notificationOccurred(.success)
    }

    static func levelLose() {
        notification.notificationOccurred(.error)
    }

    static func buttonTap() {
        lightImpact.impactOccurred()
    }
}
