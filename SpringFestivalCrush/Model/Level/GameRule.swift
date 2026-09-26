import Foundation

/// A level's place in play order, e.g. Ox 3.
struct LevelRef: Hashable {
    let zodiac: ChineseZodiac
    let number: Int
}

/// One rule of the board. Each is taught on the first level or two where it matters,
/// then lives in the rule handbook instead of repeating on every briefing.
enum GameRule: String, CaseIterable, Identifiable {
    case goals
    case swapMatch
    case lock
    case lightning
    case blastTile
    case luckyFive
    case armor
    case combos
    case ice
    case cascade
    case doubleLock
    case ratGuardian
    case oxGuardian
    case tigerGuardian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goals: String(localized: "Goals")
        case .swapMatch: String(localized: "Swap & Match")
        case .lock: String(localized: "Lock")
        case .lightning: String(localized: "Festival Lightning")
        case .blastTile: String(localized: "Blast Tile")
        case .luckyFive: String(localized: "Lucky Five")
        case .armor: String(localized: "Gold Frame")
        case .combos: String(localized: "Power-up Combos")
        case .ice: String(localized: "Ice")
        case .cascade: String(localized: "Chain Reaction")
        case .doubleLock: String(localized: "Double Lock")
        case .ratGuardian, .oxGuardian, .tigerGuardian: guardian!.title
        }
    }

    /// The words behind the picture, one tap away behind its "?".
    var detail: String {
        switch self {
        case .goals: String(localized: "Complete every goal before you run out of moves.")
        case .swapMatch: String(localized: "Swap two neighboring tiles to line up 3 or more of the same kind.")
        case .lock: String(localized: "Match beside a lock to break it.")
        case .lightning: String(localized: "Match in an L or T shape to make Lightning. Swap it to clear its whole row and column.")
        case .blastTile: String(localized: "Match 4 in a row to make a blast tile. Clear it to blast the tiles around it.")
        case .luckyFive: String(localized: "Match 5 in a row to make a Lucky Five. Swap it with a tile to collect every tile of that kind.")
        case .armor: String(localized: "Gold frame · 2 hits: match once to crack the shell, then clear the tile on a later move. Blasts and hammers also crack one layer.")
        case .combos: String(localized: "Swap two power-ups into each other for a much bigger blast.")
        case .ice: String(localized: "Ice: clear a neighboring tile to thaw it before matching.")
        case .cascade: String(localized: "Falling tiles can match on their own. Chain reactions score more and open tight spaces.")
        case .doubleLock: String(localized: "A double lock needs two matches beside it. The first turns it into a normal lock.")
        case .ratGuardian, .oxGuardian, .tigerGuardian: guardian!.instructions
        }
    }

    var guardian: BossConfiguration.Kind? {
        switch self {
        case .ratGuardian: .rat
        case .oxGuardian: .ox
        case .tigerGuardian: .tiger
        default: nil
        }
    }

    /// Whether a level puts this rule's piece on the board.
    fileprivate func isOnBoard(_ data: LevelData) -> Bool {
        let tiles = Set(data.tiles.joined())
        func has(_ type: Tile.TileType) -> Bool { tiles.contains(type.rawValue) }
        func any(_ grid: [[Int]]?) -> Bool { grid?.joined().contains { $0 > 0 } ?? false }
        switch self {
        // A double lock becomes a plain lock, so its levels teach locks too.
        case .lock: return has(.lock) || has(.doubleLock) || has(.vaultLock)
        case .doubleLock: return has(.doubleLock) || has(.vaultLock)
        case .lightning: return has(.lightning)
        case .luckyFive: return has(.five)
        case .blastTile: return has(.enhanced)
        case .armor: return any(data.armor)
        case .ice: return any(data.ice)
        case .ratGuardian, .oxGuardian, .tigerGuardian: return data.boss?.kind == guardian
        case .goals, .swapMatch, .combos, .cascade: return false
        }
    }

    /// Ideas that hold on every board: from this level on, every level counts as showing them.
    /// Spaced out so the first levels teach one or two new things at a time.
    fileprivate var alwaysFrom: LevelRef? {
        switch self {
        case .goals, .swapMatch: LevelRef(zodiac: .rat, number: 1)
        case .blastTile: LevelRef(zodiac: .rat, number: 3)
        case .luckyFive: LevelRef(zodiac: .rat, number: 4)
        case .combos: LevelRef(zodiac: .rat, number: 6)
        case .cascade: LevelRef(zodiac: .rat, number: 9)
        default: nil
        }
    }

    /// How many briefings teach this rule before it's left to the handbook.
    fileprivate var lessonCount: Int { self == .goals || guardian != nil ? 1 : 2 }
}

/// Where each rule is taught, worked out from the level files so it follows the levels.
struct RuleCurriculum {
    static let shared = RuleCurriculum(levels: bundledLevels())

    /// Every level in play order.
    let order: [LevelRef]
    /// The level that first shows each rule. Rules no level uses are left out.
    let introductions: [GameRule: LevelRef]
    private let lessonsByLevel: [LevelRef: [GameRule]]

    init(levels: [(LevelRef, LevelData)]) {
        order = levels.map(\.0)
        var introductions: [GameRule: LevelRef] = [:]
        var lessons: [LevelRef: [GameRule]] = [:]
        for rule in GameRule.allCases {
            let start = rule.alwaysFrom.flatMap { ref in levels.firstIndex { $0.0 == ref } }
            let showing = levels.enumerated().filter { index, level in
                rule.isOnBoard(level.1) || (start.map { index >= $0 } ?? false)
            }.map(\.element.0)
            guard let first = showing.first else { continue }
            introductions[rule] = first
            for ref in showing.prefix(rule.lessonCount) { lessons[ref, default: []].append(rule) }
        }
        self.introductions = introductions
        lessonsByLevel = lessons
    }

    /// The rules this level's briefing teaches, in teaching order.
    func lessons(for level: LevelRef) -> [GameRule] { lessonsByLevel[level] ?? [] }

    /// A rule unlocks in the handbook once the player reaches the level that teaches it.
    func isUnlocked(_ rule: GameRule, reached: (LevelRef) -> Bool) -> Bool {
        introductions[rule].map(reached) ?? false
    }

    /// Whether this level is the first to show the rule.
    func introduces(_ rule: GameRule, at level: LevelRef) -> Bool { introductions[rule] == level }

    /// Every rule the game teaches, in the order players meet them.
    var rules: [GameRule] {
        GameRule.allCases.filter { introductions[$0] != nil }.sorted { lhs, rhs in
            let left = order.firstIndex(of: introductions[lhs]!) ?? 0
            let right = order.firstIndex(of: introductions[rhs]!) ?? 0
            return left != right ? left < right
                : GameRule.allCases.firstIndex(of: lhs)! < GameRule.allCases.firstIndex(of: rhs)!
        }
    }

    private static func bundledLevels() -> [(LevelRef, LevelData)] {
        Zodiac.all.filter { $0.numLevels > 0 }.flatMap { zodiac in
            (1 ... zodiac.numLevels).compactMap { number in
                LevelData.loadFrom(file: "\(zodiac.zodiacType.name)_Level_\(number)")
                    .map { (LevelRef(zodiac: zodiac.zodiacType, number: number), $0) }
            }
        }
    }
}

/// Which handbook rules the player has already looked at, so new ones can wear a dot.
enum RuleHandbookStore {
    private static let seenKey = "ruleHandbookSeen"

    static func seen(in defaults: UserDefaults = .standard) -> Set<GameRule> {
        Set((defaults.stringArray(forKey: seenKey) ?? []).compactMap(GameRule.init(rawValue:)))
    }

    static func markSeen(_ rules: some Sequence<GameRule>, in defaults: UserDefaults = .standard) {
        let all = seen(in: defaults).union(rules)
        defaults.set(all.map(\.rawValue).sorted(), forKey: seenKey)
    }
}
