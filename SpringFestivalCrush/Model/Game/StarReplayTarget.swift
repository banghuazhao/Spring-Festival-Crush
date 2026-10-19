/// Read-only score guidance for the next star after a completed attempt.
struct StarReplayTarget: Equatable {
    let stars: Int
    let score: Int
    let pointsNeeded: Int
}
