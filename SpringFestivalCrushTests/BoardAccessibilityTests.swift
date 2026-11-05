import XCTest
import SpriteKit
import SwiftUI
@testable import SpringFestivalCrush

/// Records real accessibility routing without making the assertions depend on random cascades.
@MainActor
private final class AccessibilityRoutingModel: GameModel {
    var runsGameplay = false
    var onRegularSwap: ((Swap) -> Void)?
    var regularSwaps: [Swap] = []
    var ruyiSwaps: [Swap] = []
    var hammerTargets: [BoardAccessibilityCell] = []

    override func handleSwipe(_ swap: Swap) async {
        regularSwaps.append(swap)
        onRegularSwap?(swap)
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
        XCTAssertFalse(fixture.view.isAccessibilityElement)
        XCTAssertEqual(fixture.view.accessibilityElements?.count, expected.count + 1)
        XCTAssertEqual(fixture.view.accessibilityElementCount(), expected.count + 1)
        XCTAssertNotNil(fixture.view.accessibilityElement(at: 0) as? UIAccessibilityElement)
        for (index, element) in fixture.view.tileElements.enumerated() {
            XCTAssertTrue(fixture.view.accessibilityElement(at: index + 1) as? BoardAccessibilityElement === element)
            XCTAssertEqual(fixture.view.index(ofAccessibilityElement: element), index + 1)
        }
        XCTAssertNil(fixture.view.accessibilityElement(at: -1))
        XCTAssertNil(fixture.view.accessibilityElement(at: expected.count + 1))
        XCTAssertEqual(fixture.view.index(ofAccessibilityElement: NSObject()), NSNotFound)
        let firstElement = try XCTUnwrap(fixture.view.tileElements.first)
        fixture.view.accessibilityElementsHidden = true
        XCTAssertEqual(fixture.view.accessibilityElements?.count, 0)
        XCTAssertEqual(fixture.view.accessibilityElementCount(), 0)
        XCTAssertNil(fixture.view.accessibilityElement(at: 0))
        XCTAssertEqual(fixture.view.index(ofAccessibilityElement: firstElement), NSNotFound)
        XCTAssertFalse(firstElement.accessibilityActivate())
        fixture.view.accessibilityElementsHidden = false
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

    func testNativeRotorsStayStableAndMoveFocusWithoutActivatingTiles() async throws {
        let fixture = try await makeFixture()
        fixture.source.type = .lightning
        fixture.view.refreshAccessibility()
        let original = try XCTUnwrap(fixture.view.accessibilityCustomRotors)
        XCTAssertEqual(original.map(\.name), BoardAccessibilityRotor.allCases.map(\.title))
        fixture.view.refreshAccessibility()
        let refreshed = try XCTUnwrap(fixture.view.accessibilityCustomRotors)
        XCTAssertTrue(zip(original, refreshed).allSatisfy { $0 === $1 })

        let powerRotor = try XCTUnwrap(original.first { $0.name == BoardAccessibilityRotor.powerUps.title })
        let predicate = UIAccessibilityCustomRotorSearchPredicate()
        predicate.currentItem = UIAccessibilityCustomRotorItemResult(targetElement: fixture.view, targetRange: nil)
        predicate.searchDirection = .next
        let result = try XCTUnwrap(powerRotor.itemSearchBlock(predicate))
        let target = try XCTUnwrap(result.targetElement as? BoardAccessibilityElement)
        XCTAssertEqual(target.cell, fixture.sourceCell)
        XCTAssertTrue(fixture.view.tileElements.contains { $0 === target })
        let moves = fixture.game.movesLeft
        XCTAssertTrue(fixture.view.activate(fixture.sourceCell))
        _ = fixture.view.rotorElement(for: .rows, from: target, forward: false)
        XCTAssertTrue(target.accessibilityTraits.contains(.selected), "Exploration must preserve the selected swap origin")
        XCTAssertEqual(fixture.game.movesLeft, moves)
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.ruyiSwaps.isEmpty)
        XCTAssertTrue(fixture.game.hammerTargets.isEmpty)
        XCTAssertNil(fixture.view.pendingAction)
    }

    func testRowsRotorKeepsTheClosestColumnAcrossShapedRowsAndStopsAtEdges() async throws {
        let fixture = try await makeFixture(zodiacIndex: 3, levelNumber: 17)
        let elements = fixture.view.tileElements
        let rows = Set(elements.map { $0.cell.row }).sorted(by: >)
        XCTAssertEqual(fixture.view.rotorElement(for: .rows, from: nil, forward: true)?.cell, elements.first?.cell)
        XCTAssertEqual(fixture.view.rotorElement(for: .rows, from: nil, forward: false)?.cell, elements.last?.cell)
        for element in elements {
            let index = try XCTUnwrap(rows.firstIndex(of: element.cell.row))
            for forward in [true, false] {
                let nextIndex = index + (forward ? 1 : -1)
                let actual = fixture.view.rotorElement(for: .rows, from: element, forward: forward)
                guard rows.indices.contains(nextIndex) else {
                    XCTAssertNil(actual, "Row navigation must not wrap around the board")
                    continue
                }
                let targetRow = rows[nextIndex]
                let expected = elements.filter { $0.cell.row == targetRow }.min {
                    let firstDistance = abs($0.cell.column - element.cell.column)
                    let secondDistance = abs($1.cell.column - element.cell.column)
                    return firstDistance == secondDistance ? $0.cell.column < $1.cell.column : firstDistance < secondDistance
                }
                XCTAssertEqual(actual?.cell, expected?.cell)
            }
        }
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
    }

    func testPowerUpRotorUsesLiveTypesInReadingOrderFromAnyFocusedTile() async throws {
        let fixture = try await makeFixture()
        let elements = fixture.view.tileElements
        for element in elements {
            fixture.game.level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = .bowl
        }
        let powers = [elements[1], elements[elements.count / 2], try XCTUnwrap(elements.last)]
        for (element, type) in zip(powers, [SymbolType.five, .redPocketEnhanced, .lightning]) {
            fixture.game.level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = type
        }
        fixture.view.refreshAccessibility()
        XCTAssertEqual(rotorCells(.powerUps, in: fixture.view, forward: true), powers.map(\.cell))
        XCTAssertEqual(rotorCells(.powerUps, in: fixture.view, forward: false), powers.reversed().map(\.cell))
        XCTAssertTrue(fixture.view.rotorElement(for: .powerUps, from: elements[0], forward: true) === powers[0])
        XCTAssertNil(fixture.view.rotorElement(for: .powerUps, from: elements[0], forward: false))
        fixture.game.level.symbol(atColumn: powers[0].cell.column, row: powers[0].cell.row)?.type = .bowl
        XCTAssertTrue(fixture.view.rotorElement(for: .powerUps, from: nil, forward: true) === powers[1],
                      "Rotors must search live pieces, even before labels refresh")
    }

    func testGoalRotorIncludesEnhancedConvertedAndProtectedCollectionTiles() async throws {
        let fixture = try await makeFixture()
        let level = try XCTUnwrap(fixture.game.level)
        let elements = fixture.view.tileElements
        for element in elements {
            level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = .bowl
            level.tileAt(column: element.cell.column, row: element.cell.row)?.jellyCount = 0
        }
        level.levelGoal.levelTarget = LevelTarget(redPocket: 3)
        let enhanced = try XCTUnwrap(level.symbol(atColumn: elements[1].cell.column, row: elements[1].cell.row))
        enhanced.type = .redPocketEnhanced
        enhanced.iceLayer = 2
        enhanced.armorLayers = 1
        let converted = try XCTUnwrap(level.symbol(atColumn: elements[3].cell.column, row: elements[3].cell.row))
        converted.type = .lightning
        converted.convertedFromType = .redPocket
        fixture.view.refreshAccessibility()
        XCTAssertEqual(rotorCells(.goalTiles, in: fixture.view, forward: true), [elements[1].cell, elements[3].cell])
        XCTAssertTrue(fixture.view.rotorElement(for: .goalTiles, from: elements[2], forward: true) === elements[3])
        XCTAssertTrue(fixture.view.rotorElement(for: .goalTiles, from: elements[2], forward: false) === elements[1])
        level.levelGoal.levelTarget.redPocket = 0
        XCTAssertNil(fixture.view.rotorElement(for: .goalTiles, from: nil, forward: true))
        level.levelGoal.levelTarget.redPocket = -2
        XCTAssertNil(fixture.view.rotorElement(for: .goalTiles, from: nil, forward: false))
    }

    func testGoalRotorFindsBlockersBlossomsGiftsAndActivationGoals() async throws {
        let fixture = try await makeFixture()
        let level = try XCTUnwrap(fixture.game.level)
        let elements = fixture.view.tileElements
        for element in elements {
            level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = .bowl
            level.tileAt(column: element.cell.column, row: element.cell.row)?.jellyCount = 0
        }
        let types: [SymbolType] = [.lock, .heavyLock, .vaultLock, .chocolate, .ingredient, .lightning, .five, .lanternEnhanced]
        for (element, type) in zip(elements, types) {
            level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = type
        }
        level.tileAt(column: elements[8].cell.column, row: elements[8].cell.row)?.jellyCount = 2
        let scenarios: [(LevelTarget, [Int])] = [
            (LevelTarget(lock: 1), [0, 1, 2]),
            (LevelTarget(jelly: 1), [8]),
            (LevelTarget(ingredient: 1), [4]),
            (LevelTarget(lightningCombos: 1), [5]),
            (LevelTarget(fiveCombos: 1), [6]),
            (LevelTarget(enhancedCombos: 1), [7]),
            (LevelTarget(lock: 0, jelly: 0, ingredient: 0, lightningCombos: 0, fiveCombos: 0, enhancedCombos: 0), [])
        ]
        for (target, indices) in scenarios {
            level.levelGoal.levelTarget = target
            XCTAssertEqual(rotorCells(.goalTiles, in: fixture.view, forward: true), indices.map { elements[$0].cell })
        }
    }

    func testGoalRotorIncludesDirectGuardianTargetsOnlyWhileGuardianIsAlive() async throws {
        let fixture = try await makeFixture()
        let level = try XCTUnwrap(fixture.game.level)
        let elements = fixture.view.tileElements
        level.levelGoal.levelTarget = LevelTarget()
        let scenarios: [(BossConfiguration.Kind, [SymbolType])] = [
            (.rat, [.redPocket, .redPocketEnhanced]),
            (.ox, [.lightning, .five, .lanternEnhanced]),
            (.tiger, [.firecracker, .firecrackerEnhanced]),
            (.rabbit, [.lantern, .lanternEnhanced, .lock, .heavyLock, .vaultLock])
        ]
        for (kind, types) in scenarios {
            for element in elements {
                let piece = try XCTUnwrap(level.symbol(atColumn: element.cell.column, row: element.cell.row))
                piece.type = .bowl
                piece.convertedFromType = nil
                piece.armorLayers = 0
                level.tileAt(column: element.cell.column, row: element.cell.row)?.jellyCount = 0
            }
            for (element, type) in zip(elements, types) {
                level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = type
            }
            let armored = elements[types.count]
            if kind == .ox {
                level.symbol(atColumn: armored.cell.column, row: armored.cell.row)?.armorLayers = 1
            } else {
                level.symbol(atColumn: armored.cell.column, row: armored.cell.row)?.type = .chocolate
            }
            level.boss = BossEncounter(configuration: BossConfiguration(kind: kind, health: 10))
            let expected = elements.prefix(types.count + (kind == .ox ? 1 : 0)).map(\.cell)
            XCTAssertEqual(rotorCells(.goalTiles, in: fixture.view, forward: true), expected)
            level.boss = BossEncounter(configuration: BossConfiguration(kind: kind, health: 0))
            XCTAssertNil(fixture.view.rotorElement(for: .goalTiles, from: nil, forward: true))
        }
    }

    func testRotorsRejectPausedBusyExpiredAndObsoleteBoards() async throws {
        let fixture = try await makeFixture()
        let element = try XCTUnwrap(fixture.view.tileElements.first)
        fixture.view.gameplayPaused = true
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: nil, forward: true))
        fixture.view.gameplayPaused = false
        fixture.view.isPaused = true
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: nil, forward: true))
        fixture.view.isPaused = false
        fixture.game.movesLeft = 0
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: element, forward: true))
        fixture.game.movesLeft = 20
        fixture.game.secondsLeft = 0
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: nil, forward: true))
        fixture.game.secondsLeft = nil
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: nil, forward: true))
        await fixture.view.pendingAction?.value
        fixture.game.gameState = .win
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: nil, forward: true))
        fixture.game.selectLevel(2)
        _ = fixture.game.level.shuffle()
        fixture.game.gameState = .inProgress
        XCTAssertNil(fixture.view.rotorElement(for: .rows, from: element, forward: true))
    }

    private func rotorCells(_ kind: BoardAccessibilityRotor, in board: BoardAccessibilityView,
                            forward: Bool) -> [BoardAccessibilityCell] {
        var result: [BoardAccessibilityCell] = []
        var current: BoardAccessibilityElement?
        for _ in 0...board.tileElements.count {
            guard let next = board.rotorElement(for: kind, from: current, forward: forward) else { return result }
            result.append(next.cell)
            current = next
        }
        XCTFail("Rotor navigation must stop at the edge instead of cycling")
        return result
    }

    func testSettledNativeMoveAnnouncesEachGoalChangeAndCompletionOnce() async throws {
        let fixture = try await makeFixture()
        let game = fixture.game
        game.level.levelGoal.levelTarget = LevelTarget(firecracker: 5, lock: 1, lightningCombos: 2)
        fixture.source.type = .lightning
        game.level.detectPossibleSwaps()
        fixture.view.refreshAccessibility()
        let before = BoardAccessibilityGoalSummary(targets: game.createLevelTargetDatas())
        game.onRegularSwap = { [weak game] _ in
            guard let game else { return }
            game.level.levelGoal.levelTarget.firecracker = 2
            game.level.levelGoal.levelTarget.lock = 0
            game.level.levelGoal.levelTarget.lightningCombos = 1
            game.score = 120
            game.movesLeft -= 1
        }
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        await fixture.view.pendingAction?.value
        let changes = BoardAccessibilityGoalSummary(targets: game.createLevelTargetDatas()).changes(since: before)
        let spoken = try XCTUnwrap(fixture.view.lastAnnouncement)
        XCTAssertFalse(changes.isEmpty)
        XCTAssertTrue(spoken.contains(changes))
        XCTAssertEqual(spoken.components(separatedBy: changes).count - 1, 1,
                       "One settled action must produce one combined per-goal receipt")
        XCTAssertEqual(game.regularSwaps.count, 1)
        XCTAssertEqual(game.movesLeft, 19)
    }

    func testFinalMoveReceiptsAreQueuedWithoutReopeningCoveredBoard() async throws {
        for state in [GameModel.GameState.win, .offeringContinue, .lose] {
            let fixture = try await makeFixture()
            let game = fixture.game
            game.level.levelGoal.levelTarget = LevelTarget(dumpling: 2)
            fixture.source.type = .lightning
            game.level.detectPossibleSwaps()
            fixture.view.refreshAccessibility()
            let before = BoardAccessibilityGoalSummary(targets: game.createLevelTargetDatas())
            game.onRegularSwap = { [weak game] _ in
                game?.level.levelGoal.levelTarget.dumpling = 0
                game?.gameState = state
            }
            XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
            await fixture.view.pendingAction?.value
            let expected = BoardAccessibilityGoalSummary(targets: game.createLevelTargetDatas()).changes(since: before)
            XCTAssertFalse(expected.isEmpty)
            XCTAssertEqual(fixture.view.lastAnnouncement, expected)
            XCTAssertTrue(fixture.view.lastAnnouncementIsQueued)
            XCTAssertTrue(fixture.view.accessibilityElementsHidden)
            XCTAssertTrue(fixture.view.tileElements.isEmpty)
        }
    }

    func testReadBoardStatusActionIncludesIndividualRemainingAndCompletedGoals() async throws {
        let fixture = try await makeFixture()
        fixture.game.level.levelGoal.levelTarget = LevelTarget(redPocket: 4, lock: 0, fiveCombos: 2)
        fixture.view.refreshAccessibility()
        let element = try XCTUnwrap(fixture.view.tileElements.first)
        let action = try XCTUnwrap(element.accessibilityCustomActions?.first { $0.name == String(localized: "Read board status") })
        XCTAssertTrue(try XCTUnwrap(action.actionHandler)(action))
        let expected = BoardAccessibilityGoalSummary(targets: fixture.game.createLevelTargetDatas()).remainingDescription
        XCTAssertTrue(try XCTUnwrap(fixture.view.lastAnnouncement).contains(expected))
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertNil(fixture.view.pendingAction)
    }

    func testUnchangedAndInvalidNativeMovesDoNotInventGoalProgress() async throws {
        let fixture = try await makeFixture()
        let level = try XCTUnwrap(fixture.game.level)
        level.levelGoal.levelTarget = LevelTarget(lightningCombos: 3)
        fixture.source.type = .lightning
        level.detectPossibleSwaps()
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        await fixture.view.pendingAction?.value
        let unchangedGoalStatus = BoardAccessibilityGoalSummary(targets: fixture.game.createLevelTargetDatas()).remainingDescription
        XCTAssertFalse(try XCTUnwrap(fixture.view.lastAnnouncement).contains(unchangedGoalStatus))

        // This repeating six-color pattern has no adjacent duplicates. Exchanging the
        // fixture's ordinary neighbors cannot form a three-tile match.
        let types: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        for element in fixture.view.tileElements {
            level.symbol(atColumn: element.cell.column, row: element.cell.row)?.type = types[(element.cell.column + element.cell.row * 2) % types.count]
        }
        level.detectPossibleSwaps()
        let swap = Swap(symbolA: fixture.source, symbolB: fixture.destination)
        XCTAssertFalse(level.isPossibleSwap(swap))
        fixture.view.refreshAccessibility()
        XCTAssertTrue(fixture.view.swap(fixture.sourceCell, columnDelta: 1, rowDelta: 0))
        await fixture.view.pendingAction?.value
        XCTAssertEqual(fixture.view.lastAnnouncement, String(localized: "No match. Move not used."))
        XCTAssertEqual(level.levelGoal.levelTarget.lightningCombos, 3)
    }

    func testNativeSpokenPreviewActionsPreserveBoardCostsAndSelection() async throws {
        let fixture = try await makeFixture()
        let level = try XCTUnwrap(fixture.game.level)
        fixture.source.type = .lightning
        // An explicitly requested spoken preview stays available with drag previews off.
        fixture.scene.settingModel.powerUpPreviewsEnabled = false
        level.detectPossibleSwaps()
        fixture.view.refreshAccessibility()
        let origin = fixture.sourceCell
        XCTAssertTrue(fixture.view.activate(origin))
        let element = try XCTUnwrap(fixture.view.tileElements.first { $0.cell == origin })
        let pieces = fixture.view.tileElements.compactMap { level.symbol(atColumn: $0.cell.column, row: $0.cell.row) }
        let types = pieces.map(\.type)
        let positions = pieces.map { BoardAccessibilityCell(column: $0.column, row: $0.row) }
        let ice = pieces.map(\.iceLayer)
        let armor = pieces.map(\.armorLayers)
        let inventory = [fixture.game.movesLeft, fixture.game.score, fixture.game.hammerCharges,
                         fixture.game.swapCharges, fixture.game.shuffleCharges]
        let targets = BoardAccessibilityGoalSummary(targets: fixture.game.createLevelTargetDatas())
        let expected = try XCTUnwrap(BoardAccessibilityBlastSummary(level: level,
            swap: Swap(symbolA: fixture.source, symbolB: fixture.destination), zodiac: fixture.game.zodiac))
        let action = try XCTUnwrap(element.accessibilityCustomActions?.first { $0.name == String(localized: "Preview right") })
        XCTAssertTrue(try XCTUnwrap(action.actionHandler)(action))
        XCTAssertEqual(fixture.view.lastSpokenPreview, expected)
        XCTAssertEqual(fixture.view.lastAnnouncement, expected.summaryDescription)

        let detailAction = try XCTUnwrap(element.accessibilityCustomActions?.first { $0.name == String(localized: "Read preview details") })
        XCTAssertTrue(try XCTUnwrap(detailAction.actionHandler)(detailAction))
        XCTAssertEqual(fixture.view.lastAnnouncement, expected.affectedCellsDescription)
        let header = try XCTUnwrap(fixture.view.accessibilityElements?.first as? UIAccessibilityElement)
        XCTAssertNotNil(header.accessibilityCustomActions?.first { $0.name == String(localized: "Read preview details") })
        XCTAssertTrue(element.accessibilityTraits.contains(.selected))
        XCTAssertNotNil(fixture.scene.selectionSprite.parent, "Previewing must retain the visible swap selection")
        XCTAssertEqual(pieces.map(\.type), types)
        XCTAssertEqual(pieces.map { BoardAccessibilityCell(column: $0.column, row: $0.row) }, positions)
        XCTAssertEqual(pieces.map(\.iceLayer), ice)
        XCTAssertEqual(pieces.map(\.armorLayers), armor)
        XCTAssertEqual([fixture.game.movesLeft, fixture.game.score, fixture.game.hammerCharges,
                        fixture.game.swapCharges, fixture.game.shuffleCharges], inventory)
        XCTAssertEqual(BoardAccessibilityGoalSummary(targets: fixture.game.createLevelTargetDatas()), targets)
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.ruyiSwaps.isEmpty)
        XCTAssertTrue(fixture.game.hammerTargets.isEmpty)
        XCTAssertNil(fixture.view.pendingAction)
    }

    func testSpokenPreviewRejectsBoardPauseModeGenerationAndLevelChanges() async throws {
        let fixture = try await makeFixture()
        fixture.source.type = .lightning
        fixture.scene.settingModel.powerUpPreviewsEnabled = true
        let origin = fixture.sourceCell
        func preview() {
            fixture.view.refreshAccessibility()
            XCTAssertTrue(fixture.view.preview(origin, columnDelta: 1, rowDelta: 0))
            XCTAssertNotNil(fixture.view.lastSpokenPreview)
        }
        func assertInvalid() {
            XCTAssertFalse(fixture.view.readPreviewDetails())
            XCTAssertNil(fixture.view.lastSpokenPreview)
        }
        preview()
        fixture.destination.type = .bowl
        assertInvalid()
        fixture.destination.type = .dumpling
        preview()
        fixture.view.gameplayPaused = true
        assertInvalid()
        fixture.view.gameplayPaused = false
        preview()
        fixture.game.hammerModeActive = true
        assertInvalid()
        fixture.game.hammerModeActive = false
        preview()
        fixture.scene.cancelBlastPreview()
        assertInvalid()
        preview()
        fixture.game.level.performSwap(Swap(symbolA: fixture.source, symbolB: fixture.destination))
        assertInvalid()
        fixture.game.selectLevel(2)
        assertInvalid()
        XCTAssertTrue(fixture.game.regularSwaps.isEmpty)
        XCTAssertTrue(fixture.game.hammerTargets.isEmpty)
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
        let gifts = String(localized: "gifts to deliver")
        let receipt = String(localized: "\(gifts): complete, \(1) completed this move.")
        XCTAssertTrue(try XCTUnwrap(fixture.view.lastAnnouncement).contains(receipt))
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
