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
        let dominant = dominantSourceType(in: all)
        let centers: [Symbol]
        switch combination {
        case .fiveLightning:
            centers = all.filter { $0.type.isMatchableTo(dominant) && canConvert($0) }
        case .enhancedFive:
            centers = all.filter { $0.type.isMatchableTo(enhanced!.type) && canConvert($0) }
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
                    || cross(target, around: lightning!, radius: 0)
            case .lightningLightning:
                return sources.contains {
                    cross(target, around: $0, radius: 1)
                        || abs(target.row - $0.row) == abs(target.column - $0.column)
                }
            case .enhancedLightning:
                return cross(target, around: lightning!, radius: 2)
                    || square(target, around: enhanced!, radius: 2)
            case .enhancedFive:
                return centers.contains { square(target, around: $0, radius: 1) }
            }
        }
        let chain = Chain(chainType: .combination)
        chain.combination = combination
        chain.combinationSources = sources
        chain.blastCenters = centers
        chain.sourceType = enhanced?.type ?? dominant
        chain.activatedSpecials = sources
        if combination == .fiveLightning || combination == .enhancedFive {
            chain.transformedSymbols = centers
            chain.transformationType = combination == .fiveLightning ? .lightning : enhanced!.type
            chain.activatedSpecials += centers
        }
        chain.add(symbols: affected)
        return chain
    }

    private func canConvert(_ symbol: Symbol) -> Bool {
        !symbol.isFrozen && symbol.armorLayers == 0 && !symbol.armorHitThisTurn
    }

    func dominantSourceType(in pieces: [Symbol]) -> SymbolType {
        let types: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        return types.sorted { a, b in
            let countA = pieces.filter { $0.type.isMatchableTo(a) }.count
            let countB = pieces.filter { $0.type.isMatchableTo(b) }.count
            return countA == countB ? a.spriteName < b.spriteName : countA > countB
        }.first!
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
