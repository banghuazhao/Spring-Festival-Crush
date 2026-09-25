import Foundation

/// A one-time "keep going" offer shown between running out and the defeat screen.
/// Pricing is pure and escalates per attempt, so it is covered by unit tests.
struct ContinueOffer: Equatable {
    static let maxPerAttempt = 3
    static let extraMoves = 5
    static let extraSeconds = 20
    private static let coinCosts = [30, 60, 90]

    let reason: GameModel.LoseReason
    /// Zero-based count of continues already bought in this attempt.
    let index: Int
    let grantsMoves: Bool
    let grantsSeconds: Bool
    /// Goal pieces still missing, for "only N to go" framing. Zero for boss-only levels.
    let piecesRemaining: Int
    /// 0...1 progress toward the goals, so the offer can say how close the player came.
    let progress: Double

    var coinCost: Int { Self.coinCosts[min(index, Self.coinCosts.count - 1)] }
    /// A rewarded video can only pay for the first continue of each attempt.
    var allowsRewardedAd: Bool { index == 0 }

    /// Nil once the player has used every continue for this attempt.
    static func make(
        reason: GameModel.LoseReason,
        continuesUsed: Int,
        movesLeft: Int,
        secondsLeft: Int?,
        piecesRemaining: Int,
        progress: Double
    ) -> ContinueOffer? {
        guard continuesUsed < maxPerAttempt else { return nil }
        // A timed level can run out of both at once; the offer refills whatever ran out.
        let grantsSeconds = reason == .outOfTime || secondsLeft == 0
        let grantsMoves = reason == .outOfMoves || movesLeft <= 0
        return ContinueOffer(
            reason: reason,
            index: continuesUsed,
            grantsMoves: grantsMoves,
            grantsSeconds: grantsSeconds,
            piecesRemaining: max(0, piecesRemaining),
            progress: min(1, max(0, progress))
        )
    }
}
