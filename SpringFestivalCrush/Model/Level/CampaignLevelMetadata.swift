/// Immutable presentation metadata, loaded once rather than decoding level files per map node.
enum CampaignLevelMetadata {
    private static let bossLevels: [ChineseZodiac: Set<Int>] = {
        Dictionary(uniqueKeysWithValues: Zodiac.all.map { zodiac in
            let levels: Set<Int>
            if zodiac.numLevels > 0 {
                levels = Set((1...zodiac.numLevels).filter { number in
                    LevelData.loadFrom(file: "\(zodiac.zodiacType.name)_Level_\(number)")?.boss != nil
                })
            } else {
                levels = []
            }
            return (zodiac.zodiacType, levels)
        })
    }()

    static func isBoss(zodiac: ChineseZodiac, level: Int) -> Bool {
        bossLevels[zodiac]?.contains(level) ?? false
    }
}
