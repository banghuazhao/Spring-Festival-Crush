import SpriteKit

// MARK: - SymbolType

enum SymbolType: Int {
    case unknown = 0
    case firecracker
    case redPocket
    case dumpling
    case bowl
    case lantern
    case zodiac
    case lock

    var spriteName: String {
        let spriteNames = [
            "firecracker",
            "redPocket",
            "dumpling",
            "bowl",
            "lantern",
        ]

        return spriteNames[rawValue - 1]
    }

    var highlightedSpriteName: String {
        return spriteName + "-Highlighted"
    }

    static func random() -> SymbolType {
        return SymbolType(rawValue: Int(arc4random_uniform(6)) + 1)!
    }
}

// MARK: - Symbol

class Symbol: CustomStringConvertible, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(row * 10 + column)
    }

    var description: String {
        return "\(type)(\(column),\(row))"
    }

    var column: Int
    var row: Int
    let type: SymbolType
    var sprite: SKSpriteNode?

    init(column: Int, row: Int, symbolType: SymbolType) {
        self.column = column
        self.row = row
        type = symbolType
    }

    func createSpriteNode(zodiac: Zodiac) -> SKSpriteNode {
        let spriteNode: SKSpriteNode
        switch type {
        case .zodiac:
            let emojiTexture = SKTexture.texture(from: zodiac.emoji, fontSize: 40)
            spriteNode = SKSpriteNode(texture: emojiTexture)
        case .lock:
            let texture = SKTexture.texture(from: "🔒", fontSize: 40)
            spriteNode = SKSpriteNode(texture: texture)
        default:
            spriteNode = SKSpriteNode(imageNamed: type.spriteName)
        }
        return spriteNode
    }

    func isMovable() -> Bool {
        switch type {
        case .lock:
            false
        default:
            true
        }
    }
    
    func isMatchable() -> Bool {
        switch type {
        case .lock:
            false
        default:
            true
        }
    }
}

extension Symbol: Equatable {
    static func == (lhs: Symbol, rhs: Symbol) -> Bool {
        return lhs.column == rhs.column && lhs.row == rhs.row
    }
}
