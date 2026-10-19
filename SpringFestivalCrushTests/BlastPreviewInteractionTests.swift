import XCTest
import SpriteKit
import SwiftUI
@testable import SpringFestivalCrush

/// Records the scene's existing dispatch paths without introducing random cascade resolution.
@MainActor
private final class BlastPreviewRoutingModel: GameModel {
    var regularSwaps: [Swap] = []
    var ruyiSwaps: [Swap] = []

    override func handleSwipe(_ swap: Swap) async { regularSwaps.append(swap) }
    override func useRuyiSwap(_ swap: Swap) async { ruyiSwaps.append(swap) }
}

@MainActor
final class BlastPreviewInteractionTests: XCTestCase {
    private struct Fixture {
        let game: BlastPreviewRoutingModel
        let settings: SettingModel
        let feedback: GameFeedback
        let scene: GameScene
        let view: SKView
        let source: Symbol
        let destination: Symbol
    }

    private struct PieceState: Equatable {
        let identity: ObjectIdentifier
        let column: Int
        let row: Int
        let type: SymbolType
        let armor: Int
        let armorHit: Bool
        let ice: Int
        let spritePosition: CGPoint?
    }

    private struct AttemptState: Equatable {
        let pieces: [PieceState]
        let goals: Data
        let inventory: [Int]
        let moves: Int
        let seconds: Int?
        let score: Int
        let guardianHealth: Int?
    }

    private func makeFixture(size: CGSize = CGSize(width: 320, height: 568),
                             zodiacIndex: Int = 0, levelNumber: Int = 1) async throws -> Fixture {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "swapCharges",
                    "hasSeenTutorial", "isPlayBackgroundMusic", "playSoundEffect", "musicVolume", "soundEffectsVolume",
                    "hapticsEnabled", "screenShakeEnabled", "reducedEffects", "idleHintsEnabled", "powerUpPreviewsEnabled"]
        let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        addTeardownBlock {
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        let game = BlastPreviewRoutingModel()
        game.zodiac = Zodiac.all[zodiacIndex]
        game.selectLevel(levelNumber)
        game.hasSeenTutorial = true
        await game.setupNewGame()
        let level = try XCTUnwrap(game.level)
        game.movesLeft = 20
        game.secondsLeft = nil

        let symbols = boardSymbols(in: level)
        let pairs = symbols.compactMap { source -> (Symbol, Symbol)? in
            guard source.column + 1 < level.numColumns,
                  let destination = level.symbol(atColumn: source.column + 1, row: source.row),
                  source.isMovable(), destination.isMovable(), !source.isFrozen, !destination.isFrozen else { return nil }
            return (source, destination)
        }.sorted {
            let centerColumn = level.numColumns / 2
            let centerRow = level.numRows / 2
            let firstDistance = abs($0.0.column - centerColumn) + abs($0.0.row - centerRow)
            let secondDistance = abs($1.0.column - centerColumn) + abs($1.0.row - centerRow)
            if firstDistance != secondDistance { return firstDistance < secondDistance }
            return ($0.0.row, $0.0.column) < ($1.0.row, $1.0.column)
        }
        let pair = try XCTUnwrap(pairs.first)
        pair.0.type = .lightning
        pair.1.type = .dumpling
        for symbol in [pair.0, pair.1] {
            symbol.armorLayers = 0
            symbol.armorHitThisTurn = false
            symbol.iceLayer = 0
        }

        let settings = SettingModel()
        settings.isPlayBackgroundMusic = false
        settings.playSoundEffect = false
        settings.hapticsEnabled = false
        settings.idleHintsEnabled = false
        settings.powerUpPreviewsEnabled = true
        let feedback = GameFeedback()
        let scene = GameScene(size: size, gameModel: game, themeModel: ThemeModel(),
                              settingModel: settings, feedback: feedback, reduceMotion: true)
        // The model is already in progress, so the initializer's setup task cannot redeal it.
        scene.setupLayerPosition()
        scene.addTiles()
        await scene.addSymbols(for: Set(symbols), shouldAnimate: false)
        scene.gameLayer.isHidden = false
        scene.setUserInteraction(enabled: true)

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
            scene.cancelBlastPreview()
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            game.onTapBack()
        }
        return Fixture(game: game, settings: settings, feedback: feedback, scene: scene, view: view,
                       source: pair.0, destination: pair.1)
    }

    private func boardSymbols(in level: Level) -> [Symbol] {
        (0..<level.numRows).flatMap { row in
            (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
        }
    }

    private func state(of fixture: Fixture) throws -> AttemptState {
        let game = fixture.game
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return AttemptState(pieces: boardSymbols(in: game.level).map {
            PieceState(identity: ObjectIdentifier($0), column: $0.column, row: $0.row, type: $0.type,
                       armor: $0.armorLayers, armorHit: $0.armorHitThisTurn, ice: $0.iceLayer,
                       spritePosition: $0.sprite?.position)
        }, goals: try encoder.encode(game.level.levelGoal.levelTarget),
           inventory: [game.coins, game.lives, game.hammerCharges, game.shuffleCharges, game.swapCharges],
           moves: game.movesLeft, seconds: game.secondsLeft, score: game.score,
           guardianHealth: game.bossStatus?.health)
    }

    private func showPreview(in fixture: Fixture) throws {
        XCTAssertTrue(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        XCTAssertNil(fixture.scene.moveBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        XCTAssertTrue(fixture.feedback.blastPreviewVisible)
        XCTAssertNotNil(fixture.scene.pendingBlastPreview)
    }

    private func assertCleared(_ fixture: Fixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(fixture.feedback.blastPreviewVisible, file: file, line: line)
        XCTAssertNil(fixture.scene.pendingBlastPreview, file: file, line: line)
        XCTAssertTrue(fixture.scene.blastPreviewLayer.children.isEmpty, file: file, line: line)
    }

    func testPreviewIsReadOnlyAndDrawsOnlyClippedDirectHits() async throws {
        let fixture = try await makeFixture()
        let before = try state(of: fixture)
        try showPreview(in: fixture)
        XCTAssertEqual(try state(of: fixture), before)
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.ruyiSwaps.isEmpty)
        let preview = try XCTUnwrap(fixture.scene.pendingBlastPreview?.preview)
        XCTAssertEqual(fixture.scene.blastPreviewLayer.children.count, preview.affectedCells.count)
        XCTAssertTrue(fixture.scene.blastPreviewLayer.parent === fixture.scene.cropLayer)
        XCTAssertTrue(fixture.scene.cropLayer.maskNode === fixture.scene.maskLayer)
        for cell in preview.affectedCells {
            let node = try XCTUnwrap(fixture.scene.blastPreviewLayer.childNode(withName: "blast-preview-\(cell.column)-\(cell.row)") as? SKShapeNode)
            let expectedPosition = fixture.scene.pointFor(column: cell.column, row: cell.row)
            XCTAssertEqual(node.position.x, expectedPosition.x, accuracy: 0.001)
            XCTAssertEqual(node.position.y, expectedPosition.y, accuracy: 0.001)
            XCTAssertEqual(node.fillColor.cgColor.alpha, 0)
            XCTAssertFalse(node.hasActions())
        }
    }

    func testReturningOutsideCancellingAndPausingNeverDispatch() async throws {
        let fixture = try await makeFixture()
        let before = try state(of: fixture)
        try showPreview(in: fixture)
        XCTAssertNil(fixture.scene.moveBoardTouch(column: fixture.source.column, row: fixture.source.row))
        assertCleared(fixture)
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.source.column, row: fixture.source.row))

        try showPreview(in: fixture)
        XCTAssertNil(fixture.scene.moveBoardTouch(column: nil, row: nil))
        assertCleared(fixture)
        XCTAssertNil(fixture.scene.endBoardTouch(column: nil, row: nil))

        try showPreview(in: fixture)
        fixture.scene.touchesCancelled([], with: nil)
        assertCleared(fixture)
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))

        try showPreview(in: fixture)
        fixture.scene.setFeedbackPaused(true)
        assertCleared(fixture)
        fixture.scene.setFeedbackPaused(false)
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        XCTAssertEqual(try state(of: fixture), before)
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
    }

    func testValidReleaseDispatchesOnceAndDuplicateEndDoesNotCancelIt() async throws {
        let fixture = try await makeFixture()
        try showPreview(in: fixture)
        let dispatch = try XCTUnwrap(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        await dispatch.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)
        XCTAssertTrue(fixture.game.regularSwaps[0].symbolA === fixture.source)
        XCTAssertTrue(fixture.game.regularSwaps[0].symbolB === fixture.destination)
        assertCleared(fixture)
    }

    func testPauseDisableRemovalAndRestartInvalidatePendingReleases() async throws {
        let fixture = try await makeFixture()
        try showPreview(in: fixture)
        let pausedDispatch = try XCTUnwrap(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        fixture.scene.setFeedbackPaused(true)
        fixture.scene.setFeedbackPaused(false)
        await pausedDispatch.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)

        try showPreview(in: fixture)
        fixture.settings.powerUpPreviewsEnabled = false
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        assertCleared(fixture)
        fixture.settings.powerUpPreviewsEnabled = true

        try showPreview(in: fixture)
        fixture.scene.setUserInteraction(enabled: false)
        fixture.scene.setUserInteraction(enabled: true)
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        assertCleared(fixture)

        try showPreview(in: fixture)
        let replacedDispatch = try XCTUnwrap(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        fixture.game.selectLevel(1)
        await replacedDispatch.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        fixture.scene.removeAllSymbols()
        assertCleared(fixture)
    }

    func testDisabledOrdinaryAndRuyiSwapsUseImmediateRouting() async throws {
        let fixture = try await makeFixture()
        fixture.settings.powerUpPreviewsEnabled = false
        XCTAssertTrue(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        let disabledDispatch = try XCTUnwrap(fixture.scene.moveBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        await disabledDispatch.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)
        assertCleared(fixture)

        fixture.settings.powerUpPreviewsEnabled = true
        fixture.source.type = .firecracker
        XCTAssertTrue(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        let ordinaryDispatch = try XCTUnwrap(fixture.scene.moveBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        // A second gesture cannot erase an ordinary swap already committed by the first move.
        XCTAssertFalse(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        await ordinaryDispatch.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 2)
        assertCleared(fixture)

        fixture.source.type = .lightning
        fixture.game.swapModeActive = true
        XCTAssertTrue(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        let ruyiDispatch = try XCTUnwrap(fixture.scene.moveBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        await ruyiDispatch.value
        XCTAssertEqual(fixture.game.ruyiSwaps.count, 1)
        XCTAssertEqual(fixture.game.regularSwaps.count, 2)
        assertCleared(fixture)

        fixture.game.swapModeActive = false
        fixture.game.isTutorialHintActive = true
        XCTAssertTrue(fixture.scene.beginBoardTouch(column: fixture.source.column, row: fixture.source.row))
        let tutorialDispatch = try XCTUnwrap(fixture.scene.moveBoardTouch(column: fixture.destination.column, row: fixture.destination.row))
        await tutorialDispatch.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 3)
        assertCleared(fixture)
    }

    func testPreviewSurvivesOnlyTheOriginalLivePair() async throws {
        let fixture = try await makeFixture()
        try showPreview(in: fixture)
        fixture.game.level.performSwap(Swap(symbolA: fixture.source, symbolB: fixture.destination))
        XCTAssertNil(fixture.scene.endBoardTouch(column: fixture.source.column, row: fixture.source.row))
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        assertCleared(fixture)
    }

    func testStaticPreviewRendersOnSmallPhoneTabletAndNewGuardianBoard() async throws {
        for (name, size, zodiacIndex, level) in [
            ("small-phone", CGSize(width: 320, height: 568), 0, 1),
            ("tablet", CGSize(width: 768, height: 1024), 0, 1),
            ("Rabbit-17-small-phone", CGSize(width: 320, height: 568), 3, 17)
        ] {
            let fixture = try await makeFixture(size: size, zodiacIndex: zodiacIndex, levelNumber: level)
            try showPreview(in: fixture)
            let texture = try XCTUnwrap(fixture.view.texture(from: fixture.scene,
                crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)))
            let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
            attachment.name = "Blast-preview-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
