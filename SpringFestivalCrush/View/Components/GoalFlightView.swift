import SwiftUI

struct GoalFlightView: View {
    let flight: GoalFlight
    let origin: CGPoint
    let onArrival: () -> Void
    @State private var arrived = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(1..<4) { index in
                Circle()
                    .fill(AppTheme.festivalGold.opacity(0.5 / Double(index)))
                    .frame(width: 6, height: 6)
                    .modifier(GoalFlightPath(
                        progress: arrived ? 1 : 0,
                        source: CGPoint(x: flight.source.x - origin.x, y: flight.source.y - origin.y),
                        destination: CGPoint(x: flight.destination.x - origin.x, y: flight.destination.y - origin.y),
                        lag: CGFloat(index) * 0.045
                    ))
            }
            flight.image
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .shadow(color: AppTheme.festivalGold.opacity(0.7), radius: 5)
                .scaleEffect(arrived ? 0.68 : 1.1)
                .modifier(GoalFlightPath(
                    progress: arrived ? 1 : 0,
                    source: CGPoint(x: flight.source.x - origin.x, y: flight.source.y - origin.y),
                    destination: CGPoint(x: flight.destination.x - origin.x, y: flight.destination.y - origin.y)
                ))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.42), completionCriteria: .logicallyComplete) {
                arrived = true
            } completion: {
                onArrival()
            }
        }
    }
}
