import SwiftUI

struct LevelCompleteView: View {
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var revealedStars = 0
    @State private var rewardVisible = false
    @State private var revealID = UUID()

    private var hasNextLevel: Bool {
        gameModel.currentLevel >= 1 && gameModel.currentLevel < gameModel.zodiac.numLevels && gameModel.lives > 0
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

                        Button {
                            HapticManager.buttonTap()
                            gameModel.onTapVictoryMap()
                        } label: {
                            Label("Continue to Map", systemImage: "map.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                        .accessibilityIdentifier("victory-map")
                        .accessibilityHint("You can continue immediately; rewards are already saved")

                        if hasNextLevel {
                            Button {
                                HapticManager.buttonTap()
                                gameModel.onTapNextLevel()
                            } label: {
                                Label("Play Next", systemImage: "play.fill").frame(maxWidth: .infinity)
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
            } else {
                revealNextStar(token: token)
            }
        }
        .onDisappear { revealID = UUID() }
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
                if revealID == token { onRevealComplete() }
            }
        }
    }
}
