//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SpriteKit
import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var themeModel: ThemeModel
    @EnvironmentObject var settingModel: SettingModel

    let screenSize: CGSize

    @State private var gameScene: GameScene?
    @State var showingSettings: Bool = false
    // Measured from the actual HUD view (see .measureHeight() below) so the hint banner
    // sits right under it regardless of how many rows the HUD is currently showing.
    @State private var hudHeight: CGFloat = 100

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Only one hint is ever shown — hammer mode (an active state needing the player's
    // attention) takes priority over the one-time tutorial hint.
    private var activeBanner: HUDBanner? {
        if gameModel.hammerModeActive {
            return HUDBanner(id: "hammer", text: "Tap a tile to clear it", icon: "hammer.fill", tint: .orange)
        }
        if gameModel.isTutorialHintActive {
            return HUDBanner(id: "tutorial", text: "Swipe two tiles to match 3 or more!", icon: nil, tint: .black)
        }
        return nil
    }

    private var boosters: [BoosterItem] {
        guard gameModel.hammerCharges > 0 else { return [] }
        return [
            BoosterItem(
                id: "hammer",
                icon: "hammer.fill",
                count: gameModel.hammerCharges,
                isActive: gameModel.hammerModeActive,
                activeGradient: AppTheme.dangerGradient,
                idleGradient: AppTheme.accentGradient,
                action: { gameModel.hammerModeActive.toggle() }
            )
        ]
    }

    var body: some View {
        ZStack {
            if let gameScene {
                SpriteView(scene: gameScene)
                    .ignoresSafeArea(.all)
            }

            VStack {
                gameStatusView
                    .measureHeight()
                    .onPreferenceChange(HeightPreferenceKey.self) { hudHeight = $0 }
                    .padding()
                Spacer() // This pushes the content to the top
                if !boosters.isEmpty {
                    BoosterTrayView(boosters: boosters)
                        .padding(.bottom, 8)
                }
                HStack {
                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapShuffle()
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.accentGradient))
                    .padding()

                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: gameModel.hammerCharges)

            if let banner = activeBanner {
                HUDBannerView(banner: banner, topOffset: hudHeight + 24)
            }

            ZStack {
                if gameModel.gameState == .lose || gameModel.gameState == .win {
                    Color.black.opacity(0.2).ignoresSafeArea()
                }

                if gameModel.gameState == .lose {
                    LevelFailedView()
                } else if gameModel.gameState == .win {
                    LevelCompleteView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeBanner)
        .onAppear {
            gameScene = GameScene(
                size: screenSize,
                gameModel: gameModel,
                themeModel: themeModel,
                settingModel: settingModel
            )
        }
        .onReceive(timerTicker) { _ in
            gameModel.tickTimer()
        }
    }

    var gameStatusView: some View {
        HStack(alignment: .top, spacing: 10) {
            // Level Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("LEVEL")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    Text("\(gameModel.currentLevel)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(gameModel.movesLeft <= 5 ? .red : .yellow)
                    Text("\(gameModel.movesLeft)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(gameModel.movesLeft <= 5 ? .red : .yellow)
                        .contentTransition(.numericText())
                        .animation(.default, value: gameModel.movesLeft)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.2)))

                if let secondsLeft = gameModel.secondsLeft {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text(String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(secondsLeft <= 10 ? .red : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.2)))
                }
            }
            .frame(minWidth: 80)

            Divider()
                .background(Color.white)

            // Score + Target Info
            VStack(alignment: .leading, spacing: 6) {
                Text("\(gameModel.score)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.default, value: gameModel.score)

                GeometryReader { geo in
                    StarProgressView(
                        currentScore: gameModel.score,
                        levelGoal: gameModel.level.levelGoal,
                        width: geo.size.width
                    )
                }
                .frame(height: 20)

                LevelTargetView(levelTargetDatas: gameModel.createLevelTargetDatas())
            }
            .frame(minWidth: 160)

            Divider()
                .background(Color.white)

            Button {
                HapticManager.buttonTap()
                showingSettings.toggle() // Show settings when tapped
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.gameIcon)
            .padding(.leading, 10) // Add some spacing from the progress bar
            .sheet(isPresented: $showingSettings) {
                SettingsView() // Display the settings view when tapped
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: 600)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius, style: .continuous)
                .fill(AppTheme.primaryGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.panelCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        )
    }
}

struct StarProgressView: View {
    let currentScore: Int
    let levelGoal: LevelGoal

    let width: CGFloat
    let starPositions: [CGFloat] = [0.33, 0.66, 1.0] // Relative positions of stars on the bar

    var body: some View {
        ZStack(alignment: .leading) {
            // Background Bar
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.25))
                .frame(height: 12)

            // Foreground Bar (Progress)
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.accentGradient)
                .frame(width: min(1.0, CGFloat(currentScore) / CGFloat(levelGoal.thirdStarScore)) * width, height: 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentScore)

            // Star Indicators
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: width * starPositions[0])
                progressStar(earned: currentScore >= levelGoal.firstStarScore)
                Spacer()
                progressStar(earned: currentScore >= levelGoal.secondStarScore)
                Spacer()
                progressStar(earned: currentScore >= levelGoal.thirdStarScore)
            }
        }
        .frame(height: 20)
    }

    private func progressStar(earned: Bool) -> some View {
        Image(systemName: "star.fill")
            .foregroundColor(earned ? .yellow : .white.opacity(0.5))
            .shadow(color: earned ? .yellow.opacity(0.7) : .clear, radius: 4)
            .scaleEffect(earned ? 1.15 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: earned)
    }
}

struct LevelTargetView: View {
    let levelTargetDatas: [LevelTargetData]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(levelTargetDatas) { levelTargetData in
                    HStack(spacing: 2) {
                        levelTargetData.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)

                        if levelTargetData.targetNum > 0 {
                            Text("\(levelTargetData.targetNum)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 2, y: 2)
                        } else {
                            Text("✅")
                                .font(.system(size: 16))
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
