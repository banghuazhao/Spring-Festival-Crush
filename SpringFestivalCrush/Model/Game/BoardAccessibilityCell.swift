import Foundation

/// A stable board location. The tile at this location can change after a turn settles.
struct BoardAccessibilityCell: Hashable {
    let column: Int
    let row: Int

    static let instructions = String(localized: "Puzzle board. Rows are numbered from top to bottom and columns from left to right. Double-tap a tile to select it, then double-tap a neighboring tile to swap. Double-tap the selected tile to cancel. You can also choose Swap up, Swap down, Swap left, or Swap right in the Actions rotor. With the Hammer active, double-tap a tile to hit it.")

    func positionLabel(in level: Level) -> String {
        String(localized: "Row \(level.numRows - row), Column \(column + 1)")
    }

    func label(in level: Level, zodiac: Zodiac) -> String {
        var parts = [positionLabel(in: level)]
        guard column >= 0, column < level.numColumns, row >= 0, row < level.numRows,
              let tile = level.tileAt(column: column, row: row) else {
            parts.append(String(localized: "Empty space"))
            return parts.joined(separator: ", ")
        }

        if let symbol = level.symbol(atColumn: column, row: row) {
            parts.append(name(for: symbol.type, zodiac: zodiac))
            if symbol.iceLayer > 0 {
                parts.append(String(localized: "Ice layers: \(symbol.iceLayer)"))
            }
            if symbol.armorLayers > 0 {
                parts.append(String(localized: "Gold frame layers: \(symbol.armorLayers)"))
            }
            if !symbol.isMovable() {
                parts.append(String(localized: "Cannot be swapped"))
            }
        } else {
            parts.append(String(localized: "Empty tile"))
        }
        if tile.jellyCount > 0 {
            parts.append(String(localized: "Moon blossom layers: \(tile.jellyCount)"))
        }
        if row == 0, level.levelGoal.levelTarget.ingredient != nil {
            parts.append(String(localized: "Gift delivery exit"))
        }
        return parts.joined(separator: ", ")
    }

    private func name(for type: SymbolType, zodiac: Zodiac) -> String {
        switch type {
        case .unknown:
            String(localized: "Unknown tile")
        case .firecracker:
            String(localized: "Firecracker")
        case .redPocket:
            String(localized: "Red envelope")
        case .dumpling:
            String(localized: "Dumpling")
        case .bowl:
            String(localized: "Bowl")
        case .lantern:
            String(localized: "Lantern")
        case .zodiac:
            String(localized: "\(zodiac.zodiacType.localizedName) zodiac tile")
        case .lock:
            String(localized: "Lock, hits remaining: \(1)")
        case .heavyLock:
            String(localized: "Lock, hits remaining: \(2)")
        case .vaultLock:
            String(localized: "Lock, hits remaining: \(3)")
        case .chocolate:
            String(localized: "Chocolate")
        case .ingredient:
            String(localized: "Gift")
        case .five:
            String(localized: "Lucky Five")
        case .lightning:
            String(localized: "Lightning")
        case .firecrackerEnhanced:
            String(localized: "\(name(for: .firecracker, zodiac: zodiac)), Blast Tile")
        case .redPocketEnhanced:
            String(localized: "\(name(for: .redPocket, zodiac: zodiac)), Blast Tile")
        case .dumplingEnhanced:
            String(localized: "\(name(for: .dumpling, zodiac: zodiac)), Blast Tile")
        case .bowlEnhanced:
            String(localized: "\(name(for: .bowl, zodiac: zodiac)), Blast Tile")
        case .lanternEnhanced:
            String(localized: "\(name(for: .lantern, zodiac: zodiac)), Blast Tile")
        case .zodiacEnhanced:
            String(localized: "\(name(for: .zodiac, zodiac: zodiac)), Blast Tile")
        }
    }
}
