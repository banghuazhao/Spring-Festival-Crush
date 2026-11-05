import Foundation

/// Spoken descriptions capture the engine's direct footprint without changing the board.
/// The snapshot contains only values; callers discard it when the live board changes.
struct BoardAccessibilityBlastSummary: Equatable {
    let source: BoardAccessibilityCell
    let destination: BoardAccessibilityCell
    let affectedCells: [BoardAccessibilityCell]
    let protectedTileCount: Int
    let combination: PowerUpCombination?
    let summaryDescription: String
    let affectedCellsDescription: String

    init?(level: Level, swap: Swap, zodiac: Zodiac) {
        guard let preview = level.blastPreview(for: swap) else { return nil }
        let sourceCell = BoardAccessibilityCell(column: swap.symbolA.column, row: swap.symbolA.row)
        let destinationCell = BoardAccessibilityCell(column: swap.symbolB.column, row: swap.symbolB.row)
        let orderedCells = preview.affectedCells.map { BoardAccessibilityCell(column: $0.column, row: $0.row) }
            .sorted { first, second in
                first.row == second.row ? first.column < second.column : first.row > second.row
            }
        source = sourceCell
        destination = destinationCell
        affectedCells = orderedCells
        combination = preview.combination

        // Footprint coordinates are after the virtual swap. Count protection on the
        // piece that would occupy each coordinate, without performing that swap.
        protectedTileCount = orderedCells.filter { cell in
            let symbol: Symbol?
            if cell == sourceCell { symbol = swap.symbolB }
            else if cell == destinationCell { symbol = swap.symbolA }
            else { symbol = level.symbol(atColumn: cell.column, row: cell.row) }
            guard let symbol else { return false }
            return symbol.isFrozen || symbol.armorLayers > 0 || symbol.armorHitThisTurn
                || [.heavyLock, .vaultLock].contains(symbol.type)
        }.count

        let direction: String
        if destination.column > source.column { direction = String(localized: "Swap right") }
        else if destination.column < source.column { direction = String(localized: "Swap left") }
        else if destination.row > source.row { direction = String(localized: "Swap up") }
        else { direction = String(localized: "Swap down") }
        let sourceLabel = source.label(in: level, zodiac: zodiac)
        let destinationLabel = destination.label(in: level, zodiac: zodiac)
        var parts = [String(localized: "\(direction). From \(sourceLabel). To \(destinationLabel).")]
        if let combination = preview.combination {
            let name = String(localized: String.LocalizationValue(combination.title))
            parts.append(String(localized: "Combined power: \(name)."))
        }
        parts.append(String(localized: "Direct-hit area: \(affectedCells.count) tiles."))
        if protectedTileCount > 0 {
            parts.append(String(localized: "Protected tiles in this area: \(protectedTileCount)."))
        }
        parts.append(String(localized: "Protection can absorb hits. Chain reactions and falling tiles can extend the effect. Preview only; no move or tool used."))
        summaryDescription = parts.joined(separator: " ")

        // Group contiguous columns while retaining every hole in a shaped board.
        var positions: [String] = []
        var index = 0
        while index < affectedCells.count {
            let first = affectedCells[index]
            var last = first
            index += 1
            while index < affectedCells.count,
                  affectedCells[index].row == first.row,
                  affectedCells[index].column == last.column + 1 {
                last = affectedCells[index]
                index += 1
            }
            if first.column == last.column {
                positions.append(first.positionLabel(in: level))
            } else {
                positions.append(String(localized: "Row \(level.numRows - first.row), Columns \(first.column + 1) through \(last.column + 1)"))
            }
        }
        let positionList = positions.joined(separator: "; ")
        affectedCellsDescription = String(localized: "Direct-hit positions: \(positionList).")
    }
}
