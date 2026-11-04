import Foundation

/// Navigation categories inspect the current board and never change game state.
enum BoardAccessibilityRotor: CaseIterable {
    case rows
    case powerUps
    case goalTiles

    var title: String {
        switch self {
        case .rows: String(localized: "Rows")
        case .powerUps: String(localized: "Power-ups")
        case .goalTiles: String(localized: "Goal tiles")
        }
    }

    func matches(_ cell: BoardAccessibilityCell, in level: Level) -> Bool {
        guard cell.column >= 0, cell.column < level.numColumns,
              cell.row >= 0, cell.row < level.numRows,
              let tile = level.tileAt(column: cell.column, row: cell.row),
              let symbol = level.symbol(atColumn: cell.column, row: cell.row) else { return false }
        switch self {
        case .rows:
            return true
        case .powerUps:
            return symbol.isSpecialPowerUp || symbol.type.isEnhanced
        case .goalTiles:
            let goal = level.levelGoal.levelTarget
            if (goal.jelly ?? 0) > 0, tile.jellyCount > 0 { return true }
            if (goal.fiveCombos ?? 0) > 0, symbol.type == .five { return true }
            if (goal.lightningCombos ?? 0) > 0, symbol.type == .lightning { return true }
            if (goal.enhancedCombos ?? 0) > 0, symbol.type.isEnhanced { return true }
            // Converted powers still collect their original color, exactly as the rules do.
            let remaining: Int?
            switch symbol.collectionType {
            case .firecracker, .firecrackerEnhanced: remaining = goal.firecracker
            case .redPocket, .redPocketEnhanced: remaining = goal.redPocket
            case .dumpling, .dumplingEnhanced: remaining = goal.dumpling
            case .bowl, .bowlEnhanced: remaining = goal.bowl
            case .lantern, .lanternEnhanced: remaining = goal.lantern
            case .zodiac, .zodiacEnhanced: remaining = goal.zodiac
            case .lock, .heavyLock, .vaultLock: remaining = goal.lock
            case .ingredient: remaining = goal.ingredient
            default: remaining = nil
            }
            return (remaining ?? 0) > 0 || helpsGuardianObjective(symbol, in: level)
        }
    }

    private func helpsGuardianObjective(_ symbol: Symbol, in level: Level) -> Bool {
        guard let boss = level.boss, boss.health > 0 else { return false }
        // Include direct contributions only; predicting cascades would make navigation
        // depend on speculative future board states rather than the tile being read.
        switch boss.configuration.kind {
        case .rat:
            return symbol.collectionType.isMatchableTo(boss.tribute)
        case .ox:
            return symbol.armorLayers > 0 || symbol.type.isEnhanced || symbol.isSpecialPowerUp
        case .tiger:
            return symbol.collectionType.isMatchableTo(.firecracker)
        case .rabbit:
            return symbol.collectionType.isMatchableTo(.lantern)
                || [.lock, .heavyLock, .vaultLock].contains(symbol.type)
        }
    }
}
