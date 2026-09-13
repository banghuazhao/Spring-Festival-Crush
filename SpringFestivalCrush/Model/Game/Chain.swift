class Chain: Hashable, CustomStringConvertible {
    var symbols: [Symbol] = []
    var score = 0
    var combination: PowerUpCombination?
    var combinationSources: [Symbol] = []
    var blastCenters: [Symbol] = []
    var sourceType: SymbolType?
    var transformationType: SymbolType?
    var transformedSymbols: [Symbol] = []
    var activatedSpecials: [Symbol] = []
    var detonations: [PowerUpDetonation] = []
    var specialsResolved = false
    var reactionDelay: Double = 0
    // Keep the original match geometry for special creation; only cleared pieces score goals.
    var resistedSymbols = Set<ObjectIdentifier>()
    var clearedSymbols: [Symbol] {
        symbols.filter { !resistedSymbols.contains(ObjectIdentifier($0)) }
    }

    enum ChainType: CustomStringConvertible {
        case horizontal3
        case vertical3
        case locks
        case horizontal4
        case vertical4
        case five
        case single
        case enhanced
        // L/T-shape match (horizontal3 + vertical3 sharing one symbol) → creates lightning symbol
        case lShape
        // Result of activating a five-universal symbol (clears all of one type)
        case fiveEffect
        // Result of activating a lightning symbol (clears full row + column)
        case lightning
        case combination

        var description: String {
            switch self {
            case .horizontal3: return "Horizontal3"
            case .vertical3: return "Vertical3"
            case .locks: return "Locks"
            case .horizontal4: return "Horizontal4"
            case .vertical4: return "Vertical4"
            case .five: return "five"
            case .single: return "eliminate"
            case .enhanced: return "enhanced"
            case .lShape: return "LShape"
            case .fiveEffect: return "FiveEffect"
            case .lightning: return "Lightning"
            case .combination: return "Combination"
            }
        }
    }

    var chainType: ChainType
    init(chainType: ChainType) {
        self.chainType = chainType
    }

    func add(symbol: Symbol) {
        symbols.append(symbol)
    }

    func add(symbols: [Symbol]) {
        self.symbols.append(contentsOf: symbols)
    }

    func firstSymbol() -> Symbol {
        return symbols[0]
    }

    func lastSymbol() -> Symbol {
        return symbols[symbols.count - 1]
    }

    var length: Int {
        return symbols.count
    }

    var description: String {
        return "type:\(chainType) symbols:\(symbols)"
    }

    func hash(into hasher: inout Hasher) {
        for symbol in symbols {
            hasher.combine(symbol)
        }
        hasher.combine(chainType)
        hasher.combine(combination)
    }

    static func == (lhs: Chain, rhs: Chain) -> Bool {
        lhs.symbols == rhs.symbols && lhs.chainType == rhs.chainType && lhs.combination == rhs.combination
    }
}

/// Immutable activation context survives removal and carries the initiating color through a blast.
struct PowerUpDetonation {
    let symbol: Symbol
    let type: SymbolType
    let sourceType: SymbolType
    let targets: [Symbol]
}
