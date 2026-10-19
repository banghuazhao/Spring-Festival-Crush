import XCTest
@testable import SpringFestivalCrush

@MainActor
final class ChocolateTurnCadenceTests: XCTestCase {
    private func makeGame(onCommand: @escaping (GameModel.Command) -> Void) async throws -> GameModel {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "swapCharges", "hasSeenTutorial"]
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
        game.coins = 1000
        game.lives = 10
        game.invokeCommand = onCommand
        game.level.noShuffle = true
        game.level.tileAt(column: 0, row: 0)?.type = .chocolate
        game.level.levelGoal.levelTarget = LevelTarget(zodiac: 10000)
        await game.setupNewGame()

        // A settled board without matches keeps refill randomness out of cadence checks.
        let types: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        for row in 0..<game.numRows {
            for column in 0..<game.numColumns {
                let symbol = try XCTUnwrap(game.level.symbol(atColumn: column, row: row))
                symbol.type = column == 0 && row == 0 ? .chocolate : types[(column + row * 2) % types.count]
                symbol.armorLayers = 0
                symbol.armorHitThisTurn = false
                symbol.iceLayer = 0
            }
        }
        return game
    }

    private func chocolateCount(_ game: GameModel) -> Int {
        (0..<game.numRows).reduce(0) { total, row in
            total + (0..<game.numColumns).filter {
                game.level.symbol(atColumn: $0, row: row)?.type == .chocolate
            }.count
        }
    }

    private func paidSwap(_ game: GameModel) throws -> Swap {
        let swap = Swap(symbolA: try XCTUnwrap(game.level.symbol(atColumn: 3, row: 3)),
                        symbolB: try XCTUnwrap(game.level.symbol(atColumn: 4, row: 3)))
        // Pre-authorize this fixture's swap to isolate paid-turn accounting from matching.
        game.level.possibleSwaps = [swap]
        return swap
    }

    func testOnlyPaidTurnsSpreadAndDuplicateTurnCallbacksStayQuiet() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        XCTAssertEqual(spreads, 0, "Setup must not spread chocolate")
        XCTAssertEqual(chocolateCount(game), 1)
        await game.beginNextTurn()
        await game.beginNextTurn()
        XCTAssertEqual(spreads, 0)

        let moves = game.movesLeft
        await game.handleSwipe(try paidSwap(game))
        XCTAssertEqual(game.movesLeft, moves - 1)
        XCTAssertEqual(spreads, 1)
        XCTAssertEqual(chocolateCount(game), 2)
        await game.beginNextTurn()
        await game.beginNextTurn()
        XCTAssertEqual(spreads, 1, "The consumed paid turn must not be replayed")

        await game.handleSwipe(try paidSwap(game))
        XCTAssertEqual(spreads, 2)
        XCTAssertEqual(chocolateCount(game), 3)
    }

    func testHammerRuyiAndShuffleDoNotSpreadChocolate() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        let moves = game.movesLeft
        game.grantRewardedHammer()
        game.hammerModeActive = true
        await game.useHammer(atColumn: 6, row: 6)
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(game), 1)
        game.grantRewardedSwap()
        game.swapModeActive = true
        await game.useRuyiSwap(try paidSwap(game))
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(game), 1)

        game.level.noShuffle = false
        game.grantRewardedShuffle()
        let shuffled = expectation(description: "Free shuffle finished")
        game.invokeCommand = { command in
            if case .onChocolateSpread = command { spreads += 1 }
            if case .setUserInteraction(true) = command { shuffled.fulfill() }
        }
        game.onTapShuffle()
        await fulfillment(of: [shuffled], timeout: 5)
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(game), 1)
        XCTAssertEqual(game.movesLeft, moves)
    }

    func testPaidMoveSpreadIsDeferredUntilContinueAndConsumedOnce() async throws {
        for useCoins in [false, true] {
            var spreads = 0
            let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
            game.movesLeft = 1
            await game.handleSwipe(try paidSwap(game))
            XCTAssertEqual(game.gameState, .offeringContinue)
            XCTAssertEqual(spreads, 0, "An unresolved offer does not advance the board")

            let resumed = expectation(description: "Deferred paid turn resumed, coins \(useCoins)")
            game.invokeCommand = { command in
                if case .onChocolateSpread = command { spreads += 1 }
                if case .setUserInteraction(true) = command { resumed.fulfill() }
            }
            if useCoins { XCTAssertTrue(game.acceptContinueWithCoins()) }
            else { game.acceptContinueFromRewardedAd() }
            XCTAssertFalse(game.acceptContinueWithCoins(), "The same offer cannot replay a paid turn")
            await fulfillment(of: [resumed], timeout: 5)
            XCTAssertEqual(spreads, 1)
            XCTAssertEqual(chocolateCount(game), 2)
            XCTAssertEqual(game.gameState, .inProgress)
            await game.beginNextTurn()
            XCTAssertEqual(spreads, 1)
        }
    }

    func testTimerOnlyContinueHasNoPaidTurnToSpread() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        game.secondsLeft = 0
        await game.beginNextTurn()
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.continueOffer?.reason, .outOfTime)
        let resumed = expectation(description: "Timer-only continue resumed")
        game.invokeCommand = { command in
            if case .onChocolateSpread = command { spreads += 1 }
            if case .setUserInteraction(true) = command { resumed.fulfill() }
        }
        game.acceptContinueFromRewardedAd()
        await fulfillment(of: [resumed], timeout: 5)
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(game), 1)
    }

    func testADeadlineReachedDuringAPaidMoveKeepsItsDeferredSpread() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        game.invokeCommandAsync = { command in
            if case .onValidSwap = command { game.secondsLeft = 0 }
        }
        await game.handleSwipe(try paidSwap(game))
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.continueOffer?.reason, .outOfTime)
        XCTAssertEqual(spreads, 0)
        let resumed = expectation(description: "Paid timed-out move resumed")
        game.invokeCommand = { command in
            if case .onChocolateSpread = command { spreads += 1 }
            if case .setUserInteraction(true) = command { resumed.fulfill() }
        }
        game.acceptContinueFromRewardedAd()
        await fulfillment(of: [resumed], timeout: 5)
        XCTAssertEqual(spreads, 1)
        XCTAssertEqual(chocolateCount(game), 2)
        await game.beginNextTurn()
        XCTAssertEqual(spreads, 1)
    }

    func testDeclineAndRestartDiscardDeferredChocolateSpread() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        game.movesLeft = 1
        await game.handleSwipe(try paidSwap(game))
        game.declineContinue()
        game.declineContinue()
        await game.beginNextTurn()
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(game), 1)

        // The old continue task must also be inert if a restart replaces its attempt first.
        let restarted = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        restarted.movesLeft = 1
        await restarted.handleSwipe(try paidSwap(restarted))
        XCTAssertTrue(restarted.acceptContinueWithCoins())
        await restarted.onTapRestartLevel()
        await Task.yield()
        XCTAssertEqual(restarted.gameState, .inProgress)
        XCTAssertEqual(spreads, 0)
        XCTAssertEqual(chocolateCount(restarted), 0, "Restart loads fresh authored pieces")
    }

    func testFinalLossDoesNotReplayTheLastPaidTurn() async throws {
        var spreads = 0
        let game = try await makeGame { if case .onChocolateSpread = $0 { spreads += 1 } }
        for offerIndex in 0..<ContinueOffer.maxPerAttempt {
            game.movesLeft = 1
            await game.handleSwipe(try paidSwap(game))
            XCTAssertEqual(game.continueOffer?.index, offerIndex)
            let resumed = expectation(description: "Continue \(offerIndex) finished")
            game.invokeCommand = { command in
                if case .onChocolateSpread = command { spreads += 1 }
                if case .setUserInteraction(true) = command { resumed.fulfill() }
            }
            XCTAssertTrue(game.acceptContinueWithCoins())
            await fulfillment(of: [resumed], timeout: 5)
            XCTAssertEqual(spreads, offerIndex + 1)
        }
        game.movesLeft = 1
        await game.handleSwipe(try paidSwap(game))
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertNil(game.continueOffer)
        await game.beginNextTurn()
        game.declineContinue()
        XCTAssertEqual(spreads, ContinueOffer.maxPerAttempt)
        XCTAssertEqual(chocolateCount(game), 1 + ContinueOffer.maxPerAttempt)
    }
}
