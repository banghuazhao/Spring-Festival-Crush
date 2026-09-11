import SwiftUI

struct LivesHeaderView: View {
    @EnvironmentObject private var gameModel: GameModel
    var tint: Color = AppTheme.festivalRed

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    Label("\(gameModel.lives)/\(GameModel.maxLives)", systemImage: "heart.fill")
                        .foregroundStyle(AppTheme.festivalRed)
                        .accessibilityLabel("\(gameModel.lives) of \(GameModel.maxLives) lives")
                    Spacer(minLength: 0)
                    if gameModel.lives == GameModel.maxLives {
                        Text("FULL").font(.caption.weight(.black)).foregroundStyle(tint)
                    }
                    Label {
                        Text(gameModel.coins, format: .number)
                    } icon: {
                        Image(systemName: "circle.inset.filled").foregroundStyle(AppTheme.festivalGoldDark)
                    }
                        .foregroundStyle(AppTheme.ink)
                        .accessibilityLabel("\(gameModel.coins) coins")
                }
                VStack(spacing: 8) {
                    Label("\(gameModel.lives)/\(GameModel.maxLives) lives", systemImage: "heart.fill")
                        .foregroundStyle(AppTheme.festivalRed)
                    Label("\(gameModel.coins) coins", systemImage: "circle.fill")
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .font(.system(.headline, design: .rounded, weight: .heavy))

            if gameModel.lives < GameModel.maxLives {
                // Only the countdown redraws each second; chapter scenery and nodes don't poll.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Next heart in \(countdownText)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.ink.opacity(0.75))
                        .onChange(of: context.date) { _, _ in gameModel.refreshLives() }
                }
                RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                    gameModel.grantRewardedLife()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(AppTheme.festivalGold.opacity(0.8), lineWidth: 2))
        .shadow(color: tint.opacity(0.12), radius: 5, y: 3)
    }

    private var countdownText: String {
        let seconds = Int(gameModel.timeUntilNextLife)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
