import Foundation

struct BossConfiguration: Codable {
    enum Kind: String, Codable {
        case rat, ox, tiger

        var title: String {
            switch self {
            case .rat: "🐭 Treasury Rat"
            case .ox: "🐮 Iron Ox"
            case .tiger: "🐯 Snowfang Tiger"
            }
        }

        var instructions: String {
            switch self {
            case .rat: "Match the current tribute: red envelopes, then dumplings. The Rat changes tribute and armors two treasures every 3 moves."
            case .ox: "Crack armor for 2 damage. Trigger an enhanced tile, lightning or star for 4 damage. The Ox armors three tiles every 4 moves."
            case .tiger: "Clear firecrackers for damage; every tile in a second cascade or later also deals damage. Every 3 moves, the Tiger freezes up to two tiles in the marked row."
            }
        }
    }

    let kind: Kind
    let health: Int
    var attackInterval: Int { kind == .ox ? 4 : 3 }
}
