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
        // Boosters are purchased per attempt; clear any leftovers from a previous level.
        pendingExtraMoves = 0
        hammerCharges = 0
        hammerModeActive = false
    }

    /// Applies a purchased "+moves" booster to the level about to start. Call after `selectLevel`.
    func applyExtraMovesBooster() {
        guard coins >= Self.extraMovesBoosterCost else { return }
        coins -= Self.extraMovesBoosterCost
        pendingExtraMoves += Self.extraMovesBoosterAmount
    }

    /// Applies a purchased hammer charge to the level about to start. Call after `selectLevel`.
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
        } else {
            Task { @MainActor in
                selectLevel(currentLevel + 1)
                await setupNewGame()
            }
        }
    }

    func onTapTryAgainLevel() {
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
