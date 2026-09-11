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

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isShowingResult: Bool {
        gameModel.gameState == .lose || gameModel.gameState == .win
    }

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
                imageName: "HammerBoosterIcon",
                title: "Festival Hammer",
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
                    .blur(radius: isShowingResult ? 2 : 0)
                    .scaleEffect(isShowingResult ? 0.99 : 1)
                    .animation(.easeOut(duration: 0.3), value: isShowingResult)
            }

            VStack(spacing: 0) {
                gameStatusView
                    .padding()

                if let banner = activeBanner {
                    HUDBannerView(banner: banner)
                }

                Spacer(minLength: 0)
                bottomDock
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: gameModel.hammerCharges)

            ZStack {
                if isShowingResult {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay(Color.black.opacity(0.48))
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if gameModel.gameState == .lose {
                    LevelFailedView()
                        .transition(.scale(scale: 0.65).combined(with: .opacity))
                } else if gameModel.gameState == .win {
                    CelebrationBurstView()
                        .allowsHitTesting(false)
                    LevelCompleteView()
                        .transition(.scale(scale: 0.65).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: activeBanner)
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: gameModel.gameState)
        .onAppear {
            // Built once per presentation: GameScene's initializer kicks off setupNewGame(),
            // so rebuilding it on a second onAppear (e.g. after the pause sheet closes) would
            // silently restart the level with the score and moves reset.
            guard gameScene == nil else { return }
            gameScene = GameScene(
                size: screenSize,
                gameModel: gameModel,
                themeModel: themeModel,
                settingModel: settingModel
            )
        }
        .onReceive(timerTicker) { _ in
            // The pause button opens the settings sheet — a timed level must not keep
            // counting down behind it.
            guard !showingSettings else { return }
            gameModel.tickTimer()
        }
    }

    var gameStatusView: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                HUDLevelMedallion(level: gameModel.currentLevel)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("\(gameModel.score)")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }

                    StarProgressView(currentScore: gameModel.score, levelGoal: gameModel.level.levelGoal)
                }
                .frame(maxWidth: .infinity)

                HUDStatTile(
                    icon: "arrow.triangle.2.circlepath",
                    title: "MOVES",
                    value: "\(gameModel.movesLeft)",
                    isCritical: gameModel.movesLeft <= 5
                )

                Button {
                    HapticManager.buttonTap()
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(AppTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppTheme.creamHighlight))
                        .overlay(Circle().stroke(AppTheme.festivalGold, lineWidth: 3))
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
                }
                .buttonStyle(.gameIcon)
                .accessibilityLabel("Pause and settings")
                .sheet(isPresented: $showingSettings) {
                    // Wrapped in its own stack so the pause sheet actually has a title bar and
                    // a Resume button — presented bare, SettingsView's navigationTitle is
                    // dropped and its first tappable row sits directly under the finger that
                    // opened the sheet.
                    NavigationStack {
                        SettingsView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Resume") { showingSettings = false }
                                        .fontWeight(.semibold)
                                }
                            }
                    }
                }
            }

            HStack(spacing: 8) {
                if let secondsLeft = gameModel.secondsLeft {
                    HUDTimerPill(secondsLeft: secondsLeft)
                }

                Text("GOALS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                LevelTargetView(levelTargetDatas: gameModel.createLevelTargetDatas())
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var bottomDock: some View {
        VStack(spacing: 6) {
            if !boosters.isEmpty {
                BoosterTrayView(boosters: boosters)
            }

            HStack(spacing: 12) {
                Button {
                    HapticManager.buttonTap()
                    gameModel.onTapShuffle()
                } label: {
                    Label {
                        Text("Shuffle · −1")
                    } icon: {
                        Image("ShuffleBoosterIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.accentGradient))

                Button {
                    HapticManager.buttonTap()
                    gameModel.onTapBack()
                } label: {
                    Label("Exit", systemImage: "xmark")
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

private struct HUDLevelMedallion: View {
    let level: Int

    var body: some View {
        VStack(spacing: -2) {
            // Levels below 1 aren't file-backed levels (the DEBUG demos use -1), so the
            // medallion names them instead of rendering a nonsense "LEVEL -1".
            Text(level >= 1 ? "LEVEL" : "SPRING")
                .font(.system(size: 8, weight: .black, design: .rounded))
            Text(level >= 1 ? "\(level)" : "DEMO")
                .font(.system(size: level >= 1 ? 22 : 13, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(AppTheme.ink)
        .frame(width: 54, height: 54)
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 8, weight: .black, design: .rounded))
            .opacity(0.78)

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .contentTransition(.numericText())
        }
        .foregroundStyle(isCritical ? Color.white : AppTheme.ink)
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

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
            Text(String(format: "%02d:%02d", max(0, secondsLeft) / 60, max(0, secondsLeft) % 60))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(size: 14, weight: .black, design: .rounded))
        .foregroundStyle(secondsLeft <= 10 ? Color.white : AppTheme.ink)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Capsule().fill(secondsLeft <= 10 ? Color.red : AppTheme.creamHighlight))
        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
    }
}

struct StarProgressView: View {
    let currentScore: Int
    let levelGoal: LevelGoal

    private static let starSize: CGFloat = 15

    /// Each star sits at its own score threshold, so a star lights up exactly when the fill
    /// reaches it. Hardcoded thirds used to place them wherever, and levels don't use even
    /// thirds (the first star is typically ~40% of the third-star score), so stars lit up
    /// well after the bar had passed them and the last star never sat at the bar's end.
    private var thresholds: [Int] {
        [levelGoal.firstStarScore, levelGoal.secondStarScore, levelGoal.thirdStarScore]
    }

    private func fraction(for score: Int) -> CGFloat {
        let goal = max(1, levelGoal.thirdStarScore)
        return min(1, max(0, CGFloat(score) / CGFloat(goal)))
    }

    var body: some View {
        // GeometryReader is kept fully self-contained here, bounded by the .frame(height:)
        // below at the same level — a GeometryReader used further up the tree (e.g. by the
        // caller, to compute this view's width) reports an unbounded ideal size to its own
        // ancestors during layout, which previously caused the whole HUD card to expand to
        // fill the screen once its ancestor lost its fixed height.
        GeometryReader { geo in
            // Stars are centred on their threshold, so the track is inset by half a star at
            // each end to keep the outermost ones inside the HUD card.
            let inset = Self.starSize / 2
            let width = max(0, geo.size.width - Self.starSize)
            ZStack(alignment: .leading) {
                // Background Bar
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.25))
                    .frame(height: 12)

                // Foreground Bar (Progress)
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.accentGradient)
                    .frame(width: inset + fraction(for: currentScore) * width, height: 12)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentScore)

                // Star Indicators, each anchored to the score that earns it
                ForEach(thresholds.indices, id: \.self) { index in
                    progressStar(earned: currentScore >= thresholds[index])
                        .position(
                            x: inset + fraction(for: thresholds[index]) * width,
                            y: geo.size.height / 2
                        )
                }
            }
        }
        .frame(height: 20)
    }

    private func progressStar(earned: Bool) -> some View {
        Image(systemName: "star.fill")
            .font(.system(size: Self.starSize))
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
