import XCTest
import SpriteKit
import SwiftData
import SwiftUI
@testable import SpringFestivalCrush

@MainActor
final class ProgressionTests: XCTestCase {
    private func isolatedRow(armor: Bool = true) throws -> (Level, [Symbol]) {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        let pieces = level.shuffle()
        pieces.forEach { $0.type = .lock }
        let row = try (0..<3).map { try XCTUnwrap(level.symbol(atColumn: $0, row: 0)) }
        row.forEach { $0.type = .zodiac; $0.armorLayers = armor ? 1 : 0 }
        return (level, row)
    }

    func testArmorNeedsTwoPlayerTurnsAndNeverCountsAsCollectedOnFirstHit() throws {
        let (level, row) = try isolatedRow()
        let before = level.levelGoal.levelTarget.zodiac
        let first = level.removeMatches()
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(first.flatMap(\.clearedSymbols).isEmpty)
        XCTAssertEqual(first.first?.score, 0)
        level.updateLevelTarget(by: first)
        XCTAssertEqual(level.levelGoal.levelTarget.zodiac, before)
        for tile in row {
            XCTAssertTrue(level.symbol(atColumn: tile.column, row: tile.row) === tile)
            XCTAssertEqual(tile.armorLayers, 0)
        }
        XCTAssertTrue(level.removeMatches().isEmpty, "A stationary match must not instantly hit again")
        level.finishArmorTurn()
        let second = level.removeMatches()
        XCTAssertEqual(second.flatMap(\.clearedSymbols).count, 3)
        level.updateLevelTarget(by: second)
        XCTAssertEqual(level.levelGoal.levelTarget.zodiac, (before ?? 0) - 3)
    }

    func testHammerCracksArmorWithoutDeletingSpriteOrGoal() throws {
        let (level, row) = try isolatedRow()
        let hit = try XCTUnwrap(level.useHammer(atColumn: 0, row: 0))
        XCTAssertTrue(hit.clearedSymbols.isEmpty)
        XCTAssertTrue(level.symbol(atColumn: 0, row: 0) === row[0])
        level.finishArmorTurn()
        XCTAssertEqual(level.useHammer(atColumn: 0, row: 0)?.clearedSymbols.count, 1)
        XCTAssertNil(level.symbol(atColumn: 0, row: 0))
    }

    func testArmoredSpecialAnchorSurvivesFourMatch() throws {
        let (level, row) = try isolatedRow(armor: false)
        let fourth = try XCTUnwrap(level.symbol(atColumn: 3, row: 0))
        fourth.type = .zodiac
        row[0].armorLayers = 1
        let chains = level.removeMatches()
        let specials = level.createSpecialSymbols(for: chains)
        XCTAssertEqual(specials.count, 1)
        XCTAssertTrue(level.symbol(atColumn: 0, row: 0) === row[0])
        XCTAssertNotEqual(specials.first?.column, 0)
    }

    func testVictoryBonusDoesNotEnhanceProtectedTiles() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_5"))
        let pieces = level.shuffle()
        pieces.forEach { $0.armorLayers = 1 }
        XCTAssertTrue(level.enhanceSymbols(num: 20).isEmpty)
        XCTAssertTrue(level.removeSpecialSymbols().isEmpty)
    }

    func testBossWeaknessesAndCadenceAreDistinct() {
        let tribute = Chain(chainType: .horizontal3)
        tribute.add(symbols: (0..<3).map { Symbol(column: $0, row: 0, symbolType: .redPocket) })
        var rat = BossEncounter(configuration: .init(kind: .rat, health: 24))
        rat.receive(chains: [tribute], cascadeDepth: 1)
        XCTAssertEqual(rat.health, 21)
        XCTAssertFalse(rat.advanceTurn())
        XCTAssertFalse(rat.advanceTurn())
        XCTAssertTrue(rat.advanceTurn())
        XCTAssertEqual(rat.tribute, .dumpling)
        rat.receive(chains: [tribute], cascadeDepth: 1)
        XCTAssertEqual(rat.health, 21)

        var ox = BossEncounter(configuration: .init(kind: .ox, health: 36))
        ox.receive(chains: [tribute], cascadeDepth: 3)
        XCTAssertEqual(ox.health, 36)
        tribute.resistedSymbols.insert(ObjectIdentifier(tribute.symbols[0]))
        ox.receive(chains: [tribute], cascadeDepth: 1)
        XCTAssertEqual(ox.health, 34)
        ox.receive(chains: [tribute], cascadeDepth: 1)
        XCTAssertEqual(ox.health, 34, "One armor hit cannot be credited twice")
        tribute.resistedSymbols.removeAll()
        var tiger = BossEncounter(configuration: .init(kind: .tiger, health: 40))
        tiger.receive(chains: [tribute], cascadeDepth: 1)
        XCTAssertEqual(tiger.health, 40)
        tiger.receive(chains: [tribute], cascadeDepth: 2)
        XCTAssertEqual(tiger.health, 37)

        var rabbit = BossEncounter(configuration: .init(kind: .rabbit, health: 40))
        let lanterns = Chain(chainType: .horizontal3)
        lanterns.add(symbols: (0..<3).map { Symbol(column: $0, row: 0, symbolType: .lantern) })
        let opened = Chain(chainType: .locks)
        opened.add(symbol: Symbol(column: 5, row: 5, symbolType: .lock))
        rabbit.receive(chains: [tribute], cascadeDepth: 3)
        XCTAssertEqual(rabbit.health, 40, "Only lanterns and locks hurt the Jade Rabbit")
        rabbit.receive(chains: [lanterns, opened], cascadeDepth: 1)
        XCTAssertEqual(rabbit.health, 35)
    }

    func testNewLevelsInAFinishedChapterOpenTheFirstNewLevel() throws {
        let saved = UserDefaults.standard.object(forKey: "firstLaunch")
        addTeardownBlock {
            if let saved { UserDefaults.standard.set(saved, forKey: "firstLaunch") }
            else { UserDefaults.standard.removeObject(forKey: "firstLaunch") }
        }
        let container = try ModelContainer(for: ZodiacRecord.self, LevelRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        // A player who finished the old 10-level Tiger chapter and is midway through Ox's old 10.
        for (zodiac, completed) in [(ChineseZodiac.tiger, 10), (.ox, 6)] {
            let record = ZodiacRecord(zodiacType: zodiac, isUnlocked: true)
            context.insert(record)
            for number in 1...10 {
                let level = LevelRecord(number: number, isUnlocked: number <= completed + 1, zodiacRecord: record)
                level.isComplete = number <= completed
                context.insert(level)
                record.levelRecords.append(level)
            }
        }
        try context.save()
        let game = GameModel()
        game.firstLaunch = false
        game.initializeRecords(modelContext: context)

        func level(_ zodiac: ChineseZodiac, _ number: Int) -> LevelRecord? {
            game.zodiacRecords.first { $0.zodiacType == zodiac }?.levelRecords.first { $0.number == number }
        }
        XCTAssertEqual(level(.tiger, 11)?.isUnlocked, true)
        XCTAssertEqual(level(.tiger, 12)?.isUnlocked, false)
        XCTAssertEqual(level(.ox, 11)?.isUnlocked, false, "Ox 10 is not beaten yet")
        XCTAssertEqual(level(.tiger, 15)?.isComplete, false)
    }

    /// An empty store on a later launch (the saved file could not be opened, so the game runs
    /// in memory) must still give the player a map to play, not a blank one.
    func testEmptyStoreAfterFirstLaunchIsSetUpAgain() throws {
        let saved = UserDefaults.standard.object(forKey: "firstLaunch")
        addTeardownBlock {
            if let saved { UserDefaults.standard.set(saved, forKey: "firstLaunch") }
            else { UserDefaults.standard.removeObject(forKey: "firstLaunch") }
        }
        let container = try ModelContainer(for: ZodiacRecord.self, LevelRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let game = GameModel()
        game.firstLaunch = false
        game.initializeRecords(modelContext: container.mainContext)

        XCTAssertEqual(game.zodiacRecords.count, Zodiac.all.count)
        let rat = try XCTUnwrap(game.zodiacRecords.first { $0.zodiacType == .rat })
        XCTAssertTrue(rat.isUnlocked)
        XCTAssertEqual(rat.levelRecords.filter(\.isUnlocked).map(\.number), [1])

        // Appearing again must not add a second set of records.
        game.initializeRecords(modelContext: container.mainContext)
        let stored = try container.mainContext.fetch(FetchDescriptor<ZodiacRecord>())
        XCTAssertEqual(stored.count, Zodiac.all.count)
    }

    func testUnopenableProgressStoreFallsBackInsteadOfCrashing() throws {
        let unopenable = URL(fileURLWithPath: "/dev/null/progress.store")
        let container = RecordManager.makeContainer(url: unopenable)
        let context = container.mainContext
        context.insert(ZodiacRecord(zodiacType: .rat, isUnlocked: true))
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ZodiacRecord>()).count, 1)
    }

    func testAnyWinEarnsAStarAndHigherStarsNeedTheirScores() {
        let goal = LevelGoal(firstStarScore: 1000, secondStarScore: 5000, thirdStarScore: 9000, levelTarget: LevelTarget())
        XCTAssertEqual(goal.stars(forWinningScore: 0), 1)
        XCTAssertEqual(goal.stars(forWinningScore: 4999), 1)
        XCTAssertEqual(goal.stars(forWinningScore: 5000), 2)
        XCTAssertEqual(goal.stars(forWinningScore: 9000), 3)
        XCTAssertEqual(goal.stars(forWinningScore: 50000), 3)
    }

    func testReplayTargetUsesTheImmediateNextStarAtScoreBoundaries() {
        let goal = LevelGoal(firstStarScore: 1000, secondStarScore: 5000, thirdStarScore: 9000, levelTarget: LevelTarget())
        let cases: [(score: Int, stars: Int, target: StarReplayTarget?)] = [
            (0, 1, StarReplayTarget(stars: 2, score: 5000, pointsNeeded: 5000)),
            (999, 1, StarReplayTarget(stars: 2, score: 5000, pointsNeeded: 4001)),
            (1000, 1, StarReplayTarget(stars: 2, score: 5000, pointsNeeded: 4000)),
            (4999, 1, StarReplayTarget(stars: 2, score: 5000, pointsNeeded: 1)),
            (5000, 2, StarReplayTarget(stars: 3, score: 9000, pointsNeeded: 4000)),
            (8999, 2, StarReplayTarget(stars: 3, score: 9000, pointsNeeded: 1)),
            (9000, 3, nil),
            (50000, 3, nil)
        ]
        for testCase in cases {
            let summary = VictorySummary(zodiac: .rat, level: 1, score: testCase.score, stars: testCase.stars,
                                         coins: 15, newlyUnlockedLevel: nil)
            XCTAssertEqual(summary.nextStarTarget(for: goal), testCase.target,
                           "Final score \(testCase.score) with \(testCase.stars) stars")
        }
    }

    func testReplayTargetIgnoresHistoricalBestScore() {
        let goal = LevelGoal(firstStarScore: 1000, secondStarScore: 5000, thirdStarScore: 9000, levelTarget: LevelTarget())
        let firstWin = VictorySummary(zodiac: .rat, level: 1, score: 4999, stars: 1, coins: 15,
                                      newlyUnlockedLevel: nil)
        let replay = VictorySummary(zodiac: .rat, level: 1, score: 4999, stars: 1, coins: 15,
                                    newlyUnlockedLevel: nil, previousBest: 100000)
        XCTAssertEqual(replay.nextStarTarget(for: goal), firstWin.nextStarTarget(for: goal))
        XCTAssertEqual(replay.nextStarTarget(for: goal), StarReplayTarget(stars: 2, score: 5000, pointsNeeded: 1))
    }

    func testReplayTargetRejectsMissingOrInvalidThresholds() {
        let summary = VictorySummary(zodiac: .rat, level: 1, score: 0, stars: 1, coins: 15,
                                     newlyUnlockedLevel: nil)
        let thresholds = [
            (0, 5000, 9000), (1000, 0, 9000), (1000, 5000, 0),
            (-1, 5000, 9000), (1000, 1000, 9000), (1000, 5000, 5000),
            (5000, 1000, 9000), (1000, 9000, 5000)
        ]
        for (first, second, third) in thresholds {
            let goal = LevelGoal(firstStarScore: first, secondStarScore: second, thirdStarScore: third,
                                 levelTarget: LevelTarget())
            XCTAssertNil(summary.nextStarTarget(for: goal), "Invalid thresholds: \(first), \(second), \(third)")
        }
    }

    func testReplayTargetRejectsMismatchedReceiptsAndDebugLevels() {
        let goal = LevelGoal(firstStarScore: 1000, secondStarScore: 5000, thirdStarScore: 9000, levelTarget: LevelTarget())
        let cases = [(1, 0, 0), (1, 0, 4), (1, 5000, 1), (1, 4999, 2), (1, -1, 1), (0, 0, 1), (-1, 0, 1)]
        for (level, score, stars) in cases {
            let summary = VictorySummary(zodiac: .rat, level: level, score: score, stars: stars, coins: 15,
                                         newlyUnlockedLevel: nil)
            XCTAssertNil(summary.nextStarTarget(for: goal), "Invalid receipt: level \(level), score \(score), stars \(stars)")
        }
    }

    func testReplayTargetHandlesTheLargestValidScoreWithoutOverflow() {
        let goal = LevelGoal(firstStarScore: 1, secondStarScore: 2, thirdStarScore: .max, levelTarget: LevelTarget())
        let summary = VictorySummary(zodiac: .rat, level: 1, score: .max - 1, stars: 2, coins: 15,
                                     newlyUnlockedLevel: nil)
        XCTAssertEqual(summary.nextStarTarget(for: goal), StarReplayTarget(stars: 3, score: .max, pointsNeeded: 1))
    }

    func testBestScoreKeepsTheHighestWinPerLevel() throws {
        let suite = "BestScoreStoreTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(BestScoreStore.best(for: .tiger, level: 5, defaults: defaults), 0)
        XCTAssertEqual(BestScoreStore.record(8000, for: .tiger, level: 5, defaults: defaults), 0)
        XCTAssertEqual(BestScoreStore.record(6000, for: .tiger, level: 5, defaults: defaults), 8000)
        XCTAssertEqual(BestScoreStore.best(for: .tiger, level: 5, defaults: defaults), 8000)
        XCTAssertEqual(BestScoreStore.record(9000, for: .tiger, level: 5, defaults: defaults), 8000)
        XCTAssertEqual(BestScoreStore.best(for: .tiger, level: 5, defaults: defaults), 9000)
        XCTAssertEqual(BestScoreStore.best(for: .tiger, level: 6, defaults: defaults), 0, "Levels keep separate bests")
        XCTAssertEqual(BestScoreStore.best(for: .ox, level: 5, defaults: defaults), 0, "Chapters keep separate bests")

        func summary(score: Int, previousBest: Int) -> VictorySummary {
            VictorySummary(zodiac: .tiger, level: 5, score: score, stars: 1, coins: 0, newlyUnlockedLevel: nil,
                           previousBest: previousBest)
        }
        XCTAssertFalse(summary(score: 8000, previousBest: 0).isNewBest, "A first win is not a new best")
        XCTAssertFalse(summary(score: 6000, previousBest: 8000).isNewBest)
        XCTAssertFalse(summary(score: 8000, previousBest: 8000).isNewBest)
        XCTAssertTrue(summary(score: 9000, previousBest: 8000).isNewBest)
    }

    func testJadeRabbitLocksTwoTilesInTheMarkedColumn() throws {
        let level = try XCTUnwrap(Level(filename: "Rabbit_Level_15"))
        _ = level.shuffle()
        let boss = try XCTUnwrap(level.boss)
        XCTAssertEqual(boss.configuration.kind, .rabbit)
        let column = boss.nextAttackLane % level.numColumns
        func locks() -> [Symbol] {
            (0..<level.numColumns).flatMap { c in (0..<level.numRows).compactMap { level.symbol(atColumn: c, row: $0) } }
                .filter { $0.type == .lock }
        }
        XCTAssertTrue(locks().isEmpty)
        let attacks = (0 ..< boss.configuration.attackInterval).filter { _ in level.advanceBossTurn() }.count
        XCTAssertEqual(attacks, 1)
        let locked = locks()
        XCTAssertEqual(locked.count, 2)
        XCTAssertTrue(locked.allSatisfy { $0.column == column && !$0.isMovable() })
        for piece in locked {
            XCTAssertEqual(level.tileAt(column: piece.column, row: piece.row)?.type, .lock)
        }
        // A raid never buries the board: protected pieces stay within the shared budget.
        for _ in 0..<90 { level.advanceBossTurn() }
        XCTAssertLessThanOrEqual(locks().count, 12)
    }

    func testBossMustBeDefeatedEvenAfterAllCollectionGoals() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_15"))
        level.levelGoal.levelTarget = LevelTarget()
        XCTAssertFalse(level.doesReachLevelTarget())
        let chain = Chain(chainType: .fiveEffect)
        chain.add(symbols: (0..<30).map { Symbol(column: $0, row: 0, symbolType: .redPocket) })
        level.boss?.receive(chains: [chain], cascadeDepth: 1)
        XCTAssertTrue(level.doesReachLevelTarget())
        XCTAssertEqual(level.boss?.health, 0)
    }

    func testAllChaptersHaveProgressionSnowAndFinalBoss() throws {
        for (chapter, count) in [("Rat", 17), ("Ox", 17), ("Tiger", 17), ("Rabbit", 17)] {
            var previousTier = 0
            var snowLevels = 0
            for number in 1...count {
                let level = try XCTUnwrap(Level(filename: "\(chapter)_Level_\(number)"))
                XCTAssertGreaterThanOrEqual(level.difficulty, previousTier)
                previousTier = level.difficulty
                if level.hasSnow { snowLevels += 1 }
                XCTAssertEqual(level.boss != nil, number == 15 || number == count,
                               "Keep the original guardian encounter and end the expansion with its rematch")
                let pieces = level.shuffle()
                XCTAssertFalse(level.possibleSwaps.isEmpty)
                XCTAssertTrue(level.removeMatches().isEmpty)
                for piece in pieces where piece.armorLayers > 0 {
                    XCTAssertTrue(piece.type.isNormalMatchable)
                    XCTAssertFalse(piece.isFrozen)
                }
            }
            XCTAssertGreaterThan(snowLevels, 0)
        }
    }

    func testExpansionContainsCompactChallengesAndDifferentGuardianArenas() throws {
        let playable = Zodiac.all.filter(\.isAvailable)
        XCTAssertEqual(playable.map(\.numLevels), [17, 17, 17, 17])
        for chapter in ["Rat", "Ox", "Tiger"] {
            let compact = try XCTUnwrap(Level(filename: "\(chapter)_Level_16"))
            XCTAssertEqual(compact.numColumns, 5)
            XCTAssertEqual(compact.numRows, 5)
            XCTAssertEqual(compact.possibleSymbols?.count, 4)
            XCTAssertTrue((8...12).contains(compact.maximumMoves))
            XCTAssertNil(compact.boss)
            XCTAssertNil(compact.timeLimit)
        }
        for zodiac in playable {
            let chapter = zodiac.zodiacType.name
            let original = try XCTUnwrap(LevelData.loadFrom(file: "\(chapter)_Level_15"))
            let rematch = try XCTUnwrap(LevelData.loadFrom(file: "\(chapter)_Level_17"))
            XCTAssertEqual(rematch.boss?.kind, original.boss?.kind)
            XCTAssertNotNil(rematch.boss)
            XCTAssertNotEqual(rematch.tiles, original.tiles, "A rematch must offer a different arena")
            XCTAssertTrue(rematch.tiles.joined().contains(0), "Arena openings create new routes")
            XCTAssertNil(rematch.timeLimit)
        }
    }

    func testChocolateGardenUsesExistingBlossomAndCollectionGoals() throws {
        let data = try XCTUnwrap(LevelData.loadFrom(file: "Rabbit_Level_16"))
        let chocolateCount = data.tiles.joined().filter { $0 == Tile.TileType.chocolate.rawValue }.count
        XCTAssertTrue((1...2).contains(chocolateCount), "Start with a small, containable pocket")
        let blossomLayers = try XCTUnwrap(data.jelly).joined().reduce(0, +)
        XCTAssertGreaterThan(blossomLayers, 0)
        let garden = try XCTUnwrap(Level(filename: "Rabbit_Level_16"))
        XCTAssertEqual(garden.levelGoal.levelTarget.jelly, blossomLayers)
        XCTAssertGreaterThan(garden.levelGoal.levelTarget.lantern ?? 0, 0)
        XCTAssertNil(garden.levelGoal.levelTarget.ingredient)
        XCTAssertNil(garden.timeLimit)
        XCTAssertNil(garden.boss)
    }

    func testFinishedFifteenLevelChaptersOpenOnlyTheFirstExpansionLevel() throws {
        let saved = UserDefaults.standard.object(forKey: "firstLaunch")
        addTeardownBlock {
            if let saved { UserDefaults.standard.set(saved, forKey: "firstLaunch") }
            else { UserDefaults.standard.removeObject(forKey: "firstLaunch") }
        }
        let container = try ModelContainer(for: ZodiacRecord.self, LevelRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        for zodiac in Zodiac.all.filter(\.isAvailable) {
            let record = ZodiacRecord(zodiacType: zodiac.zodiacType, isUnlocked: true)
            context.insert(record)
            for number in 1...15 {
                let level = LevelRecord(number: number, isUnlocked: true, zodiacRecord: record)
                level.isComplete = true
                level.stars = 3
                context.insert(level)
                record.levelRecords.append(level)
            }
        }
        try context.save()
        let game = GameModel()
        game.firstLaunch = false
        game.initializeRecords(modelContext: context)
        game.initializeRecords(modelContext: context)

        for record in game.zodiacRecords {
            XCTAssertEqual(record.levelRecords.count, 17, "Repeated initialization must not duplicate levels")
            let previousFinale = try XCTUnwrap(record.levelRecords.first { $0.number == 15 })
            XCTAssertTrue(previousFinale.isComplete)
            XCTAssertEqual(previousFinale.stars, 3)
            let firstNew = try XCTUnwrap(record.levelRecords.first { $0.number == 16 })
            XCTAssertTrue(firstNew.isUnlocked)
            XCTAssertFalse(firstNew.isComplete)
            XCTAssertEqual(firstNew.stars, 0)
            let rematch = try XCTUnwrap(record.levelRecords.first { $0.number == 17 })
            XCTAssertFalse(rematch.isUnlocked)
            XCTAssertFalse(rematch.isComplete)
        }
    }

    func testHazardsPreservePiecesAndRemainBounded() throws {
        let level = try XCTUnwrap(Level(filename: "Tiger_Level_15"))
        let pieces = level.shuffle()
        let identities = Set(pieces.map(ObjectIdentifier.init))
        let specials = pieces.filter { $0.isSpecialPowerUp }
        for _ in 0..<60 { level.advanceBossTurn() }
        let after = (0..<level.numColumns).flatMap { c in
            (0..<level.numRows).compactMap { level.symbol(atColumn: c, row: $0) }
        }
        XCTAssertEqual(Set(after.map(ObjectIdentifier.init)), identities)
        XCTAssertLessThanOrEqual(after.filter { $0.isFrozen || $0.armorLayers > 0 }.count, 12)
        XCTAssertTrue(specials.allSatisfy { $0.isSpecialPowerUp && !$0.isFrozen })
    }

    func testOnlyPaidMovesAdvanceBossClock() async throws {
        let game = GameModel()
        game.zodiac = Zodiac.all[0]
        game.selectLevel(15)
        await game.setupNewGame()
        game.level.boss = BossEncounter(configuration: .init(kind: .rat, health: 1000))
        await game.beginNextTurn()
        XCTAssertEqual(game.level.boss?.turns, 0)
        let swap = try XCTUnwrap(game.level.possibleSwaps.first)
        await game.handleSwipe(swap)
        XCTAssertEqual(game.level.boss?.turns, 1)
        await game.beginNextTurn()
        XCTAssertEqual(game.level.boss?.turns, 1)
    }

    func testMalformedProtectionGridIsRejected() throws {
        let data = try XCTUnwrap(LevelData.loadFrom(file: "Rat_Level_5"))
        XCTAssertTrue(data.hasValidLayout)
        data.armor = [[1]]
        XCTAssertFalse(data.hasValidLayout)
    }

    func testBossGameScreenFitsSmallPhone() async throws {
        for chapter in [2, 3] {
            try await assertBossScreenFitsSmallPhone(chapter: chapter)
        }
    }

    private func assertBossScreenFitsSmallPhone(chapter: Int) async throws {
        let game = GameModel()
        game.zodiac = Zodiac.all[chapter]
        game.selectLevel(15)
        await game.setupNewGame()
        let size = CGSize(width: 375, height: 667)
        let feedback = GameFeedback()
        let scene = GameScene(size: size, gameModel: game, themeModel: ThemeModel(),
                              settingModel: SettingModel(), feedback: feedback, reduceMotion: true)
        scene.setupLayerPosition()
        scene.addTiles()
        let symbols = (0..<game.numColumns).flatMap { c in
            (0..<game.numRows).compactMap { game.level.symbol(atColumn: c, row: $0) }
        }
        await scene.addSymbols(for: Set(symbols), shouldAnimate: false)
        scene.gameLayer.isHidden = false
        game.invokeCommand?(.refreshOverlays)
        scene.refreshSeason()
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        let texture = try XCTUnwrap(view.texture(from: scene, crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)))
        let board = UIImage(cgImage: texture.cgImage())
        let hud = GameStatusView(gameModel: game, feedback: feedback, onPause: {})
            .frame(width: size.width - 32)
        let hudImage = try XCTUnwrap(ImageRenderer(content: hud).uiImage)
        let boardTop = size.height / 2 - scene.tilesLayer.position.y - game.tileSize.height * CGFloat(game.numRows)
        XCTAssertGreaterThan(boardTop, 75 + hudImage.size.height, "Boss HUD must not cover tiles")
        XCTAssertGreaterThan(game.tileSize.width, 28, "Keep small-phone tiles playable")
        let content = ZStack(alignment: .top) {
            Image(uiImage: board).resizable().frame(width: size.width, height: size.height)
            hud.padding(.top, 75)
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Boss-small-phone-\(game.zodiac.zodiacType.name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/spring-boss-small-phone-\(game.zodiac.zodiacType.name).png"))
    }

    func testBossAndSnowVisuals() async throws {
        let game = GameModel()
        game.zodiac = Zodiac.all[2]
        game.selectLevel(15)
        await game.setupNewGame()
        let size = CGSize(width: 393, height: 852)
        let scene = GameScene(size: size, gameModel: game, themeModel: ThemeModel(),
                              settingModel: SettingModel(), feedback: GameFeedback(), reduceMotion: true)
        scene.setupLayerPosition()
        scene.addTiles()
        let symbols = (0..<game.numColumns).flatMap { c in
            (0..<game.numRows).compactMap { game.level.symbol(atColumn: c, row: $0) }
        }
        await scene.addSymbols(for: Set(symbols), shouldAnimate: false)
        scene.gameLayer.isHidden = false
        game.invokeCommand?(.refreshOverlays)
        scene.refreshSeason()
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        if let texture = view.texture(from: scene, crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)) {
            let image = UIImage(cgImage: texture.cgImage())
            let attachment = XCTAttachment(image: image)
            attachment.name = "Snowfang-board"
            attachment.lifetime = .keepAlways
            add(attachment)
            try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/spring-snow-board.png"))
        }
        let hud = BossEncounterView(encounter: try XCTUnwrap(game.bossStatus))
            .padding().frame(width: 353).background(Color.red)
        let renderer = ImageRenderer(content: hud)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/spring-boss-hud.png"))
    }
}
