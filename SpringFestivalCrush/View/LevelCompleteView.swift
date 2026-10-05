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

    private var hasNextLevel: Bool {
        gameModel.currentLevel >= 1 && gameModel.currentLevel < gameModel.zodiac.numLevels && gameModel.lives > 0
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
                GamePopupPanel(title: "LEVEL COMPLETE!", tone: .gold) {
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(AppTheme.festivalRed)
                            .frame(width: 76, height: 76)
                            .background(AppTheme.festivalGold.gradient, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 3))
                            .accessibilityHidden(true)

                        HStack(spacing: 7) {
                            ForEach(0..<3) { index in
                                StarView(earned: index < (gameModel.victorySummary?.stars ?? 0))
                                    .opacity(index < revealedStars ? 1 : 0.2)
                                    .scaleEffect(reduceMotion || index < revealedStars ? 1 : 0.78)
                                    .rotationEffect(.degrees(reduceMotion || index < revealedStars ? 0 : -12))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(gameModel.victorySummary?.stars ?? 0) of 3 stars earned")

                        VStack(spacing: 4) {
                            Text("FESTIVAL SCORE").font(.caption.bold())
                            Text("\(gameModel.victorySummary?.score ?? gameModel.score)")
                                .font(.largeTitle.bold().monospacedDigit())
                                .foregroundStyle(AppTheme.festivalRed)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))

                        VictoryRewardView(
                            coins: gameModel.victorySummary?.coins ?? 0,
                            balance: gameModel.coins,
                            revealed: rewardVisible
                        )

                        if let next = gameModel.victorySummary?.newlyUnlockedLevel {
                            Label("Level \(next) unlocked!", systemImage: "lock.open.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.festivalRed)
                        }

                        if let progress = chestProgress {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("STAR CHESTS", systemImage: "star.fill")
                                    .font(.caption.bold())
                                if let chest = progress.next {
                                    ProgressView(value: Double(min(progress.stars, chest.threshold)),
                                                 total: Double(chest.threshold))
                                        .tint(AppTheme.festivalRed)
                                        .accessibilityHidden(true)
                                    Text("\(min(progress.stars, chest.threshold))/\(chest.threshold) stars")
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    if progress.stars >= chest.threshold {
                                        Text("A star chest is ready on the map!")
                                            .font(.subheadline)
                                    } else {
                                        Text("Stars to next chest: \(chest.threshold - progress.stars)")
                                            .font(.subheadline)
                                    }
                                } else {
                                    Label("All star chests opened!", systemImage: "checkmark.seal.fill")
                                        .font(.subheadline)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("victory-chest-progress")
                        }

                        Button {
                            HapticManager.buttonTap()
                            gameModel.onTapVictoryMap()
                        } label: {
                            actionLabel("Continue to Map", systemImage: "map.fill")
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                        .accessibilityIdentifier("victory-map")
                        .accessibilityHint("You can continue immediately; rewards are already saved")

                        if hasNextLevel {
                            Button {
                                HapticManager.buttonTap()
                                gameModel.onTapNextLevel()
                            } label: {
                                actionLabel("Play Next", systemImage: "play.fill")
                            }
                            .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                            .accessibilityIdentifier("victory-next")
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
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
        .onDisappear { revealID = UUID() }
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
            Label(title, systemImage: systemImage).frame(maxWidth: .infinity)
        }
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
