import Foundation

extension Level {
    /// Snapshot the footprint before removing anything. One chain means overlapping
    /// lanes, blast centers, scoring, and positional jelly can never double-count a tile.
    func makeCombinationChain(_ combination: PowerUpCombination, for swap: Swap) -> Chain {
        let all = (0..<numRows).flatMap { row in
            (0..<numColumns).compactMap { symbol(atColumn: $0, row: row) }
        }
        let sources = [swap.symbolA, swap.symbolB].sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        let enhanced = sources.first { $0.type.isEnhanced }
        let lightning = sources.first { $0.type == .lightning }
        let normalTypes: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        let dominant = normalTypes.sorted { a, b in
            let countA = all.filter { $0.type.isMatchableTo(a) }.count
            let countB = all.filter { $0.type.isMatchableTo(b) }.count
            return countA == countB ? a.spriteName < b.spriteName : countA > countB
        }.first!
        let centers: [Symbol]
        switch combination {
        case .fiveLightning:
            centers = all.filter { $0.type.isMatchableTo(dominant) }
        case .enhancedFive:
            centers = all.filter { $0.type.isMatchableTo(enhanced!.type) }
        default:
            centers = sources
        }
        func cross(_ target: Symbol, around source: Symbol, radius: Int) -> Bool {
            abs(target.row - source.row) <= radius || abs(target.column - source.column) <= radius
        }
        func square(_ target: Symbol, around source: Symbol, radius: Int) -> Bool {
            abs(target.row - source.row) <= radius && abs(target.column - source.column) <= radius
        }
        let affected = all.filter { target in
            if sources.contains(where: { $0 === target }) { return true }
            switch combination {
            case .fiveFive: return true
            case .fiveLightning:
                return centers.contains { cross(target, around: $0, radius: 0) }
                    || sources.contains { cross(target, around: $0, radius: 1) }
            case .lightningLightning:
                return sources.contains {
                    cross(target, around: $0, radius: 1)
                        || abs(target.row - $0.row) == abs(target.column - $0.column)
                }
            case .enhancedLightning:
                return cross(target, around: lightning!, radius: 2)
                    || square(target, around: enhanced!, radius: 2)
            case .enhancedFive:
                return centers.contains { square(target, around: $0, radius: 2) }
            }
        }
        let chain = Chain(chainType: .combination)
        chain.combination = combination
        chain.combinationSources = sources
        chain.blastCenters = centers
        chain.add(symbols: affected)
        return chain
    }

    #if DEBUG
    func configureCombinationDemo(_ combination: PowerUpCombination) {
        for row in 0..<numRows {
            for column in 0..<numColumns { tileAt(column: column, row: row)?.type = .normal }
        }
        func tileType(_ type: SymbolType) -> Tile.TileType {
            if type == .five { return .five }
            if type == .lightning { return .lightning }
            return .enhanced
        }
        let pair = combination.demoTypes
        tileAt(column: numColumns / 2 - 1, row: numRows / 2)?.type = tileType(pair.0)
        tileAt(column: numColumns / 2, row: numRows / 2)?.type = tileType(pair.1)
        levelGoal.levelTarget = LevelTarget(
            lightningCombos: combination.lightningCount > 0 ? combination.lightningCount : nil,
            fiveCombos: combination.fiveCount > 0 ? combination.fiveCount : nil,
            enhancedCombos: combination.enhancedCount > 0 ? combination.enhancedCount : nil
        )
    }
    #endif
}
