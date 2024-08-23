//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

class GameModel: ObservableObject {
    enum Command {
        case addTiles
        case shuffle(Set<Cookie>)
    }

    enum CommandAsync {
        case onValidSwap(Swap)
        case onInvalidSwap(Swap)
        case onMatchedSprites(Set<Chain>)
        case onFallingCookies([[Cookie]])
        case onNewSprites([[Cookie]])
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
    @Published var moves: Int = 0
    @Published var score: Int = 0

    var level: Level!
    var zodiac: Zodiac!

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
        "Moves\n \(moves)/\(level.maximumMoves)"
    }

    func selectZodiac(_ chineseZodiac: ChineseZodiac) {
        zodiac = Zodiac(numLevels: 20, chineseZodiac: chineseZodiac)
    }

    func selectLevel(_ selectedLevel: Int) {
        currentLevel = selectedLevel
        level = Level(filename: "Level_\(selectedLevel)")
        level.resetComboMultiplier()
        moves = 0
        score = 0
        gameState = .loading
    }

    func onGameSceneLoad() {
        invokeCommand?(.addTiles)
        gameState = .inProgress
        shuffle()
    }

    func shuffle() {
        let newSprites = level.shuffle()
        invokeCommand?(.shuffle(newSprites))
    }

    func increaseMove() {
        moves += 1
    }

    func onTapShuffle() {
        increaseMove()
        checkGameState()
        if gameState == .inProgress {
            shuffle()
        }
    }

    private func checkGameState() {
        if score >= level.targetScore {
            gameState = .win
        }

        if moves > level.maximumMoves {
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
                let elementA = swap.cookieA
                let elementB = swap.cookieB
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
        let chains = level.removeMatches()
        if chains.count == 0 {
            beginNextTurn()
            return
        }

        await invokeCommandAsync?(.onMatchedSprites(chains))

        for chain in chains {
            score += chain.score
        }

        let columns = level.fillHoles()
        await invokeCommandAsync?(.onFallingCookies(columns))
        let topUpColumns = level.topUpCookies()

        await invokeCommandAsync?(.onNewSprites(topUpColumns))

        await handleMatches()
    }

    func beginNextTurn() {
        level.detectPossibleSwaps()
        increaseMove()
        checkGameState()
    }

    func onTapNextLevel() {
        if currentLevel >= zodiac.numLevels {
            gameState = .notStart
        } else {
            selectLevel(currentLevel + 1)
            onGameSceneLoad()
        }
    }

    func onTapTryAgainLevel() {
        selectLevel(currentLevel)
        onGameSceneLoad()
    }
}
