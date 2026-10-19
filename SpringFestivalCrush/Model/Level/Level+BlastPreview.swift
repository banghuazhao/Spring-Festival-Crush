extension Level {
    /// Plans against virtual post-swap positions without changing any live board state.
    /// Protection may absorb a hit, and reactions can reach beyond this direct footprint.
    func blastPreview(for swap: Swap) -> BlastPreview? {
        typealias Cell = BlastPreview.Cell
        let a = swap.symbolA
        let b = swap.symbolB
        func isInside(_ symbol: Symbol) -> Bool {
            symbol.column >= 0 && symbol.column < numColumns && symbol.row >= 0 && symbol.row < numRows
        }
        guard a !== b, isInside(a), isInside(b),
              symbol(atColumn: a.column, row: a.row) === a,
              symbol(atColumn: b.column, row: b.row) === b,
              tileAt(column: a.column, row: a.row) != nil,
              tileAt(column: b.column, row: b.row) != nil,
              abs(a.column - b.column) + abs(a.row - b.row) == 1,
              a.isMovable(), b.isMovable(), !a.isFrozen, !b.isFrozen else { return nil }

        func isCharged(_ symbol: Symbol) -> Bool { symbol.isSpecialPowerUp || symbol.type.isEnhanced }
        func isUnprotected(_ symbol: Symbol) -> Bool { symbol.armorLayers == 0 && !symbol.armorHitThisTurn }
        let charged = [a, b].filter(isCharged)
        guard !charged.isEmpty, charged.allSatisfy(isUnprotected) else { return nil }

        let cellA = Cell(column: a.column, row: a.row)
        let cellB = Cell(column: b.column, row: b.row)
        func swappedCell(of symbol: Symbol) -> Cell {
            if symbol === a { return cellB }
            if symbol === b { return cellA }
            return Cell(column: symbol.column, row: symbol.row)
        }
        let live = (0..<numRows).flatMap { row in
            (0..<numColumns).compactMap { column -> Symbol? in
                guard tileAt(column: column, row: row) != nil else { return nil }
                return symbol(atColumn: column, row: row)
            }
        }
        guard live.allSatisfy({ isInside($0) && symbol(atColumn: $0.column, row: $0.row) === $0 }) else { return nil }
        let pieces = live.map {
            BlastPreviewPiece(cell: swappedCell(of: $0), type: $0.type,
                              isMatchable: $0.isMatchable(), canConvert: !$0.isFrozen && isUnprotected($0))
        }
        let sources = [a, b].map {
            BlastPreviewPiece(cell: swappedCell(of: $0), type: $0.type,
                              isMatchable: $0.isMatchable(), canConvert: isUnprotected($0))
        }
        func cross(_ target: Cell, _ source: Cell, radius: Int) -> Bool {
            abs(target.row - source.row) <= radius || abs(target.column - source.column) <= radius
        }
        func square(_ target: Cell, _ source: Cell, radius: Int) -> Bool {
            abs(target.row - source.row) <= radius && abs(target.column - source.column) <= radius
        }
        if let combination = PowerUpCombination(a.type, b.type) {
            let sourceCells = Set(sources.map(\.cell))
            let enhanced = sources.first { $0.type.isEnhanced }
            let lightning = sources.first { $0.type == .lightning }
            let centers: [BlastPreviewPiece]
            switch combination {
            case .fiveLightning:
                let dominant = dominantSourceType(in: live)
                centers = pieces.filter { $0.type.isMatchableTo(dominant) && $0.canConvert }
            case .enhancedFive:
                guard let enhanced else { return nil }
                centers = pieces.filter { $0.type.isMatchableTo(enhanced.type) && $0.canConvert }
            default:
                centers = sources
            }
            let affected = pieces.filter { target in
                if sourceCells.contains(target.cell) { return true }
                switch combination {
                case .fiveFive:
                    return true
                case .fiveLightning:
                    return centers.contains { cross(target.cell, $0.cell, radius: 0) }
                        || lightning.map { cross(target.cell, $0.cell, radius: 0) } == true
                case .lightningLightning:
                    return sources.contains {
                        cross(target.cell, $0.cell, radius: 1)
                            || abs(target.cell.row - $0.cell.row) == abs(target.cell.column - $0.cell.column)
                    }
                case .enhancedLightning:
                    return lightning.map { cross(target.cell, $0.cell, radius: 2) } == true
                        || enhanced.map { square(target.cell, $0.cell, radius: 2) } == true
                case .enhancedFive:
                    return centers.contains { square(target.cell, $0.cell, radius: 1) }
                }
            }
            return BlastPreview(affectedCells: Set(affected.map(\.cell)), sourceCells: sourceCells,
                                combination: combination)
        }
        if let five = sources.first(where: { $0.type == .five }) {
            let partner = a.type == .five ? b.type : a.type
            let affected = pieces.filter { $0.cell == five.cell || $0.type.isMatchableTo(partner) }
            return BlastPreview(affectedCells: Set(affected.map(\.cell)), sourceCells: [five.cell], combination: nil)
        }
        if let lightning = sources.first(where: { $0.type == .lightning }) {
            let affected = pieces.filter { cross($0.cell, lightning.cell, radius: 0) }
            return BlastPreview(affectedCells: Set(affected.map(\.cell)), sourceCells: [lightning.cell], combination: nil)
        }

        // Enhanced pieces only fire when the swap matches them; a valid match elsewhere
        // does not activate an enhanced tile that happens to be the other swapped piece.
        var board: [Cell: BlastPreviewPiece] = [:]
        for piece in pieces { board[piece.cell] = piece }
        func hasMatch(_ source: BlastPreviewPiece) -> Bool {
            guard source.isMatchable else { return false }
            func run(columnStep: Int, rowStep: Int) -> Int {
                var count = 0
                var column = source.cell.column + columnStep
                var row = source.cell.row + rowStep
                while let piece = board[Cell(column: column, row: row)],
                      piece.isMatchable, piece.type.isMatchableTo(source.type) {
                    count += 1
                    column += columnStep
                    row += rowStep
                }
                return count
            }
            return 1 + run(columnStep: -1, rowStep: 0) + run(columnStep: 1, rowStep: 0) >= 3
                || 1 + run(columnStep: 0, rowStep: -1) + run(columnStep: 0, rowStep: 1) >= 3
        }
        let active = sources.filter { $0.type.isEnhanced && hasMatch($0) }
        guard !active.isEmpty else { return nil }
        let affected = pieces.filter { target in active.contains { square(target.cell, $0.cell, radius: 1) } }
        return BlastPreview(affectedCells: Set(affected.map(\.cell)), sourceCells: Set(active.map(\.cell)), combination: nil)
    }
}

private struct BlastPreviewPiece {
    let cell: BlastPreview.Cell
    let type: SymbolType
    let isMatchable: Bool
    let canConvert: Bool
}
