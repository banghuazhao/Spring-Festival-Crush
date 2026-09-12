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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    let screenSize: CGSize

    @State private var gameScene: GameScene?
    @StateObject private var feedback = GameFeedback()
    @State private var showingPause = false
    @State private var isExiting = false
    @State private var refillTool: GameTool?
    @State private var needsResumeAfterInterruption = false
    #if !targetEnvironment(macCatalyst)
    @ObservedObject private var rewardAds = ToolRewardAdManager.shared
    #endif

    private var isWatchingRewardAd: Bool {
        #if !targetEnvironment(macCatalyst)
        rewardAds.isPresenting
        #else
        false
        #endif
    }

    private var isGameplayPaused: Bool {
        showingPause || isExiting || refillTool != nil || scenePhase != .active || needsResumeAfterInterruption || isWatchingRewardAd
    }

    private let timerTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isShowingResult: Bool {
        gameModel.gameState == .lose || gameModel.gameState == .win
    }

    // Only one hint is ever shown — hammer mode (an active state needing the player's
    // attention) takes priority over the one-time tutorial hint.
    private var activeBanner: HUDBanner? {
        if gameModel.gameState == .finishing {
            return HUDBanner(id: "finishing", text: "Level cleared! Counting your bonus…", icon: "star.fill", tint: .orange)
        }
        if let notice = gameModel.toolNotice {
            return HUDBanner(id: notice, text: notice, icon: "shuffle", tint: .black)
        }
        if gameModel.hammerModeActive {
            return HUDBanner(id: "hammer", text: "Tap a tile to clear it", icon: "hammer.fill", tint: .orange)
        }
        if gameModel.isTutorialHintActive {
            return HUDBanner(id: "tutorial", text: "Swipe two tiles to match 3 or more!", icon: nil, tint: .black)
        }
        return nil
    }

    private var boosters: [BoosterItem] {
        return [
            BoosterItem(
                id: "shuffle", icon: "shuffle", imageName: "ShuffleBoosterIcon",
                title: "Shuffle", count: gameModel.shuffleCharges, isActive: false,
                activeGradient: AppTheme.accentGradient, idleGradient: AppTheme.accentGradient,
                action: {
                    if gameModel.shuffleCharges > 0 { gameModel.onTapShuffle() }
                    else { refillTool = .shuffle }
                },
                onRefill: { refillTool = .shuffle }
            ),
            BoosterItem(
                id: "hammer",
                icon: "hammer.fill",
                imageName: "HammerBoosterIcon",
                title: "Festival Hammer",
                count: gameModel.hammerCharges,
                isActive: gameModel.hammerModeActive,
                activeGradient: AppTheme.dangerGradient,
                idleGradient: AppTheme.accentGradient,
                action: {
                    if gameModel.hammerCharges > 0 { gameModel.hammerModeActive.toggle() }
                    else { refillTool = .hammer }
                },
                onRefill: { refillTool = .hammer }
            )
        ]
    }

    var body: some View {
        ZStack {
            if let gameScene {
                SpriteView(scene: gameScene, isPaused: isGameplayPaused)
                    .allowsHitTesting(!isGameplayPaused)
                    .accessibilityHidden(showingPause)
                    .ignoresSafeArea(.all)
                    .blur(radius: isShowingResult ? 2 : 0)
                    .scaleEffect(isShowingResult && !reduceMotion ? 0.99 : 1)
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
            .allowsHitTesting(!isShowingResult && !isGameplayPaused)
            .accessibilityHidden(isShowingResult || showingPause || refillTool != nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: gameModel.hammerCharges)

            GoalCollectionOverlay(feedback: feedback)
                .ignoresSafeArea()

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
                        .transition(reduceMotion ? .opacity : .offset(y: 18).combined(with: .opacity))
                } else if gameModel.gameState == .win {
                    if !reduceMotion {
                        CelebrationBurstView()
                            .allowsHitTesting(false)
                    }
                    LevelCompleteView()
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
                }
            }

            if showingPause {
                PauseMenuView(
                    onResume: {
                        needsResumeAfterInterruption = false
                        showingPause = false
                    },
                    onRestart: {
                        needsResumeAfterInterruption = false
                        showingPause = false
                        feedback.clear()
                        Task { @MainActor in await gameModel.onTapRestartLevel() }
                    },
                    onExit: {
                        isExiting = true
                        showingPause = false
                        gameModel.onTapBack()
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showingPause)
        .animation(.easeInOut(duration: 0.25), value: activeBanner)
        .animation(reduceMotion ? .easeOut(duration: 0.18)
                   : (gameModel.gameState == .lose ? .easeOut(duration: 0.24)
                      : .spring(response: 0.36, dampingFraction: 0.8)), value: gameModel.gameState)
        .onPreferenceChange(GoalFramePreference.self) { frames in
            feedback.goalFrames = frames
        }
        .onPreferenceChange(GoalViewportPreference.self) { frame in
            feedback.viewport = frame
        }
        .onChange(of: isGameplayPaused) { _, paused in
            if paused { feedback.clear() }
            gameScene?.setFeedbackPaused(paused)
        }
        .onChange(of: gameModel.gameState) { _, state in
            if state == .win { gameScene?.playVictoryAccent() }
            if state != .inProgress {
                feedback.clear()
                gameScene?.cancelIdleHint()
            }
        }
        .onChange(of: reduceMotion) { _, value in
            gameScene?.reduceMotion = value
            gameScene?.applyMotionPreferences()
            feedback.clear()
            gameScene?.scheduleIdleHint()
        }
        .onChange(of: settingModel.idleHintsEnabled) { _, _ in gameScene?.scheduleIdleHint() }
        .onChange(of: gameModel.hammerModeActive) { _, _ in gameScene?.scheduleIdleHint() }
        .onDisappear {
            feedback.clear()
            gameScene?.cancelIdleHint()
        }
        .sheet(item: $refillTool) { tool in
            ToolRefillView(tool: tool) {
                switch tool {
                case .shuffle: gameModel.grantRewardedShuffle()
                case .hammer: gameModel.grantRewardedHammer()
                }
            }
        }
        .onAppear {
            // Built once per presentation: GameScene's initializer kicks off setupNewGame(),
            // so rebuilding it on a second onAppear (e.g. after Settings closes) would
            // silently restart the level with the score and moves reset.
            guard gameScene == nil else { return }
            gameScene = GameScene(
                size: screenSize,
                gameModel: gameModel,
                themeModel: themeModel,
                settingModel: settingModel,
                feedback: feedback,
                reduceMotion: reduceMotion
            )
        }
        .onReceive(timerTicker) { _ in
            // Pause stays visible beneath Settings, so the entire menu flow suspends time.
            guard !isGameplayPaused else { return }
            gameModel.tickTimer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, !showingPause, refillTool == nil, !isShowingResult, !isWatchingRewardAd {
                needsResumeAfterInterruption = true
            } else if phase == .active, needsResumeAfterInterruption {
                showingPause = true
            }
        }
        .task(id: gameModel.toolNotice) {
            guard gameModel.toolNotice != nil else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            gameModel.toolNotice = nil
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
                    showingPause = true
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
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("game-pause")
            }

            HStack(spacing: 8) {
                if let secondsLeft = gameModel.secondsLeft {
                    HUDTimerPill(secondsLeft: secondsLeft)
                }

                Text("GOALS")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                LevelTargetView(
                    levelTargetDatas: gameModel.createLevelTargetDatas(),
                    pendingAmounts: Dictionary(uniqueKeysWithValues: gameModel.createLevelTargetDatas().map {
                        ($0.id, feedback.pendingAmount(for: $0.id))
                    }),
                    impacts: feedback.impacts,
                    reportsFrames: true
                )
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
        BoosterTrayView(boosters: boosters)
        .disabled(gameModel.gameState != .inProgress || gameModel.isResolvingBoard || isGameplayPaused)
        .padding(10)
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
    var pendingAmounts: [String: Int] = [:]
    var impacts: [String: Int] = [:]
    var reportsFrames = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(levelTargetDatas) { levelTargetData in
                    GoalTargetPill(
                        target: levelTargetData,
                        pendingAmount: pendingAmounts[levelTargetData.id, default: 0],
                        impact: impacts[levelTargetData.id, default: 0],
                        reportsFrame: reportsFrames
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 34)
        .background {
            if reportsFrames {
                GeometryReader { geometry in
                    Color.clear.preference(key: GoalViewportPreference.self, value: geometry.frame(in: .global))
                }
            }
        }
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
