import Foundation

/// A lightweight receipt of goal counters at one point in a turn. No images, live
/// symbols, or model references survive in the snapshot.
struct BoardAccessibilityGoalSummary: Equatable {
    private struct Goal: Equatable {
        let id: String
        let remaining: Int
    }

    private let goals: [Goal]
    private let guardianHealth: Int?

    init(targets: [LevelTargetData], guardianHealth: Int? = nil) {
        var seen = Set<String>()
        goals = targets.compactMap { target in
            guard seen.insert(target.id).inserted else { return nil }
            return Goal(id: target.id, remaining: max(0, target.targetNum))
        }
        self.guardianHealth = guardianHealth.map { max(0, $0) }
    }

    /// Includes completed goals, so a status request can distinguish them from goals
    /// that the level never asked the player to complete.
    var remainingDescription: String {
        var parts = goals.map { remainingDescription(for: $0) }
        if let guardianHealth {
            parts.append(guardianHealth == 0
                ? String(localized: "Guardian defeated!")
                : String(localized: "Guardian health \(guardianHealth)."))
        }
        return parts.joined(separator: " ")
    }

    /// Compares settled counters with the turn's starting snapshot. New or removed
    /// objectives are not inferred to be progress; increased counts are stated plainly.
    func changes(since previous: Self) -> String {
        var parts: [String] = []
        for goal in goals {
            guard let oldGoal = previous.goals.first(where: { $0.id == goal.id }),
                  oldGoal.remaining != goal.remaining else { continue }
            let completed = oldGoal.remaining - goal.remaining
            let name = name(for: goal.id)
            if completed <= 0 {
                parts.append(remainingDescription(for: goal))
            } else if goal.remaining == 0 {
                parts.append(String(localized: "\(name): complete, \(completed) completed this move."))
            } else {
                parts.append(String(localized: "\(name): \(goal.remaining) remaining, \(completed) completed this move."))
            }
        }
        if let guardianHealth, let oldHealth = previous.guardianHealth, guardianHealth != oldHealth {
            if guardianHealth == 0 {
                parts.append(String(localized: "Guardian defeated!"))
            } else if guardianHealth < oldHealth {
                let damage = oldHealth - guardianHealth
                parts.append(String(localized: "Guardian: \(damage) damage, \(guardianHealth) health remaining."))
            } else {
                parts.append(String(localized: "Guardian health \(guardianHealth)."))
            }
        }
        return parts.joined(separator: " ")
    }

    private func remainingDescription(for goal: Goal) -> String {
        let name = name(for: goal.id)
        return goal.remaining == 0
            ? String(localized: "\(name): complete.")
            : String(localized: "\(name): \(goal.remaining) remaining.")
    }

    private func name(for id: String) -> String {
        switch id {
        case "firecracker": String(localized: "firecrackers")
        case "redPocket": String(localized: "red envelopes")
        case "dumpling": String(localized: "dumplings")
        case "bowl": String(localized: "bowls")
        case "lantern": String(localized: "lanterns")
        case "zodiac": String(localized: "Zodiac tiles")
        case "lock": String(localized: "locks")
        case "jelly": String(localized: "moon blossoms")
        case "ingredient": String(localized: "gifts to deliver")
        case "lightningCombos": String(localized: "Lightning activations")
        case "fiveCombos": String(localized: "Lucky Five activations")
        case "enhancedCombos": String(localized: "Blast Tile activations")
        default: String(localized: "Other goal")
        }
    }
}
