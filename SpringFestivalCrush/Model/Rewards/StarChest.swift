import Foundation

enum StarChestState: Equatable {
    case locked, ready, opened
}

/// Three chests per zodiac chapter, opened by collecting stars on its levels. Chest
/// thresholds sit at one, two and three stars per level, so the last chest asks for a
/// perfect chapter and gives replays a purpose.
struct StarChestTrack: Equatable {
    struct Chest: Equatable, Identifiable {
        let index: Int
        let threshold: Int
        let reward: RewardBundle
        var id: Int { index }
    }

    let chests: [Chest]
    let maxStars: Int

    init(levelCount: Int) {
        let count = max(0, levelCount)
        maxStars = count * 3
        chests = (0 ..< 3).map { index in
            Chest(index: index, threshold: max(1, count * (index + 1)), reward: Self.reward(for: index))
        }
    }

    static func reward(for index: Int) -> RewardBundle {
        switch index {
        case 0: RewardBundle(coins: 50, shuffles: 1)
        case 1: RewardBundle(coins: 80, hammers: 1, swaps: 1)
        default: RewardBundle(coins: 150, shuffles: 1, hammers: 2, swaps: 2)
        }
    }

    func state(of chest: Chest, stars: Int, claimed: Set<Int>) -> StarChestState {
        if claimed.contains(chest.index) { return .opened }
        return stars >= chest.threshold ? .ready : .locked
    }

    /// Chests the player has earned but not opened yet.
    func readyChests(stars: Int, claimed: Set<Int>) -> [Chest] {
        chests.filter { !claimed.contains($0.index) && stars >= $0.threshold }
    }
}

/// Which chests each chapter has opened, persisted per zodiac.
enum StarChestStore {
    private static func key(_ zodiac: ChineseZodiac) -> String { "starChestsClaimed.\(zodiac.name)" }

    static func claimed(for zodiac: ChineseZodiac, defaults: UserDefaults = .standard) -> Set<Int> {
        Set(defaults.array(forKey: key(zodiac)) as? [Int] ?? [])
    }

    /// Returns false if the chest was already opened, so a double tap can never pay twice.
    @discardableResult
    static func markClaimed(_ index: Int, for zodiac: ChineseZodiac, defaults: UserDefaults = .standard) -> Bool {
        var claimed = claimed(for: zodiac, defaults: defaults)
        guard claimed.insert(index).inserted else { return false }
        defaults.set(claimed.sorted(), forKey: key(zodiac))
        return true
    }
}
