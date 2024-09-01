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
    private var modelContext: ModelContext?

    enum Command {
        case setupLayers
        case setupTiles
        case setUserInteraction(Bool)
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

    @Published var currentLevel: Int = 0
    @Published var movesLeft: Int = 0
    @Published var score: Int = 0

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
            zodiacRecords = newZodiacRecords
        } else {
            let request = FetchDescriptor<ZodiacRecord>()

            do {
                let records = try modelContext.fetch(request)
                zodiacRecords = records
            } catch {
                print("Failed to fetch ZodiacRecords: \(error)")
            }
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

    @MainActor
    func setupNewGame() async {
        movesLeft = level.maximumMoves
        score = 0
        invokeCommand?(.setupLayers)
        invokeCommand?(.setupTiles)
        let newSymbols = level.shuffle()
        await invokeCommandAsync?(.setupSymbols(newSymbols))
        await invokeCommandAsync?(.onGameBegin)
        gameState = .inProgress
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
        gameState = .win
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
        if level.isPossibleSwap(swap) {
            decreaseMove()
            level.performSwap(swap)
            await invokeCommandAsync?(.onValidSwap(swap))
            invokeCommand?(.setUserInteraction(false))
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
                allChains = allChains.union(explodeChains)
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
}
