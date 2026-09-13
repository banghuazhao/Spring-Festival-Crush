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
    case heavyLock
    case vaultLock // three-hit lock: vaultLock -> heavyLock -> lock -> cleared
    case chocolate // blocker: spreads to adjacent matchable symbols each move, clears like a lock
    case ingredient // escort objective: must reach the bottom row to be collected
    // Special power-up symbols
    case five       // universal: clears all of one type when swapped
    case lightning  // clears full row + column when swapped
    case firecrackerEnhanced
    case redPocketEnhanced
    case dumplingEnhanced
    case bowlEnhanced
    case lanternEnhanced
    case zodiacEnhanced

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
        case .heavyLock: "heavyLock"
        case .vaultLock: "vaultLock"
        case .chocolate: "chocolate"
        case .ingredient: "ingredient"
        case .five: "five"
        case .lightning: "lightning"
        case .firecrackerEnhanced: "firecracker"
        case .redPocketEnhanced: "redPocket"
        case .dumplingEnhanced: "dumpling"
        case .bowlEnhanced: "bowl"
        case .lanternEnhanced: "lantern"
        case .zodiacEnhanced: "zodiac"
        }
    }

    // Fallback glyph for blockers/specials that do not yet have bespoke artwork.
    var emojiForHighlight: String? {
        switch self {
        case .lock: return "🔒"
        case .heavyLock: return "⛓️"
        case .vaultLock: return "🔐"
        case .chocolate: return "🍫"
        case .ingredient: return "🎁"
        case .five: return "🌟"
        case .lightning: return "⚡️"
        default: return nil
        }
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
        case "heavyLock":
            self = .heavyLock
        case "vaultLock":
            self = .vaultLock
        case "chocolate":
            self = .chocolate
        case "ingredient":
            self = .ingredient
        default:
            return nil
        }
    }

    static func randomMovableSymbolType(_ possibleSymbols: [String]?) -> SymbolType {
        var candidateSymbolTypes: [SymbolType]
        if let possibleSymbols {
            candidateSymbolTypes = possibleSymbols.compactMap { SymbolType(rawValue: $0) }
        } else {
            candidateSymbolTypes = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
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
        hasher.combine(column)
        hasher.combine(row)
    }

    var description: String {
        return "\(type)(\(column),\(row))"
    }

    var column: Int
    var row: Int
    var type: SymbolType
    var sprite: SKSpriteNode?
    // Conversion changes the power, but collecting it still credits its original color.
    var convertedFromType: SymbolType?
    var collectionType: SymbolType { convertedFromType ?? type }
    // Ice wraps any matchable symbol without changing its type. It moves with the symbol
    // through swaps/falls (unlike jelly, which stays pinned to a board cell) and is cleared
    // one layer at a time whenever an adjacent cell is cleared, same trigger as locks.
    var iceLayer: Int = 0
    var isFrozen: Bool { iceLayer > 0 }
    var armorLayers = 0
    // A cracked tile survives the current move, including overlapping blasts and cascades.
    var armorHitThisTurn = false

    init(column: Int, row: Int, symbolType: SymbolType) {
        self.column = column
        self.row = row
        type = symbolType
    }

    @MainActor
    func createSpriteNode(zodiac: Zodiac) -> SKSpriteNode {
        SKSpriteNode(texture: TileArtwork.texture(for: type, zodiac: zodiac))
    }

    func isMovable() -> Bool {
        switch type {
        case .lock, .heavyLock, .vaultLock, .chocolate:
            false
        default:
            true
        }
    }

    func isMatchable() -> Bool {
        guard !isFrozen, !armorHitThisTurn else { return false }
        switch type {
        case .lock, .heavyLock, .vaultLock, .chocolate, .five, .lightning, .ingredient:
            return false
        default:
            return true
        }
    }

    var isSpecialPowerUp: Bool {
        type == .five || type == .lightning
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
