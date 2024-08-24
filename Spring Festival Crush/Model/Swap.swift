struct Swap: CustomStringConvertible, Hashable {
    let symbolA: Symbol
    let symbolB: Symbol

    func hash(into hasher: inout Hasher) {
        hasher.combine(symbolA.hashValue ^ symbolB.hashValue)
    }
    
    static func == (lhs: Swap, rhs: Swap) -> Bool {
        return (lhs.symbolA == rhs.symbolA && lhs.symbolB == rhs.symbolB) ||
            (lhs.symbolB == rhs.symbolA && lhs.symbolA == rhs.symbolB)
    }

    init(symbolA: Symbol, symbolB: Symbol) {
        self.symbolA = symbolA
        self.symbolB = symbolB
    }

    var description: String {
        return "swap \(symbolA) with \(symbolB)"
    }
}
