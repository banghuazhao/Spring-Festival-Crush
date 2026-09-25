import Foundation

/// A bundle of currency and tools granted by envelopes, chests and continues.
struct RewardBundle: Equatable, Hashable {
    var coins = 0
    var shuffles = 0
    var hammers = 0
    var swaps = 0
    var lives = 0

    var isEmpty: Bool { coins == 0 && shuffles == 0 && hammers == 0 && swaps == 0 && lives == 0 }

    static func + (lhs: RewardBundle, rhs: RewardBundle) -> RewardBundle {
        RewardBundle(coins: lhs.coins + rhs.coins, shuffles: lhs.shuffles + rhs.shuffles,
                     hammers: lhs.hammers + rhs.hammers, swaps: lhs.swaps + rhs.swaps,
                     lives: lhs.lives + rhs.lives)
    }

    /// Display rows, in a stable order, for reward reveals.
    var items: [RewardItem] {
        var items = [RewardItem]()
        if coins > 0 { items.append(RewardItem(kind: .coins, amount: coins)) }
        if lives > 0 { items.append(RewardItem(kind: .lives, amount: lives)) }
        if hammers > 0 { items.append(RewardItem(kind: .hammer, amount: hammers)) }
        if swaps > 0 { items.append(RewardItem(kind: .swap, amount: swaps)) }
        if shuffles > 0 { items.append(RewardItem(kind: .shuffle, amount: shuffles)) }
        return items
    }
}

struct RewardItem: Identifiable, Hashable {
    enum Kind: String {
        case coins, lives, hammer, swap, shuffle

        var imageName: String? {
            switch self {
            case .hammer: "HammerBoosterIcon"
            case .swap: "SwapBoosterIcon"
            case .shuffle: "ShuffleBoosterIcon"
            case .coins, .lives: nil
            }
        }

        var systemImage: String {
            switch self {
            case .coins: "circle.inset.filled"
            case .lives: "heart.fill"
            case .hammer: "hammer.fill"
            case .swap: "arrow.left.arrow.right"
            case .shuffle: "shuffle"
            }
        }

        var name: String {
            switch self {
            case .coins: String(localized: "Coins")
            case .lives: String(localized: "Lives")
            case .hammer: String(localized: "Festival Hammer")
            case .swap: String(localized: "Ruyi Swap")
            case .shuffle: String(localized: "Shuffle")
            }
        }
    }

    let kind: Kind
    let amount: Int
    var id: String { kind.rawValue }
}
