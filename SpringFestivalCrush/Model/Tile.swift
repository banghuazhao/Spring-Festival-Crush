import Foundation

class Tile {
    enum TileType: Int {
        case empty = 0
        case normal = 1
        // In the game, the Lock is a special obstacle that encases a tile, preventing it from being matched or interacted with until it is removed. To unlock and clear the tile, players must make a match using one adjacent element. Once the match is made, the lock will break, freeing the tile and allowing it to be used in subsequent moves. The Lock adds an extra layer of challenge, requiring strategic planning to clear the board.
        case lock = 2
    }
    
    var type: TileType = .normal
    
    init(type: Int) {
        self.type = TileType(rawValue: type) ?? .normal
    }
}
