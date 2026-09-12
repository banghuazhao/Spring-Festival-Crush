import SwiftUI

struct GoalCollectionOverlay: View {
    @ObservedObject var feedback: GameFeedback

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            ForEach(feedback.flights) { flight in
                GoalFlightView(flight: flight, origin: origin) {
                    feedback.arrive(flight.id)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
