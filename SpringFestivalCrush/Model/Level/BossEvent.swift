import Foundation

/// One guardian reaction for the HUD avatar. A fresh id on every event lets the
/// view replay the same reaction twice in a row (two hits, two raids).
struct BossEvent: Equatable, Identifiable {
    enum Kind: Equatable {
        case hit(Int)
        /// One move before the guardian's raid: the avatar winds up.
        case windUp
        case attack
        case defeated
    }

    let id = UUID()
    let kind: Kind
}

extension BossConfiguration.Kind {
    var avatar: String {
        switch self {
        case .rat: "🐭"
        case .ox: "🐮"
        case .tiger: "🐯"
        }
    }

    /// Short lines the guardian says in its speech bubble.
    func taunt(for event: BossEvent.Kind) -> String {
        switch (self, event) {
        case (.rat, .windUp): String(localized: "My treasury needs more tribute…")
        case (.rat, .attack): String(localized: "Mine now! Squeak!")
        case (.rat, .hit): String(localized: "Hey, those were mine!")
        case (.rat, .defeated): String(localized: "Fine, keep your fortune!")
        case (.ox, .windUp): String(localized: "Hooves down… charging!")
        case (.ox, .attack): String(localized: "Iron hide, iron will!")
        case (.ox, .hit): String(localized: "Moo! That cracked!")
        case (.ox, .defeated): String(localized: "You out-pushed an ox!")
        case (.tiger, .windUp): String(localized: "Feel the winter wind…")
        case (.tiger, .attack): String(localized: "Snowfang strikes!")
        case (.tiger, .hit): String(localized: "Grr! Firecrackers!")
        case (.tiger, .defeated): String(localized: "Spring wins this year…")
        }
    }
}
