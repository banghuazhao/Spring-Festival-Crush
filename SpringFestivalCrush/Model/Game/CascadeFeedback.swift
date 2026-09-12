import Foundation

/// Bounded presentation tiers; these do not multiply the score or alter match rules.
struct CascadeFeedback {
    let depth: Int
    var tier: Int { min(5, max(1, depth)) }
    var playbackRate: Float { 1 + Float(tier - 1) * 0.08 }
    var volume: Float { 0.55 + Float(tier - 1) * 0.05 }
    var title: String? {
        switch depth {
        case ...1: nil
        case 2: "Nice!"
        case 3: "Great!"
        default: "Brilliant!"
        }
    }
}
