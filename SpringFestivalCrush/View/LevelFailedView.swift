import SwiftUI

struct LevelFailedView: View {
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @State private var settled = false
    @State private var revealID = UUID()
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

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

                        Text("So close! Every attempt reveals a better path.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink.opacity(0.75))
                            .multilineTextAlignment(.center)

                        Grid(horizontalSpacing: 28, verticalSpacing: 5) {
                            GridRow {
                                Text("LEVEL")
                                Text("SCORE")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.ink.opacity(0.7))
                            GridRow {
                                Text(gameModel.currentLevel >= 1 ? "\(gameModel.currentLevel)" : "DEMO")
                                Text("\(gameModel.score)")
                            }
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(AppTheme.festivalRed)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))

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
