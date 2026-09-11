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
    static let maxLives = 10
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

    /// Spends one life when a level attempt is lost (out of moves). Starting or replaying a
    /// level does NOT cost a life — only failing one does. Safe to call unconditionally.
    private func loseLifeOnFailure() {
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
        // Board-wide jelly/ice visual refresh — fired after any batch of clears since either
        // (or both) may have changed anywhere on the board.
        case refreshOverlays
        case onChocolateSpread(Symbol)
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
        case onIngredientsCollected([Symbol])
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

    /// Why the current attempt ended, so the failure screen can name the actual cause
    /// instead of always claiming the player ran out of moves.
    enum LoseReason {
        case outOfMoves
        case outOfTime

        var title: String {
            switch self {
            case .outOfMoves: "OUT OF MOVES"
            case .outOfTime: "TIME'S UP"
            }
        }

        var icon: String {
            switch self {
            case .outOfMoves: "flag.checkered"
            case .outOfTime: "clock.badge.exclamationmark.fill"
            }
        }
    }

    @Published var gameState: GameState = .notStart
    @Published private(set) var loseReason: LoseReason = .outOfMoves

    @Published var shouldPresentGame: Bool = false
    #if DEBUG
    @Published var shouldPresentDebugDemo: Bool = false
    #endif

    @Published var currentLevel: Int = 0
    @Published var movesLeft: Int = 0
    @Published var score: Int = 0
    // Set from level.timeLimit at the start of a timed level; nil for ordinary moves-only levels.
    @Published var secondsLeft: Int?

    // MARK: - Boosters & currency
    @AppStorage("coins") var coins: Int = 100
    @Published var pendingExtraMoves: Int = 0
    @Published private(set) var hammerCharges = UserDefaults.standard.integer(forKey: "hammerCharges") {
        didSet { UserDefaults.standard.set(hammerCharges, forKey: "hammerCharges") }
    }
    @Published private(set) var shuffleCharges = UserDefaults.standard.object(forKey: "shuffleCharges") as? Int ?? 3 {
        didSet { UserDefaults.standard.set(shuffleCharges, forKey: "shuffleCharges") }
    }
    @Published private(set) var isResolvingBoard = false
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
    }

    /// Extra moves and targeting are per-attempt; earned tool inventory carries over.
    func resetBoostersForNewAttempt() {
        pendingExtraMoves = 0
        hammerModeActive = false
        isResolvingBoard = false
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

    func grantRewardedShuffle() { shuffleCharges += 1 }
    func grantRewardedHammer() { hammerCharges += 1 }

    @MainActor
    func setupNewGame() async {
        loseReason = .outOfMoves
        movesLeft = level.maximumMoves + pendingExtraMoves
        pendingExtraMoves = 0
        score = 0
        secondsLeft = level.timeLimit
        invokeCommand?(.setupLayers)
        invokeCommand?(.setupTiles)
        let newSymbols = level.shuffle()
        await invokeCommandAsync?(.setupSymbols(newSymbols))
        await invokeCommandAsync?(.onGameBegin)
        gameState = .inProgress
        maybeShowTutorial()
        invokeCommand?(.refreshOverlays)
    }

    /// Called once per second by the UI while a timed level is in progress.
    @MainActor
    func tickTimer() {
        guard gameState == .inProgress, var remaining = secondsLeft else { return }
        remaining -= 1
        secondsLeft = remaining
        if remaining <= 0 {
            Task { @MainActor in
                await handleGameLose(reason: .outOfTime)
            }
        }
    }

    /// Instantly clears the tapped tile using a purchased hammer charge, at no move cost.
    @MainActor
    func useHammer(atColumn column: Int, row: Int) async {
        guard gameState == .inProgress, !isResolvingBoard,
              hammerModeActive, hammerCharges > 0 else { return }
        guard let chain = level.useHammer(atColumn: column, row: row) else { return }
        isResolvingBoard = true
        defer { isResolvingBoard = false }
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
        guard gameState == .inProgress, !isResolvingBoard, shuffleCharges > 0 else { return }
        // Reserve a charge synchronously so rapid taps cannot launch overlapping shuffles.
        isResolvingBoard = true
        shuffleCharges -= 1
        hammerModeActive = false
        invokeCommand?(.setUserInteraction(false))
        Task { @MainActor in
            defer {
                isResolvingBoard = false
                if gameState == .inProgress { invokeCommand?(.setUserInteraction(true)) }
            }
            let newSymbols = level.shuffle()
            await invokeCommandAsync?(.shuffle(newSymbols))
        }
    }

    private func hasGameWin() -> Bool {
        level.doesReachLevelTarget()
    }

    @MainActor
    private func handleGameWin() async {
        // Guards against double-processing: a timed level's countdown (tickTimer) and the
        // moves-exhausted path (beginNextTurn) both call into handleGameWin/handleGameLose
        // without checking each other, so if one already ended the level while the other's
        // async chain was still in flight (e.g. mid match-cascade animation), it would
        // otherwise run a second time — double-awarding coins or double-deducting a life.
        guard gameState == .inProgress else { return }
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
        if let lockChain = level.resolveBlockers() {
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
    private func handleGameLose(reason: LoseReason = .outOfMoves) async {
        guard gameState == .inProgress else { return }
        loseReason = reason
        gameState = .lose
        loseLifeOnFailure()
        HapticManager.levelLose()
        await invokeCommandAsync?(.onGameOver)
    }

    /// Dismisses whichever full-screen game presentation is currently active — the normal
    /// level flow (shouldPresentGame) or, in DEBUG builds, the special-effects demo
    /// (shouldPresentDebugDemo). Both flags exist because GameView is reused for both.
    @MainActor
    private func exitToMenu() {
        gameState = .notStart
        // Clear temporary extra moves and armed targeting, but retain tool inventory.
        resetBoostersForNewAttempt()
        shouldPresentGame = false
        #if DEBUG
        shouldPresentDebugDemo = false
        #endif
        // Every route out of a level lands here (Exit, out-of-lives, finishing a zodiac), and
        // each one needs the menu track back — a level with its own bgMusic would otherwise
        // keep playing over the level map.
        Task {
            await BackgroundMusicManager.shared.playDefaultBackgroundMusic()
        }
    }

    @MainActor
    func onTapBack() {
        exitToMenu()
    }

    @MainActor
    func handleSwipe(_ swap: Swap) async {
        guard gameState == .inProgress, !isResolvingBoard else { return }
        isResolvingBoard = true
        defer { isResolvingBoard = false }
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
        if let lockChain = level.resolveBlockers() {
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
        invokeCommand?(.refreshOverlays)

        let columns = level.fillHoles()
        await invokeCommandAsync?(.onFallingSymbols(columns))

        let collectedIngredients = level.collectIngredientsAtBottom()
        if !collectedIngredients.isEmpty {
            score += Self.ingredientCollectedScore * collectedIngredients.count
            await invokeCommandAsync?(.onIngredientsCollected(collectedIngredients))
        }

        let topUpColumns = level.topUpSymbols()

        await invokeCommandAsync?(.onNewSprites(topUpColumns))
    }

    private static let ingredientCollectedScore = 50

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
            if let spread = level.spreadChocolateIfNeeded() {
                invokeCommand?(.onChocolateSpread(spread))
            }
            level.detectPossibleSwaps()
        }
    }

    @MainActor
    func onTapNextLevel() {
        // currentLevel < 1 means this isn't a real, file-backed level (e.g. the DEBUG
        // special-effects demo uses -1) — there's no "next level" to load in that case.
        guard currentLevel >= 1, currentLevel < zodiac.numLevels else {
            exitToMenu()
            return
        }
        guard lives > 0 else {
            // Out of lives — bounce to level select, which shows the lives countdown.
            exitToMenu()
            return
        }
        resetBoostersForNewAttempt()
        Task { @MainActor in
            selectLevel(currentLevel + 1)
            await setupNewGame()
        }
    }

    @MainActor
    func onTapTryAgainLevel() {
        guard currentLevel >= 1, lives > 0 else {
            exitToMenu()
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

    @MainActor
    func debugLaunchElementsDemo() {
        zodiac = Zodiac.all.first(where: { $0.zodiacType == .rat }) ?? Zodiac.all.first!
        guard let demoLevel = Level(filename: "Debug_Elements") else { return }
        level = demoLevel
        currentLevel = -1
        currentLevelRecord = nil
        shouldPresentDebugDemo = true
    }
    #endif
}
