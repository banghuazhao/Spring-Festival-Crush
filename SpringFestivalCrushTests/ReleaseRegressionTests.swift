import XCTest
import SpriteKit
import SwiftUI
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

    func testGoalReceiptsClampOvercollectionAndUseMatchingSource() {
        let before = LevelTarget(firecracker: 2, dumpling: 0).getLevelTargetDatas(gameZodiac: Zodiac.all[0])
        let after = LevelTarget(firecracker: -3, dumpling: -1).getLevelTargetDatas(gameZodiac: Zodiac.all[0])
        let receipts = GoalProgress.changes(before: before, after: after, symbols: [
            Symbol(column: 0, row: 0, symbolType: .dumpling),
            Symbol(column: 3, row: 4, symbolType: .firecrackerEnhanced)
        ])
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.amount, 2)
        XCTAssertEqual(receipts.first?.goalID, "firecracker")
        XCTAssertEqual(receipts.first?.column, 3)
        XCTAssertEqual(receipts.first?.row, 4)
    }

    func testGoalFlightArrivalIsIdempotentAndClearInvalidatesOldArrivals() throws {
        let feedback = GameFeedback()
        feedback.viewport = CGRect(x: 0, y: 0, width: 300, height: 100)
        feedback.goalFrames = ["bowl": CGRect(x: 100, y: 30, width: 26, height: 26)]
        let receipt = GoalProgress(goalID: "bowl", amount: 3, column: 1, row: 1)
        feedback.collect(receipt, image: Image("bowl"), source: CGPoint(x: 100, y: 300), reduceMotion: false)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 3)
        let id = try XCTUnwrap(feedback.flights.first?.id)
        feedback.arrive(id)
        feedback.arrive(id)
        XCTAssertEqual(feedback.impacts["bowl"], 1)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 0)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: false)
        let oldID = try XCTUnwrap(feedback.flights.first?.id)
        feedback.clear()
        feedback.arrive(oldID)
        XCTAssertTrue(feedback.impacts.isEmpty)
        XCTAssertTrue(feedback.flights.isEmpty)
    }

    func testReducedMotionAndOffscreenGoalsNeverHoldCounters() {
        let feedback = GameFeedback()
        feedback.viewport = CGRect(x: 0, y: 0, width: 100, height: 50)
        feedback.goalFrames = ["bowl": CGRect(x: 10, y: 10, width: 26, height: 26)]
        let receipt = GoalProgress(goalID: "bowl", amount: 1, column: 1, row: 1)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: true)
        XCTAssertTrue(feedback.flights.isEmpty)
        XCTAssertEqual(feedback.impacts["bowl"], 1)
        feedback.goalFrames["bowl"] = CGRect(x: 110, y: 10, width: 26, height: 26)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: false)
        XCTAssertTrue(feedback.flights.isEmpty)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 0)
        XCTAssertEqual(feedback.impacts["bowl"], 2)
    }

    func testCascadeIntensityIsBounded() {
        XCTAssertNil(CascadeFeedback(depth: 1).title)
        XCTAssertNotNil(CascadeFeedback(depth: 2).title)
        XCTAssertLessThan(CascadeFeedback(depth: 1).playbackRate, CascadeFeedback(depth: 3).playbackRate)
        XCTAssertEqual(CascadeFeedback(depth: 5).playbackRate, CascadeFeedback(depth: 999).playbackRate)
        XCTAssertLessThanOrEqual(CascadeFeedback(depth: 999).volume, 0.8)
    }

    func testExitDuringHammerWindupCannotApplyOldGoalFeedback() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let charges = game.hammerCharges
        var receipts = 0
        game.invokeCommand = { command in
            if case .onGoalProgress = command { receipts += 1 }
        }
        game.invokeCommandAsync = { command in
            if case .onHammerImpact = command {
                game.onTapBack()
                game.selectLevel(2)
                game.score = 123
            }
        }
        await game.useHammer(atColumn: 0, row: 0)
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.gameState, .loading)
        XCTAssertEqual(game.score, 123)
        XCTAssertEqual(game.hammerCharges, charges - 1)
        XCTAssertEqual(receipts, 0)
    }

    func testEachPlayerActionStartsCascadeAtOne() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        var depths: [Int] = []
        game.invokeCommand = { command in
            if case let .onCascade(depth) = command { depths.append(depth) }
        }
        for _ in 0..<2 {
            depths.removeAll()
            let swap = try XCTUnwrap(game.level.possibleSwaps.first)
            await game.handleSwipe(swap)
            XCTAssertEqual(depths.first, 1)
            XCTAssertEqual(depths, Array(0..<depths.count).map { $0 + 1 })
        }
    }

    func testShuffleAnimationKeepsSpriteIdentityAndEndsExactlyOnCells() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let feedback = GameFeedback()
        let scene = GameScene(size: CGSize(width: 390, height: 844), gameModel: game,
                              themeModel: ThemeModel(), settingModel: SettingModel(), feedback: feedback)
        scene.setupLayerPosition()
        let original = (0..<game.numRows).flatMap { row in
            (0..<game.numColumns).compactMap { game.level.symbol(atColumn: $0, row: row) }
        }
        await scene.addSymbols(for: Set(original), shouldAnimate: false)
        let identities = original.map { ObjectIdentifier($0.sprite!) }
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        let view = SKView(frame: windowScene.coordinateSpace.bounds)
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.presentScene(scene)
        addTeardownBlock { @MainActor in
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        for reduced in [false, true] {
            scene.reduceMotion = reduced
            let shuffled = try XCTUnwrap(game.level.reshuffleExistingSymbols())
            await scene.shuffle(by: shuffled)
            XCTAssertEqual(original.map { ObjectIdentifier($0.sprite!) }, identities)
            for symbol in original {
                let sprite = try XCTUnwrap(symbol.sprite)
                XCTAssertEqual(sprite.position, scene.pointFor(column: symbol.column, row: symbol.row))
                XCTAssertEqual(sprite.xScale, 1)
                XCTAssertEqual(sprite.yScale, 1)
                XCTAssertEqual(sprite.alpha, 1)
                XCTAssertTrue(sprite.parent === scene.symbolsLayer)
            }
        }
        let match = Chain(chainType: .horizontal3)
        match.add(symbols: Array(original.prefix(3)))
        await scene.animateMatchedSymbols(for: [match])
        // Native keyed `run` is synchronous: this catches an accidental fire-and-forget
        // removal that lets the next cascade fill cells before the old sprites disappear.
        for symbol in match.symbols { XCTAssertNil(symbol.sprite?.parent) }
    }
}
