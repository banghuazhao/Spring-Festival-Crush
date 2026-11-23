import StoreKit
import SwiftUI

struct LevelCompleteView: View {
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var revealedStars = 0
    @State private var rewardVisible = false
    @State private var revealID = UUID()
    @AccessibilityFocusState private var headingFocused: Bool

    private var hasNextLevel: Bool {
        gameModel.currentLevel >= 1 && gameModel.currentLevel < gameModel.zodiac.numLevels && gameModel.lives > 0
    }

    private var nextStarTarget: StarReplayTarget? {
        guard let summary = gameModel.victorySummary,
              summary.level == gameModel.currentLevel,
              let zodiac = gameModel.zodiac, summary.zodiac == zodiac.zodiacType,
              let level = gameModel.level else { return nil }
        return summary.nextStarTarget(for: level.levelGoal)
    }

    /// Saved best stars already include this win, so replays cannot count twice.
    private var chestProgress: (stars: Int, next: StarChestTrack.Chest?)? {
        guard let summary = gameModel.victorySummary, summary.level >= 1,
              let record = gameModel.currentZodiacRecord, record.zodiacType == summary.zodiac,
              !record.levelRecords.isEmpty else { return nil }
        let stars = record.levelRecords.reduce(0) { $0 + $1.stars }
        let track = StarChestTrack(levelCount: record.levelRecords.count)
        let claimed = StarChestStore.claimed(for: summary.zodiac)
        return (stars, track.chests.first { !claimed.contains($0.index) })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GamePopupPanel(title: "LEVEL COMPLETE!", tone: .gold, titleFocus: $headingFocused) {
                    VStack(spacing: 10) {
                        HStack(alignment: .bottom, spacing: AppTheme.Space.xs) {
                            ForEach(0..<3) { index in
                                StarView(earned: index < (gameModel.victorySummary?.stars ?? 0), size: index == 1 ? 62 : 48)
                                    .opacity(index < revealedStars ? 1 : 0.2)
                                    .scaleEffect(reduceMotion || index < revealedStars ? 1 : 0.78)
                                    .rotationEffect(.degrees(reduceMotion || index < revealedStars ? 0 : -12))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(gameModel.victorySummary?.stars ?? 0) of 3 stars earned")

                        VStack(spacing: 0) {
                            GameSectionLabel("FESTIVAL SCORE")
                            Text("\(gameModel.victorySummary?.score ?? gameModel.score)")
                                .font(.system(.largeTitle, design: .rounded, weight: .black).monospacedDigit())
                                .foregroundStyle(AppTheme.festivalRed)
                            if let summary = gameModel.victorySummary {
                                if summary.isNewBest {
                                    Label("NEW BEST!", systemImage: "trophy.fill")
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(AppTheme.dangerGradient, in: Capsule())
                                        .accessibilityIdentifier("victory-new-best")
                                } else if summary.previousBest > 0 {
                                    Label {
                                        Text(verbatim: summary.previousBest.formatted())
                                    } icon: {
                                        Image(systemName: "trophy.fill")
                                    }
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(Text("Best score: \(summary.previousBest)"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        VictoryRewardView(
                            coins: gameModel.victorySummary?.coins ?? 0,
                            balance: gameModel.coins,
                            revealed: rewardVisible
                        )

                        if let target = nextStarTarget {
                            StarReplayTargetView(target: target)
                        }

                        if let progress = chestProgress {
                            chestProgressRow(progress)
                        }

                        if let next = gameModel.victorySummary?.newlyUnlockedLevel {
                            Label("Level \(next) unlocked!", systemImage: "lock.open.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(AppTheme.festivalRed)
                        }

                        if hasNextLevel && dynamicTypeSize < .xxLarge {
                            // Side by side only while both labels fit in full.
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .top, spacing: AppTheme.Space.sm) {
                                    playNextButton.fixedSize(horizontal: true, vertical: false)
                                    continueToMapButton
                                }
                                VStack(spacing: AppTheme.Space.sm) {
                                    playNextButton
                                    continueToMapButton
                                }
                            }
                        } else {
                            VStack(spacing: AppTheme.Space.sm) {
                                if hasNextLevel { playNextButton }
                                continueToMapButton
                            }
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
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
            let token = UUID()
            revealID = token
            if reduceMotion {
                revealedStars = 3
                rewardVisible = true
                onRevealComplete()
                maybeAskForReview(token: token)
            } else {
                revealNextStar(token: token)
            }
        }
        .onDisappear {
            headingFocused = false
            revealID = UUID()
        }
    }

    private var playNextButton: some View {
        Button {
            HapticManager.buttonTap()
            gameModel.onTapNextLevel()
        } label: {
            actionLabel("Play Next", systemImage: "play.fill")
        }
        .buttonStyle(.gameSecondary)
        .accessibilityIdentifier("victory-next")
    }

    private var continueToMapButton: some View {
        Button {
            HapticManager.buttonTap()
            gameModel.onTapVictoryMap()
        } label: {
            actionLabel("Continue to Map", systemImage: "map.fill")
        }
        .buttonStyle(.gameGold)
        .accessibilityIdentifier("victory-map")
        .accessibilityHint("You can continue immediately; rewards are already saved")
    }

    @ViewBuilder
    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 6) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } else {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
        }
    }

    private func chestProgressRow(_ progress: (stars: Int, next: StarChestTrack.Chest?)) -> some View {
        HStack(spacing: AppTheme.Space.sm) {
            if let chest = progress.next {
                let isReady = progress.stars >= chest.threshold
                FestivalChestArt(state: isReady ? .ready : .locked, width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        GameSectionLabel("STAR CHESTS")
                        Spacer(minLength: AppTheme.Space.xs)
                        Text(verbatim: "\(min(progress.stars, chest.threshold))/\(chest.threshold)")
                            .font(.system(.caption, design: .rounded, weight: .heavy).monospacedDigit())
                    }
                    ProgressView(value: Double(min(progress.stars, chest.threshold)),
                                 total: Double(chest.threshold))
                        .tint(AppTheme.festivalRed)
                        .accessibilityHidden(true)
                    if isReady {
                        Text("A star chest is ready on the map!")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.festivalRed)
                    }
                }
            } else {
                Label("All star chests opened!", systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameInset(padding: AppTheme.Space.sm, radius: AppTheme.Radius.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("STAR CHESTS"))
        .accessibilityValue(chestAccessibilityValue(progress))
        .accessibilityIdentifier("victory-chest-progress")
    }

    private func chestAccessibilityValue(_ progress: (stars: Int, next: StarChestTrack.Chest?)) -> Text {
        guard let chest = progress.next else { return Text("All star chests opened!") }
        let count = Text("\(min(progress.stars, chest.threshold))/\(chest.threshold) stars")
        return count + Text(verbatim: ". ") + (progress.stars >= chest.threshold
            ? Text("A star chest is ready on the map!")
            : Text("Stars to next chest: \(chest.threshold - progress.stars)"))
    }

    /// Asks for a rating only at a high point, after the stars have landed.
    private func maybeAskForReview(token: UUID) {
        guard let summary = gameModel.victorySummary, !ReviewPromptStore.isRunningTests,
              ReviewPromptPolicy.shouldAsk(
                summary: summary,
                lifetimeWins: gameModel.lifetimeLevelWins,
                lastPromptDate: ReviewPromptStore.lastPromptDate,
                lastPromptVersion: ReviewPromptStore.lastPromptVersion,
                currentVersion: ReviewPromptStore.currentVersion
              ) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            // Still on this victory screen, and no ad is covering it.
            guard revealID == token, gameModel.gameState == .win else { return }
            ReviewPromptStore.recordPrompt()
            requestReview()
        }
    }

    private func revealNextStar(token: UUID) {
        guard revealID == token else { return }
        if revealedStars < 3 {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65), completionCriteria: .logicallyComplete) {
                revealedStars += 1
            } completion: {
                guard revealID == token else { return }
                if revealedStars <= (gameModel.victorySummary?.stars ?? 0) { HapticManager.tileSelected() }
                revealNextStar(token: token)
            }
        } else {
            withAnimation(.easeOut(duration: 0.22), completionCriteria: .logicallyComplete) {
                rewardVisible = true
            } completion: {
                guard revealID == token else { return }
                onRevealComplete()
                maybeAskForReview(token: token)
            }
        }
    }
}
