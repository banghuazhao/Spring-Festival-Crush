//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelCompleteView: View {
    @EnvironmentObject var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var starsVisible = false

    private var hasNextLevel: Bool {
        gameModel.currentLevel >= 1 && gameModel.currentLevel < gameModel.zodiac.numLevels
    }

    private var earnedStars: [Bool] {
        [
            gameModel.score >= gameModel.level.levelGoal.firstStarScore,
            gameModel.score >= gameModel.level.levelGoal.secondStarScore,
            gameModel.score >= gameModel.level.levelGoal.thirdStarScore,
        ]
    }

    var body: some View {
        GamePopupPanel(title: "LEVEL COMPLETE!", tone: .gold) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, AppTheme.festivalGold],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 52
                            )
                        )
                        .frame(width: 82, height: 82)
                        .overlay(Circle().stroke(AppTheme.festivalGoldDark, lineWidth: 4))
                        .shadow(color: AppTheme.festivalGold.opacity(0.7), radius: 16)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(AppTheme.festivalRed)
                }
                .scaleEffect(reduceMotion || starsVisible ? 1 : 0.35)
                .rotationEffect(.degrees(reduceMotion || starsVisible ? 0 : -12))
                .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.58), value: starsVisible)

                HStack(spacing: 7) {
                    ForEach(earnedStars.indices, id: \.self) { index in
                        StarView(earned: earnedStars[index])
                            .scaleEffect(reduceMotion || starsVisible ? 1 : 0.05)
                            .rotationEffect(.degrees(reduceMotion || starsVisible ? 0 : -20))
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.5)
                                    .delay(0.12 + Double(index) * 0.15),
                                value: starsVisible
                            )
                    }
                }

                VStack(spacing: 3) {
                    Text("FESTIVAL SCORE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.62))
                    Text("\(gameModel.score)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.festivalRed)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.creamHighlight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.festivalGold.opacity(0.65), lineWidth: 2)
                        )
                )

                if hasNextLevel && gameModel.lives <= 0 {
                    Label("Out of lives", systemImage: "heart.slash.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.festivalRed)
                }

                Button {
                    HapticManager.buttonTap()
                    gameModel.onTapNextLevel()
                } label: {
                    let canContinue = hasNextLevel && gameModel.lives > 0
                    Label(canContinue ? "Next Level" : "Back to Levels", systemImage: canContinue ? "arrow.right" : "map.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
            }
            .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 24)
        .onAppear { starsVisible = true }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
