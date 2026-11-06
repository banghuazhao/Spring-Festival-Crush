import SwiftUI

struct GameStatusView: View {
    @ObservedObject var gameModel: GameModel
    @ObservedObject var feedback: GameFeedback
    let onPause: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var scoreLabelSize = 10
    @ScaledMetric(relativeTo: .headline) private var scoreSize = 17
    @ScaledMetric(relativeTo: .caption2) private var goalLabelSize = 9

    private var usesExpandedLayout: Bool { dynamicTypeSize >= .xxLarge }

    var body: some View {
        VStack(spacing: 9) {
            if usesExpandedLayout {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Group {
                            if gameModel.currentLevel >= 1 {
                                Text("Level") + Text(verbatim: " \(gameModel.currentLevel)")
                            } else {
                                Text("DEMO")
                            }
                        }
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        pauseButton
                    }
                    scoreProgress
                    HUDStatTile(
                        icon: "arrow.triangle.2.circlepath", title: "MOVES",
                        value: "\(gameModel.movesLeft)", isCritical: gameModel.movesLeft <= 5
                    )
                }
            } else {
                HStack(spacing: 8) {
                    HUDLevelMedallion(level: gameModel.currentLevel)
                    scoreProgress
                        .frame(maxWidth: .infinity)
                    HUDStatTile(
                        icon: "arrow.triangle.2.circlepath", title: "MOVES",
                        value: "\(gameModel.movesLeft)", isCritical: gameModel.movesLeft <= 5
                    )
                    pauseButton
                }
            }

            if let encounter = gameModel.bossStatus {
                BossEncounterView(encounter: encounter, event: gameModel.bossEvent)
            } else if gameModel.level.hasSnow {
                Label("Auspicious Snow · 瑞雪兆丰年", systemImage: "snowflake")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            if usesExpandedLayout {
                VStack(alignment: .leading, spacing: 8) {
                    timer
                    goals
                }
            } else {
                HStack(spacing: 8) {
                    timer
                    goals
                }
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

    private var scoreProgress: some View {
        VStack(alignment: .leading, spacing: 3) {
            let layout = usesExpandedLayout
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 5))
            layout {
                Text("SCORE")
                    .font(.system(size: scoreLabelSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Text("\(gameModel.score)")
                    .font(.system(size: scoreSize, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            StarProgressView(currentScore: gameModel.score, levelGoal: gameModel.level.levelGoal)
                .accessibilityHidden(true)
        }
    }

    private var pauseButton: some View {
        #if targetEnvironment(macCatalyst)
        pauseArtwork
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .overlay {
                NativePauseActivationButton {
                    HapticManager.buttonTap()
                    onPause()
                }
            }
        #else
        Button {
            HapticManager.buttonTap()
            onPause()
        } label: {
            pauseArtwork
        }
        .buttonStyle(.gameIcon)
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("game-pause")
        #endif
    }

    private var pauseArtwork: some View {
        Image(systemName: "pause.fill")
            .font(.headline.weight(.black))
            .foregroundStyle(AppTheme.ink)
            .frame(minWidth: 44, minHeight: 44)
            .padding(usesExpandedLayout ? 8 : 0)
            .background(Circle().fill(AppTheme.creamHighlight))
            .overlay(Circle().stroke(AppTheme.festivalGold, lineWidth: 3))
            .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
    }

    @ViewBuilder
    private var timer: some View {
        if let secondsLeft = gameModel.secondsLeft {
            HUDTimerPill(secondsLeft: secondsLeft)
        } else if gameModel.level.timeLimit != nil, gameModel.attemptTimerMode == .untimed {
            Label("Untimed", systemImage: "timer")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minHeight: 34)
                .background(AppTheme.creamHighlight, in: Capsule())
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 4) {
            if usesExpandedLayout {
                Text("GOALS")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.72))
            }
            HStack(spacing: 8) {
                if !usesExpandedLayout {
                    Text("GOALS")
                        .font(.system(size: goalLabelSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }
                LevelTargetView(
                    levelTargetDatas: gameModel.createLevelTargetDatas(),
                    pendingAmounts: Dictionary(uniqueKeysWithValues: gameModel.createLevelTargetDatas().map {
                        ($0.id, feedback.pendingAmount(for: $0.id))
                    }), impacts: feedback.impacts, reportsFrames: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

}

private struct HUDLevelMedallion: View {
    let level: Int
    @ScaledMetric(relativeTo: .caption2) private var labelSize = 8
    @ScaledMetric(relativeTo: .title2) private var valueSize = 22
    @ScaledMetric(relativeTo: .caption) private var demoSize = 13
    @ScaledMetric(relativeTo: .caption) private var diameter = 54

    var body: some View {
        VStack(spacing: -2) {
            // Levels below 1 aren't file-backed levels (the DEBUG demos use -1), so the
            // medallion names them instead of rendering a nonsense "LEVEL -1".
            Text(level >= 1 ? "LEVEL" : "SPRING" as LocalizedStringKey)
                .font(.system(size: labelSize, weight: .black, design: .rounded))
            Text(level >= 1 ? "\(level)" : "DEMO" as LocalizedStringKey)
                .font(.system(size: level >= 1 ? valueSize : demoSize, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(AppTheme.ink)
        .frame(width: diameter, height: diameter)
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
    @ScaledMetric(relativeTo: .caption2) private var labelSize = 8
    @ScaledMetric(relativeTo: .title2) private var valueSize = 20

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(LocalizedStringKey(title))
            }
            .font(.system(size: labelSize, weight: .black, design: .rounded))
            .opacity(0.78)

            Text(value)
                .font(.system(size: valueSize, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(isCritical ? Color.white : AppTheme.ink)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
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
    @ScaledMetric(relativeTo: .subheadline) private var textSize = 14

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text(String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(size: textSize, weight: .black, design: .rounded))
        .foregroundStyle(secondsLeft <= 10 ? Color.white : AppTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 34)
        .background(Capsule().fill(secondsLeft <= 10 ? Color.red : AppTheme.creamHighlight))
        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
    }
}

