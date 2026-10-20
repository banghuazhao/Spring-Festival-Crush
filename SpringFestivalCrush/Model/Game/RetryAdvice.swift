/// A single explanation of an unfinished task, without predicting the next attempt.
enum RetryAdvice: String, CaseIterable {
    case gifts = "Clear below gifts to reach marked exits; blasts or the Hammer can also collect them directly."
    case activations = "Activate the required power-ups; creating them alone does not count."
    case rat = "Match the Rat's shown tribute: it alternates between red envelopes and dumplings."
    case ox = "Crack gold frames or activate power-ups to damage the Ox."
    case tiger = "Match firecrackers to hurt the Tiger; later cascades deal extra damage."
    case rabbit = "Collect lanterns or break locks to damage the Rabbit."
    case locks = "Match beside locks to weaken them; power-ups can clear them directly."
    case blossoms = "Clear tiles on moon blossoms; deep pink blossoms need two clears."
    case colors = "Prioritize matches of the tiles still shown in your goals."

    /// Prefer specialized goals before general collection advice. Never use completed goals.
    static func choose(remainingGoals: [String: Int], guardian: BossEncounter?) -> RetryAdvice? {
        func unfinished(_ keys: [String]) -> Bool { keys.contains { (remainingGoals[$0] ?? 0) > 0 } }
        if unfinished(["ingredient"]) { return .gifts }
        if unfinished(["lightningCombos", "fiveCombos", "enhancedCombos"]) { return .activations }
        if let guardian, guardian.health > 0, guardian.configuration.health > 0 {
            switch guardian.configuration.kind {
            case .rat: return .rat
            case .ox: return .ox
            case .tiger: return .tiger
            case .rabbit: return .rabbit
            }
        }
        if unfinished(["lock"]) { return .locks }
        if unfinished(["jelly"]) { return .blossoms }
        if unfinished(["firecracker", "redPocket", "dumpling", "bowl", "lantern", "zodiac"]) { return .colors }
        return nil
    }
}
