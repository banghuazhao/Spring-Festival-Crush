//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

class GameModel: ObservableObject {
    enum Command {
        case setupTiles
        case setupSymbols(Set<Symbol>)
        case shuffle(Set<Symbol>)
    }

    enum CommandAsync {
        case onValidSwap(Swap)
        case onInvalidSwap(Swap)
        case onMatchedSprites(Set<Chain>)
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

    var levelLabel: String {
        "Level\n \(currentLevel)/\(zodiac.numLevels)"
    }

    var scoreLabel: String {
        "Score\n \(score)/\(level.targetScore)"
    }

    var moveLabel: String {
        "Moves Left\n \(movesLeft)"
    }

    var tileSize: CGSize {
        calculateTileSize(screenSize: screenSize)
    }

    func selectZodiac(_ chineseZodiac: ChineseZodiac) {
        zodiac = Zodiac(numLevels: 20, chineseZodiac: chineseZodiac)
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
    }

    @MainActor
    func setupNewGame() async {
        movesLeft = level.maximumMoves
        score = 0
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
        if score >= level.targetScore {
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

        await invokeCommandAsync?(.onMatchedSprites(chains))

        for chain in chains {
            score += chain.score
        }

        let columns = level.fillHoles()
        await invokeCommandAsync?(.onFallingSymbols(columns))
        let topUpColumns = level.topUpSymbols()

        await invokeCommandAsync?(.onNewSprites(topUpColumns))

        await handleMatches()
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
        gameState = .loading
        Task { @MainActor in
            await setupNewGame()
        }
    }
}
