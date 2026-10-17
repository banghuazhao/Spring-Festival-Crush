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
}
