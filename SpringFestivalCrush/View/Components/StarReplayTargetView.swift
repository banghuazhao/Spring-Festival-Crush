import SwiftUI

/// Feedback for the completed attempt; the player's saved best stars stay independent.
struct StarReplayTargetView: View {
    let target: StarReplayTarget

    var body: some View {
        HStack(spacing: AppTheme.Space.sm) {
            Image(systemName: "star.leadinghalf.filled")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.festivalGoldDark)
                .accessibilityHidden(true)
            Text("\(target.pointsNeeded) more points for \(target.stars) stars")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameInset(padding: AppTheme.Space.sm, radius: AppTheme.Radius.sm)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Next star score: \(target.score.formatted()) points"))
        .accessibilityIdentifier("victory-next-star")
    }
}
