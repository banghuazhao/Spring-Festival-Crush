import SwiftUI

struct LevelFailedView: View {
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var settled = false
    @State private var revealID = UUID()
    @AccessibilityFocusState private var headingFocused: Bool
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    private var unfinishedTargets: [LevelTargetData] {
        guard gameModel.level != nil, gameModel.zodiac != nil else { return [] }
        return gameModel.createLevelTargetDatas().filter { $0.targetNum > 0 }
    }

    private var guardianHealthLeft: Int {
        max(0, gameModel.bossStatus?.health ?? 0)
    }

    private var retryAdvice: RetryAdvice? {
        guard gameModel.currentLevel >= 1, gameModel.level != nil, gameModel.zodiac != nil else { return nil }
        let remaining = unfinishedTargets.reduce(into: [String: Int]()) { $0[$1.id] = $1.targetNum }
        return RetryAdvice.choose(remainingGoals: remaining, guardian: gameModel.bossStatus)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GamePopupPanel(title: gameModel.loseReason.title, tone: .red, titleFocus: $headingFocused) {
                    VStack(spacing: 10) {
                        resultStats

                        if gameModel.goalProgress >= 0.85 {
                            Text("So close! Every attempt reveals a better path.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }

                        remainingGoals

                        if let advice = retryAdvice {
                            Group {
                                if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(AppTheme.festivalGoldDark)
                                            .accessibilityHidden(true)
                                        Text(LocalizedStringKey(advice.rawValue))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                } else {
                                    Label {
                                        Text(LocalizedStringKey(advice.rawValue))
                                            .fixedSize(horizontal: false, vertical: true)
                                    } icon: {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(AppTheme.festivalGoldDark)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .gameInset(padding: AppTheme.Space.sm, radius: AppTheme.Radius.sm)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("defeat-retry-tip")
                        }

                        if gameModel.lives > 0 {
                            Button(action: retry) {
                                actionLabel("Try Again", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.gameGold)
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
                            actionLabel("Back to Levels", systemImage: "map.fill")
                        }
                        .buttonStyle(.gameSecondary)
                        .accessibilityIdentifier("defeat-map")
                    }
                }
                .padding(AppTheme.Space.lg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            headingFocused = true
            reveal()
        }
        .onDisappear {
            headingFocused = false
            revealID = UUID()
        }
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
                HStack(spacing: AppTheme.Space.md) {
                    Image(systemName: gameModel.loseReason.icon)
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.festivalRed)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.cream, in: Circle())
                        .overlay(Circle().strokeBorder(AppTheme.goldGradient, lineWidth: 1.5))
                        .rotationEffect(.degrees(reduceMotion || settled ? 0 : -6))
                        .scaleEffect(reduceMotion || settled ? 1 : 0.9)
                        .accessibilityHidden(true)
                    statColumn("LEVEL") {
                        Text(gameModel.currentLevel >= 1 ? "\(gameModel.currentLevel)" : "DEMO" as LocalizedStringKey)
                    }
                    statColumn("SCORE") {
                        Text("\(gameModel.score)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .gameInset(padding: AppTheme.Space.sm)
    }

    private func statColumn<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 0) {
            GameSectionLabel(title)
            value()
                .font(.system(.title3, design: .rounded, weight: .black).monospacedDigit())
                .foregroundStyle(AppTheme.festivalRed)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var remainingGoals: some View {
        let targets = unfinishedTargets
        let health = guardianHealthLeft
        if !targets.isEmpty || health > 0 {
            VStack(alignment: .leading, spacing: 6) {
                GameSectionLabel("GOALS REMAINING")

                if dynamicTypeSize >= .xxLarge {
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
                            Text(LocalizedStringKey(goalName(target.imageName)))
                        }
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                        if health > 0 {
                            GoalChip(count: health, label: Text("Guardian health left")) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(AppTheme.festivalRed)
                            }
                        }
                        ForEach(targets) { target in
                            GoalChip(count: target.targetNum, label: Text(LocalizedStringKey(goalName(target.imageName)))) {
                                target.image.resizable().scaledToFit()
                            }
                        }
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
        .background(AppTheme.paper, in: .rect(cornerRadius: AppTheme.Radius.sm))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 6) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } else {
            Label(title, systemImage: systemImage).frame(maxWidth: .infinity)
        }
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
        case "ingredient": String(localized: "gifts to deliver")
        case "lightningCombos": String(localized: "Lightning activations")
        case "fiveCombos": String(localized: "Lucky Five activations")
        case "enhancedCombos": String(localized: "Blast Tile activations")
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
