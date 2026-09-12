/// Swapping two charged pieces activates a single combined effect, in either order.
enum PowerUpCombination: String, CaseIterable, Identifiable {
    case fiveLightning, fiveFive, lightningLightning, enhancedLightning, enhancedFive

    var id: String { rawValue }
    init?(_ a: SymbolType, _ b: SymbolType) {
        switch (a, b) {
        case (.five, .five): self = .fiveFive
        case (.five, .lightning), (.lightning, .five): self = .fiveLightning
        case (.lightning, .lightning): self = .lightningLightning
        case (.lightning, _) where b.isEnhanced: self = .enhancedLightning
        case (_, .lightning) where a.isEnhanced: self = .enhancedLightning
        case (.five, _) where b.isEnhanced: self = .enhancedFive
        case (_, .five) where a.isEnhanced: self = .enhancedFive
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .fiveLightning: "Five + Lightning"
        case .fiveFive: "Five + Five"
        case .lightningLightning: "Lightning + Lightning"
        case .enhancedLightning: "Enhanced Four + Lightning"
        case .enhancedFive: "Enhanced Four + Five"
        }
    }

    var effectName: String {
        switch self {
        case .fiveLightning: "FORTUNE STORM"
        case .fiveFive: "GRAND REUNION"
        case .lightningLightning: "THUNDER CROSS"
        case .enhancedLightning: "FIRECRACKER THUNDER"
        case .enhancedFive: "BLOSSOM FESTIVAL"
        }
    }

    var detail: String {
        switch self {
        case .fiveLightning: "Lightning strikes the rows and columns of the most common color, plus a wide central cross."
        case .fiveFive: "Clears the entire board, including armor, ice, locks, and every jelly layer."
        case .lightningLightning: "Sweeps a three-wide cross through both pieces, with diagonal lightning."
        case .enhancedLightning: "Sweeps a five-wide cross and a 5 × 5 explosion around the enhanced piece."
        case .enhancedFive: "Triggers a 5 × 5 blast around every tile of the enhanced piece’s color."
        }
    }

    var demoTypes: (SymbolType, SymbolType) {
        switch self {
        case .fiveLightning: (.five, .lightning)
        case .fiveFive: (.five, .five)
        case .lightningLightning: (.lightning, .lightning)
        case .enhancedLightning: (.bowlEnhanced, .lightning)
        case .enhancedFive: (.bowlEnhanced, .five)
        }
    }

    var fiveCount: Int { self == .fiveFive ? 2 : (self == .fiveLightning || self == .enhancedFive ? 1 : 0) }
    var lightningCount: Int { self == .lightningLightning ? 2 : (self == .fiveLightning || self == .enhancedLightning ? 1 : 0) }
    var enhancedCount: Int { self == .enhancedFive || self == .enhancedLightning ? 1 : 0 }
    var duration: Double { self == .fiveFive ? 1.12 : 0.96 }
}
