extension Level {
    /// Ranks existing legal hints by observed direct progress, without forecasting cascades.
    /// Equal or unhelpful candidates retain the original coordinate-first choice.
    func goalAwareHintSwap() -> Swap? {
        typealias Cell = BlastPreview.Cell
        var original: [Cell: HintPiece] = [:]
        for row in 0..<numRows {
            for column in 0..<numColumns {
                guard let piece = symbol(atColumn: column, row: row) else { continue }
                guard piece.column == column, piece.row == row,
                      tileAt(column: column, row: row) != nil else { return nil }
                original[Cell(column: column, row: row)] = HintPiece(piece)
            }
        }
        func key(_ swap: Swap) -> (Int, Int, Int, Int) {
            let a = (swap.symbolA.row, swap.symbolA.column)
            let b = (swap.symbolB.row, swap.symbolB.column)
            return a < b ? (a.0, a.1, b.0, b.1) : (b.0, b.1, a.0, a.1)
        }
        let goal = levelGoal.levelTarget
        let colors: [(SymbolType, Int?)] = [(.firecracker, goal.firecracker), (.redPocket, goal.redPocket),
            (.dumpling, goal.dumpling), (.bowl, goal.bowl), (.lantern, goal.lantern), (.zodiac, goal.zodiac)]
        func capped(_ amount: Double, by remaining: Int?) -> Double {
            min(max(0, amount), Double(max(0, remaining ?? 0)))
        }
        let hasGoals = colors.contains { ($0.1 ?? 0) > 0 }
            || [goal.lock, goal.jelly, goal.ingredient, goal.lightningCombos, goal.fiveCombos, goal.enhancedCombos]
                .contains { ($0 ?? 0) > 0 }
            || (boss?.health ?? 0) > 0
        var best: Swap?
        var bestBenefit = -Double.infinity
        for swap in possibleSwaps.sorted(by: { key($0) < key($1) }) {
            let a = Cell(column: swap.symbolA.column, row: swap.symbolA.row)
            let b = Cell(column: swap.symbolB.column, row: swap.symbolB.row)
            guard let first = original[a], let second = original[b],
                  first.identity == ObjectIdentifier(swap.symbolA), second.identity == ObjectIdentifier(swap.symbolB),
                  first.movable, second.movable, !first.frozen, !second.frozen,
                  abs(a.column - b.column) + abs(a.row - b.row) == 1 else { continue }
            var board = original
            board[a] = second
            board[b] = first
            func matched(at cell: Cell) -> Set<Cell> {
                guard let source = board[cell], source.matchable else { return [] }
                func run(_ dc: Int, _ dr: Int) -> [Cell] {
                    var result: [Cell] = []
                    var next = Cell(column: cell.column + dc, row: cell.row + dr)
                    while let piece = board[next], piece.matchable, piece.type.isMatchableTo(source.type) {
                        result.append(next)
                        next = Cell(column: next.column + dc, row: next.row + dr)
                    }
                    return result
                }
                let horizontal = run(-1, 0) + [cell] + run(1, 0)
                let vertical = run(0, -1) + [cell] + run(0, 1)
                return Set((horizontal.count >= 3 ? horizontal : []) + (vertical.count >= 3 ? vertical : []))
            }
            let matches = matched(at: a).union(matched(at: b))
            let preview = blastPreview(for: swap)
            let instant = first.special || second.special
            // Protected power-ups have no reliable direct preview, so keep another legal hint.
            guard !instant || preview != nil, !matches.isEmpty || preview != nil else { continue }
            let impacted = instant ? (preview?.affectedCells ?? []) : matches.union(preview?.affectedCells ?? [])
            let fullClear = preview?.combination == .fiveFive
            let cleared = Set(impacted.filter { cell in
                guard let piece = board[cell] else { return false }
                return fullClear || (piece.armor == 0 && !piece.armorHit)
            })
            var benefit = 0.0
            for (color, remaining) in colors {
                benefit += 100 * capped(Double(cleared.filter { board[$0]?.collectionType.isMatchableTo(color) == true }.count), by: remaining)
            }
            let blossoms = cleared.reduce(0.0) { total, cell in
                let layers = max(0, tileAt(column: cell.column, row: cell.row)?.jellyCount ?? 0)
                return total + (fullClear ? Double(layers) : (layers > 0 ? 1 : 0))
            }
            benefit += 100 * capped(blossoms, by: goal.jelly)

            let ordinaryClears = instant ? Set<Cell>() : cleared.intersection(matches)
            func neighbors(_ cell: Cell) -> [Cell] {
                [Cell(column: cell.column - 1, row: cell.row), Cell(column: cell.column + 1, row: cell.row),
                 Cell(column: cell.column, row: cell.row - 1), Cell(column: cell.column, row: cell.row + 1)]
            }
            let adjacent = Set(ordinaryClears.flatMap(neighbors)).subtracting(cleared)
            let directLocks = cleared.filter { board[$0]?.type.isHintLock == true }.count
            let nearbyLocks = adjacent.filter { board[$0]?.type == .lock }.count
            benefit += 100 * capped(Double(directLocks + nearbyLocks), by: goal.lock)
            let layeredLocks = adjacent.filter { board[$0]?.type == .heavyLock || board[$0]?.type == .vaultLock }.count
            benefit += 20 * capped(Double(layeredLocks), by: goal.lock)

            let active = preview?.sourceCells.compactMap { board[$0] } ?? []
            benefit += 100 * capped(Double(active.filter { $0.type == .lightning }.count), by: goal.lightningCombos)
            benefit += 100 * capped(Double(active.filter { $0.type == .five }.count), by: goal.fiveCombos)
            benefit += 100 * capped(Double(active.filter { $0.type.isEnhanced }.count), by: goal.enhancedCombos)

            let giftsCleared = cleared.filter { board[$0]?.type == .ingredient }.count
            var helpedGifts = 0
            for (cell, piece) in board where piece.type == .ingredient && !cleared.contains(cell) {
                var row = cell.row - 1
                var openedPath = false
                while row >= 0, let below = board[Cell(column: cell.column, row: row)] {
                    let belowCell = Cell(column: cell.column, row: row)
                    if cleared.contains(belowCell) { openedPath = true }
                    if (!below.movable || below.type == .ingredient) && !cleared.contains(belowCell) { break }
                    row -= 1
                }
                if openedPath { helpedGifts += 1 }
            }
            // Opening a lower path is useful progress, not a promise of immediate delivery.
            let giftCredits = capped(Double(giftsCleared), by: goal.ingredient)
            benefit += 100 * giftCredits
            benefit += 60 * min(Double(helpedGifts), max(0, Double(max(0, goal.ingredient ?? 0)) - giftCredits))

            let cracked = fullClear ? 0 : impacted.filter { (board[$0]?.armor ?? 0) > 0 && board[$0]?.armorHit == false }.count
            if hasGoals {
                benefit += Double(cracked) * 12
                benefit += Double(adjacent.filter { board[$0]?.frozen == true }.count) * 8
            }
            if let boss, boss.health > 0 {
                let damage: Double
                switch boss.configuration.kind {
                case .rat:
                    damage = Double(cleared.filter { board[$0]?.collectionType.isMatchableTo(boss.tribute) == true }.count)
                case .ox:
                    damage = Double(cracked) * 2 + Double(active.count) * 4
                case .tiger:
                    damage = Double(cleared.filter { board[$0]?.collectionType.isMatchableTo(.firecracker) == true }.count)
                case .rabbit:
                    damage = Double(cleared.filter { board[$0]?.collectionType.isMatchableTo(.lantern) == true }.count)
                        + Double(directLocks + nearbyLocks) * 2
                }
                benefit += 80 * min(Double(boss.health), damage)
            }
            if best == nil || benefit > bestBenefit {
                best = swap
                bestBenefit = benefit
            }
        }
        return best
    }
}

private struct HintPiece {
    let identity: ObjectIdentifier
    let type: SymbolType
    let collectionType: SymbolType
    let movable: Bool
    let matchable: Bool
    let frozen: Bool
    let armor: Int
    let armorHit: Bool
    var special: Bool { type == .five || type == .lightning }

    init(_ piece: Symbol) {
        identity = ObjectIdentifier(piece)
        type = piece.type
        collectionType = piece.collectionType
        movable = piece.isMovable()
        matchable = piece.isMatchable()
        frozen = piece.isFrozen
        armor = piece.armorLayers
        armorHit = piece.armorHitThisTurn
    }
}

private extension SymbolType {
    var isHintLock: Bool { self == .lock || self == .heavyLock || self == .vaultLock }
}
