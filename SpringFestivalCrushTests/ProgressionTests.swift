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
        for (chapter, count) in [("Rat", 15), ("Ox", 15), ("Tiger", 15), ("Rabbit", 15)] {
            var previousTier = 0
            var snowLevels = 0
            for number in 1...count {
                let level = try XCTUnwrap(Level(filename: "\(chapter)_Level_\(number)"))
                XCTAssertGreaterThanOrEqual(level.difficulty, previousTier)
                previousTier = level.difficulty
                if level.hasSnow { snowLevels += 1 }
                XCTAssertEqual(level.boss != nil, number == count)
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
