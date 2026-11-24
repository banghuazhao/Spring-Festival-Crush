import StoreKitTest
import XCTest
@testable import SpringFestivalCrush

@MainActor
final class PremiumAndCollectionTests: XCTestCase {
    override func tearDown() async throws {
        PremiumStore.shared.setPremiumForDebug(false)
        try await super.tearDown()
    }

    private func level(_ filename: String) throws -> GameModel {
        let model = GameModel()
        model.zodiac = try XCTUnwrap(Zodiac.all.first { $0.zodiacType == .rat })
        model.level = try XCTUnwrap(Level(filename: filename))
        return model
    }

    // MARK: Premium store

    /// Opt-in with `TEST_RUNNER_STOREKIT_PURCHASE=1`: on a simulator with no Apple Account, StoreKit
    /// can raise a system sign-in alert that deactivates the app and stalls later SpriteKit tests.
    func testLocalStoreKitPurchaseUnlocksAndRestoresPremium() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STOREKIT_PURCHASE"] == "1",
                          "Set TEST_RUNNER_STOREKIT_PURCHASE=1 to run the local StoreKit purchase")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Premium", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        addTeardownBlock { session.clearTransactions() }

        let suite = "PremiumStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        let store = PremiumStore(defaults: defaults, observesTransactions: false)
        await store.refreshEntitlement()
        XCTAssertFalse(store.isPremium)
        await store.loadProduct()
        XCTAssertEqual(store.product?.id, PremiumStore.productID)
        XCTAssertEqual(store.product?.type, .nonConsumable)

        await store.purchase()
        XCTAssertTrue(store.isPremium, store.message ?? "")

        let reinstalled = PremiumStore(defaults: nil, observesTransactions: false)
        XCTAssertFalse(reinstalled.isPremium)
        await reinstalled.refreshEntitlement()
        XCTAssertTrue(reinstalled.isPremium, "A new install must recover the purchase from StoreKit")

        session.clearTransactions()
        await reinstalled.refreshEntitlement()
        XCTAssertFalse(reinstalled.isPremium, "A removed transaction must end Premium")
    }

    // MARK: Premium benefits

    func testPremiumContinuesAreFreeUnlimitedAndNeverOfferAnAd() throws {
        let offer = try XCTUnwrap(ContinueOffer.make(
            reason: .outOfMoves, continuesUsed: ContinueOffer.maxPerAttempt + 4,
            movesLeft: 0, secondsLeft: nil, piecesRemaining: 3, progress: 0.5, isPremium: true))
        XCTAssertEqual(offer.coinCost, 0)
        XCTAssertFalse(offer.allowsRewardedAd)
        XCTAssertNil(ContinueOffer.make(
            reason: .outOfMoves, continuesUsed: ContinueOffer.maxPerAttempt,
            movesLeft: 0, secondsLeft: nil, piecesRemaining: 3, progress: 0.5),
                     "Free players keep the existing limit")
    }

    func testPremiumToolsAndBoostersSpendNothing() throws {
        let model = try level("Rat_Level_1")
        let coins = model.coins
        let hammers = model.hammerCharges
        let swaps = model.swapCharges
        PremiumStore.shared.setPremiumForDebug(true)

        XCTAssertTrue(model.canPlay)
        XCTAssertTrue(model.canUseHammer)
        XCTAssertTrue(model.canUseShuffle)
        XCTAssertTrue(model.canUseSwap)
        model.applyExtraMovesBooster()
        model.applyHammerBooster()
        model.applySwapBooster()

        XCTAssertEqual(model.pendingExtraMoves, GameModel.extraMovesBoosterAmount)
        XCTAssertEqual(model.coins, coins)
        XCTAssertEqual(model.hammerCharges, hammers, "Unlimited tools must not grow the saved inventory")
        XCTAssertEqual(model.swapCharges, swaps)
        model.resetBoostersForNewAttempt()
    }

    // MARK: Dragon guardian

    func testDragonTakesTileAndPowerDamageAndAlternatesItsBreath() throws {
        var encounter = BossEncounter(configuration: .init(kind: .dragon, health: 50))
        let chain = Chain(chainType: .horizontal3)
        chain.add(symbols: (0 ..< 3).map { Symbol(column: $0, row: 0, symbolType: .zodiac) })
        encounter.receive(chains: [chain], cascadeDepth: 1)
        XCTAssertEqual(encounter.health, 47)

        let power = Chain(chainType: .horizontal3)
        power.add(symbol: Symbol(column: 0, row: 1, symbolType: .bowlEnhanced))
        encounter.receive(chains: [power], cascadeDepth: 1)
        XCTAssertEqual(encounter.health, 44, "An activated power-up deals 3")

        XCTAssertTrue(encounter.nextBreathIsFrost)
        for _ in 0 ..< 2 { XCTAssertFalse(encounter.advanceTurn()) }
        XCTAssertTrue(encounter.advanceTurn())
        XCTAssertTrue(encounter.landedBreathIsFrost)
        XCTAssertFalse(encounter.nextBreathIsFrost)
        for _ in 0 ..< 2 { XCTAssertFalse(encounter.advanceTurn()) }
        XCTAssertTrue(encounter.advanceTurn())
        XCTAssertFalse(encounter.landedBreathIsFrost)
    }

    func testDragonBreathProtectsOnlyTheMarkedColumn() throws {
        let level = try XCTUnwrap(Level(filename: "Dragon_Level_15"))
        for symbol in level.shuffle() {
            symbol.iceLayer = 0
            symbol.armorLayers = 0
        }
        let lane = try XCTUnwrap(level.boss).nextAttackLane % level.numColumns
        for _ in 0 ..< 3 { level.advanceBossTurn() }
        let frosted = (0 ..< level.numColumns).flatMap { column in
            (0 ..< level.numRows).compactMap { level.symbol(atColumn: column, row: $0) }
        }.filter(\.isFrozen)
        XCTAssertEqual(frosted.count, 2)
        XCTAssertTrue(frosted.allSatisfy { $0.column == lane })
    }

    func testDragonChapterIsPlayableWithItsOwnArt() throws {
        let dragon = try XCTUnwrap(Zodiac.all.first { $0.zodiacType == .dragon })
        XCTAssertTrue(dragon.isAvailable)
        XCTAssertEqual(dragon.numLevels, 20)
        XCTAssertNotNil(UIImage(named: try XCTUnwrap(dragon.tileAssetName)))
        XCTAssertNotNil(UIImage(named: dragon.gameBackground))
        XCTAssertEqual(ZodiacCollection.guardianLevel(for: .dragon), 15)
        XCTAssertEqual(RuleCurriculum.shared.introductions[.dragonGuardian], LevelRef(zodiac: .dragon, number: 15))
    }

    // MARK: Collection

    func testCardTiersFollowGuardianWinAndPerfectStars() {
        func card(_ results: [(number: Int, isComplete: Bool, stars: Int)]) -> ZodiacCard {
            ZodiacCollection.card(zodiac: .ox, levelCount: 2, guardianLevel: 2, results: results)
        }
        XCTAssertEqual(card([(1, true, 3), (2, false, 0)]).tier, .locked)
        XCTAssertEqual(card([(1, true, 2), (2, true, 3)]).tier, .earned)
        XCTAssertEqual(card([(1, true, 3), (2, true, 3)]).tier, .gilded)
        XCTAssertEqual(ZodiacCollection.card(zodiac: .pig, levelCount: 0, guardianLevel: nil, results: []).isAvailable, false)
    }

    func testEveryPlayableChapterHasAStoryInEveryLanguage() throws {
        let stories = Zodiac.all.filter(\.isAvailable).map { ZodiacCollection.story(for: $0.zodiacType) }
        XCTAssertEqual(stories.compactMap { $0 }.count, Zodiac.all.filter(\.isAvailable).count)
        let keys = ["Go Premium", "Restore Purchase", "ZODIAC COLLECTION", "🐲 Cloud Dragon",
                    "Match Dragon tiles or activate power-ups to damage the Dragon."]
        for language in ["zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                                      inDirectory: nil, forLocalization: language))
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let table = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: String])
            for key in keys { XCTAssertNotEqual(table[key] ?? key, key, "\(language) must translate \(key)") }
        }
    }

    func testSeenCardsClearTheNewDot() throws {
        let suite = "ZodiacCardStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let owned = ZodiacCard(zodiac: .rat, tier: .earned, stars: 20, maxStars: 60, isAvailable: true)
        XCTAssertTrue(ZodiacCardStore.hasUnseen([owned], in: defaults))
        ZodiacCardStore.markSeen([.rat], in: defaults)
        XCTAssertFalse(ZodiacCardStore.hasUnseen([owned], in: defaults))
    }
}
