class Chain: Hashable, CustomStringConvertible {
    var symbols: [Symbol] = []
    var score = 0

    enum ChainType: CustomStringConvertible {
        case horizontal
        case vertical
        case locks

        var description: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical: return "Vertical"
            case .locks: return "Locks"
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
        hasher.combine(symbols.reduce(0) { $0.hashValue ^ $1.hashValue })
    }

    static func == (lhs: Chain, rhs: Chain) -> Bool {
        return lhs.symbols == rhs.symbols
    }
}
