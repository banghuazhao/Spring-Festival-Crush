import XCTest
@testable import SpringFestivalCrush

/// Continue offers, Ruyi Swap, daily envelopes, star chests, review timing and localization.
@MainActor
final class FestivalFeaturesTests: XCTestCase {
    private func makeGame() -> GameModel {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "swapCharges",
                    "hasSeenTutorial", "lifetimeLevelWins"]
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

    private func makeDefaults() -> UserDefaults {
        let name = "FestivalFeaturesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func settle(_ game: GameModel) async {
        for _ in 0 ..< 500 where game.isResolvingBoard { await Task.yield() }
    }

    /// Plays until the moves run out without reaching the (unreachable) goal.
    private func runOutOfMoves(_ game: GameModel) async {
        game.movesLeft = 0
        await game.beginNextTurn()
    }

    // MARK: - Continue offer

    func testContinuePricingEscalatesAndEnds() throws {
        let first = try XCTUnwrap(ContinueOffer.make(reason: .outOfMoves, continuesUsed: 0, movesLeft: 0,
                                                     secondsLeft: nil, piecesRemaining: 3, progress: 0.9))
        XCTAssertEqual(first.coinCost, 30)
        XCTAssertTrue(first.allowsRewardedAd)
        XCTAssertTrue(first.grantsMoves)
        XCTAssertFalse(first.grantsSeconds)
        let third = try XCTUnwrap(ContinueOffer.make(reason: .outOfMoves, continuesUsed: 2, movesLeft: 0,
                                                     secondsLeft: nil, piecesRemaining: 3, progress: 2))
        XCTAssertEqual(third.coinCost, 90)
        XCTAssertFalse(third.allowsRewardedAd)
        XCTAssertEqual(third.progress, 1)
        XCTAssertNil(ContinueOffer.make(reason: .outOfMoves, continuesUsed: ContinueOffer.maxPerAttempt, movesLeft: 0,
                                        secondsLeft: nil, piecesRemaining: 3, progress: 0.5))
        let both = try XCTUnwrap(ContinueOffer.make(reason: .outOfTime, continuesUsed: 0, movesLeft: 0,
                                                    secondsLeft: 0, piecesRemaining: 1, progress: 0.5))
        XCTAssertTrue(both.grantsMoves)
        XCTAssertTrue(both.grantsSeconds)
    }

    func testRunningOutOffersContinueBeforeCostingALife() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        game.lives = 10
        game.coins = 200
        await runOutOfMoves(game)
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.lives, 10)
        XCTAssertEqual(game.continueOffer?.coinCost, 30)

        XCTAssertTrue(game.acceptContinueWithCoins())
        await settle(game)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(game.movesLeft, ContinueOffer.extraMoves)
        XCTAssertEqual(game.coins, 170)
        XCTAssertFalse(game.acceptContinueWithCoins(), "No offer is pending once play resumes")

        await runOutOfMoves(game)
        XCTAssertEqual(game.continueOffer?.coinCost, 60)
        XCTAssertFalse(game.continueOffer?.allowsRewardedAd ?? true)
        game.acceptContinueFromRewardedAd()
        XCTAssertEqual(game.gameState, .offeringContinue, "Only the first continue can be paid with an ad")
        XCTAssertTrue(game.acceptContinueWithCoins())
        await settle(game)

        await runOutOfMoves(game)
        XCTAssertTrue(game.acceptContinueWithCoins())
        await settle(game)
        XCTAssertEqual(game.coins, 200 - 30 - 60 - 90)

        // The fourth time there is nothing left to offer: the attempt fails normally.
        await runOutOfMoves(game)
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertNil(game.continueOffer)
        XCTAssertEqual(game.lives, 9)
    }

    func testContinueNeedsEnoughCoinsAndAdContinueIsFree() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        game.coins = 10
        await runOutOfMoves(game)
        XCTAssertFalse(game.acceptContinueWithCoins())
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.coins, 10)
        game.acceptContinueFromRewardedAd()
        await settle(game)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(game.coins, 10)
        XCTAssertEqual(game.movesLeft, ContinueOffer.extraMoves)
    }

    func testLeavingFromTheOfferStillCostsALifeAndDeclineIsSingleShot() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        game.lives = 10
        await runOutOfMoves(game)
        game.onTapBack()
        XCTAssertEqual(game.lives, 9)
        XCTAssertEqual(game.gameState, .notStart)

        game.selectLevel(1)
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        await runOutOfMoves(game)
        game.declineContinue()
        game.declineContinue()
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertEqual(game.lives, 8)
        game.onTapBack()
    }

    // MARK: - Ruyi Swap

    func testRuyiSwapTradesAnyNeighboursWithoutSpendingAMove() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        game.grantRewardedSwap()
        let charges = game.swapCharges
        let moves = game.movesLeft
        var pair: Swap?
        search: for row in 0 ..< game.numRows {
            for column in 0 ..< game.numColumns - 1 {
                guard let a = game.level.symbol(atColumn: column, row: row),
                      let b = game.level.symbol(atColumn: column + 1, row: row),
                      a.isMovable(), b.isMovable(), !a.isSpecialPowerUp, !b.isSpecialPowerUp,
                      a.type != b.type else { continue }
                let swap = Swap(symbolA: a, symbolB: b)
                if !game.level.isPossibleSwap(swap) { pair = swap; break search }
            }
        }
        let swap = try XCTUnwrap(pair, "Level 1 should have a non-matching neighbour pair")
        let before = (swap.symbolA.column, swap.symbolB.column)

        await game.useRuyiSwap(swap)
        XCTAssertEqual(game.swapCharges, charges, "Nothing happens until the tool is armed")

        game.swapModeActive = true
        await game.useRuyiSwap(swap)
        XCTAssertEqual(game.swapCharges, charges - 1)
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertFalse(game.swapModeActive)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(swap.symbolA.column, before.1)
        XCTAssertEqual(swap.symbolB.column, before.0)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testToolModesAreExclusiveAndSuppressIdleHints() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        game.hammerModeActive = true
        game.swapModeActive = true
        XCTAssertFalse(game.hammerModeActive)
        XCTAssertNil(game.suggestedIdleSwap())
        game.hammerModeActive = true
        XCTAssertFalse(game.swapModeActive)
        game.resetBoostersForNewAttempt()
        XCTAssertFalse(game.hammerModeActive)
        XCTAssertFalse(game.swapModeActive)
    }

    func testRewardBundlesLandInTheSavedInventory() {
        let game = makeGame()
        let before = (game.coins, game.shuffleCharges, game.hammerCharges, game.swapCharges)
        game.grant(RewardBundle(coins: 25, shuffles: 1, hammers: 2, swaps: 3))
        XCTAssertEqual(game.coins, before.0 + 25)
        XCTAssertEqual(game.shuffleCharges, before.1 + 1)
        XCTAssertEqual(game.hammerCharges, before.2 + 2)
        XCTAssertEqual(game.swapCharges, before.3 + 3)
        XCTAssertEqual(GameModel().swapCharges, before.3 + 3)
    }

    // MARK: - Daily red envelope

    func testDailyEnvelopeStreakRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let monday = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 24 * 60 * 60
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: nil, lastDay: 0, now: monday, calendar: calendar), .ready(day: 1))
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: monday, lastDay: 3, now: monday + 60, calendar: calendar),
                       .claimed(nextDay: 4))
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: monday, lastDay: 3, now: monday + day, calendar: calendar),
                       .ready(day: 4))
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: monday, lastDay: 3, now: monday + 2 * day, calendar: calendar),
                       .ready(day: 1), "Missing a whole day restarts the streak")
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: monday, lastDay: 7, now: monday + day, calendar: calendar),
                       .ready(day: 1), "The cycle starts over after the big day-7 envelope")
        XCTAssertEqual(DailyEnvelopeRules.status(lastClaim: monday, lastDay: 2, now: monday - day, calendar: calendar),
                       .claimed(nextDay: 3), "Winding the clock back never unlocks an envelope")
        XCTAssertGreaterThan(DailyEnvelopeRules.reward(forDay: 7).coins, DailyEnvelopeRules.reward(forDay: 5).coins)
        for streakDay in 1 ... DailyEnvelopeRules.cycleLength {
            XCTAssertFalse(DailyEnvelopeRules.reward(forDay: streakDay).isEmpty)
        }
    }

    func testDailyEnvelopeClaimsOncePerDayAndDoublesOnce() {
        let game = makeGame()
        let defaults = makeDefaults()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        let envelope = DailyEnvelopeModel(defaults: defaults, now: { now })
        XCTAssertTrue(envelope.isReady)
        let coins = game.coins
        XCTAssertEqual(envelope.claim(into: game), DailyEnvelopeRules.reward(forDay: 1))
        XCTAssertEqual(game.coins, coins + DailyEnvelopeRules.reward(forDay: 1).coins)
        XCTAssertNil(envelope.claim(into: game))
        XCTAssertFalse(envelope.isReady)
        envelope.doubleLastReward(into: game)
        envelope.doubleLastReward(into: game)
        XCTAssertEqual(game.coins, coins + 2 * DailyEnvelopeRules.reward(forDay: 1).coins)

        now += 24 * 60 * 60
        envelope.refresh()
        XCTAssertEqual(envelope.status, .ready(day: 2))
        let shuffles = game.shuffleCharges
        envelope.claim(into: game)
        XCTAssertEqual(game.shuffleCharges, shuffles + 1)
        XCTAssertEqual(DailyEnvelopeModel(defaults: defaults, now: { now }).status, .claimed(nextDay: 3))
    }

    // MARK: - Star chests

    func testStarChestThresholdsAndSingleClaim() {
        let rat = StarChestTrack(levelCount: 15)
        XCTAssertEqual(rat.chests.map(\.threshold), [15, 30, 45])
        XCTAssertEqual(rat.maxStars, 45)
        XCTAssertEqual(StarChestTrack(levelCount: 10).chests.map(\.threshold), [10, 20, 30])
        XCTAssertEqual(rat.state(of: rat.chests[0], stars: 14, claimed: []), .locked)
        XCTAssertEqual(rat.state(of: rat.chests[0], stars: 15, claimed: []), .ready)
        XCTAssertEqual(rat.state(of: rat.chests[0], stars: 45, claimed: [0]), .opened)
        XCTAssertEqual(rat.readyChests(stars: 31, claimed: [0]).map(\.index), [1])

        let defaults = makeDefaults()
        XCTAssertTrue(StarChestStore.markClaimed(1, for: .ox, defaults: defaults))
        XCTAssertFalse(StarChestStore.markClaimed(1, for: .ox, defaults: defaults))
        XCTAssertEqual(StarChestStore.claimed(for: .ox, defaults: defaults), [1])
        XCTAssertTrue(StarChestStore.claimed(for: .rat, defaults: defaults).isEmpty)
    }

    // MARK: - Review prompt

    func testReviewPromptOnlyAtHighPoints() {
        let perfect = VictorySummary(zodiac: .rat, level: 4, score: 9000, stars: 3, coins: 15, newlyUnlockedLevel: 5)
        let plain = VictorySummary(zodiac: .rat, level: 4, score: 900, stars: 1, coins: 15, newlyUnlockedLevel: 5)
        let boss = VictorySummary(zodiac: .tiger, level: 10, score: 900, stars: 1, coins: 15, newlyUnlockedLevel: nil,
                                  defeatedBoss: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func ask(_ summary: VictorySummary, wins: Int = 10, last: Date? = nil, version: String? = nil) -> Bool {
            ReviewPromptPolicy.shouldAsk(summary: summary, lifetimeWins: wins, lastPromptDate: last,
                                         lastPromptVersion: version, currentVersion: "3.3.0", now: now)
        }
        XCTAssertTrue(ask(perfect))
        XCTAssertTrue(ask(boss))
        XCTAssertFalse(ask(plain))
        XCTAssertFalse(ask(perfect, wins: 2))
        XCTAssertFalse(ask(perfect, version: "3.3.0"))
        XCTAssertFalse(ask(perfect, last: now - 10 * 24 * 60 * 60, version: "3.2.0"))
        XCTAssertTrue(ask(perfect, last: now - 90 * 24 * 60 * 60, version: "3.2.0"))
    }

    // MARK: - Game feel

    func testCascadesClimbThePentatonicLadder() {
        XCTAssertEqual(CascadeFeedback(depth: 1).noteStep, 0)
        XCTAssertEqual(CascadeFeedback(depth: 3).noteStep, 2)
        XCTAssertEqual(CascadeFeedback(depth: 99).noteStep, 7)
        XCTAssertEqual(GameSound.note(-4), .pluck1)
        XCTAssertEqual(GameSound.note(50), .pluck8)
        for sound in GameSound.allCases {
            XCTAssertNotNil(Bundle.main.url(forResource: sound.rawValue, withExtension: nil), sound.rawValue)
        }
    }

    func testGuardiansAttackOnTheirIntervalAndAlwaysHaveALine() throws {
        let level = try XCTUnwrap(Level(filename: "Tiger_Level_10"))
        _ = level.shuffle()
        let interval = try XCTUnwrap(level.boss).configuration.attackInterval
        let attacks = (0 ..< interval * 2).filter { _ in level.advanceBossTurn() }.count
        XCTAssertEqual(attacks, 2)
        for kind in [BossConfiguration.Kind.rat, .ox, .tiger] {
            for event in [BossEvent.Kind.hit(3), .windUp, .attack, .defeated] {
                XCTAssertFalse(kind.taunt(for: event).isEmpty)
            }
        }
    }

    // MARK: - Localization

    func testChineseStringsCoverNewFeaturesWithMatchingPlaceholders() throws {
        for language in ["zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                                      inDirectory: nil, forLocalization: language))
            let table = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            for key in ["KEEP GOING?", "Ruyi Swap", "DAILY RED ENVELOPE", "STAR CHESTS", "FESTIVAL FINALE!",
                        "Only %lld more pieces to go!", "LEVEL COMPLETE!", "OUT OF MOVES", "Lantern Harbor",
                        "Firecrackers + cascades · row %lld freezes in %lld moves"] {
                XCTAssertNotNil(table[key], "\(language) is missing \(key)")
            }
            let specifier = try NSRegularExpression(pattern: "%(?:\\d\\$)?(?:lld|@|lf|d)")
            func specifiers(_ text: String) -> [String] {
                specifier.matches(in: text, range: NSRange(text.startIndex..., in: text))
                    .map { (text as NSString).substring(with: $0.range) }.sorted()
            }
            for (key, value) in table {
                XCTAssertEqual(specifiers(key), specifiers(value), "\(language): \(key)")
            }
        }
    }

    func testEveryLevelHintIsDrawnAsPictures() {
        var checked = 0
        for zodiac in ["Rat", "Ox", "Tiger"] {
            var number = 1
            while let level = Level(filename: "\(zodiac)_Level_\(number)") {
                if let hint = level.mechanicHint {
                    XCTAssertFalse(MechanicTip.tips(in: hint).isEmpty, "\(zodiac) \(number): \(hint)")
                    checked += 1
                }
                number += 1
            }
        }
        XCTAssertGreaterThan(checked, 30)
        XCTAssertEqual(MechanicTip.tips(in: "Swap neighbors to match 3. Match 4 for a blast tile, 5 for a star."),
                       [.swapToMatch, .specials])
        XCTAssertEqual(MechanicTip.tips(in: "Gold frame · 2 hits. Ice: thaw. Chain reactions. Match 4 or 5 to make special tiles."),
                       [.armor, .ice, .cascade, .specials])
    }
}
