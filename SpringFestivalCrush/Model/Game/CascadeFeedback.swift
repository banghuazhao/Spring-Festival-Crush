import Foundation

/// Bounded presentation tiers; these do not multiply the score or alter match rules.
struct CascadeFeedback {
    let depth: Int
    var tier: Int { min(5, max(1, depth)) }
    var playbackRate: Float { 1 + Float(tier - 1) * 0.08 }
    var volume: Float { 0.55 + Float(tier - 1) * 0.05 }
    /// Pentatonic string for this cascade: the first match plucks the lowest string and
    /// each further cascade climbs one, topping out on the eighth.
    var noteStep: Int { min(7, max(0, depth - 1)) }
    var title: String? {
        switch depth {
        case ...1: nil
        case 2: String(localized: "Nice!")
        case 3: String(localized: "Great!")
        default: String(localized: "Brilliant!")
        }
    }
}
