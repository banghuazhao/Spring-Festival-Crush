import SwiftUI

struct SelectLevelView: View {
    @EnvironmentObject private var gameModel: GameModel
    @EnvironmentObject private var settingModel: SettingModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var presentLevelIsLocked = false
    @State private var presentOutOfLives = false
    @State private var selectedLevel: LevelRecord?
    @State private var levelToStart: Int?
    @State private var gameDismissalCount = 0
    @State private var celebration: VictorySummary?
    @State private var revealProgress: CGFloat = 1
    @State private var hasFocusedInitialLevel = false
    @State private var claimedChests = Set<Int>()
    @State private var openedChest: StarChestTrack.Chest?

    /// Progression wins over array order, including a fully completed chapter.
    static func initialFocusLevel(in records: [LevelRecord], unlockAll: Bool) -> Int? {
        records.filter { $0.isUnlocked || unlockAll }.map(\.number).max()
    }

    private var theme: ZodiacChapterTheme {
        ZodiacChapterTheme(zodiac: gameModel.zodiac?.zodiacType ?? .rat)
    }

    private var currentLevel: LevelRecord? {
        gameModel.currentLevelRecords.first { !$0.isComplete && ($0.isUnlocked || settingModel.unlockAllLevels) }
    }

    /// After clearing a chapter, recommend an unlocked level with stars still to earn.
    private var recommendedLevel: LevelRecord? {
        currentLevel
            ?? gameModel.currentLevelRecords.first { $0.stars < 3 && ($0.isUnlocked || settingModel.unlockAllLevels) }
            ?? gameModel.currentLevelRecords.first { $0.isUnlocked || settingModel.unlockAllLevels }
    }

    private var completedCount: Int {
        gameModel.currentLevelRecords.filter(\.isComplete).count
    }

    private var chapterStars: Int {
        gameModel.currentLevelRecords.reduce(0) { $0 + $1.stars }
    }

    private var chestTrack: StarChestTrack {
        StarChestTrack(levelCount: gameModel.currentLevelRecords.count)
    }

    var body: some View {
        ZStack {
            ZodiacChapterScenery(theme: theme).ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if dynamicTypeSize.isAccessibilitySize {
                            LivesHeaderView(tint: theme.accent)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        ZodiacChapterHeader(
                            theme: theme,
                            completed: completedCount,
                            total: gameModel.currentLevelRecords.count,
                            stars: chapterStars
                        )

                        if !gameModel.currentLevelRecords.isEmpty {
                            StarChestTrackView(
                                theme: theme,
                                track: chestTrack,
                                stars: chapterStars,
                                claimed: claimedChests,
                                open: openChest
                            )
                        }

                        if gameModel.currentLevelRecords.isEmpty {
                            ContentUnavailableView("The trail is being built", systemImage: "sparkles", description: Text("New levels are on their way to \(theme.name)."))
                                .foregroundStyle(AppTheme.ink)
                                .padding(.vertical, 40)
                        } else {
                            ZodiacLevelTrail(
                                records: gameModel.currentLevelRecords,
                                currentLevel: currentLevel?.number,
                                unlockAll: settingModel.unlockAllLevels,
                                theme: theme,
                                celebratingLevel: celebration?.mapFocusLevel,
                                newlyUnlockedLevel: celebration?.newlyUnlockedLevel,
                                revealProgress: revealProgress,
                                select: selectLevel
                            )

                            VStack(spacing: 8) {
                                Image(systemName: completedCount == gameModel.currentLevelRecords.count ? "checkmark.seal.fill" : "flag.checkered")
                                    .font(.largeTitle)
                                Text(completedCount == gameModel.currentLevelRecords.count ? "Chapter complete!" : "A little closer to good fortune" as LocalizedStringKey)
                                    .font(.headline)
                                Text(completedCount == gameModel.currentLevelRecords.count ? "Replay your favorite levels and collect every star." : "Clear the trail, one level at a time." as LocalizedStringKey)
                                    .font(.subheadline)
                                if completedCount == gameModel.currentLevelRecords.count {
                                    Button("Back to Zodiac Map", systemImage: "map", action: { dismiss() })
                                        .buttonStyle(.gamePrimary(gradient: theme.gradient))
                                        .padding(.top, 8)
                                }
                            }
                            .foregroundStyle(theme.accent)
                            .multilineTextAlignment(.center)
                            .padding(28)
                        }
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    // Resolve after the trail IDs have been laid out. Do this once per
                    // map visit, not on sheet dismissals or subsequent manual scrolling.
                    DispatchQueue.main.async {
                        guard !hasFocusedInitialLevel,
                              let number = Self.initialFocusLevel(
                                in: gameModel.currentLevelRecords,
                                unlockAll: settingModel.unlockAllLevels
                              ) else { return }
                        hasFocusedInitialLevel = true
                        proxy.scrollTo(number, anchor: .center)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        LivesHeaderView(tint: theme.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .frame(maxWidth: 600)
                            .frame(maxWidth: .infinity)
                            .background(theme.sky.opacity(0.96))
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let recommendedLevel {
                        ZodiacChapterDock(
                            theme: theme,
                            levelNumber: recommendedLevel.number,
                            isComplete: recommendedLevel.isComplete,
                            locate: { locate(recommendedLevel.number, using: proxy) },
                            play: { selectLevel(recommendedLevel) }
                        )
                    }
                }
                .onChange(of: gameDismissalCount) { _, _ in
                    revealReturn(using: proxy)
                }
            }
        }
        .overlay {
            if let openedChest {
                StarChestRewardView(chest: openedChest) {
                    withAnimation(.easeOut(duration: 0.2)) { self.openedChest = nil }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .fullScreenCover(isPresented: $gameModel.shouldPresentGame, onDismiss: {
            gameDismissalCount += 1
        }) {
            GeometryReader { geometry in GameView(screenSize: geometry.size) }
        }
        // Start only after sheet dismissal, avoiding overlapping UIKit presentations.
        .sheet(item: $selectedLevel, onDismiss: startPendingLevel) { record in
            PreLevelBoosterView(levelNumber: record.number) {
                levelToStart = record.number
            }
        }
        .navigationTitle(theme.zodiac.localizedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.sky, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.accent)
        .gameNotice(isPresented: $presentLevelIsLocked, message: "Complete the previous level to unlock this one.", icon: "lock.fill", tint: theme.accent)
        .gameNotice(isPresented: $presentOutOfLives, message: "Out of lives. A new heart is on the way!", icon: "heart.slash.fill", tint: AppTheme.festivalRed)
        .onAppear {
            gameModel.refreshLives()
            claimedChests = StarChestStore.claimed(for: theme.zodiac)
        }
    }

    /// Grants the chest once; the store refuses a second claim for the same chest.
    private func openChest(_ chest: StarChestTrack.Chest) {
        guard chapterStars >= chest.threshold,
              StarChestStore.markClaimed(chest.index, for: theme.zodiac) else { return }
        gameModel.grant(chest.reward)
        claimedChests = StarChestStore.claimed(for: theme.zodiac)
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
            openedChest = chest
        }
    }

    private func selectLevel(_ record: LevelRecord) {
        guard record.isUnlocked || settingModel.unlockAllLevels else {
            HapticManager.locked()
            presentLevelIsLocked = true
            return
        }
        gameModel.refreshLives()
        guard gameModel.lives > 0 else {
            HapticManager.locked()
            presentOutOfLives = true
            return
        }
        HapticManager.buttonTap()
        celebration = nil
        levelToStart = nil
        gameModel.resetBoostersForNewAttempt()
        selectedLevel = record
    }

    private func startPendingLevel() {
        guard let levelNumber = levelToStart else { return }
        levelToStart = nil
        gameModel.selectLevel(levelNumber)
        gameModel.shouldPresentGame = true
    }

    private func locate(_ number: Int, using proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.86)) {
            proxy.scrollTo(number, anchor: .center)
        }
    }

    private func revealReturn(using proxy: ScrollViewProxy) {
        guard let receipt = gameModel.takeTrailCelebration(), receipt.level >= 1 else {
            if let recommendedLevel { locate(recommendedLevel.number, using: proxy) }
            return
        }
        celebration = receipt
        revealProgress = reduceMotion ? 1 : 0
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35), completionCriteria: .logicallyComplete) {
            proxy.scrollTo(receipt.mapFocusLevel, anchor: .center)
        } completion: {
            guard celebration?.id == receipt.id, !gameModel.shouldPresentGame else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) {
                revealProgress = 1
            }
            HapticManager.levelWin()
        }
    }
}
