import Foundation

class Tile {
    enum TileType: Int {
        case empty = 0
        case normal = 1
        case lock = 2
        case doubleLock = 3
        // Pre-placed special power-up tiles. Usable in any level's JSON, not just debug ones.
        case five = 4
        case lightning = 5
        case enhanced = 6
        // Three-hit lock: vaultLock -> doubleLock -> lock -> cleared.
        case vaultLock = 7
        // Spreads to adjacent matchable tiles each move until adjacent-cleared like a lock.
        case chocolate = 8
        // Escort objective: must reach the bottom row to be collected.
        case ingredient = 9
    }

    var type: TileType = .normal
    // Jelly is an independent overlay layer: it exists underneath whatever symbol currently
    // occupies this cell and is decremented whenever that cell is cleared, regardless of the
    // clearing mechanism (match, special explosion, hammer, lock removal, etc).
    var jellyCount: Int = 0
    // Ice is authored the same way as jelly but tracked per-Symbol (Symbol.swift) since it
    // needs to move with the symbol when the board shifts, not stay pinned to a cell.

    init(type: Int) {
        self.type = TileType(rawValue: type) ?? .normal
    }
}
