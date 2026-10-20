/// A value snapshot of authored starting features. It never creates a Level or deals random tiles.
struct BoardScoutingLayout: Equatable {
    struct Cell: Equatable {
        let column: Int
        /// Board coordinates: row zero is the actual bottom row.
        let row: Int
        let kind: Tile.TileType
        let iceLayers: Int
        let armorLayers: Int
        let blossomLayers: Int
    }

    let columns: Int
    let rows: Int
    /// Author order, from the top-left across each row.
    let cells: [Cell]
    let exitColumns: Set<Int>

    init?(data: LevelData) {
        guard data.hasValidLayout, let columns = data.tiles.first?.count else { return nil }
        self.columns = columns
        rows = data.tiles.count
        cells = data.tiles.enumerated().flatMap { authoredRow, values in
            values.enumerated().map { column, value in
                let kind = Tile.TileType(rawValue: value) ?? .normal
                let randomTile = kind == .normal
                let playable = kind != .empty
                return Cell(column: column, row: data.tiles.count - authoredRow - 1, kind: kind,
                            // The engine applies authored ice/armor only to ordinary random tiles.
                            iceLayers: randomTile ? max(0, data.ice?[authoredRow][column] ?? 0) : 0,
                            armorLayers: randomTile ? max(0, data.armor?[authoredRow][column] ?? 0) : 0,
                            blossomLayers: playable ? max(0, data.jelly?[authoredRow][column] ?? 0) : 0)
            }
        }
        exitColumns = (data.levelGoal.levelTarget.ingredient ?? 0) > 0
            ? Set(cells.filter { $0.row == 0 && $0.kind != .empty }.map(\.column)) : []
    }

    func cell(column: Int, row: Int) -> Cell? {
        guard column >= 0, column < columns, row >= 0, row < rows else { return nil }
        return cells[(rows - row - 1) * columns + column]
    }

    var playableCount: Int { cells.filter { $0.kind != .empty }.count }
    var holeCount: Int { cells.count - playableCount }
    var randomTileCount: Int { cells.filter { $0.kind == .normal }.count }
    var lockCount: Int { cells.filter { [.lock, .doubleLock, .vaultLock].contains($0.kind) }.count }
    var iceCount: Int { cells.filter { $0.iceLayers > 0 }.count }
    var armorCount: Int { cells.filter { $0.armorLayers > 0 }.count }
    var blossomLayerCount: Int { cells.reduce(0) { $0 + $1.blossomLayers } }
    var powerUpCount: Int { cells.filter { [.five, .lightning, .enhanced].contains($0.kind) }.count }
    var giftCount: Int { cells.filter { $0.kind == .ingredient }.count }
    var chocolateCount: Int { cells.filter { $0.kind == .chocolate }.count }
}
