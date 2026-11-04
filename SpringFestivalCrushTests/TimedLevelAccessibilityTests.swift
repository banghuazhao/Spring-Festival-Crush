import XCTest
@testable import SpringFestivalCrush

@MainActor
final class TimedLevelAccessibilityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let keys = [TimedLevelTimerMode.preferenceKey, "hasSeenTutorial", "hapticsEnabled",
                    "isPlayBackgroundMusic", "coins", "lives", "lastLifeLostTimestamp"]
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        UserDefaults.standard.removeObject(forKey: TimedLevelTimerMode.preferenceKey)
        UserDefaults.standard.set(false, forKey: "hapticsEnabled")
        UserDefaults.standard.set(false, forKey: "isPlayBackgroundMusic")
    }

    private func makeGame(timed: Bool = true) -> GameModel {
        let game = GameModel()
        if timed {
            game.debugLaunchElementsDemo()
        } else {
            game.zodiac = Zodiac.all[0]
            game.selectLevel(1)
        }
        game.hasSeenTutorial = true
        // Model rules are exercised independently of a rendering window or SKActions.
        game.invokeCommandAsync = { _ in }
        return game
    }

    func testDefaultInvalidAndPersistedTimerPreferences() {
        XCTAssertEqual(TimedLevelTimerMode.saved, .standard)
        let settings = SettingModel()
        XCTAssertEqual(settings.timedLevelTimerMode, .standard)
        settings.timedLevelTimerMode = .extraTime
        XCTAssertEqual(TimedLevelTimerMode.saved, .extraTime)
        XCTAssertEqual(SettingModel().timedLevelTimerMode, .extraTime)
        settings.timedLevelTimerMode = .untimed
        XCTAssertEqual(TimedLevelTimerMode.saved, .untimed)
        XCTAssertEqual(SettingModel().timedLevelTimerMode, .untimed)
        UserDefaults.standard.set("unrecognized", forKey: TimedLevelTimerMode.preferenceKey)
        XCTAssertEqual(TimedLevelTimerMode.saved, .standard)
        XCTAssertEqual(SettingModel().timedLevelTimerMode, .standard)
    }

    func testTimedAttemptAppliesChosenLimitWithoutChangingMoves() async throws {
        let settings = SettingModel()
        for mode in TimedLevelTimerMode.allCases {
            settings.timedLevelTimerMode = mode
            let game = makeGame()
            let authoredLimit = try XCTUnwrap(game.level.timeLimit)
            let moves = game.level.maximumMoves
            await game.setupNewGame()
            XCTAssertEqual(game.attemptTimerMode, mode)
            XCTAssertEqual(game.secondsLeft, mode.seconds(for: authoredLimit))
            XCTAssertEqual(game.movesLeft, moves)
            XCTAssertEqual(game.gameState, .inProgress)
        }
    }

    func testMovesOnlyLevelDoesNotGainATimerInAnyMode() async {
        let settings = SettingModel()
        for mode in TimedLevelTimerMode.allCases {
            settings.timedLevelTimerMode = mode
            let game = makeGame(timed: false)
            XCTAssertNil(game.level.timeLimit)
            await game.setupNewGame()
            XCTAssertNil(game.secondsLeft)
            let moves = game.movesLeft
            game.tickTimer()
            XCTAssertEqual(game.movesLeft, moves)
            XCTAssertEqual(game.gameState, .inProgress)
        }
    }

    func testPreferenceChangesWaitForRestartInsteadOfChangingRunningClock() async throws {
        let settings = SettingModel()
        settings.timedLevelTimerMode = .extraTime
        let game = makeGame()
        let authoredLimit = try XCTUnwrap(game.level.timeLimit)
        await game.setupNewGame()
        game.tickTimer()
        XCTAssertEqual(game.secondsLeft, authoredLimit * 2 - 1)
        settings.timedLevelTimerMode = .untimed
        game.tickTimer()
        XCTAssertEqual(game.secondsLeft, authoredLimit * 2 - 2)
        XCTAssertEqual(game.attemptTimerMode, .extraTime)
        await game.onTapRestartLevel()
        XCTAssertEqual(game.attemptTimerMode, .untimed)
        XCTAssertNil(game.secondsLeft)
        XCTAssertEqual(game.movesLeft, game.level.maximumMoves)

        settings.timedLevelTimerMode = .standard
        XCTAssertNil(game.secondsLeft)
        await game.onTapRestartLevel()
        XCTAssertEqual(game.attemptTimerMode, .standard)
        XCTAssertEqual(game.secondsLeft, authoredLimit)
    }

    func testUntimedAttemptIgnoresTicksButStillEnforcesMoveLimit() async throws {
        let settings = SettingModel()
        settings.timedLevelTimerMode = .untimed
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10_000
        for _ in 0..<300 { game.tickTimer() }
        XCTAssertNil(game.secondsLeft)
        XCTAssertEqual(game.gameState, .inProgress)
        game.movesLeft = 0
        await game.beginNextTurn()
        XCTAssertEqual(game.gameState, .offeringContinue)
        let offer = try XCTUnwrap(game.continueOffer)
        XCTAssertEqual(offer.reason, .outOfMoves)
        XCTAssertTrue(offer.grantsMoves)
        XCTAssertFalse(offer.grantsSeconds)

        settings.timedLevelTimerMode = .standard
        game.coins = 1_000
        XCTAssertTrue(game.acceptContinueWithCoins())
        await waitForBoardToSettle(game)
        XCTAssertNil(game.secondsLeft, "Continuing an untimed attempt must not restore a timer")
        XCTAssertEqual(game.attemptTimerMode, .untimed)
        XCTAssertEqual(game.movesLeft, ContinueOffer.extraMoves)
    }

    func testTimedContinueKeepsAttemptModeAndFixedTimeRewardAfterPreferenceChanges() async throws {
        let settings = SettingModel()
        for mode in [TimedLevelTimerMode.standard, .extraTime] {
            settings.timedLevelTimerMode = mode
            let game = makeGame()
            await game.setupNewGame()
            game.level.levelGoal.levelTarget.zodiac = 10_000
            game.coins = 1_000
            game.secondsLeft = 1
            game.tickTimer()
            for _ in 0..<200 where game.gameState == .inProgress { await Task.yield() }
            XCTAssertEqual(game.secondsLeft, 0)
            XCTAssertEqual(game.gameState, .offeringContinue)
            let offer = try XCTUnwrap(game.continueOffer)
            XCTAssertEqual(offer.reason, .outOfTime)
            XCTAssertTrue(offer.grantsSeconds)
            settings.timedLevelTimerMode = .untimed
            XCTAssertTrue(game.acceptContinueWithCoins())
            await waitForBoardToSettle(game)
            XCTAssertEqual(game.attemptTimerMode, mode)
            XCTAssertEqual(game.secondsLeft, ContinueOffer.extraSeconds)
            game.tickTimer()
            XCTAssertEqual(game.secondsLeft, ContinueOffer.extraSeconds - 1)
        }
    }

    private func waitForBoardToSettle(_ game: GameModel, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 where game.isResolvingBoard { await Task.yield() }
        XCTAssertFalse(game.isResolvingBoard, file: file, line: line)
        XCTAssertEqual(game.gameState, .inProgress, file: file, line: line)
    }
}
