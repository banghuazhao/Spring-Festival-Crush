import XCTest
import SpriteKit
import SwiftUI
@testable import SpringFestivalCrush

/// Records real accessibility routing without making the assertions depend on random cascades.
@MainActor
private final class AccessibilityRoutingModel: GameModel {
    var runsGameplay = false
    var regularSwaps: [Swap] = []
    var ruyiSwaps: [Swap] = []
    var hammerTargets: [BoardAccessibilityCell] = []

    override func handleSwipe(_ swap: Swap) async {
        regularSwaps.append(swap)
        if runsGameplay { await super.handleSwipe(swap) }
    }
    override func useRuyiSwap(_ swap: Swap) async {
        ruyiSwaps.append(swap)
        if runsGameplay { await super.useRuyiSwap(swap) }
    }
    override func useHammer(atColumn column: Int, row: Int) async {
        hammerTargets.append(BoardAccessibilityCell(column: column, row: row))
        if runsGameplay { await super.useHammer(atColumn: column, row: row) }
    }
}

@MainActor
final class BoardAccessibilityTests: XCTestCase {
    private struct Fixture {
        let game: AccessibilityRoutingModel
        let scene: GameScene
        let view: BoardAccessibilityView
        let source: Symbol
        let destination: Symbol

        var sourceCell: BoardAccessibilityCell {
            BoardAccessibilityCell(column: source.column, row: source.row)
        }

        var destinationCell: BoardAccessibilityCell {
            BoardAccessibilityCell(column: destination.column, row: destination.row)
        }
    }

    private func makeFixture(size: CGSize = CGSize(width: 320, height: 568),
                             zodiacIndex: Int = 0, levelNumber: Int = 1,
                             preserveBoard: Bool = false) async throws -> Fixture {
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
        UserDefaults.standard.set(3, forKey: "hammerCharges")
        UserDefaults.standard.set(3, forKey: "swapCharges")
        let game = AccessibilityRoutingModel()
        game.zodiac = Zodiac.all[zodiacIndex]
        game.selectLevel(levelNumber)
        game.hasSeenTutorial = true
        await game.setupNewGame()
        game.movesLeft = 20
        game.secondsLeft = nil
        let level = try XCTUnwrap(game.level)
        let symbols = (0..<level.numRows).flatMap { row in
            (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
        }
        let pair = try XCTUnwrap(symbols.compactMap { source -> (Symbol, Symbol)? in
            guard source.column + 1 < level.numColumns,
                  let destination = level.symbol(atColumn: source.column + 1, row: source.row),
                  source.isMovable(), destination.isMovable() else { return nil }
            return (source, destination)
        }.first)
        if !preserveBoard {
            pair.0.type = .firecracker
            pair.1.type = .dumpling
        }

        let settings = SettingModel()
        settings.isPlayBackgroundMusic = false
        settings.playSoundEffect = false
        settings.hapticsEnabled = false
        settings.idleHintsEnabled = false
        let scene = GameScene(size: size, gameModel: game, themeModel: ThemeModel(),
                              settingModel: settings, feedback: GameFeedback(), reduceMotion: true)
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
        let view = BoardAccessibilityView(frame: CGRect(origin: .zero, size: size))
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.presentScene(scene)
        view.refreshAccessibility()
        addTeardownBlock { @MainActor in
            scene.cancelBlastPreview()
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            game.onTapBack()
        }
        return Fixture(game: game, scene: scene, view: view, source: pair.0, destination: pair.1)
    }

    func testCellsHaveTopLeftReadingOrderAndStableIdentityAfterTileChanges() async throws {
        let fixture = try await makeFixture()
        let cells = fixture.view.tileElements.map(\.cell)
        let level = try XCTUnwrap(fixture.game.level)
        let expected = (0..<level.numRows).reversed().flatMap { row in
            (0..<level.numColumns).compactMap { column -> BoardAccessibilityCell? in
                guard level.tileAt(column: column, row: row) != nil else { return nil }
                return BoardAccessibilityCell(column: column, row: row)
            }
        }
        XCTAssertEqual(cells, expected)
        let original = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.sourceCell })
        let originalLabel = original.accessibilityLabel
        fixture.source.type = .vaultLock
        fixture.source.iceLayer = 2
        fixture.source.armorLayers = 3
        level.tileAt(column: fixture.source.column, row: fixture.source.row)?.jellyCount = 2
        fixture.view.refreshAccessibility()
        let updated = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.sourceCell })
        XCTAssertTrue(original === updated, "Falling and replacement must not recreate the focused board cell")
        XCTAssertNotEqual(updated.accessibilityLabel, originalLabel)
        let label = try XCTUnwrap(updated.accessibilityLabel)
        XCTAssertTrue(label.contains(fixture.sourceCell.positionLabel(in: level)))
        XCTAssertTrue(label.contains(String(localized: "Lock, hits remaining: \(3)")))
        XCTAssertTrue(label.contains(String(localized: "Ice layers: \(2)")))
        XCTAssertTrue(label.contains(String(localized: "Gold frame layers: \(3)")))
        XCTAssertTrue(label.contains(String(localized: "Moon blossom layers: \(2)")))
        XCTAssertTrue(label.contains(String(localized: "Cannot be swapped")))
    }

    func testAccessibilityFramesFollowSceneCoordinatesOnPhoneTabletAndGuardianBoard() async throws {
        for (size, zodiacIndex, levelNumber) in [
            (CGSize(width: 320, height: 568), 0, 1),
            (CGSize(width: 768, height: 1024), 0, 1),
            (CGSize(width: 320, height: 568), 3, 17)
        ] {
            let fixture = try await makeFixture(size: size, zodiacIndex: zodiacIndex, levelNumber: levelNumber)
            for element in fixture.view.tileElements {
                let localPoint = fixture.scene.pointFor(column: element.cell.column, row: element.cell.row)
                let scenePoint = fixture.scene.convert(localPoint, from: fixture.scene.symbolsLayer)
                let expected = fixture.view.convert(scenePoint, from: fixture.scene)
                let frame = element.accessibilityFrameInContainerSpace
                XCTAssertEqual(frame.midX, expected.x, accuracy: 0.5)
                XCTAssertEqual(frame.midY, expected.y, accuracy: 0.5)
                XCTAssertGreaterThan(frame.width, 0)
                XCTAssertGreaterThan(frame.height, 0)
                XCTAssertTrue(fixture.view.bounds.contains(frame), "The accessibility target must match a visible tile")
            }
        }
    }

    func testDoubleTapSelectsThenSwapsAndCannotDispatchTwice() async throws {
        let fixture = try await makeFixture()
        let source = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.sourceCell })
        let destination = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.destinationCell })
        XCTAssertTrue(source.accessibilityActivate())
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(destination.accessibilityActivate())
        let pending = try XCTUnwrap(fixture.view.pendingAction)
        _ = destination.accessibilityActivate()
        await pending.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)
        XCTAssertTrue(fixture.game.regularSwaps[0].symbolA === fixture.source)
        XCTAssertTrue(fixture.game.regularSwaps[0].symbolB === fixture.destination)
    }

    func testDirectionalActionsRoutePowerUpsRuyiSwapAndHammer() async throws {
        let fixture = try await makeFixture()
        fixture.source.type = .lightning
        fixture.view.refreshAccessibility()
        let source = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.sourceCell })
        let right = try XCTUnwrap(source.accessibilityCustomActions?.first { $0.name == String(localized: "Swap right") })
        XCTAssertTrue(try XCTUnwrap(right.actionHandler)(right))
        await fixture.view.pendingAction?.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)
        XCTAssertNil(fixture.scene.pendingBlastPreview, "VoiceOver actions must not require a held touch")

        fixture.game.swapModeActive = true
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        await fixture.view.pendingAction?.value
        XCTAssertEqual(fixture.game.ruyiSwaps.count, 1)
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)

        fixture.game.hammerModeActive = true
        fixture.source.type = .vaultLock
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.activate(fixture.sourceCell))
        await fixture.view.pendingAction?.value
        XCTAssertEqual(fixture.game.hammerTargets, [fixture.sourceCell], "Blockers must remain available to Hammer")
    }

    func testCancelNonadjacentAndBlockedTargetsNeverSpendAMove() async throws {
        let fixture = try await makeFixture()
        XCTAssertTrue(fixture.view.activate(fixture.sourceCell))
        XCTAssertTrue(fixture.view.activate(fixture.sourceCell))
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)

        let distant = try XCTUnwrap(fixture.view.tileElements.first {
            abs($0.cell.column - fixture.source.column) + abs($0.cell.row - fixture.source.row) > 1
        })
        _ = fixture.view.activate(fixture.sourceCell)
        _ = distant.accessibilityActivate()
        XCTAssertNil(fixture.view.pendingAction)
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)

        fixture.destination.type = .lock
        fixture.view.refreshAccessibility()
        XCTAssertFalse(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        XCTAssertFalse(fixture.view.swap(fixture.sourceCell, columnDelta: -fixture.source.column - 1, rowDelta: 0))
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
    }

    func testHammerCanTargetAGiftWithoutUsingAMove() async throws {
        let fixture = try await makeFixture()
        fixture.game.runsGameplay = true
        // Exercise real rules and accessibility updates without waiting for SKActions:
        // simulator window activation and drawables must not control rule completion.
        fixture.game.invokeCommandAsync = { _ in }
        fixture.game.level.levelGoal.levelTarget.zodiac = 10_000
        fixture.game.level.levelGoal.levelTarget.ingredient = 1
        fixture.source.type = .ingredient
        let cell = fixture.sourceCell
        let hammerCharges = fixture.game.hammerCharges
        let moves = fixture.game.movesLeft
        fixture.game.hammerModeActive = true
        fixture.view.refreshAccessibility()
        let element = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == cell })
        XCTAssertTrue(element.accessibilityActivate())
        await fixture.view.pendingAction?.value
        XCTAssertEqual(fixture.game.hammerTargets, [cell])
        XCTAssertEqual(fixture.game.hammerCharges, hammerCharges - 1)
        XCTAssertEqual(fixture.game.movesLeft, moves)
        XCTAssertEqual(fixture.game.level.levelGoal.levelTarget.ingredient, 0)
        XCTAssertFalse(fixture.game.isResolvingBoard)
        XCTAssertFalse(fixture.game.hammerModeActive)
    }

    func testNativeSwapResolvesRealCascadesSpendsOneMoveAndRefreshesFocusedCells() async throws {
        let fixture = try await makeFixture(preserveBoard: true)
        fixture.game.runsGameplay = true
        // Rendering is covered separately; cascade rules and labels must also resolve
        // when the simulator cannot draw an animation frame for this test's window.
        fixture.game.invokeCommandAsync = { _ in }
        let level = try XCTUnwrap(fixture.game.level)
        level.levelGoal.levelTarget.zodiac = 10_000
        level.detectPossibleSwaps()
        let swap = try XCTUnwrap(level.possibleSwaps.first)
        let sourceCell = BoardAccessibilityCell(column: swap.symbolA.column, row: swap.symbolA.row)
        let dc = swap.symbolB.column - swap.symbolA.column
        let dr = swap.symbolB.row - swap.symbolA.row
        let originalElements = Dictionary(uniqueKeysWithValues: fixture.view.tileElements.map { ($0.cell, $0) })
        let moves = fixture.game.movesLeft
        XCTAssertTrue(fixture.view.swap(sourceCell, columnDelta: dc, rowDelta: dr))
        let pending = try XCTUnwrap(fixture.view.pendingAction)
        XCTAssertFalse(fixture.view.swap(sourceCell, columnDelta: dc, rowDelta: dr))
        await pending.value
        XCTAssertEqual(fixture.game.regularSwaps.count, 1)
        XCTAssertEqual(fixture.game.movesLeft, moves - 1)
        XCTAssertGreaterThan(fixture.game.score, 0)
        XCTAssertFalse(fixture.game.isResolvingBoard)
        XCTAssertEqual(fixture.game.gameState, .inProgress)
        for element in fixture.view.tileElements {
            XCTAssertTrue(element === originalElements[element.cell])
            XCTAssertEqual(element.accessibilityLabel, element.cell.label(in: level, zodiac: fixture.game.zodiac))
            XCTAssertFalse(element.accessibilityTraits.contains(.notEnabled))
        }
    }

    func testSwiftUIHostRefreshesNativeBoardAfterPublishedModelChanges() async throws {
        let fixture = try await makeFixture()
        fixture.view.presentScene(nil)
        fixture.game.gameState = .loading

        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: GameBoardView(gameModel: fixture.game,
                                                              scene: fixture.scene, isPaused: false))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        addTeardownBlock { @MainActor in
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        let board = try XCTUnwrap(findBoard(in: host.view))
        XCTAssertTrue(board.accessibilityElementsHidden)
        XCTAssertTrue(board.tileElements.isEmpty)

        fixture.game.gameState = .inProgress
        try await waitForRenderedUpdate {
            !board.accessibilityElementsHidden && !board.tileElements.isEmpty
        }
        let cell = fixture.sourceCell
        let element = try XCTUnwrap(board.tileElements.first { $0.cell == cell })
        let originalLabel = element.accessibilityLabel
        fixture.source.type = .vaultLock
        fixture.game.score += 1
        let expectedLabel = cell.label(in: fixture.game.level, zodiac: fixture.game.zodiac)
        try await waitForRenderedUpdate { element.accessibilityLabel == expectedLabel }
        XCTAssertNotEqual(element.accessibilityLabel, originalLabel)
        XCTAssertTrue(board.tileElements.first { $0.cell == cell } === element)
    }

    func testElementFromPreviousLevelCannotActivateBeforeBoardRefresh() async throws {
        let fixture = try await makeFixture()
        let element = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == fixture.sourceCell })
        let previousLevel = try XCTUnwrap(fixture.game.level)
        fixture.game.selectLevel(2)
        _ = fixture.game.level.shuffle()
        fixture.game.gameState = .inProgress
        XCTAssertFalse(fixture.game.level === previousLevel)
        XCTAssertTrue(fixture.view.tileElements.contains { $0 === element }, "The native view has not refreshed yet")
        XCTAssertFalse(element.accessibilityActivate())
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.hammerTargets.isEmpty)
    }

    private func findBoard(in view: UIView) -> BoardAccessibilityView? {
        if let board = view as? BoardAccessibilityView { return board }
        for child in view.subviews {
            if let board = findBoard(in: child) { return board }
        }
        return nil
    }

    private func waitForRenderedUpdate(_ condition: @MainActor () -> Bool,
                                       file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(condition(), "Published model changes should refresh the hosted native board", file: file, line: line)
    }

    func testPauseResultsDisabledInputAndExpiredTurnRejectActions() async throws {
        let fixture = try await makeFixture()
        fixture.view.gameplayPaused = true
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.accessibilityElementsHidden)
        XCTAssertFalse(fixture.view.activate(fixture.sourceCell))
        fixture.view.gameplayPaused = false
        fixture.view.refreshAccessibility()

        fixture.scene.setUserInteraction(enabled: false)
        XCTAssertFalse(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        fixture.scene.setUserInteraction(enabled: true)

        fixture.game.movesLeft = 0
        XCTAssertFalse(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        fixture.game.movesLeft = 20
        fixture.game.secondsLeft = 0
        XCTAssertFalse(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        fixture.game.secondsLeft = nil

        fixture.game.gameState = .win
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.accessibilityElementsHidden)
        XCTAssertFalse(fixture.view.activate(fixture.sourceCell))
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
    }

    func testQueuedActionsAreInvalidatedByPauseModeAndLiveBoardReplacement() async throws {
        let fixture = try await makeFixture()
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        let paused = try XCTUnwrap(fixture.view.pendingAction)
        fixture.view.gameplayPaused = true
        fixture.view.refreshAccessibility()
        fixture.view.gameplayPaused = false
        fixture.view.refreshAccessibility()
        await paused.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)

        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        let changedMode = try XCTUnwrap(fixture.view.pendingAction)
        fixture.game.swapModeActive = true
        fixture.view.refreshAccessibility()
        await changedMode.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.ruyiSwaps.isEmpty)
        fixture.game.swapModeActive = false
        fixture.view.refreshAccessibility()

        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        let changedSymbols = try XCTUnwrap(fixture.view.pendingAction)
        fixture.game.level.performSwap(Swap(symbolA: fixture.source, symbolB: fixture.destination))
        await changedSymbols.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)

        let liveSource = fixture.sourceCell
        let delta = fixture.destination.column - fixture.source.column
        XCTAssertTrue(fixture.view.swap(liveSource, columnDelta: delta, rowDelta: 0))
        let replacedLevel = try XCTUnwrap(fixture.view.pendingAction)
        fixture.game.selectLevel(1)
        await replacedLevel.value
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
    }
}
