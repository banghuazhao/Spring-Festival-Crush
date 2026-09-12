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
                                    .scaleEffect(reduceMotion || index < revealedStars ? 1 : 0.65)
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
            withAnimation(.easeOut(duration: 0.16), completionCriteria: .logicallyComplete) {
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

struct StarView: View {
    let earned: Bool

    var body: some View {
        Image(systemName: "star.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 54, height: 54)
            .foregroundStyle(earned ? AppTheme.festivalGold : Color.gray.opacity(0.28))
            .overlay(
                Image(systemName: "star")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(earned ? Color.white.opacity(0.85) : Color.gray.opacity(0.42))
                    .padding(3)
            )
            .shadow(color: earned ? AppTheme.festivalGold.opacity(0.7) : .clear, radius: 9, y: 4)
            .accessibilityLabel(earned ? "Star earned" : "Star not earned")
    }
}

/// A deterministic celebratory layer: it fires once, returns to rest, and respects Reduce Motion.
struct CelebrationBurstView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var burst = false

    private let particles: [(x: CGFloat, y: CGFloat, rotation: Double, color: Color)] = [
        (0.10, 0.18, -25, .yellow), (0.24, 0.11, 18, .pink), (0.42, 0.17, 36, .orange),
        (0.63, 0.10, -12, .yellow), (0.84, 0.18, 24, .pink), (0.94, 0.32, 48, .orange),
        (0.07, 0.42, 22, .pink), (0.16, 0.67, -32, .yellow), (0.32, 0.82, 18, .orange),
        (0.58, 0.86, -16, .pink), (0.79, 0.76, 38, .yellow), (0.91, 0.58, -42, .orange),
    ]

    var body: some View {
        GeometryReader { geometry in
            ForEach(particles.indices, id: \.self) { index in
                let particle = particles[index]
                Group {
                    if index.isMultiple(of: 3) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 22, weight: .black))
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: 8, height: 20)
                    }
                }
                .foregroundStyle(particle.color)
                .rotationEffect(.degrees(burst ? particle.rotation + 160 : particle.rotation))
                .scaleEffect(burst ? 1 : 0.1)
                .opacity(burst ? 0.88 : 0)
                .position(x: geometry.size.width * particle.x, y: geometry.size.height * particle.y)
                .animation(
                    reduceMotion
                        ? .easeOut(duration: 0.15)
                        : .spring(response: 0.65, dampingFraction: 0.58).delay(Double(index) * 0.025),
                    value: burst
                )
            }
        }
        .ignoresSafeArea()
        .onAppear { burst = true }
        .accessibilityHidden(true)
    }
}
