//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftData
import SwiftUI

class GameModel: ObservableObject {
    @Published var zodiacRecords: [ZodiacRecord] = []
    @AppStorage("firstLaunch") var firstLaunch = true
    private var modelContext: ModelContext?

    enum Command {
        case setupLayerPosition
        case setupTiles
        case setupSymbols(Set<Symbol>)
        case shuffle(Set<Symbol>)
    }

    enum CommandAsync {
        case onValidSwap(Swap)
        case onInvalidSwap(Swap)
        case onMatchedSymbols(Set<Chain>)
        case onFallingSymbols([[Symbol]])
        case onNewSprites([[Symbol]])
        case onGameBegin
        case onGameOver
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

    func initializeRecords(modelContext: ModelContext) {
        self.modelContext = modelContext
        if firstLaunch {
            for zodiac in Zodiac.all {
                let zodiacRecord = ZodiacRecord(
                    zodiacType: zodiac.chineseZodiac,
                    isUnlocked: zodiac.chineseZodiac == .rat
                )

                modelContext.insert(zodiacRecord)

                for i in 1 ... zodiac.numLevels {
                    let levelRecord = LevelRecord(
                        number: i,
                        isUnlocked: i == 1,
                        zodiacRecord: zodiacRecord
                    )
                    modelContext.insert(levelRecord)
                    zodiacRecord.levelRecords.append(levelRecord)
                }
                zodiacRecords.append(zodiacRecord)
            }
            firstLaunch = false
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
        zodiac = Zodiac.all.first { $0.chineseZodiac == zodiacRecord.zodiacType }
        currentZodiacRecord = zodiacRecord
        currentLevelRecords = zodiacRecord.levelRecords.sorted { $0.number < $1.number }
    }

    func createLevelTargetDatas() -> [LevelTargetData] {
        level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac)
    }

    private func calculateTileSize(screenSize: CGSize) -> CGSize {
        var size: CGFloat
        if Constants.isIPhone {
            if UIScreen.main.bounds.width <= 330 {
                size = 32.0
            } else {
                size = 40.0
            }
        } else {
            size = 60.0
        }

        let playgroundWidth = screenSize.width - 20 * 2
        let playgroundHeight = screenSize.height - 60 - 60
        let minSymbolWidth = playgroundWidth / CGFloat(numColumns)
        let minSymbolHeight = playgroundHeight / CGFloat(numRows)
        let minSymbolSize = min(minSymbolWidth, minSymbolHeight)

        let minSize = min(size, minSymbolSize)

        return CGSize(width: minSize, height: minSize)
    }

    func selectLevel(_ selectedLevel: Int) {
        gameState = .loading
        currentLevel = selectedLevel
        level = Level(filename: "Level_\(selectedLevel)")
        level.resetComboMultiplier()
        currentLevelRecord = currentZodiacRecord?.levelRecords.first { $0.number == selectedLevel }
    }

    @MainActor
    func setupNewGame() async {
        movesLeft = level.maximumMoves
        score = 0
        invokeCommand?(.setupLayerPosition)
        invokeCommand?(.setupTiles)
        let newSymbols = level.shuffle()
        invokeCommand?(.setupSymbols(newSymbols))
        await invokeCommandAsync?(.onGameBegin)
        gameState = .inProgress
    }

    func shuffle() {
        let newSymbols = level.shuffle()
        invokeCommand?(.shuffle(newSymbols))
    }

    func decreaseMove() {
        movesLeft -= 1
    }

    func onTapShuffle() {
        decreaseMove()
        checkGameState()
        if gameState == .inProgress {
            shuffle()
        }
    }

    private func checkGameState() {
        if level.doesReachLevelTarget() {
            updateRecord()
            gameState = .win
            return
        }

        if movesLeft <= 0 {
            gameState = .lose
            Task { @MainActor in
                await invokeCommandAsync?(.onGameOver)
            }
        }
    }

    func onTapBack() {
        gameState = .notStart
        shouldPresentGame = false
    }

    @MainActor
    func handleSwipe(_ swap: Swap) async {
        if level.isPossibleSwap(swap) {
            level.performSwap(swap)
            let swapSet = level.possibleSwaps
            for swap in swapSet {
                let elementA = swap.symbolA
                let elementB = swap.symbolB
                elementA.sprite?.removeAction(forKey: "hintAction")
                elementA.sprite?.isHidden = false
                elementB.sprite?.removeAction(forKey: "hintAction")
                elementB.sprite?.isHidden = false
            }
            await invokeCommandAsync?(.onValidSwap(swap))
            await handleMatches()
        } else {
            await invokeCommandAsync?(.onInvalidSwap(swap))
        }
    }

    @MainActor
    func handleMatches() async {
        var chains = level.removeMatches()
        if chains.count == 0 {
            beginNextTurn()
            return
        }

        if let lockChain = level.removeLocks() {
            chains.insert(lockChain)
        }

        await invokeCommandAsync?(.onMatchedSymbols(chains))

        updateScores(from: chains)
        updateLevelTarget(from: chains)

        let columns = level.fillHoles()
        await invokeCommandAsync?(.onFallingSymbols(columns))
        let topUpColumns = level.topUpSymbols()

        await invokeCommandAsync?(.onNewSprites(topUpColumns))

        await handleMatches()
    }

    func updateScores(from chains: Set<Chain>) {
        for chain in chains {
            score += chain.score
        }
    }

    func updateLevelTarget(from chains: Set<Chain>) {
        level.levelGoal.levelTarget.updates(from: chains)
    }

    func beginNextTurn() {
        level.detectPossibleSwaps()
        decreaseMove()
        checkGameState()
    }

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
        selectLevel(currentLevel)
        Task { @MainActor in
            await setupNewGame()
        }
    }

    func updateRecord() {
        currentLevelRecord?.isComplete = true
        let firstLevel = score >= level.levelGoal.firstStarScore ? 1 : 0
        let secondLevel = score >= level.levelGoal.secondStarScore ? 1 : 0
        let thirdLevel = score >= level.levelGoal.thirdStarScore ? 1 : 0
        let currentStars = firstLevel + secondLevel + thirdLevel
        let previousStars = currentLevelRecord?.stars ?? 0
        currentLevelRecord?.stars = max(currentStars, previousStars)

        if currentLevel < zodiac.numLevels {
            let nextLevelRecord = currentZodiacRecord?.levelRecords.first {
                $0.number == currentLevel + 1
            }
            nextLevelRecord?.isUnlocked = true
        }
        unlockNextZodiacIfNeeded()
        do {
            try modelContext?.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    func unlockNextZodiacIfNeeded() {
        guard let currentZodiacRecord else { return }
        guard let currentZodiacIndex = Zodiac.all.firstIndex(where: { $0.chineseZodiac == currentZodiacRecord.zodiacType }),
              currentZodiacIndex + 1 < Zodiac.all.count else {
            return
        }

        guard let nextZodiac = zodiacRecords.first(where: {
            $0.zodiacType == Zodiac.all[currentZodiacIndex + 1].chineseZodiac
        }) else { return }

        if currentZodiacRecord.levelRecords.allSatisfy({ $0.isComplete }) {
            nextZodiac.isUnlocked = true
        }
    }
}
