import SwiftUI

struct GoalFlight: Identifiable {
    let id = UUID()
    let goalID: String
    let amount: Int
    let image: Image
    /// Window coordinates allow SpriteKit and the safe-area HUD to share destinations.
    let source: CGPoint
    let destination: CGPoint
}
