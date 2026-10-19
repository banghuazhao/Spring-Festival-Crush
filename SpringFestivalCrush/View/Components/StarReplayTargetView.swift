import SwiftUI

/// Feedback for the completed attempt; the player's saved best stars stay independent.
struct StarReplayTargetView: View {
    let target: StarReplayTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Next star for this attempt", systemImage: "star")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.festivalRed)
            Text("\(target.pointsNeeded) more points for \(target.stars) stars")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Text("Next star score: \(target.score.formatted()) points")
                .font(.footnote)
                .foregroundStyle(AppTheme.ink.opacity(0.75))
        }
        .foregroundStyle(AppTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("victory-next-star")
    }
}
