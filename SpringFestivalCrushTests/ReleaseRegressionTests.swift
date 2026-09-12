import XCTest
@testable import SpringFestivalCrush

@MainActor
final class ReleaseRegressionTests: XCTestCase {
    private func makeGame() -> GameModel {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "hasSeenTutorial"]
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        let game = GameModel()
        game.zodiac = Zodiac.all[0]
        game.selectLevel(1)
        game.hasSeenTutorial = true
        return game
    }

    func testShufflePreservesLivePiecesAndFrozenPositions() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        let original = Array(level.shuffle())
        let frozen = original[0]
        frozen.iceLayer = 2
        let position = (frozen.column, frozen.row)
        original[1].type = .lightning
        original[2].type = .lock
        let identities = Set(original.map(ObjectIdentifier.init))
        let shuffled = try XCTUnwrap(level.reshuffleExistingSymbols())
        XCTAssertEqual(Set(shuffled.map(ObjectIdentifier.init)), identities)
        XCTAssertEqual(frozen.iceLayer, 2)
        XCTAssertEqual(frozen.column, position.0)
        XCTAssertEqual(frozen.row, position.1)
        XCTAssertEqual(original[1].type, .lightning)
        XCTAssertEqual(original[2].type, .lock)
        XCTAssertFalse(level.possibleSwaps.isEmpty)
    }

    func testImpossibleShuffleDoesNotRebuildBoard() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        let original = level.shuffle()
        for symbol in original { symbol.type = .lock }
        XCTAssertNil(level.reshuffleExistingSymbols())
        for symbol in original {
            XCTAssertTrue(level.symbol(atColumn: symbol.column, row: symbol.row) === symbol)
            XCTAssertEqual(symbol.type, .lock)
        }
    }

    func testShuffleCostsOneChargeAndNoMovesEvenOnDoubleTap() async {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedShuffle()
        game.grantRewardedShuffle()
        let moves = game.movesLeft
        let charges = game.shuffleCharges
        let finished = expectation(description: "shuffle completed")
        game.invokeCommand = { command in
            if case .setUserInteraction(true) = command { finished.fulfill() }
        }
        game.onTapShuffle()
        game.onTapShuffle()
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertEqual(game.shuffleCharges, charges - 1)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testUnavailableShuffleKeepsCharge() async {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedShuffle()
        game.level.noShuffle = true
        let charges = game.shuffleCharges
        game.onTapShuffle()
        XCTAssertEqual(game.shuffleCharges, charges)
        XCTAssertNotNil(game.toolNotice)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testExitDuringSetupCannotRestartGame() async {
        let game = makeGame()
        game.invokeCommandAsync = { command in
            if case .setupSymbols = command { game.onTapBack() }
        }
        await game.setupNewGame()
        XCTAssertEqual(game.gameState, .notStart)
    }

    func testOldHammerCascadeCannotModifyNewAttempt() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let symbol = try XCTUnwrap(game.level.symbol(atColumn: 0, row: 0))
        var replaced = false
        game.invokeCommandAsync = { command in
            if case .onMatchedSymbols = command, !replaced {
                replaced = true
                game.onTapBack()
                game.selectLevel(2)
                game.score = 123
            }
        }
        await game.useHammer(atColumn: symbol.column, row: symbol.row)
        XCTAssertTrue(replaced)
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.score, 123)
        XCTAssertEqual(game.gameState, .loading)
    }

    func testTimerCannotLoseDuringWinBonusOrAwardTwice() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget = LevelTarget()
        game.movesLeft = 0
        game.secondsLeft = 1
        let lives = game.lives
        let coins = game.coins
        game.invokeCommandAsync = { command in
            if case .onEnhanceSymbols = command {
                XCTAssertEqual(game.gameState, .finishing)
                game.tickTimer()
                await game.beginNextTurn()
            }
        }
        await game.beginNextTurn()
        XCTAssertEqual(game.gameState, .win)
        XCTAssertEqual(game.lives, lives)
        XCTAssertEqual(game.coins, coins + 15)
        XCTAssertEqual(game.secondsLeft, 1)
    }

    func testTimeoutWaitsForMoveToResolve() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        let swap = try XCTUnwrap(game.level.possibleSwaps.first)
        var checkedPendingMove = false
        game.invokeCommandAsync = { command in
            if case .onValidSwap = command {
                game.secondsLeft = 1
                game.tickTimer()
                checkedPendingMove = true
                XCTAssertEqual(game.secondsLeft, 0)
                XCTAssertEqual(game.gameState, .inProgress)
            }
        }
        await game.handleSwipe(swap)
        XCTAssertTrue(checkedPendingMove)
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertEqual(game.loseReason, .outOfTime)
    }

    func testInventorySurvivesAttemptReset() {
        let game = makeGame()
        game.grantRewardedHammer()
        game.grantRewardedShuffle()
        let counts = (game.hammerCharges, game.shuffleCharges)
        game.hammerModeActive = true
        game.resetBoostersForNewAttempt()
        XCTAssertFalse(game.hammerModeActive)
        XCTAssertEqual(game.hammerCharges, counts.0)
        XCTAssertEqual(game.shuffleCharges, counts.1)
        let restored = GameModel()
        XCTAssertEqual(restored.hammerCharges, counts.0)
        XCTAssertEqual(restored.shuffleCharges, counts.1)
    }

    func testRepeatedNextLevelTapAdvancesOnlyOnce() async {
        let game = makeGame()
        game.gameState = .win
        game.lives = 10
        game.onTapNextLevel()
        game.onTapNextLevel()
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.gameState, .loading)
        // Invalidate pending setup before this isolated model is discarded.
        game.onTapBack()
    }

    func testTimerStopsAtZeroAndDeductsOnlyOneLife() async {
        let game = makeGame()
        await game.setupNewGame()
        game.lives = 10
        game.secondsLeft = 1
        let finished = expectation(description: "timeout completed")
        game.invokeCommandAsync = { command in
            if case .onGameOver = command { finished.fulfill() }
        }
        game.tickTimer()
        game.tickTimer()
        await fulfillment(of: [finished], timeout: 5)
        game.tickTimer()
        XCTAssertEqual(game.secondsLeft, 0)
        XCTAssertEqual(game.lives, 9)
        XCTAssertEqual(game.gameState, .lose)
    }
}
