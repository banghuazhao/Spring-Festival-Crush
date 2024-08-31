class Chain: Hashable, CustomStringConvertible {
    var symbols: [Symbol] = []
    var score = 0

    enum ChainType: CustomStringConvertible {
        case horizontal3
        case vertical3
        case locks
        case horizontal4
        case vertical4
        case five
        case single
        case enhanced

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
        hasher.combine(
            symbols.reduce(0) {
                $0.hashValue ^ $1.hashValue
            }
        )
        hasher.combine(chainType)
    }

    static func == (lhs: Chain, rhs: Chain) -> Bool {
        lhs.symbols == rhs.symbols && lhs.chainType == lhs.chainType
    }
}
