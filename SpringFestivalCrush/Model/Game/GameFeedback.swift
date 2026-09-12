import SwiftUI

/// Presentation-only state, owned by one GameView. Animation completions cannot award
/// progress, spend tools, or affect another level attempt.
@MainActor
final class GameFeedback: ObservableObject {
    @Published private(set) var flights: [GoalFlight] = []
    @Published private(set) var impacts: [String: Int] = [:]
    var goalFrames: [String: CGRect] = [:]
    var viewport: CGRect = .zero

    func pendingAmount(for goalID: String) -> Int {
        flights.filter { $0.goalID == goalID }.reduce(0) { $0 + $1.amount }
    }

    func collect(_ progress: GoalProgress, image: Image, source: CGPoint, reduceMotion: Bool) {
        guard !reduceMotion, let frame = goalFrames[progress.goalID],
              viewport.contains(CGPoint(x: frame.midX, y: frame.midY)),
              flights.count < 12 else {
            impacts[progress.goalID, default: 0] += 1
            return
        }
        // One representative tile per objective/batch, not dozens of crossing particles.
        flights.append(GoalFlight(
            goalID: progress.goalID, amount: progress.amount, image: image,
            source: source, destination: CGPoint(x: frame.midX, y: frame.midY)
        ))
    }

    func arrive(_ id: UUID) {
        guard let flight = flights.first(where: { $0.id == id }) else { return }
        flights.removeAll { $0.id == id }
        impacts[flight.goalID, default: 0] += 1
    }

    func clear() {
        flights.removeAll()
        impacts.removeAll()
    }
}
