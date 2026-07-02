//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftData
import SwiftUI

@MainActor
class GameModel: ObservableObject {
    @Published var zodiacRecords: [ZodiacRecord] = []
    @AppStorage("firstLaunch") var firstLaunch = true
    @AppStorage("hasSeenTutorial") var hasSeenTutorial = false
    @Published var isTutorialHintActive: Bool = false
    private var modelContext: ModelContext?

    // MARK: - Lives / energy
    static let maxLives = 5
    static let lifeRegenInterval: TimeInterval = 30 * 60 // 30 minutes per life
    @AppStorage("lives") var lives: Int = GameModel.maxLives
    @AppStorage("lastLifeLostTimestamp") private var lastLifeLostTimestamp: Double = 0
    @Published var livesRefreshTick: Int = 0 // bumped every second while a lives countdown is on screen

    /// Recomputes how many lives should have regenerated since lives last dropped below max.
    /// Call on app foreground and whenever the level-select screen appears.
    func refreshLives() {
        guard lives < Self.maxLives, lastLifeLostTimestamp > 0 else { return }
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastLifeLostTimestamp
        let regenerated = Int(elapsed / Self.lifeRegenInterval)
        guard regenerated > 0 else { return }
        lives = min(Self.maxLives, lives + regenerated)
        if lives >= Self.maxLives {
            lastLifeLostTimestamp = 0
        } else {
            lastLifeLostTimestamp += Double(regenerated) * Self.lifeRegenInterval
        }
    }

    /// Called once per second while a lives countdown is on screen. `timeUntilNextLife` is a
    /// computed property, so bumping this @Published counter is what makes SwiftUI re-render
    /// the countdown text every second instead of only when `lives` itself changes.
    func tickLivesCountdown() {
        livesRefreshTick += 1
        refreshLives()
    }

    /// Spends one life to start a level attempt. Callers must check `lives > 0` first —
    /// this is a no-op (not a hard block) so it's safe to call unconditionally from selectLevel.
    private func consumeLife() {
        guard lives > 0 else { return }
        lives -= 1
        if lastLifeLostTimestamp == 0 {
            lastLifeLostTimestamp = Date().timeIntervalSince1970
        }
    }

    /// Seconds until the next life regenerates, or 0 if lives are already full.
    var timeUntilNextLife: TimeInterval {
        guard lives < Self.maxLives, lastLifeLostTimestamp > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince1970 - lastLifeLostTimestamp
        let remainder = Self.lifeRegenInterval - elapsed.truncatingRemainder(dividingBy: Self.lifeRegenInterval)
        return max(0, remainder)
    }

    // MARK: - Rewarded video grants
    static let rewardedCoinsAmount = 40

    /// Grants the reward for watching a rewarded video to refill one life.
    func grantRewardedLife() {
        guard lives < Self.maxLives else { return }
        lives += 1
        if lives >= Self.maxLives {
            lastLifeLostTimestamp = 0
        }
    }

    /// Grants the reward for watching a rewarded video for coins.
    func grantRewardedCoins() {
        coins += Self.rewardedCoinsAmount
    }

    enum Command {
        case setupLayers
        case setupTiles
        case setUserInteraction(Bool)
        case showTutorialHint(Swap)
        case hideTutorialHint
    }

    enum CommandAsync {
        case setupSymbols(Set<Symbol>)
        case onValidSwap(Swap)
        case onInvalidSwap(Swap)
        case onMatchedSymbols(Set<Chain>)
        case onCreatingSpecialSymbols([Symbol])
        case onFallingSymbols([[Symbol]])
        case onNewSprites([[Symbol]])
        case onEnhanceSymbols([Symbol])
        case onGameBegin
        case onGameOver
        case shuffle(Set<Symbol>)
    }

    enum GameState {
        case notStart
        case loading
        case inProgress
        case lose
        case win
    }

    @Published var gameState: GameState = .notStart

    @Published var shouldPresentGame: Bool = false
    #if DEBUG
    @Published var shouldPresentDebugDemo: Bool = false
    #endif

    @Published var currentLevel: Int = 0
    @Published var movesLeft: Int = 0
    @Published var score: Int = 0

    // MARK: - Boosters & currency
    @AppStorage("coins") var coins: Int = 100
    @Published var pendingExtraMoves: Int = 0
    @Published var hammerCharges: Int = 0
    @Published var hammerModeActive: Bool = false
    static let extraMovesBoosterCost = 20
    static let extraMovesBoosterAmount = 5
    static let hammerBoosterCost = 30
    private static let levelWinCoinReward = 15

    var level: Level!
    var zodiac: Zodiac!
    var currentZodiacRecord: ZodiacRecord?
    var currentLevelRecords = [LevelRecord]()
    var currentLevelRecord: LevelRecord?
    var screenSize = UIScreen.main.bounds.size

    var invokeCommand: ((Command) -> Void)?
    var invokeCommandAsync: (@MainActor (CommandAsync) async -> Void)?

    var numColumns: Int {
        level.numColumns
    }

    var numRows: Int {
        level.numRows
    }

    var gameBackground: String {
        zodiac.gameBackground
    }

    var tileSize: CGSize {
        calculateTileSize(screenSize: screenSize)
    }

    @MainActor
    func initializeRecords(modelContext: ModelContext) {
        self.modelContext = modelContext
        var newZodiacRecords = [ZodiacRecord]()
        if firstLaunch {
            for zodiac in Zodiac.all {
                let zodiacRecord = ZodiacRecord(
                    zodiacType: zodiac.zodiacType,
                    isUnlocked: zodiac.zodiacType == .rat
                )

                modelContext.insert(zodiacRecord)
                newZodiacRecords.append(zodiacRecord)

                if zodiac.numLevels > 0 {
                    for i in 1 ... zodiac.numLevels {
                        let levelRecord = LevelRecord(
                            number: i,
                            isUnlocked: i == 1,
                            zodiacRecord: zodiacRecord
                        )
                        modelContext.insert(levelRecord)
                        zodiacRecord.levelRecords.append(levelRecord)
                    }
                }
            }
            do {
                try modelContext.save()
            } catch {
                print(error)
            }
            firstLaunch = false
            zodiacRecords = newZodiacRecords
        } else {
            let request = FetchDescriptor<ZodiacRecord>()

            do {
                let records = try modelContext.fetch(request)
                zodiacRecords = records
            } catch {
                print("Failed to fetch ZodiacRecords: \(error)")
            }

            reconcileNewLevels(modelContext: modelContext)
        }
        zodiacRecords.sort { $0.zodiacType.rawValue < $1.zodiacType.rawValue }
    }

    func selectZodiac(_ zodiacRecord: ZodiacRecord) {
        zodiac = Zodiac.all.first { $0.zodiacType == zodiacRecord.zodiacType }
        currentZodiacRecord = zodiacRecord
        currentLevelRecords = zodiacRecord.levelRecords.sorted { $0.number < $1.number }
    }

    func createLevelTargetDatas() -> [LevelTargetData] {
        level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac)
    }

    private func calculateTileSize(screenSize: CGSize) -> CGSize {
        let size: CGFloat = if Constants.isIPhone {
            UIScreen.main.bounds.width <= 330 ? 32.0 : 40.0
        } else {
            60.0
        }

        let playgroundWidth = screenSize.width - 20 * 2
        let playgroundHeight = screenSize.height - 60 - 60
        let minSymbolWidth = playgroundWidth / CGFloat(numColumns)
        let minSymbolHeight = playgroundHeight / CGFloat(numRows)
        let minSymbolSize = min(minSymbolWidth, minSymbolHeight)

        let minSize = min(size, minSymbolSize)

        return CGSize(width: minSize, height: minSize)
    }

    @MainActor
    func selectLevel(_ selectedLevel: Int) {
        gameState = .loading
        currentLevel = selectedLevel
        level = Level(filename: "\(zodiac.zodiacType.name)_Level_\(selectedLevel)")
        currentLevelRecord = currentZodiacRecord?.levelRecords.first { $0.number == selectedLevel }
        consumeLife()
    }

    /// Boosters are purchased per attempt; call before offering the booster sheet for a fresh
    /// level pick, and before any "start a level" flow that bypasses the booster sheet entirely
    /// (Next Level / Try Again), so leftovers from a previous attempt never carry over.
    func resetBoostersForNewAttempt() {
        pendingExtraMoves = 0
        hammerCharges = 0
        hammerModeActive = false
    }

    /// Applies a purchased "+moves" booster to the level about to start. Call before `selectLevel`.
    func applyExtraMovesBooster() {
        guard coins >= Self.extraMovesBoosterCost else { return }
        coins -= Self.extraMovesBoosterCost
        pendingExtraMoves += Self.extraMovesBoosterAmount
    }

    /// Applies a purchased hammer charge to the level about to start. Call before `selectLevel`.
    func applyHammerBooster() {
        guard coins >= Self.hammerBoosterCost else { return }
        coins -= Self.hammerBoosterCost
        hammerCharges += 1
    }

    @MainActor
    func setupNewGame() async {
        movesLeft = level.maximumMoves + pendingExtraMoves
        pendingExtraMoves = 0
        score = 0
        invokeCommand?(.setupLayers)
        invokeCommand?(.setupTiles)
        let newSymbols = level.shuffle()
        await invokeCommandAsync?(.setupSymbols(newSymbols))
        await invokeCommandAsync?(.onGameBegin)
        gameState = .inProgress
        maybeShowTutorial()
    }

    /// Instantly clears the tapped tile using a purchased hammer charge, at no move cost.
    @MainActor
    func useHammer(atColumn column: Int, row: Int) async {
        guard hammerModeActive, hammerCharges > 0 else { return }
        guard let chain = level.useHammer(atColumn: column, row: row) else { return }
        hammerCharges -= 1
        hammerModeActive = false
        HapticManager.bigMatch()
        invokeCommand?(.setUserInteraction(false))
        await handleMatches(for: [chain])
        await handleRemoveAndMatches()
        invokeCommand?(.setUserInteraction(true))
    }

    // Shows a one-time swipe hint on the very first level a new player ever opens.
    private func maybeShowTutorial() {
        guard !hasSeenTutorial, currentLevel == 1, zodiac.zodiacType == .rat else { return }
        guard let hintSwap = level.possibleSwaps.first else { return }
        hasSeenTutorial = true
        isTutorialHintActive = true
        invokeCommand?(.showTutorialHint(hintSwap))
    }

    func decreaseMove() {
        movesLeft -= 1
    }

    func onTapShuffle() {
        decreaseMove()
        Task { @MainActor in
            if hasGameLose() {
                await handleGameLose()
            } else {
                let newSymbols = level.shuffle()
                await invokeCommandAsync?(.shuffle(newSymbols))
            }
        }
    }

    private func hasGameWin() -> Bool {
        level.doesReachLevelTarget()
    }

    @MainActor
    private func handleGameWin() async {
        invokeCommand?(.setUserInteraction(false))
        await handleRemainingSpecialSymbol()
        await handleExtraStepsBonus()
        updateRecord()
        coins += Self.levelWinCoinReward
        gameState = .win
        HapticManager.levelWin()
        invokeCommand?(.setUserInteraction(true))
    }

    private func handleRemainingSpecialSymbol() async {
        let matchChains = level.removeMatches()
        let specialChains = level.removeSpecialSymbols()
        var chains = specialChains.union(matchChains)
        if let lockChain = level.removeLocks() {
            chains.insert(lockChain)
        }
        if chains.count == 0 {
            return
        }

        await handleMatches(for: chains)

        await handleRemainingSpecialSymbol()
    }

    private func handleExtraStepsBonus() async {
        let enhancedSymbols = level.enhanceSymbols(num: movesLeft)
        await invokeCommandAsync?(.onEnhanceSymbols(enhancedSymbols))
        await handleRemainingSpecialSymbol()
    }

    private func hasGameLose() -> Bool {
        movesLeft <= 0
    }

    @MainActor
    private func handleGameLose() async {
        gameState = .lose
        HapticManager.levelLose()
        await invokeCommandAsync?(.onGameOver)
    }

    @MainActor
    func onTapBack() {
        gameState = .notStart
        shouldPresentGame = false
        Task {
            await BackgroundMusicManager.shared.playDefaultBackgroundMusic()
        }
    }

    @MainActor
    func handleSwipe(_ swap: Swap) async {
        if isTutorialHintActive {
            isTutorialHintActive = false
            invokeCommand?(.hideTutorialHint)
        }
        if level.isPossibleSwap(swap) {
            decreaseMove()
            level.performSwap(swap)
            await invokeCommandAsync?(.onValidSwap(swap))
            invokeCommand?(.setUserInteraction(false))
            if let powerUpChains = level.tryActivateSpecialSwap(swap) {
                await handleMatches(for: powerUpChains)
            }
            await handleRemoveAndMatches()
            invokeCommand?(.setUserInteraction(true))
        } else {
            await invokeCommandAsync?(.onInvalidSwap(swap))
        }
    }

    @MainActor
    func handleRemoveAndMatches() async {
        var chains = level.removeMatches()
        if let lockChain = level.removeLocks() {
            chains.insert(lockChain)
        }
        if chains.count == 0 {
            await beginNextTurn()
            return
        }

        await handleMatches(for: chains)

        await handleRemoveAndMatches()
    }

    private func handleMatches(for chains: Set<Chain>) async {
        var allChains = chains
        async let onMatchedSymbols: Void? = invokeCommandAsync?(.onMatchedSymbols(chains))

        let explodeChains = level.explodeSpecialSymbols(for: chains)
        allChains = allChains.union(explodeChains)
        async let onSpecialSymbolExplode: Void? = invokeCommandAsync?(.onMatchedSymbols(explodeChains))

        await _ = [onMatchedSymbols, onSpecialSymbolExplode]

        var nextExplodeChains = explodeChains
        while true {
            if nextExplodeChains.contains(where: { $0.chainType == .enhanced }) {
                nextExplodeChains = level.explodeSpecialSymbols(for: nextExplodeChains)
                allChains = allChains.union(nextExplodeChains)
                await invokeCommandAsync?(.onMatchedSymbols(nextExplodeChains))
            } else {
                break
            }
        }

        let specialSymbols = level.createSpecialSymbols(for: chains)
        await invokeCommandAsync?(.onCreatingSpecialSymbols(specialSymbols))

        updateScores(from: allChains)
        level.updateLevelTarget(by: allChains)

        let columns = level.fillHoles()
        await invokeCommandAsync?(.onFallingSymbols(columns))
        let topUpColumns = level.topUpSymbols()

        await invokeCommandAsync?(.onNewSprites(topUpColumns))
    }

    func updateScores(from chains: Set<Chain>) {
        for chain in chains {
            score += chain.score
        }
    }

    @MainActor
    func beginNextTurn() async {
        if hasGameWin() {
            await handleGameWin()
        } else if hasGameLose() {
            await handleGameLose()
        } else {
            level.detectPossibleSwaps()
        }
    }

    @MainActor
    func onTapNextLevel() {
        if currentLevel >= zodiac.numLevels {
            gameState = .notStart
        } else if lives > 0 {
            resetBoostersForNewAttempt()
            Task { @MainActor in
                selectLevel(currentLevel + 1)
                await setupNewGame()
            }
        } else {
            // Out of lives — bounce to level select, which shows the lives countdown.
            gameState = .notStart
            shouldPresentGame = false
        }
    }

    func onTapTryAgainLevel() {
        guard lives > 0 else {
            gameState = .notStart
            shouldPresentGame = false
            return
        }
        resetBoostersForNewAttempt()
        Task { @MainActor in
            selectLevel(currentLevel)
            await setupNewGame()
        }
    }

    @MainActor
    func updateRecord() {
        updateCurrentLevel()
        updateNextLevelIfNeeded()
        unlockNextZodiacIfNeeded()
        do {
            try modelContext?.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    private func updateCurrentLevel() {
        currentLevelRecord?.isComplete = true
        let firstLevel = score >= level.levelGoal.firstStarScore ? 1 : 0
        let secondLevel = score >= level.levelGoal.secondStarScore ? 1 : 0
        let thirdLevel = score >= level.levelGoal.thirdStarScore ? 1 : 0
        let currentStars = firstLevel + secondLevel + thirdLevel
        let previousStars = currentLevelRecord?.stars ?? 0
        currentLevelRecord?.stars = max(currentStars, previousStars)
    }

    private func updateNextLevelIfNeeded() {
        guard currentLevel < zodiac.numLevels else { return }
        let nextLevelRecord = currentZodiacRecord?.levelRecords.first {
            $0.number == currentLevel + 1
        }
        nextLevelRecord?.isUnlocked = true
    }

    @MainActor
    private func unlockNextZodiacIfNeeded() {
        guard let currentZodiacRecord else { return }
        guard let currentZodiacIndex = Zodiac.all.firstIndex(where: { $0.zodiacType == currentZodiacRecord.zodiacType }),
              currentZodiacIndex + 1 < Zodiac.all.count else {
            return
        }

        guard let nextZodiac = zodiacRecords.first(where: {
            $0.zodiacType == Zodiac.all[currentZodiacIndex + 1].zodiacType
        }) else { return }

        if currentZodiacRecord.levelRecords.allSatisfy({ $0.isComplete }) {
            nextZodiac.isUnlocked = true
        }
    }

    // Adds missing LevelRecords when new levels are bundled into an existing install.
    private func reconcileNewLevels(modelContext: ModelContext) {
        var didChange = false
        for zodiac in Zodiac.all {
            guard zodiac.numLevels > 0,
                  let zodiacRecord = zodiacRecords.first(where: { $0.zodiacType == zodiac.zodiacType })
            else { continue }

            let existingMax = zodiacRecord.levelRecords.map { $0.number }.max() ?? 0
            guard zodiac.numLevels > existingMax else { continue }

            for i in (existingMax + 1) ... zodiac.numLevels {
                let levelRecord = LevelRecord(
                    number: i,
                    isUnlocked: existingMax == 0 && i == 1,
                    zodiacRecord: zodiacRecord
                )
                modelContext.insert(levelRecord)
                zodiacRecord.levelRecords.append(levelRecord)
                didChange = true
            }
        }
        if didChange {
            try? modelContext.save()
        }
    }

    #if DEBUG
    @MainActor
    func debugUnlockAll() {
        for zodiacRecord in zodiacRecords {
            zodiacRecord.isUnlocked = true
            for levelRecord in zodiacRecord.levelRecords {
                levelRecord.isUnlocked = true
                levelRecord.isComplete = true
                if levelRecord.stars == 0 { levelRecord.stars = 1 }
            }
        }
        try? modelContext?.save()
    }

    @MainActor
    func debugResetAll() {
        for zodiacRecord in zodiacRecords {
            modelContext?.delete(zodiacRecord)
        }
        try? modelContext?.save()
        firstLaunch = true
        zodiacRecords = []
        guard let modelContext else { return }
        initializeRecords(modelContext: modelContext)
    }

    @MainActor
    func debugLaunchSpecialDemo() {
        zodiac = Zodiac.all.first(where: { $0.zodiacType == .rat }) ?? Zodiac.all.first!
        guard let demoLevel = Level(filename: "Debug_Special") else { return }
        level = demoLevel
        currentLevel = -1
        currentLevelRecord = nil
        shouldPresentDebugDemo = true
    }
    #endif
}
