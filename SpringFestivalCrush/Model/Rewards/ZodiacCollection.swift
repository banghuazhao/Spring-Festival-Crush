import Foundation

/// One collectible per zodiac. Cards are derived from saved level results, so players who
/// beat a guardian before this feature existed already own that card.
struct ZodiacCard: Identifiable, Equatable {
    enum Tier: Int, Comparable {
        case locked, earned, gilded
        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let zodiac: ChineseZodiac
    let tier: Tier
    let stars: Int
    let maxStars: Int
    /// False while the chapter is still "coming soon".
    let isAvailable: Bool

    var id: Int { zodiac.rawValue }
    var isOwned: Bool { tier >= .earned }
}

enum ZodiacCollection {
    /// The first guardian a chapter introduces; beating it earns the card.
    static func guardianLevel(for zodiac: ChineseZodiac) -> Int? { guardianLevels[zodiac] }

    private static let guardianLevels: [ChineseZodiac: Int] = {
        var result: [ChineseZodiac: Int] = [:]
        for chapter in Zodiac.all where chapter.numLevels > 0 {
            result[chapter.zodiacType] = (1 ... chapter.numLevels).first { number in
                LevelData.loadFrom(file: "\(chapter.zodiacType.name)_Level_\(number)")?.boss != nil
            }
        }
        return result
    }()

    /// Pure, so progress rules can be tested without a saved store.
    static func card(zodiac: ChineseZodiac, levelCount: Int, guardianLevel: Int?,
                     results: [(number: Int, isComplete: Bool, stars: Int)]) -> ZodiacCard {
        let maxStars = levelCount * 3
        let stars = min(maxStars, results.reduce(0) { $0 + max(0, min(3, $1.stars)) })
        let beatGuardian = guardianLevel.map { level in
            results.contains { $0.number == level && $0.isComplete }
        } ?? false
        let tier: ZodiacCard.Tier
        if !beatGuardian {
            tier = .locked
        } else if maxStars > 0, stars >= maxStars {
            tier = .gilded
        } else {
            tier = .earned
        }
        return ZodiacCard(zodiac: zodiac, tier: tier, stars: stars, maxStars: maxStars, isAvailable: levelCount > 0)
    }

    static func cards(from records: [ZodiacRecord]) -> [ZodiacCard] {
        Zodiac.all.map { chapter in
            let record = records.first { $0.zodiacType == chapter.zodiacType }
            let results = record?.levelRecords.map { (number: $0.number, isComplete: $0.isComplete, stars: $0.stars) } ?? []
            return card(zodiac: chapter.zodiacType, levelCount: chapter.numLevels,
                        guardianLevel: guardianLevel(for: chapter.zodiacType), results: results)
        }
    }

    /// The short legend a card unlocks.
    static func story(for zodiac: ChineseZodiac) -> String? {
        switch zodiac {
        case .rat: String(localized: "The Treasury Rat counted every coin until your lanterns lit the harbor. Now it keeps the festival's fortune safe.")
        case .ox: String(localized: "The Iron Ox yields to no one, but it respects a steady hand. It now watches over the golden harvest.")
        case .tiger: String(localized: "Snowfang held winter in the bamboo. Your firecrackers woke the spring, and the Tiger bowed to the new year.")
        case .rabbit: String(localized: "The Jade Rabbit locked the garden for fun. Beaten at its own game, it leaves blossoms along your path.")
        case .dragon: String(localized: "Above the clouds, the Dragon tests every traveler. It has calmed its storm and now carries your wishes across the sky.")
        default: nil
        }
    }
}

/// Which owned cards the player has looked at, so new ones can wear a dot.
enum ZodiacCardStore {
    private static let seenKey = "zodiacCardsSeen"

    static func seen(in defaults: UserDefaults = .standard) -> Set<ChineseZodiac> {
        Set((defaults.array(forKey: seenKey) as? [Int] ?? []).compactMap(ChineseZodiac.init(rawValue:)))
    }

    static func markSeen(_ zodiacs: some Sequence<ChineseZodiac>, in defaults: UserDefaults = .standard) {
        let all = seen(in: defaults).union(zodiacs)
        defaults.set(all.map(\.rawValue).sorted(), forKey: seenKey)
    }

    static func hasUnseen(_ cards: [ZodiacCard], in defaults: UserDefaults = .standard) -> Bool {
        let seenCards = seen(in: defaults)
        return cards.contains { $0.isOwned && !seenCards.contains($0.zodiac) }
    }
}
