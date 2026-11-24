import SwiftUI

/// Lives and coins in one slim row. Large text gets a stacked layout with full labels.
struct LivesHeaderView: View {
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var tint: Color = AppTheme.festivalRed

    private var isFull: Bool { gameModel.isPremium || gameModel.lives == GameModel.maxLives }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            expanded
        } else {
            compact
        }
    }

    private var compact: some View {
        HStack(spacing: AppTheme.Space.sm) {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(AppTheme.festivalRed)
                if gameModel.isPremium {
                    Image(systemName: "infinity")
                        .font(.subheadline.weight(.black))
                        .accessibilityLabel(Text("Unlimited lives"))
                } else {
                    Text(verbatim: "\(gameModel.lives)/\(GameModel.maxLives)")
                        .monospacedDigit()
                        .accessibilityLabel(Text("\(gameModel.lives) of \(GameModel.maxLives) lives"))
                }
                if gameModel.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(AppTheme.festivalGoldDark)
                        .accessibilityHidden(true)
                } else if isFull {
                    Text("FULL")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(tint)
                } else {
                    countdown(compact: true)
                }
            }
            .modifier(HeaderPill())

            if !isFull {
                RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill",
                                 compactLabel: "+1") {
                    gameModel.grantRewardedLife()
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "circle.inset.filled")
                    .foregroundStyle(AppTheme.festivalGoldDark)
                Text(gameModel.coins, format: .number)
                    .monospacedDigit()
            }
            .modifier(HeaderPill())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(gameModel.coins) coins"))
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .foregroundStyle(AppTheme.ink)
    }

    private var expanded: some View {
        VStack(spacing: 10) {
            Group {
                if gameModel.isPremium {
                    Label("Unlimited lives", systemImage: "heart.fill")
                } else {
                    Label("\(gameModel.lives)/\(GameModel.maxLives) lives", systemImage: "heart.fill")
                }
            }
            .foregroundStyle(AppTheme.festivalRed)
            Label("\(gameModel.coins) coins", systemImage: "circle.fill")
                .foregroundStyle(AppTheme.ink)
            if !isFull {
                countdown(compact: false)
                RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                    gameModel.grantRewardedLife()
                }
            }
        }
        .font(.system(.headline, design: .rounded, weight: .heavy))
        .frame(maxWidth: .infinity)
        .gameInset(padding: AppTheme.Space.md)
    }

    /// Only the countdown redraws each second; chapter scenery and nodes don't poll.
    private func countdown(compact: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if compact {
                    Text(verbatim: countdownText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                        .accessibilityLabel(Text("Next heart in \(countdownText)"))
                } else {
                    Text("Next heart in \(countdownText)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.75))
                }
            }
            .monospacedDigit()
            .onChange(of: context.date) { _, _ in gameModel.refreshLives() }
        }
    }

    private var countdownText: String {
        let seconds = Int(gameModel.timeUntilNextLife)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct HeaderPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 11)
            .frame(minHeight: 32)
            .background(AppTheme.paper, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.hairline, lineWidth: 1))
    }
}
