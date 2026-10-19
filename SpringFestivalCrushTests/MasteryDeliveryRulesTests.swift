import XCTest
@testable import SpringFestivalCrush

@MainActor
final class MasteryDeliveryRulesTests: XCTestCase {
    private func makeGame() async throws -> GameModel {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "swapCharges", "hasSeenTutorial"]
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        let game = GameModel()
        addTeardownBlock { @MainActor in
            game.invokeCommand = nil
            game.invokeCommandAsync = nil
            game.onTapBack()
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        game.zodiac = Zodiac.all[0]
        game.selectLevel(1)
        game.hasSeenTutorial = true
        await game.setupNewGame()
        game.level.noShuffle = true
        game.level.levelGoal.levelTarget = LevelTarget(zodiac: 9999, ingredient: 2)
        let colors: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        for row in 0..<game.numRows {
            for column in 0..<game.numColumns {
                let symbol = try XCTUnwrap(game.level.symbol(atColumn: column, row: row))
                symbol.type = colors[(column + row * 2) % colors.count]
                symbol.iceLayer = 0
                symbol.armorLayers = 0
                symbol.armorHitThisTurn = false
            }
        }
        return game
    }

    private func gift(_ game: GameModel, column: Int, row: Int) throws -> Symbol {
        let piece = try XCTUnwrap(game.level.symbol(atColumn: column, row: row))
        piece.type = .ingredient
        return piece
    }

    private func seedMatch(_ game: GameModel) throws {
        for column in 3...5 {
            try XCTUnwrap(game.level.symbol(atColumn: column, row: 4)).type = .bowl
        }
    }

    func testBottomCollectionCreditsOnlyArrivedGiftsAndNeverRepeats() async throws {
        let game = try await makeGame()
        let arrived = try gift(game, column: 3, row: 0)
        let waiting = try gift(game, column: 1, row: 1)
        let collected = game.level.collectIngredientsAtBottom()
        XCTAssertEqual(collected.count, 1)
        XCTAssertTrue(collected.first === arrived)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 1)
        XCTAssertTrue(game.level.symbol(atColumn: 1, row: 1) === waiting)
        XCTAssertTrue(game.level.collectIngredientsAtBottom().isEmpty)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 1)
    }

    func testStackedGiftsSettleAndDeliverWithinOneResolutionWithoutSpendingMoves() async throws {
        let game = try await makeGame()
        let lower = try gift(game, column: 1, row: 0)
        let upper = try gift(game, column: 1, row: 1)
        try seedMatch(game)
        let moves = game.movesLeft
        var batches: [[Symbol]] = []
        var deliveryScores: [Int] = []
        var giftProgress = 0
        game.invokeCommand = { command in
            if case let .onGoalProgress(progress) = command {
                giftProgress += progress.filter { $0.goalID == "ingredient" }.reduce(0) { $0 + $1.amount }
            }
        }
        game.invokeCommandAsync = { command in
            if case let .onIngredientsCollected(pieces) = command {
                batches.append(pieces)
                deliveryScores.append(game.score)
            }
        }
        await game.handleRemoveAndMatches()
        XCTAssertEqual(batches.count, 2)
        XCTAssertEqual(Set(batches.flatMap { $0 }.map(ObjectIdentifier.init)),
                       Set([lower, upper].map(ObjectIdentifier.init)))
        XCTAssertEqual(deliveryScores.count, 2)
        if deliveryScores.count == 2 { XCTAssertEqual(deliveryScores[1] - deliveryScores[0], 50) }
        XCTAssertEqual(giftProgress, 2)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 0)
        XCTAssertEqual(game.movesLeft, moves)
        for row in 0..<game.numRows {
            for column in 0..<game.numColumns {
                XCTAssertNotNil(game.level.symbol(atColumn: column, row: row), "Delivery must not strand an empty cell")
            }
        }
        let score = game.score
        await game.beginNextTurn()
        XCTAssertEqual(game.score, score)
        XCTAssertEqual(batches.count, 2)
    }

    func testLightningCanCollectAGiftAboveTheExitWithoutExitDoubleCredit() async throws {
        let game = try await makeGame()
        let target = try gift(game, column: 1, row: 3)
        game.level.levelGoal.levelTarget.ingredient = 1
        let lightning = try XCTUnwrap(game.level.symbol(atColumn: 3, row: 3))
        lightning.type = .lightning
        let neighbor = try XCTUnwrap(game.level.symbol(atColumn: 4, row: 3))
        let swap = Swap(symbolA: lightning, symbolB: neighbor)
        game.level.performSwap(swap)
        let chains = try XCTUnwrap(game.level.tryActivateSpecialSwap(swap))
        XCTAssertTrue(chains.flatMap(\.clearedSymbols).contains { $0 === target })
        game.level.updateLevelTarget(by: chains)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 0)
        XCTAssertTrue(game.level.collectIngredientsAtBottom().isEmpty)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 0)
    }

    func testHammerCollectsAGiftDirectlyWithoutSpendingAMove() async throws {
        let game = try await makeGame()
        _ = try gift(game, column: 1, row: 4)
        game.level.levelGoal.levelTarget.ingredient = 1
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let moves = game.movesLeft
        let charges = game.hammerCharges
        var exitCollections = 0
        game.invokeCommandAsync = { command in
            if case let .onIngredientsCollected(pieces) = command { exitCollections += pieces.count }
        }
        await game.useHammer(atColumn: 1, row: 4)
        XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 0)
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertEqual(game.hammerCharges, charges - 1)
        XCTAssertEqual(exitCollections, 0, "A direct clear must not also receive an exit reward")
    }

    func testRestartDuringDeliveryDiscardsTheOldSettlingLoop() async throws {
        let game = try await makeGame()
        _ = try gift(game, column: 1, row: 0)
        let oldUpper = try gift(game, column: 1, row: 1)
        let oldLevel = try XCTUnwrap(game.level)
        try seedMatch(game)
        var collected = 0
        var oldRefills = 0
        game.invokeCommandAsync = { command in
            if case .onNewSprites = command { oldRefills += 1 }
            if case let .onIngredientsCollected(pieces) = command {
                collected += pieces.count
                game.selectLevel(1)
                await game.setupNewGame()
            }
        }
        await game.handleRemoveAndMatches()
        XCTAssertEqual(collected, 1)
        XCTAssertEqual(oldRefills, 0)
        XCTAssertFalse(game.level === oldLevel)
        XCTAssertNil(game.level.levelGoal.levelTarget.ingredient)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertTrue(oldLevel.symbol(atColumn: 1, row: 1) === oldUpper)
    }

    func testReshufflingPreservesGiftPositionsIdentityAndGoalProgress() async throws {
        let game = try await makeGame()
        game.level.noShuffle = false
        let first = try gift(game, column: 1, row: 5)
        let second = try gift(game, column: 5, row: 5)
        let frozen = try XCTUnwrap(game.level.symbol(atColumn: 3, row: 2))
        frozen.iceLayer = 1
        for _ in 0..<8 {
            XCTAssertNotNil(game.level.reshuffleExistingSymbols())
            XCTAssertTrue(game.level.symbol(atColumn: 1, row: 5) === first)
            XCTAssertTrue(game.level.symbol(atColumn: 5, row: 5) === second)
            XCTAssertTrue(game.level.symbol(atColumn: 3, row: 2) === frozen)
            XCTAssertEqual(frozen.iceLayer, 1)
            XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, 2)
            XCTAssertFalse(game.level.possibleSwaps.isEmpty)
        }
    }
}
