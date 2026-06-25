import Foundation

class Tile {
    enum TileType: Int {
        case empty = 0
        case normal = 1
        case lock = 2
        // A heavy lock that requires TWO adjacent matches to clear.
        // First hit downgrades it to a regular lock; second hit removes it.
        case doubleLock = 3
    }
    
    var type: TileType = .normal
    
    init(type: Int) {
        self.type = TileType(rawValue: type) ?? .normal
    }
}
