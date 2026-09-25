enum GameTool: String, Identifiable {
    case shuffle, hammer, swap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shuffle: String(localized: "Shuffle")
        case .hammer: String(localized: "Festival Hammer")
        case .swap: String(localized: "Ruyi Swap")
        }
    }

    var imageName: String {
        switch self {
        case .shuffle: "ShuffleBoosterIcon"
        case .hammer: "HammerBoosterIcon"
        case .swap: "SwapBoosterIcon"
        }
    }

    /// One line describing what a charge does, shown on the refill sheet.
    var detail: String {
        switch self {
        case .shuffle: String(localized: "Rearranges the board without spending a move.")
        case .hammer: String(localized: "Clears any one tile without spending a move.")
        case .swap: String(localized: "Swaps any two neighbouring tiles — no match needed, no move spent.")
        }
    }
}
