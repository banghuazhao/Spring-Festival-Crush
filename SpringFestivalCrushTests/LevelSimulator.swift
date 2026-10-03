import Foundation
@testable import SpringFestivalCrush

/// Plays a level headlessly with the same `Level` calls `GameModel` makes, minus the scene.
/// Keep `play` in step with `GameModel.handleSwipe`, `handleRemoveAndMatches`, `handleMatches`,
/// `beginNextTurn`/`advanceWorld` and the win finale, or the balance numbers drift from the game.
/// Tools, boosters, continues and the timer are left out: this measures the level itself.
@MainActor
struct LevelSimulator {
    enum Policy: String, CaseIterable {
        /// Any legal move, uniformly. A floor: a level this bot can win is never a wall.
        case random
        /// A sensible player: power-ups first, then big shapes, goal pieces and blockers, low on the board.
        case greedy
    }

    struct Outcome {
        let won: Bool
        let movesLeft: Int
        let score: Int
        let stars: Int
        /// 0...1 progress toward the goals (and the guardian) when the game ended.
        let progress: Double
        /// The board ran out of moves and could not be reshuffled.
        let stuck: Bool
        /// What was still missing when the game ended, by goal ("lock", "guardian", …).
        let remaining: [String: Int]
    }

    let filename: String
    let policy: Policy

    func play() -> Outcome {
        guard let level = Level(filename: filename) else {
            return Outcome(won: false, movesLeft: 0, score: 0, stars: 0, progress: 0, stuck: true, remaining: [:])
        }
        var game = Game(level: level)
        return game.run(policy: policy)
    }
}

@MainActor
fileprivate struct Game {
    let level: Level
    var movesLeft: Int
    var score = 0
    var cascadeDepth = 0
    var inProgress = true
    let initialPieces: Int
    let initialHealth: Int

    init(level: Level) {
        self.level = level
        movesLeft = level.maximumMoves
        initialPieces = Self.remainingPieces(level)
        initialHealth = level.boss?.health ?? 0
    }

    mutating func run(policy: LevelSimulator.Policy) -> LevelSimulator.Outcome {
        _ = level.shuffle()
        while true {
            let candidates = legalSwaps()
            guard !candidates.isEmpty else { return finish(won: false, stuck: true) }
            let swap = policy == .random ? candidates.randomElement()! : bestSwap(from: candidates)
            playMove(swap)
            // beginNextTurn
            level.finishArmorTurn()
            if level.doesReachLevelTarget() {
                playFinale()
                return finish(won: true, stuck: false)
            }
            if movesLeft <= 0 { return finish(won: false, stuck: false) }
            // advanceWorld: only paid, valid moves reach here, so the guardian always advances.
            level.advanceBossTurn()
            _ = level.spreadChocolateIfNeeded()
            level.detectPossibleSwaps()
            if level.possibleSwaps.isEmpty, !level.noShuffle {
                _ = level.reshuffleExistingSymbols()
            }
        }
    }

    // MARK: Turn

    private mutating func playMove(_ swap: Swap) {
        movesLeft -= 1
        cascadeDepth = 0
        level.performSwap(swap)
        if let powerUpChains = level.tryActivateSpecialSwap(swap) {
            handleMatches(powerUpChains)
        }
        while true {
            var chains = level.removeMatches()
            if let lockChain = level.resolveBlockers() { chains.insert(lockChain) }
            if chains.isEmpty { break }
            handleMatches(chains)
        }
    }

    private mutating func handleMatches(_ chains: Set<Chain>) {
        if inProgress, chains.contains(where: { $0.chainType != .locks && !$0.symbols.isEmpty }) {
            cascadeDepth += 1
        }
        let allChains = chains.union(level.explodeSpecialSymbols(for: chains))
        _ = level.createSpecialSymbols(for: chains)
        score += allChains.reduce(0) { $0 + $1.score }
        level.updateLevelTarget(by: allChains)
        if inProgress { level.boss?.receive(chains: allChains, cascadeDepth: cascadeDepth) }
        _ = level.fillHoles()
        score += 50 * level.collectIngredientsAtBottom().count
        _ = level.topUpSymbols()
    }

    /// Leftover specials fire, then every move left becomes a blast tile (the Festival Finale).
    private mutating func playFinale() {
        inProgress = false
        clearRemainingSpecials()
        _ = level.enhanceSymbols(num: movesLeft)
        clearRemainingSpecials()
    }

    private mutating func clearRemainingSpecials() {
        while true {
            var chains = level.removeSpecialSymbols().union(level.removeMatches())
            if let lockChain = level.resolveBlockers() { chains.insert(lockChain) }
            if chains.isEmpty { return }
            handleMatches(chains)
        }
    }

    private func finish(won: Bool, stuck: Bool) -> LevelSimulator.Outcome {
        let goal = level.levelGoal
        let stars = won ? [goal.firstStarScore, goal.secondStarScore, goal.thirdStarScore].filter { score >= $0 }.count : 0
        var progress = initialPieces > 0 ? 1 - Double(Self.remainingPieces(level)) / Double(initialPieces) : 1
        if initialHealth > 0 {
            progress = min(progress, 1 - Double(level.boss?.health ?? 0) / Double(initialHealth))
        }
        var remaining = Self.goals(level).compactMapValues { $0 }.mapValues { max(0, $0) }
        if let boss = level.boss { remaining["guardian"] = boss.health }
        return .init(won: won, movesLeft: max(0, movesLeft), score: score, stars: stars,
                     progress: won ? 1 : progress, stuck: stuck, remaining: remaining)
    }

    static func goals(_ level: Level) -> [String: Int?] {
        let target = level.levelGoal.levelTarget
        return ["firecracker": target.firecracker, "redPocket": target.redPocket, "dumpling": target.dumpling,
                "bowl": target.bowl, "lantern": target.lantern, "zodiac": target.zodiac, "lock": target.lock,
                "blossom": target.jelly, "ingredient": target.ingredient, "lightningCombos": target.lightningCombos,
                "fiveCombos": target.fiveCombos, "enhancedCombos": target.enhancedCombos]
    }

    private static func remainingPieces(_ level: Level) -> Int {
        goals(level).values.reduce(0) { $0 + max(0, ($1 ?? 0) ?? 0) }
    }

    // MARK: Moves

    private func symbol(_ column: Int, _ row: Int) -> Symbol? {
        guard column >= 0, column < level.numColumns, row >= 0, row < level.numRows else { return nil }
        return level.symbol(atColumn: column, row: row)
    }

    /// Matching swaps, plus any swap of a Lucky Five or Lightning, which fire without a match.
    private func legalSwaps() -> [Swap] {
        var swaps = level.possibleSwaps
        for column in 0 ..< level.numColumns {
            for row in 0 ..< level.numRows {
                guard let piece = symbol(column, row), piece.isSpecialPowerUp else { continue }
                for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    if let other = symbol(column + dc, row + dr), other.isMovable() {
                        swaps.insert(Swap(symbolA: piece, symbolB: other))
                    }
                }
            }
        }
        return Array(swaps)
    }

    private func bestSwap(from swaps: [Swap]) -> Swap {
        var best = swaps[0]
        var bestValue = -Double.infinity
        for swap in swaps {
            let value = evaluate(swap) + Double.random(in: 0 ..< 1)
            if value > bestValue {
                best = swap
                bestValue = value
            }
        }
        return best
    }

    /// Scores a move from the board as it would look right after the swap, before anything falls.
    private func evaluate(_ swap: Swap) -> Double {
        let a = swap.symbolA, b = swap.symbolB
        if a.isSpecialPowerUp || b.isSpecialPowerUp {
            let both = (a.isSpecialPowerUp || a.type.isEnhanced) && (b.isSpecialPowerUp || b.type.isEnhanced)
            let base = both ? 120.0 : (a.type == .five || b.type == .five ? 60 : 40)
            return base + Double(level.numRows - min(a.row, b.row)) * 0.2
        }
        let target = level.levelGoal.levelTarget
        // Virtual board after the swap.
        func piece(_ column: Int, _ row: Int) -> Symbol? {
            if column == a.column, row == a.row { return b }
            if column == b.column, row == b.row { return a }
            return symbol(column, row)
        }
        func matches(_ column: Int, _ row: Int, _ type: SymbolType) -> Bool {
            guard let other = piece(column, row), other.isMatchable() else { return false }
            return other.type.isMatchableTo(type)
        }
        var value = 0.0
        var cleared: [(Int, Int)] = []
        for moved in [a, b] {
            // `moved` lands on the other's cell.
            let (column, row) = moved === a ? (b.column, b.row) : (a.column, a.row)
            guard moved.isMatchable() else { continue }
            var left = 0, right = 0, down = 0, up = 0
            while matches(column - left - 1, row, moved.type) { left += 1 }
            while matches(column + right + 1, row, moved.type) { right += 1 }
            while matches(column, row - down - 1, moved.type) { down += 1 }
            while matches(column, row + up + 1, moved.type) { up += 1 }
            let horizontal = left + right + 1, vertical = down + up + 1
            guard horizontal >= 3 || vertical >= 3 else { continue }
            let longest = max(horizontal, vertical)
            if longest >= 5 { value += 50 }
            else if horizontal >= 3 && vertical >= 3 { value += 40 }
            else if longest == 4 { value += 30 }
            else { value += 10 }
            if horizontal >= 3 { cleared += (column - left ... column + right).map { ($0, row) } }
            if vertical >= 3 { cleared += (row - down ... row + up).map { (column, $0) } }
        }
        var seen = Set<Int>()
        var touched = Set<Int>()
        let boss = level.boss.flatMap { $0.health > 0 ? $0 : nil }
        for (column, row) in cleared where seen.insert(column * 100 + row).inserted {
            guard let piece = piece(column, row) else { continue }
            if piece.type.isEnhanced { value += 15 }
            if piece.armorLayers > 0 { value += 3 }
            if (level.tileAt(column: column, row: row)?.jellyCount ?? 0) > 0, (target.jelly ?? 0) > 0 { value += 6 }
            if Self.counts(piece.collectionType, toward: target) { value += 4 }
            if let boss {
                switch boss.configuration.kind {
                case .rat where piece.collectionType.isMatchableTo(boss.tribute): value += 5
                case .tiger where piece.collectionType.isMatchableTo(.firecracker): value += 5
                case .ox where piece.armorLayers > 0: value += 5
                case .rabbit where piece.collectionType.isMatchableTo(.lantern): value += 5
                default: break
                }
            }
            value += Double(level.numRows - row) * 0.3
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let (c, r) = (column + dc, row + dr)
                guard touched.insert(c * 100 + r).inserted, let neighbor = symbol(c, r) else { continue }
                if !neighbor.isMovable() {
                    let wanted = (target.lock ?? 0) > 0 || neighbor.type == .chocolate || boss?.configuration.kind == .rabbit
                    value += wanted ? 7 : 2
                }
                if neighbor.isFrozen { value += 4 }
            }
        }
        return value
    }

    private static func counts(_ type: SymbolType, toward target: LevelTarget) -> Bool {
        switch type.enhancedType {
        case .firecrackerEnhanced: (target.firecracker ?? 0) > 0
        case .redPocketEnhanced: (target.redPocket ?? 0) > 0
        case .dumplingEnhanced: (target.dumpling ?? 0) > 0
        case .bowlEnhanced: (target.bowl ?? 0) > 0
        case .lanternEnhanced: (target.lantern ?? 0) > 0
        case .zodiacEnhanced: (target.zodiac ?? 0) > 0
        default: false
        }
    }
}

/// Monte Carlo summary of one level under one policy.
struct LevelBalance {
    let filename: String
    let difficulty: Int
    let moves: Int
    let runs: Int
    let winRate: Double
    let starRates: [Double]
    let medianMovesLeft: Int
    /// Median final score of winning games, the yardstick for star thresholds.
    let medianWinScore: Int
    let lossProgress: Double
    let stuckRate: Double
    /// The goal furthest from done in lost games, as "lock 3.2/8": average left over of the starting count.
    let shortfall: String

    @MainActor
    init(filename: String, policy: LevelSimulator.Policy, runs: Int) {
        let level = Level(filename: filename)
        self.filename = filename
        difficulty = level?.difficulty ?? 0
        moves = level?.maximumMoves ?? 0
        self.runs = runs
        let outcomes = (0 ..< runs).map { _ in LevelSimulator(filename: filename, policy: policy).play() }
        let wins = outcomes.filter(\.won)
        let losses = outcomes.filter { !$0.won }
        winRate = Double(wins.count) / Double(max(1, runs))
        starRates = (1 ... 3).map { stars in Double(wins.filter { $0.stars >= stars }.count) / Double(max(1, runs)) }
        medianMovesLeft = wins.map(\.movesLeft).sorted().dropFirst(wins.count / 2).first ?? 0
        medianWinScore = wins.map(\.score).sorted().dropFirst(wins.count / 2).first ?? 0
        lossProgress = losses.isEmpty ? 1 : losses.map(\.progress).reduce(0, +) / Double(losses.count)
        stuckRate = Double(outcomes.filter(\.stuck).count) / Double(max(1, runs))
        var start = level.map { Game.goals($0).compactMapValues { $0 } } ?? [:]
        if let health = level?.boss?.health { start["guardian"] = health }
        let worst = start.keys.map { key -> (String, Double) in
            let left = losses.map { Double($0.remaining[key] ?? 0) }.reduce(0, +) / Double(max(1, losses.count))
            return (key, left)
        }.max { $0.1 / Double(max(1, start[$0.0]!)) < $1.1 / Double(max(1, start[$1.0]!)) }
        shortfall = worst.map { String(format: "%@ %.1f/%d", $0.0, $0.1, start[$0.0]!) } ?? ""
    }
}
