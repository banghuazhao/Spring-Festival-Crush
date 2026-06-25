import Foundation

class Tile {
    enum TileType: Int {
        case empty = 0
        case normal = 1
        case lock = 2
        case doubleLock = 3
        // Debug-only pre-placed special tiles (used by Debug_Special.json).
        // In release builds, createInitialSymbols falls through to a random movable symbol.
        case debugFive = 4
        case debugLightning = 5
        case debugEnhanced = 6
    }
    
    var type: TileType = .normal
    
    init(type: Int) {
        self.type = TileType(rawValue: type) ?? .normal
    }
}
