import Foundation

struct BossConfiguration: Codable {
    enum Kind: String, Codable {
        case rat, ox, tiger

        var title: String {
            switch self {
            case .rat: String(localized: "🐭 Treasury Rat")
            case .ox: String(localized: "🐮 Iron Ox")
            case .tiger: String(localized: "🐯 Snowfang Tiger")
            }
        }

        var instructions: String {
            switch self {
            case .rat: String(localized: "Match the current tribute: red envelopes, then dumplings. The Rat changes tribute and armors two treasures every 3 moves.")
            case .ox: String(localized: "Crack armor for 2 damage. Trigger an enhanced tile, lightning or star for 4 damage. The Ox armors three tiles every 4 moves.")
            case .tiger: String(localized: "Clear firecrackers for damage; every tile in a second cascade or later also deals damage. Every 3 moves, the Tiger freezes up to two tiles in the marked row.")
            }
        }
    }

    let kind: Kind
    let health: Int
    var attackInterval: Int { kind == .ox ? 4 : 3 }
}
