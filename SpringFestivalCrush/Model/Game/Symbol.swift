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
    case firecrackerEnhanced
    case redPocketEnhanced
    case dumplingEnhanced
    case bowlEnhanced
    case lanternEnhanced
    case zodiacEnhanced
    case five

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
        case .firecrackerEnhanced:
            "firecracker"
        case .redPocketEnhanced:
            "redPocket"
        case .dumplingEnhanced:
            "dumpling"
        case .bowlEnhanced:
            "bowl"
        case .lanternEnhanced:
            "lantern"
        case .zodiacEnhanced:
            "zodiac"
        case .five:
            "five"
        }
    }

    var highlightedSpriteName: String {
        return spriteName + "-Highlighted"
    }

    var isEnhanced: Bool {
        [.firecrackerEnhanced, .redPocketEnhanced, .dumplingEnhanced,
         .bowlEnhanced, .lanternEnhanced, .zodiacEnhanced].contains(self)
    }

    var isNormalMatchable: Bool {
        [.firecracker, .redPocket, .dumpling,
         .bowl, .lantern, .zodiac].contains(self)
    }

    var enhancedType: Self {
        switch self {
        case .firecracker: .firecrackerEnhanced
        case .redPocket: .redPocketEnhanced
        case .dumpling: .dumplingEnhanced
        case .bowl: .bowlEnhanced
        case .lantern: .lanternEnhanced
        case .zodiac: .zodiacEnhanced
        default: self
        }
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

    func isMatchableTo(_ symbolType: SymbolType) -> Bool {
        if self == symbolType {
            return true
        }

        if enhancedType == symbolType.enhancedType {
            return true
        }
        return false
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
    var type: SymbolType
    var sprite: SKSpriteNode?

    init(column: Int, row: Int, symbolType: SymbolType) {
        self.column = column
        self.row = row
        type = symbolType
    }

    func createSpriteNode(zodiac: Zodiac) -> SKSpriteNode {
        let spriteNode: SKSpriteNode
        switch type {
        case .zodiac, .zodiacEnhanced:
            let emojiTexture = SKTexture.texture(from: zodiac.emoji, fontSize: 40)
            spriteNode = SKSpriteNode(texture: emojiTexture)
        case .lock:
            let texture = SKTexture.texture(from: "🔒", fontSize: 40)
            spriteNode = SKSpriteNode(texture: texture)
        default:
            spriteNode = SKSpriteNode(imageNamed: type.spriteName)
        }
        if type.isEnhanced {
            addMagicEffect(to: spriteNode)
        }
        return spriteNode
    }

    private func addMagicEffect(to sprite: SKSpriteNode) {
        let magicLightEffect = createMagicLightEffect()
        magicLightEffect.position = CGPoint(x: 0, y: 0) // Center the effect on the sprite
        sprite.addChild(magicLightEffect)
    }

    private func createMagicLightEffect() -> SKEmitterNode {
        let magicLight = SKEmitterNode()

        // Create a simple circular texture
        let circle = SKShapeNode(circleOfRadius: 10)
        circle.fillColor = .white
        let textureView = SKView()
        let texture = textureView.texture(from: circle)

        magicLight.particleTexture = texture // Use the circle texture
        magicLight.particleBirthRate = 20 // Lower the birth rate for a more subtle effect
        magicLight.particleLifetime = 1.0
        magicLight.particlePositionRange = CGVector(dx: 2, dy: 2) // Smaller range to localize the effect
        magicLight.emissionAngleRange = 360 // Emit in a semi-circle around the sprite
        magicLight.particleSpeed = 30 // Slower speed to keep particles close to the sprite
        magicLight.particleScale = 0.1 // Smaller particle size
        magicLight.particleAlpha = 0.75
        magicLight.particleColor = UIColor.white
        magicLight.particleBlendMode = .add

        return magicLight
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

    func enhance() {
        type = type.enhancedType
    }
}

extension Symbol: Equatable {
    static func == (lhs: Symbol, rhs: Symbol) -> Bool {
        return lhs.column == rhs.column && lhs.row == rhs.row
    }
}
