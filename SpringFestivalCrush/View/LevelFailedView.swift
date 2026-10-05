import SwiftUI

struct LevelFailedView: View {
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var settled = false
    @State private var revealID = UUID()
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    private var unfinishedTargets: [LevelTargetData] {
        guard gameModel.level != nil, gameModel.zodiac != nil else { return [] }
        return gameModel.createLevelTargetDatas().filter { $0.targetNum > 0 }
    }

    private var guardianHealthLeft: Int {
        max(0, gameModel.bossStatus?.health ?? 0)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GamePopupPanel(title: gameModel.loseReason.title, tone: .red) {
                    VStack(spacing: 16) {
                        Image(systemName: gameModel.loseReason.icon)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.festivalRed)
                            .frame(width: 76, height: 76)
                            .background(AppTheme.creamHighlight.gradient, in: Circle())
                            .overlay(Circle().stroke(AppTheme.festivalGold.opacity(0.6), lineWidth: 3))
                            .rotationEffect(.degrees(reduceMotion || settled ? 0 : -6))
                            .scaleEffect(reduceMotion || settled ? 1 : 0.9)
                            .accessibilityHidden(true)

                        if gameModel.goalProgress >= 0.85 {
                            Text("So close! Every attempt reveals a better path.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }

                        resultStats

                        remainingGoals

                        if gameModel.lives > 0 {
                            Button(action: retry) {
                                Label("Try Again", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                            .accessibilityIdentifier("defeat-retry")
                        } else {
                            Label("Out of lives", systemImage: "heart.slash.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.festivalRed)
                            RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                                gameModel.grantRewardedLife()
                                gameModel.onTapTryAgainLevel()
                            }
                        }

                        Button(action: backToMap) {
                            Label("Back to Levels", systemImage: "map.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                        .accessibilityIdentifier("defeat-map")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: reveal)
        .onDisappear { revealID = UUID() }
    }

    private var resultStats: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LEVEL")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                    Text(gameModel.currentLevel >= 1 ? "\(gameModel.currentLevel)" : "DEMO" as LocalizedStringKey)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.festivalRed)
                    Divider()
                    Text("SCORE")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                    Text("\(gameModel.score)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.festivalRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Grid(horizontalSpacing: 28, verticalSpacing: 5) {
                    GridRow {
                        Text("LEVEL")
                        Text("SCORE")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    GridRow {
                        Text(gameModel.currentLevel >= 1 ? "\(gameModel.currentLevel)" : "DEMO" as LocalizedStringKey)
                        Text("\(gameModel.score)")
                    }
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.festivalRed)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var remainingGoals: some View {
        let targets = unfinishedTargets
        let health = guardianHealthLeft
        if !targets.isEmpty || health > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("GOALS REMAINING")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink.opacity(0.7))

                if health > 0 {
                    remainingGoalRow(count: health) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppTheme.festivalRed)
                            .font(.title3)
                    } name: {
                        Text("Guardian health left")
                    }
                }

                ForEach(targets) { target in
                    remainingGoalRow(count: target.targetNum) {
                        target.image
                            .resizable()
                            .scaledToFit()
                    } name: {
                        Text(goalName(target.imageName))
                    }
                }
            }
            .foregroundStyle(AppTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func remainingGoalRow<Icon: View>(count: Int, @ViewBuilder icon: () -> Icon,
                                               name: () -> Text) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        icon()
                            .frame(width: 30, height: 30)
                            .accessibilityHidden(true)
                        name()
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(count, format: .number)
                        .font(.headline.bold().monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    icon()
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)
                    name()
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(count, format: .number)
                        .font(.headline.bold().monospacedDigit())
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 10)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    /// Matches the existing names on the pre-level briefing without changing goal data.
    private func goalName(_ imageName: String) -> String {
        switch imageName {
        case "firecracker": String(localized: "firecrackers")
        case "redPocket": String(localized: "red envelopes")
        case "dumpling": String(localized: "dumplings")
        case "bowl": String(localized: "bowls")
        case "lantern": String(localized: "lanterns")
        case "zodiac": String(localized: "\(gameModel.zodiac.zodiacType.localizedName) tiles")
        case "lock": String(localized: "locks")
        case "jelly": String(localized: "moon blossoms")
        case "ingredient": String(localized: "gifts to bring to the bottom")
        case "lightningCombos": String(localized: "lightning combos")
        case "fiveCombos": String(localized: "five-tile combos")
        case "enhancedCombos": String(localized: "enhanced combos")
        default: imageName
        }
    }

    private func reveal() {
        let token = UUID()
        revealID = token
        guard !reduceMotion else { settled = true; onRevealComplete(); return }
        withAnimation(.easeOut(duration: 0.24), completionCriteria: .logicallyComplete) {
            settled = true
        } completion: {
            if revealID == token { onRevealComplete() }
        }
    }

    private func retry() {
        HapticManager.buttonTap()
        gameModel.onTapTryAgainLevel()
    }

    private func backToMap() {
        HapticManager.buttonTap()
        gameModel.onTapBack()
    }
}
