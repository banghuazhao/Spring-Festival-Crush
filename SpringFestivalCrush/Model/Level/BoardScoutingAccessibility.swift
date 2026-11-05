import Foundation

/// Describes only authored starting features. Reading a scouting cell never creates
/// a Level, deals a symbol, or predicts the color of a random tile.
struct BoardScoutingAccessibility {
    let layout: BoardScoutingLayout

    /// The layout keeps authored reading order, from the top-left across each row.
    var cells: [BoardScoutingLayout.Cell] { layout.cells }

    func label(column: Int, row: Int) -> String? {
        guard let cell = layout.cell(column: column, row: row) else { return nil }
        var parts = [String(localized: "Row \(layout.rows - row), Column \(column + 1)")]
        switch cell.kind {
        case .empty:
            parts.append(String(localized: "Hole, no tile"))
        case .normal:
            parts.append(String(localized: "Random tile"))
        case .lock:
            parts.append(String(localized: "Lock, hits remaining: \(1)"))
        case .doubleLock:
            parts.append(String(localized: "Lock, hits remaining: \(2)"))
        case .vaultLock:
            parts.append(String(localized: "Lock, hits remaining: \(3)"))
        case .five:
            parts.append(String(localized: "Lucky Five"))
        case .lightning:
            parts.append(String(localized: "Lightning"))
        case .enhanced:
            parts.append(String(localized: "Blast Tile, random tile type"))
        case .chocolate:
            parts.append(String(localized: "Chocolate"))
        case .ingredient:
            parts.append(String(localized: "Gift"))
        }
        if cell.iceLayers > 0 {
            parts.append(String(localized: "Ice layers: \(cell.iceLayers)"))
        }
        if cell.armorLayers > 0 {
            parts.append(String(localized: "Gold frame layers: \(cell.armorLayers)"))
        }
        if cell.blossomLayers > 0 {
            parts.append(String(localized: "Moon blossom layers: \(cell.blossomLayers)"))
        }
        if cell.kind != .empty, row == 0, layout.exitColumns.contains(column) {
            parts.append(String(localized: "Gift delivery exit"))
        }
        return parts.joined(separator: ", ")
    }

    func sortPriority(column: Int, row: Int) -> Double {
        guard layout.cell(column: column, row: row) != nil else { return 0 }
        let index = (layout.rows - row - 1) * layout.columns + column
        return Double(layout.cells.count - index)
    }
}
