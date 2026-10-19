import Foundation

/// Immutable receipt for one completed attempt; presentation never grants rewards.
struct VictorySummary: Identifiable {
    let id = UUID()
    let zodiac: ChineseZodiac
    let level: Int
    let score: Int
    let stars: Int
    let coins: Int
    let newlyUnlockedLevel: Int?
    var defeatedBoss = false
    var usedContinue = false
    /// The level's best score before this win; 0 the first time it is won.
    var previousBest = 0
    var mapFocusLevel: Int { newlyUnlockedLevel ?? level }
    /// Beat an earlier winning score. A first win is not called a new best.
    var isNewBest: Bool { previousBest > 0 && score > previousBest }

    /// The immediate next star relative to this attempt, independent of saved best stars.
    /// Invalid thresholds or a receipt that does not match them provide no guidance.
    func nextStarTarget(for goal: LevelGoal) -> StarReplayTarget? {
        guard level >= 1, score >= 0, (1...2).contains(stars),
              goal.firstStarScore > 0,
              goal.secondStarScore > goal.firstStarScore,
              goal.thirdStarScore > goal.secondStarScore,
              goal.stars(forWinningScore: score) == stars else { return nil }

        let targetScore = stars == 1 ? goal.secondStarScore : goal.thirdStarScore
        guard targetScore > score else { return nil }
        return StarReplayTarget(stars: stars + 1, score: targetScore, pointsNeeded: targetScore - score)
    }
}
