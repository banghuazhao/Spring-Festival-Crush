import XCTest
import SpriteKit
import SwiftUI
@testable import SpringFestivalCrush

@MainActor
final class DeliveryTeachingTests: XCTestCase {
    private let newKeys = [
        "Power-up Goals", "Gift Delivery",
        "Activate the pictured power-ups to meet their goals. Chain reactions count too. Creating a power-up does not count, and swapping two power-ups together is not required.",
        "Clear tiles beneath gifts to help them reach a marked exit on the board's bottom row. A higher ledge is not an exit. Blasts and the Hammer can also collect gifts directly.",
        "Lightning activations", "Lucky Five activations", "Blast Tile activations", "gifts to deliver", "Zodiac tiles",
        "After 7 quiet seconds, highlight a possible move that helps your remaining goals when available. Hints never spend a move or use a tool."
    ]

    private func lessonData(targets: [String: Int] = [:], tile: Int = 1) throws -> LevelData {
        let object: [String: Any] = [
            "tiles": [[1, 1, 1], [1, tile, 1], [1, 1, 1]], "moves": 20,
            "levelGoal": ["firstStarScore": 100, "secondStarScore": 200, "thirdStarScore": 300,
                          "levelTarget": targets]
        ]
        return try JSONDecoder().decode(LevelData.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testNewRulesBeginAtMasteryAndDeliveryWithoutChangingEarlierLessons() {
        let curriculum = RuleCurriculum.shared
        XCTAssertEqual(curriculum.introductions[.powerUpGoals], LevelRef(zodiac: .rat, number: 18))
        XCTAssertEqual(curriculum.introductions[.giftDelivery], LevelRef(zodiac: .rat, number: 19))
        XCTAssertTrue(curriculum.lessons(for: LevelRef(zodiac: .rat, number: 18)).contains(.powerUpGoals))
        XCTAssertTrue(curriculum.lessons(for: LevelRef(zodiac: .rat, number: 19)).contains(.giftDelivery))
        for zodiac in [ChineseZodiac.rat, .ox, .tiger, .rabbit] {
            for number in 1...17 {
                let lessons = curriculum.lessons(for: LevelRef(zodiac: zodiac, number: number))
                XCTAssertFalse(lessons.contains(.powerUpGoals))
                XCTAssertFalse(lessons.contains(.giftDelivery))
            }
        }
        XCTAssertFalse(curriculum.isUnlocked(.giftDelivery) { $0 == LevelRef(zodiac: .rat, number: 18) })
        XCTAssertTrue(curriculum.isUnlocked(.giftDelivery) { $0 == LevelRef(zodiac: .rat, number: 19) })
    }

    func testActivationLessonRequiresPositiveGoalsRatherThanOnlyPowerUpTiles() throws {
        let earlier = LevelRef(zodiac: .rat, number: 18)
        let later = LevelRef(zodiac: .rat, number: 19)
        for key in ["lightningCombos", "fiveCombos", "enhancedCombos"] {
            let zero = try lessonData(targets: [key: 0], tile: Tile.TileType.lightning.rawValue)
            let positive = try lessonData(targets: [key: 2])
            let curriculum = RuleCurriculum(levels: [(earlier, zero), (later, positive)])
            XCTAssertEqual(curriculum.introductions[.powerUpGoals], later, key)
            XCTAssertFalse(curriculum.lessons(for: earlier).contains(.powerUpGoals), key)
        }
        let onlyPower = try lessonData(tile: Tile.TileType.five.rawValue)
        XCTAssertNil(RuleCurriculum(levels: [(earlier, onlyPower)]).introductions[.powerUpGoals])
    }

    func testDeliveryLessonDetectsEitherAnEscortTargetOrAGiftTile() throws {
        let ref = LevelRef(zodiac: .rat, number: 19)
        for data in [try lessonData(targets: ["ingredient": 2]),
                     try lessonData(tile: Tile.TileType.ingredient.rawValue)] {
            XCTAssertEqual(RuleCurriculum(levels: [(ref, data)]).introductions[.giftDelivery], ref)
        }
        XCTAssertNil(RuleCurriculum(levels: [(ref, try lessonData())]).introductions[.giftDelivery])
    }

    func testBossMapBadgesUseActualBossesRatherThanTheLastLevel() {
        for zodiac in [ChineseZodiac.rat, .ox, .tiger, .rabbit] {
            XCTAssertTrue(CampaignLevelMetadata.isBoss(zodiac: zodiac, level: 15))
            XCTAssertTrue(CampaignLevelMetadata.isBoss(zodiac: zodiac, level: 17))
            XCTAssertFalse(CampaignLevelMetadata.isBoss(zodiac: zodiac, level: 18))
            XCTAssertFalse(CampaignLevelMetadata.isBoss(zodiac: zodiac, level: 19))
            XCTAssertFalse(CampaignLevelMetadata.isBoss(zodiac: zodiac, level: 0))
        }
    }

    private func makeNativeScene(zodiacIndex: Int, levelNumber: Int, size: CGSize,
                                 forceGiftGoal: Bool = false) async throws -> (GameModel, GameScene, SKView) {
        let keys = ["hasSeenTutorial", "isPlayBackgroundMusic", "playSoundEffect", "hapticsEnabled", "idleHintsEnabled"]
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        let game = GameModel()
        game.zodiac = Zodiac.all[zodiacIndex]
        game.selectLevel(levelNumber)
        game.hasSeenTutorial = true
        await game.setupNewGame()
        if forceGiftGoal { game.level.levelGoal.levelTarget.ingredient = 2 }
        let settings = SettingModel()
        settings.isPlayBackgroundMusic = false
        settings.playSoundEffect = false
        settings.hapticsEnabled = false
        settings.idleHintsEnabled = false
        let scene = GameScene(size: size, gameModel: game, themeModel: ThemeModel(),
                              settingModel: settings, feedback: GameFeedback(), reduceMotion: true)
        scene.setupLayerPosition()
        scene.addTiles()
        let symbols = (0..<game.numRows).flatMap { row in
            (0..<game.numColumns).compactMap { game.level.symbol(atColumn: $0, row: row) }
        }
        await scene.addSymbols(for: Set(symbols), shouldAnimate: false)
        scene.gameLayer.isHidden = false
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        let controller = UIViewController()
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.presentScene(scene)
        addTeardownBlock { @MainActor in
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            game.onTapBack()
        }
        return (game, scene, view)
    }

    func testAllDeliveryBoardsMarkEveryBottomCellWithoutChangingTheBoard() async throws {
        for (zodiacIndex, size) in [(0, CGSize(width: 320, height: 568)),
                                    (1, CGSize(width: 320, height: 568)),
                                    (2, CGSize(width: 320, height: 568)),
                                    (3, CGSize(width: 320, height: 568)),
                                    (3, CGSize(width: 768, height: 1024))] {
            let (game, scene, view) = try await makeNativeScene(zodiacIndex: zodiacIndex, levelNumber: 19, size: size)
            let before = (game.movesLeft, game.score, game.level.levelGoal.levelTarget.ingredient)
            let bottomColumns = (0..<game.numColumns).filter { game.level.tileAt(column: $0, row: 0) != nil }
            XCTAssertEqual(scene.deliveryExitLayer.children.count, bottomColumns.count)
            XCTAssertTrue(scene.deliveryExitLayer.parent === scene.gameLayer)
            XCTAssertFalse(scene.deliveryExitLayer.parent === scene.cropLayer)
            XCTAssertEqual(scene.deliveryExitLayer.position, scene.symbolsLayer.position)
            XCTAssertFalse(scene.deliveryExitLayer.isUserInteractionEnabled)
            for column in bottomColumns {
                let marker = try XCTUnwrap(scene.deliveryExitLayer.childNode(withName: "delivery-exit-\(column)") as? SKShapeNode)
                XCTAssertEqual(marker.position.x, scene.pointFor(column: column, row: 0).x, accuracy: 0.001)
                XCTAssertLessThan(marker.calculateAccumulatedFrame().maxY, 0)
                XCTAssertGreaterThanOrEqual(marker.calculateAccumulatedFrame().minY, -12.5)
                XCTAssertFalse(marker.hasActions())
                XCTAssertNil(marker.physicsBody)
                XCTAssertFalse(marker.isUserInteractionEnabled)
                let bottomInScene = scene.convert(CGPoint(x: marker.position.x, y: -12.5), from: scene.deliveryExitLayer)
                XCTAssertGreaterThan(bottomInScene.y, -size.height / 2 + 120,
                                     "Delivery exits should remain clear of the small-phone dock reserve")
            }
            scene.refreshDeliveryExits()
            XCTAssertEqual(scene.deliveryExitLayer.children.count, bottomColumns.count, "Refreshing must not duplicate exits")
            XCTAssertEqual(game.movesLeft, before.0)
            XCTAssertEqual(game.score, before.1)
            XCTAssertEqual(game.level.levelGoal.levelTarget.ingredient, before.2)
            let texture = try XCTUnwrap(view.texture(from: scene,
                crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)))
            let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
            attachment.name = "Gift-exits-\(game.zodiac.zodiacType.name)-\(Int(size.width))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testHigherLedgesHaveNoExitsAndMarkersClearOnNonDeliveryBoards() async throws {
        let (game, scene, _) = try await makeNativeScene(zodiacIndex: 3, levelNumber: 17,
            size: CGSize(width: 320, height: 568), forceGiftGoal: true)
        var higherLedges = 0
        for column in 0..<game.numColumns {
            let marker = scene.deliveryExitLayer.childNode(withName: "delivery-exit-\(column)")
            if game.level.tileAt(column: column, row: 0) == nil {
                XCTAssertNil(marker)
                if (1..<game.numRows).contains(where: { game.level.tileAt(column: column, row: $0) != nil }) {
                    higherLedges += 1
                }
            } else {
                XCTAssertNotNil(marker)
            }
        }
        XCTAssertGreaterThan(higherLedges, 0, "The fixture must have playable ledges above bottom-row holes")
        scene.removeAllTiles()
        XCTAssertTrue(scene.deliveryExitLayer.children.isEmpty)
        scene.addTiles()
        XCTAssertFalse(scene.deliveryExitLayer.children.isEmpty)
        game.level.levelGoal.levelTarget.ingredient = 0
        scene.refreshDeliveryExits()
        XCTAssertTrue(scene.deliveryExitLayer.children.isEmpty)
        game.selectLevel(1)
        scene.removeAllTiles()
        scene.setupLayerPosition()
        scene.addTiles()
        XCTAssertTrue(scene.deliveryExitLayer.children.isEmpty)
    }

    func testNewTeachingAndGoalNamesAreLocalizedInAllThreeLanguages() throws {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings",
                inDirectory: nil, forLocalization: language))
            let strings = try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
            for key in newKeys {
                let value = try XCTUnwrap(strings[key], "\(language) missing \(key)")
                XCTAssertFalse(value.isEmpty)
                if language != "en" { XCTAssertNotEqual(value, key) }
            }
        }
    }
}
