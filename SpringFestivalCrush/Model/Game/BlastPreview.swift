/// Coordinates touched directly by an activating swap, before reactions or falling tiles.
struct BlastPreview: Equatable {
    struct Cell: Hashable {
        let column: Int
        let row: Int
    }

    let affectedCells: Set<Cell>
    let sourceCells: Set<Cell>
    let combination: PowerUpCombination?
}
