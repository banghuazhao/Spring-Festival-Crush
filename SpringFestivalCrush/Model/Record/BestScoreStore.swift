import Foundation

/// Each level's best winning score. Kept in UserDefaults, like the star chests, so adding it
/// needs no change to the saved SwiftData progress.
enum BestScoreStore {
    private static func key(_ zodiac: ChineseZodiac, level: Int) -> String { "bestScore.\(zodiac.name).\(level)" }

    /// 0 until the level has been won since best scores were added.
    static func best(for zodiac: ChineseZodiac, level: Int, defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: key(zodiac, level: level))
    }

    /// Saves a winning score if it beats the saved best. Returns the best from before this win.
    @discardableResult
    static func record(_ score: Int, for zodiac: ChineseZodiac, level: Int, defaults: UserDefaults = .standard) -> Int {
        let previous = best(for: zodiac, level: level, defaults: defaults)
        if score > previous { defaults.set(score, forKey: key(zodiac, level: level)) }
        return previous
    }
}
