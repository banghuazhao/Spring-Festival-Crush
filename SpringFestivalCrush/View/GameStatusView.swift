import SwiftUI

struct GameStatusView: View {
    @ObservedObject var gameModel: GameModel
    @ObservedObject var feedback: GameFeedback
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                HUDLevelMedallion(level: gameModel.currentLevel)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("\(gameModel.score)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }

                    StarProgressView(currentScore: gameModel.score, levelGoal: gameModel.level.levelGoal)
                }
                .frame(maxWidth: .infinity)

                HUDStatTile(
                    icon: "arrow.triangle.2.circlepath",
                    title: "MOVES",
                    value: "\(gameModel.movesLeft)",
                    isCritical: gameModel.movesLeft <= 5
                )

                Button {
                    HapticManager.buttonTap()
                    onPause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppTheme.creamHighlight))
                        .overlay(Circle().stroke(AppTheme.festivalGold, lineWidth: 3))
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
                }
                .buttonStyle(.gameIcon)
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("game-pause")
            }

            if let encounter = gameModel.bossStatus {
                BossEncounterView(encounter: encounter)
            } else if gameModel.level.hasSnow {
                Label("Auspicious Snow · 瑞雪兆丰年", systemImage: "snowflake")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                if let secondsLeft = gameModel.secondsLeft {
                    HUDTimerPill(secondsLeft: secondsLeft)
                }

                Text("GOALS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                LevelTargetView(
                    levelTargetDatas: gameModel.createLevelTargetDatas(),
                    pendingAmounts: Dictionary(uniqueKeysWithValues: gameModel.createLevelTargetDatas().map {
                        ($0.id, feedback.pendingAmount(for: $0.id))
                    }),
                    impacts: feedback.impacts,
                    reportsFrames: true
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 11)
        .frame(maxWidth: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.festivalRed, AppTheme.festivalRedDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius, style: .continuous)
                        .stroke(AppTheme.festivalGold, lineWidth: 3)
                )
                .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        )
    }

}

private struct HUDLevelMedallion: View {
    let level: Int

    var body: some View {
        VStack(spacing: -2) {
            // Levels below 1 aren't file-backed levels (the DEBUG demos use -1), so the
            // medallion names them instead of rendering a nonsense "LEVEL -1".
            Text(level >= 1 ? "LEVEL" : "SPRING")
                .font(.system(size: 8, weight: .black, design: .rounded))
            Text(level >= 1 ? "\(level)" : "DEMO")
                .font(.system(size: level >= 1 ? 22 : 13, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(AppTheme.ink)
        .frame(width: 54, height: 54)
        .background(Circle().fill(AppTheme.creamHighlight))
        .overlay(Circle().stroke(AppTheme.festivalGold, lineWidth: 3))
        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
    }
}

private struct HUDStatTile: View {
    let icon: String
    let title: String
    let value: String
    let isCritical: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 8, weight: .black, design: .rounded))
            .opacity(0.78)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(isCritical ? Color.white : AppTheme.ink)
        .frame(minWidth: 55, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCritical ? Color.red : AppTheme.creamHighlight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCritical ? Color.white.opacity(0.75) : AppTheme.festivalGold, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: value)
    }
}

private struct HUDTimerPill: View {
    let secondsLeft: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text(String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(size: 14, weight: .black, design: .rounded))
        .foregroundStyle(secondsLeft <= 10 ? Color.white : AppTheme.ink)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Capsule().fill(secondsLeft <= 10 ? Color.red : AppTheme.creamHighlight))
        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
    }
}

