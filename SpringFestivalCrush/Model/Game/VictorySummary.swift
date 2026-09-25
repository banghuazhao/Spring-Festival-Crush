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
    var mapFocusLevel: Int { newlyUnlockedLevel ?? level }
}
