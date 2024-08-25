import SpriteKit

// MARK: - SymbolType

enum SymbolType: String {
    case unknown
    case firecracker
    case redPocket
    case dumpling
    case bowl
    case lantern
    case zodiac
    case lock

    var spriteName: String {
        switch self {
        case .unknown: "unknown"
        case .firecracker: "firecracker"
        case .redPocket: "redPocket"
        case .dumpling: "dumpling"
        case .bowl: "bowl"
        case .lantern: "lantern"
        case .zodiac: "zodiac"
        case .lock: "lock"
        }
    }

    var highlightedSpriteName: String {
        return spriteName + "-Highlighted"
    }

    init?(rawValue: String) {
        switch rawValue {
        case "unknown":
            self = .unknown
        case "firecracker":
            self = .firecracker
        case "redPocket":
            self = .redPocket
        case "dumpling":
            self = .dumpling
        case "bowl":
            self = .bowl
        case "lantern":
            self = .lantern
        case "zodiac":
            self = .zodiac
        case "lock":
            self = .lock
        default:
            return nil
        }
    }

    static func randomMovableSymbolType(_ possibleSymbols: [String]?) -> SymbolType {
        var candidateSymbolTypes: [SymbolType]
        if let possibleSymbols {
            candidateSymbolTypes = possibleSymbols.compactMap { SymbolType(rawValue: $0) }
        } else {
            candidateSymbolTypes = [.firecracker, .redPocket, dumpling, .bowl, .lantern, .zodiac]
        }
        return candidateSymbolTypes.randomElement() ?? .zodiac
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
