import XCTest
import SpriteKit
import SwiftUI
@testable import SpringFestivalCrush

@MainActor
final class ReleaseRegressionTests: XCTestCase {
    private func makeGame() -> GameModel {
        let keys = ["coins", "lives", "lastLifeLostTimestamp", "shuffleCharges", "hammerCharges", "hasSeenTutorial",
                    "isPlayBackgroundMusic", "playSoundEffect", "musicVolume", "soundEffectsVolume", "hapticsEnabled",
                    "screenShakeEnabled", "reducedEffects", "idleHintsEnabled", "unlockAllLevels"]
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

    func testLevelMapFocusUsesLatestUnlockedLevel() {
        let zodiac = ZodiacRecord(zodiacType: .rat, isUnlocked: true)
        let records = (1...30).reversed().map {
            LevelRecord(number: $0, isUnlocked: $0 <= 19, zodiacRecord: zodiac)
        }
        XCTAssertEqual(SelectLevelView.initialFocusLevel(in: records, unlockAll: false), 19)
        records.forEach { $0.isComplete = $0.isUnlocked }
        XCTAssertEqual(SelectLevelView.initialFocusLevel(in: records, unlockAll: false), 19)
        XCTAssertEqual(SelectLevelView.initialFocusLevel(in: records, unlockAll: true), 30)
        XCTAssertNil(SelectLevelView.initialFocusLevel(in: [], unlockAll: false))
        records.forEach { $0.isUnlocked = $0.number == 1 }
        XCTAssertEqual(SelectLevelView.initialFocusLevel(in: records, unlockAll: false), 1)
    }

    func testHomeMapKeepsLandmarksInsetOnTallPhones() {
        for screen in [CGSize(width: 375, height: 812), CGSize(width: 402, height: 874),
                       CGSize(width: 440, height: 956), CGSize(width: 768, height: 1024),
                       CGSize(width: 874, height: 402)] {
            let map = SelectChineseZodiacView.mapSize(for: screen)
            XCTAssertGreaterThanOrEqual(map.width, screen.width)
            XCTAssertGreaterThanOrEqual(map.height, screen.height)
            XCTAssertEqual(map.height / map.width, 1881.0 / 836.0, accuracy: 0.001)
            let nodeSize = min(max(screen.width * 0.19, 48), 84)
            // Include the current-node halo, which extends beyond the button.
            let edgeClearance = screen.width / 2 - map.width * 0.2 - (nodeSize + 12) * 1.16 / 2
            XCTAssertGreaterThanOrEqual(edgeClearance, 32)
        }
    }

    func testMapsRenderAtLatestProgressOnIPhone17() async throws {
        let game = makeGame()
        game.zodiacRecords = ChineseZodiac.allCases.map {
            ZodiacRecord(zodiacType: $0, isUnlocked: $0 == .rat)
        }
        let zodiac = ZodiacRecord(zodiacType: .rat, isUnlocked: true)
        game.currentLevelRecords = (1...30).map {
            let record = LevelRecord(number: $0, isUnlocked: $0 <= 19, zodiacRecord: zodiac)
            record.isComplete = $0 < 19
            record.stars = $0 < 19 ? 3 : 0
            return record
        }
        let settings = SettingModel()
        settings.unlockAllLevels = false
        for accessible in [false, true] {
            try await snapshot(name: "Map-progress-19-\(accessible)", size: CGSize(width: 402, height: 874)) { ready in
                NavigationStack { SelectLevelView() }
                    .environmentObject(game)
                    .environmentObject(settings)
                    .environment(\.gameReducedEffects, true)
                    .environment(\.dynamicTypeSize, accessible ? .accessibility3 : .large)
                    .onAppear { DispatchQueue.main.async(execute: ready) }
            }
        }
        try await snapshot(name: "Home-map-iPhone17", size: CGSize(width: 402, height: 874)) { ready in
            NavigationStack { SelectChineseZodiacView() }
                .environmentObject(game)
                .environmentObject(settings)
                .environment(\.gameReducedEffects, true)
                .onAppear { DispatchQueue.main.async(execute: ready) }
        }
    }

    func testLaunchArtworkFillsPhoneAndTablet() throws {
        let artwork = try XCTUnwrap(UIImage(named: "LaunchFestival"))
        XCTAssertEqual(artwork.size.width / artwork.size.height, 0.5, accuracy: 0.01)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.keyWindow
        for size in [CGSize(width: 375, height: 812), CGSize(width: 402, height: 874),
                     CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768)] {
            let controller = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                previousWindow?.makeKeyAndVisible()
            }
            window.layoutIfNeeded()
            controller.view.layoutIfNeeded()
            let imageView = try XCTUnwrap(controller.view.subviews.first as? UIImageView)
            XCTAssertNotNil(imageView.image)
            XCTAssertEqual(imageView.frame, controller.view.bounds)
            XCTAssertEqual(imageView.contentMode, .scaleAspectFill)
            XCTAssertTrue(imageView.clipsToBounds)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Launch-\(Int(size.width))-\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testShufflePreservesLivePiecesAndFrozenPositions() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        let original = Array(level.shuffle())
        let frozen = original[0]
        frozen.iceLayer = 2
        let position = (frozen.column, frozen.row)
        original[1].type = .lightning
        original[2].type = .lock
        let identities = Set(original.map(ObjectIdentifier.init))
        let shuffled = try XCTUnwrap(level.reshuffleExistingSymbols())
        XCTAssertEqual(Set(shuffled.map(ObjectIdentifier.init)), identities)
        XCTAssertEqual(frozen.iceLayer, 2)
        XCTAssertEqual(frozen.column, position.0)
        XCTAssertEqual(frozen.row, position.1)
        XCTAssertEqual(original[1].type, .lightning)
        XCTAssertEqual(original[2].type, .lock)
        XCTAssertFalse(level.possibleSwaps.isEmpty)
    }

    func testReshuffleAlwaysFindsPlayableBoardOnEveryLevel() throws {
        let levels = [("Rat", 15), ("Ox", 15), ("Tiger", 10)]
            .flatMap { name, count in (1...count).map { "\(name)_Level_\($0)" } }
        for filename in levels {
            let level = try XCTUnwrap(Level(filename: filename), filename)
            _ = level.shuffle()
            for attempt in 0..<30 {
                XCTAssertNotNil(level.reshuffleExistingSymbols(), "\(filename) attempt \(attempt)")
                XCTAssertFalse(level.possibleSwaps.isEmpty, "\(filename) attempt \(attempt)")
                XCTAssertTrue(level.removeMatches().isEmpty, "\(filename) attempt \(attempt)")
            }
        }
    }

    func testImpossibleShuffleDoesNotRebuildBoard() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        let original = level.shuffle()
        for symbol in original { symbol.type = .lock }
        XCTAssertNil(level.reshuffleExistingSymbols())
        for symbol in original {
            XCTAssertTrue(level.symbol(atColumn: symbol.column, row: symbol.row) === symbol)
            XCTAssertEqual(symbol.type, .lock)
        }
    }

    func testShuffleCostsOneChargeAndNoMovesEvenOnDoubleTap() async {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedShuffle()
        game.grantRewardedShuffle()
        let moves = game.movesLeft
        let charges = game.shuffleCharges
        let finished = expectation(description: "shuffle completed")
        game.invokeCommand = { command in
            if case .setUserInteraction(true) = command { finished.fulfill() }
        }
        game.onTapShuffle()
        game.onTapShuffle()
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertEqual(game.shuffleCharges, charges - 1)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testUnavailableShuffleKeepsCharge() async {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedShuffle()
        game.level.noShuffle = true
        let charges = game.shuffleCharges
        game.onTapShuffle()
        XCTAssertEqual(game.shuffleCharges, charges)
        XCTAssertNotNil(game.toolNotice)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testExitDuringSetupCannotRestartGame() async {
        let game = makeGame()
        game.invokeCommandAsync = { command in
            if case .setupSymbols = command { game.onTapBack() }
        }
        await game.setupNewGame()
        XCTAssertEqual(game.gameState, .notStart)
    }

    func testOldHammerCascadeCannotModifyNewAttempt() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let symbol = try XCTUnwrap(game.level.symbol(atColumn: 0, row: 0))
        var replaced = false
        game.invokeCommandAsync = { command in
            if case .onMatchedSymbols = command, !replaced {
                replaced = true
                game.onTapBack()
                game.selectLevel(2)
                game.score = 123
            }
        }
        await game.useHammer(atColumn: symbol.column, row: symbol.row)
        XCTAssertTrue(replaced)
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.score, 123)
        XCTAssertEqual(game.gameState, .loading)
    }

    func testTimerCannotLoseDuringWinBonusOrAwardTwice() async {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget = LevelTarget()
        game.movesLeft = 0
        game.secondsLeft = 1
        let lives = game.lives
        let coins = game.coins
        game.invokeCommandAsync = { command in
            if case .onEnhanceSymbols = command {
                XCTAssertEqual(game.gameState, .finishing)
                game.tickTimer()
                await game.beginNextTurn()
            }
        }
        await game.beginNextTurn()
        XCTAssertEqual(game.gameState, .win)
        XCTAssertEqual(game.lives, lives)
        XCTAssertEqual(game.coins, coins + 15)
        XCTAssertEqual(game.secondsLeft, 1)
    }

    func testTimeoutWaitsForMoveToResolve() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        let swap = try XCTUnwrap(game.level.possibleSwaps.first)
        var checkedPendingMove = false
        game.invokeCommandAsync = { command in
            if case .onValidSwap = command {
                game.secondsLeft = 1
                game.tickTimer()
                checkedPendingMove = true
                XCTAssertEqual(game.secondsLeft, 0)
                XCTAssertEqual(game.gameState, .inProgress)
            }
        }
        await game.handleSwipe(swap)
        XCTAssertTrue(checkedPendingMove)
        // Running out now pauses on the continue offer; declining is what ends the attempt.
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.loseReason, .outOfTime)
        game.declineContinue()
        XCTAssertEqual(game.gameState, .lose)
        XCTAssertEqual(game.loseReason, .outOfTime)
    }

    func testInventorySurvivesAttemptReset() {
        let game = makeGame()
        game.grantRewardedHammer()
        game.grantRewardedShuffle()
        let counts = (game.hammerCharges, game.shuffleCharges)
        game.hammerModeActive = true
        game.resetBoostersForNewAttempt()
        XCTAssertFalse(game.hammerModeActive)
        XCTAssertEqual(game.hammerCharges, counts.0)
        XCTAssertEqual(game.shuffleCharges, counts.1)
        let restored = GameModel()
        XCTAssertEqual(restored.hammerCharges, counts.0)
        XCTAssertEqual(restored.shuffleCharges, counts.1)
    }

    func testRepeatedNextLevelTapAdvancesOnlyOnce() async {
        let game = makeGame()
        game.gameState = .win
        game.lives = 10
        game.onTapNextLevel()
        game.onTapNextLevel()
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.gameState, .loading)
        // Invalidate pending setup before this isolated model is discarded.
        game.onTapBack()
    }

    func testTimerStopsAtZeroAndDeductsOnlyOneLife() async {
        let game = makeGame()
        await game.setupNewGame()
        game.lives = 10
        game.secondsLeft = 1
        let finished = expectation(description: "timeout completed")
        game.invokeCommandAsync = { command in
            if case .onGameOver = command { finished.fulfill() }
        }
        game.tickTimer()
        game.tickTimer()
        for _ in 0 ..< 200 where game.gameState != .offeringContinue { await Task.yield() }
        XCTAssertEqual(game.gameState, .offeringContinue)
        XCTAssertEqual(game.lives, 10, "The offer itself never costs a life")
        game.declineContinue()
        game.declineContinue()
        await fulfillment(of: [finished], timeout: 5)
        game.tickTimer()
        XCTAssertEqual(game.secondsLeft, 0)
        XCTAssertEqual(game.lives, 9)
        XCTAssertEqual(game.gameState, .lose)
    }

    func testGoalReceiptsClampOvercollectionAndUseMatchingSource() {
        let before = LevelTarget(firecracker: 2, dumpling: 0).getLevelTargetDatas(gameZodiac: Zodiac.all[0])
        let after = LevelTarget(firecracker: -3, dumpling: -1).getLevelTargetDatas(gameZodiac: Zodiac.all[0])
        let receipts = GoalProgress.changes(before: before, after: after, symbols: [
            Symbol(column: 0, row: 0, symbolType: .dumpling),
            Symbol(column: 3, row: 4, symbolType: .firecrackerEnhanced)
        ])
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.amount, 2)
        XCTAssertEqual(receipts.first?.goalID, "firecracker")
        XCTAssertEqual(receipts.first?.column, 3)
        XCTAssertEqual(receipts.first?.row, 4)
    }

    func testGoalFlightArrivalIsIdempotentAndClearInvalidatesOldArrivals() throws {
        let feedback = GameFeedback()
        feedback.viewport = CGRect(x: 0, y: 0, width: 300, height: 100)
        feedback.goalFrames = ["bowl": CGRect(x: 100, y: 30, width: 26, height: 26)]
        let receipt = GoalProgress(goalID: "bowl", amount: 3, column: 1, row: 1)
        feedback.collect(receipt, image: Image("bowl"), source: CGPoint(x: 100, y: 300), reduceMotion: false)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 3)
        let id = try XCTUnwrap(feedback.flights.first?.id)
        feedback.arrive(id)
        feedback.arrive(id)
        XCTAssertEqual(feedback.impacts["bowl"], 1)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 0)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: false)
        let oldID = try XCTUnwrap(feedback.flights.first?.id)
        feedback.clear()
        feedback.arrive(oldID)
        XCTAssertTrue(feedback.impacts.isEmpty)
        XCTAssertTrue(feedback.flights.isEmpty)
    }

    func testReducedMotionAndOffscreenGoalsNeverHoldCounters() {
        let feedback = GameFeedback()
        feedback.viewport = CGRect(x: 0, y: 0, width: 100, height: 50)
        feedback.goalFrames = ["bowl": CGRect(x: 10, y: 10, width: 26, height: 26)]
        let receipt = GoalProgress(goalID: "bowl", amount: 1, column: 1, row: 1)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: true)
        XCTAssertTrue(feedback.flights.isEmpty)
        XCTAssertEqual(feedback.impacts["bowl"], 1)
        feedback.goalFrames["bowl"] = CGRect(x: 110, y: 10, width: 26, height: 26)
        feedback.collect(receipt, image: Image("bowl"), source: .zero, reduceMotion: false)
        XCTAssertTrue(feedback.flights.isEmpty)
        XCTAssertEqual(feedback.pendingAmount(for: "bowl"), 0)
        XCTAssertEqual(feedback.impacts["bowl"], 2)
    }

    func testCascadeIntensityIsBounded() {
        XCTAssertNil(CascadeFeedback(depth: 1).title)
        XCTAssertNotNil(CascadeFeedback(depth: 2).title)
        XCTAssertLessThan(CascadeFeedback(depth: 1).playbackRate, CascadeFeedback(depth: 3).playbackRate)
        XCTAssertEqual(CascadeFeedback(depth: 5).playbackRate, CascadeFeedback(depth: 999).playbackRate)
        XCTAssertLessThanOrEqual(CascadeFeedback(depth: 999).volume, 0.8)
    }

    func testExitDuringHammerWindupCannotApplyOldGoalFeedback() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let charges = game.hammerCharges
        var receipts = 0
        game.invokeCommand = { command in
            if case .onGoalProgress = command { receipts += 1 }
        }
        game.invokeCommandAsync = { command in
            if case .onHammerImpact = command {
                game.onTapBack()
                game.selectLevel(2)
                game.score = 123
            }
        }
        await game.useHammer(atColumn: 0, row: 0)
        XCTAssertEqual(game.currentLevel, 2)
        XCTAssertEqual(game.gameState, .loading)
        XCTAssertEqual(game.score, 123)
        XCTAssertEqual(game.hammerCharges, charges - 1)
        XCTAssertEqual(receipts, 0)
    }

    func testEachPlayerActionStartsCascadeAtOne() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        var depths: [Int] = []
        game.invokeCommand = { command in
            if case let .onCascade(depth) = command { depths.append(depth) }
        }
        for _ in 0..<2 {
            depths.removeAll()
            let swap = try XCTUnwrap(game.level.possibleSwaps.first)
            await game.handleSwipe(swap)
            XCTAssertEqual(depths.first, 1)
            XCTAssertEqual(depths, Array(0..<depths.count).map { $0 + 1 })
        }
    }

    func testShuffleAnimationKeepsSpriteIdentityAndEndsExactlyOnCells() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let feedback = GameFeedback()
        let scene = GameScene(size: CGSize(width: 390, height: 844), gameModel: game,
                              themeModel: ThemeModel(), settingModel: SettingModel(), feedback: feedback)
        scene.setupLayerPosition()
        let original = (0..<game.numRows).flatMap { row in
            (0..<game.numColumns).compactMap { game.level.symbol(atColumn: $0, row: row) }
        }
        await scene.addSymbols(for: Set(original), shouldAnimate: false)
        let identities = original.map { ObjectIdentifier($0.sprite!) }
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        let view = SKView(frame: windowScene.coordinateSpace.bounds)
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.presentScene(scene)
        addTeardownBlock { @MainActor in
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        let moves = game.movesLeft
        let charges = game.hammerCharges
        scene.settingModel.idleHintsEnabled = true
        scene.showIdleHint()
        XCTAssertEqual(scene.idleHintLayer.children.count, 2)
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertEqual(game.hammerCharges, charges)
        scene.setFeedbackPaused(true)
        XCTAssertTrue(scene.idleHintLayer.children.isEmpty)
        scene.showIdleHint()
        XCTAssertTrue(scene.idleHintLayer.children.isEmpty)
        scene.setFeedbackPaused(false)
        XCTAssertNotNil(scene.action(forKey: "idleHintDelay"))
        scene.settingModel.idleHintsEnabled = false
        scene.scheduleIdleHint()
        XCTAssertNil(scene.action(forKey: "idleHintDelay"))
        scene.settingModel.playSoundEffect = false
        scene.playSound(.hammer)
        XCTAssertNil(scene.lastSoundTimes[.hammer])
        scene.settingModel.playSoundEffect = true
        scene.settingModel.soundEffectsVolume = 0
        scene.playSound(.hammer)
        XCTAssertNil(scene.lastSoundTimes[.hammer])
        for reduced in [false, true] {
            scene.reduceMotion = reduced
            let shuffled = try XCTUnwrap(game.level.reshuffleExistingSymbols())
            await scene.shuffle(by: shuffled)
            XCTAssertEqual(original.map { ObjectIdentifier($0.sprite!) }, identities)
            for symbol in original {
                let sprite = try XCTUnwrap(symbol.sprite)
                XCTAssertEqual(sprite.position, scene.pointFor(column: symbol.column, row: symbol.row))
                XCTAssertEqual(sprite.xScale, 1)
                XCTAssertEqual(sprite.yScale, 1)
                XCTAssertEqual(sprite.alpha, 1)
                XCTAssertTrue(sprite.parent === scene.symbolsLayer)
            }
        }
        scene.reduceMotion = false
        let a = try XCTUnwrap(original[0].sprite)
        let enhancedSymbol = Symbol(column: 0, row: 0, symbolType: .firecrackerEnhanced)
        let charged = enhancedSymbol.createSpriteNode(zodiac: game.zodiac)
        charged.size = game.tileSize
        scene.symbolsLayer.addChild(charged)
        for reduced in [false, true] {
            scene.reduceMotion = reduced
            let movesBefore = game.movesLeft
            await scene.animateEnhancedBirth(on: charged)
            XCTAssertEqual(charged.xScale, 1)
            XCTAssertEqual(charged.yScale, 1)
            XCTAssertEqual(charged.alpha, 1)
            XCTAssertTrue(charged.children.isEmpty)
            XCTAssertEqual(game.movesLeft, movesBefore)
        }
        charged.removeFromParent()
        scene.reduceMotion = false
        let b = try XCTUnwrap(original[1].sprite)
        let positions = (a.position, b.position)
        let depths = (a.zPosition, b.zPosition)
        let visualSwap = Swap(symbolA: original[0], symbolB: original[1])
        await scene.animateSwap(visualSwap)
        XCTAssertEqual(a.position, positions.1)
        XCTAssertEqual(b.position, positions.0)
        XCTAssertEqual(a.zPosition, depths.0)
        XCTAssertEqual(b.zPosition, depths.1)
        await scene.animateInvalidSwap(visualSwap)
        XCTAssertEqual(a.position, positions.1)
        XCTAssertEqual(b.position, positions.0)
        XCTAssertEqual(a.zPosition, depths.0)
        XCTAssertEqual(b.zPosition, depths.1)
        let match = Chain(chainType: .horizontal3)
        match.add(symbols: Array(original.prefix(3)))
        await scene.animateMatchedSymbols(for: [match])
        // Native keyed `run` is synchronous: this catches an accidental fire-and-forget
        // removal that lets the next cascade fill cells before the old sprites disappear.
        for symbol in match.symbols { XCTAssertNil(symbol.sprite?.parent) }
    }

    func testVictoryReceiptAndMapCelebrationAreOneShot() async throws {
        let game = makeGame()
        let zodiac = ZodiacRecord(zodiacType: .rat, isUnlocked: true)
        let first = LevelRecord(number: 1, isUnlocked: true, zodiacRecord: zodiac)
        let next = LevelRecord(number: 2, isUnlocked: false, zodiacRecord: zodiac)
        zodiac.levelRecords = [first, next]
        game.currentZodiacRecord = zodiac
        game.currentLevelRecord = first
        await game.setupNewGame()
        game.level.levelGoal.levelTarget = LevelTarget()
        game.movesLeft = 0
        game.score = 1000
        let coins = game.coins
        await game.beginNextTurn()
        let receipt = try XCTUnwrap(game.victorySummary)
        XCTAssertEqual(receipt.coins, 15)
        XCTAssertEqual(receipt.score, game.score)
        XCTAssertEqual(receipt.newlyUnlockedLevel, 2)
        XCTAssertTrue(next.isUnlocked)
        game.onTapVictoryMap()
        game.onTapVictoryMap()
        XCTAssertEqual(game.takeTrailCelebration()?.id, receipt.id)
        XCTAssertNil(game.takeTrailCelebration())
        XCTAssertEqual(game.coins, coins + 15)
        XCTAssertEqual(game.gameState, .notStart)
    }

    func testReplayVictoryDoesNotClaimAnExistingUnlock() async throws {
        let game = makeGame()
        let zodiac = ZodiacRecord(zodiacType: .rat, isUnlocked: true)
        let first = LevelRecord(number: 1, isUnlocked: true, zodiacRecord: zodiac)
        let next = LevelRecord(number: 2, isUnlocked: true, zodiacRecord: zodiac)
        zodiac.levelRecords = [first, next]
        game.currentZodiacRecord = zodiac
        game.currentLevelRecord = first
        await game.setupNewGame()
        game.level.levelGoal.levelTarget = LevelTarget()
        game.movesLeft = 0
        await game.beginNextTurn()
        XCTAssertNil(game.victorySummary?.newlyUnlockedLevel)
        XCTAssertEqual(game.victorySummary?.mapFocusLevel, 1)
    }

    func testIdleHintPolicySuppressesToolsTutorialAndResolvingMoves() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.level.levelGoal.levelTarget.zodiac = 10000
        XCTAssertNotNil(game.suggestedIdleSwap())
        game.hammerModeActive = true
        XCTAssertNil(game.suggestedIdleSwap())
        game.hammerModeActive = false
        game.isTutorialHintActive = true
        XCTAssertNil(game.suggestedIdleSwap())
        game.isTutorialHintActive = false
        let swap = try XCTUnwrap(game.suggestedIdleSwap())
        game.invokeCommandAsync = { command in
            if case .onValidSwap = command { XCTAssertNil(game.suggestedIdleSwap()) }
        }
        await game.handleSwipe(swap)
        game.gameState = .finishing
        XCTAssertNil(game.suggestedIdleSwap())
    }

    func testComfortPreferencesPersistAndHapticsRespectMute() {
        _ = makeGame() // Restore all changed preference keys during teardown.
        let settings = SettingModel()
        settings.hapticsEnabled = false
        settings.musicVolume = 0.25
        settings.soundEffectsVolume = 0.4
        settings.reducedEffects = true
        settings.idleHintsEnabled = false
        settings.screenShakeEnabled = false
        XCTAssertFalse(HapticManager.isEnabled)
        let restored = SettingModel()
        XCTAssertEqual(restored.musicVolume, 0.25)
        XCTAssertEqual(restored.soundEffectsVolume, 0.4)
        XCTAssertTrue(restored.reducedEffects)
        XCTAssertFalse(restored.idleHintsEnabled)
        XCTAssertFalse(restored.screenShakeEnabled)
        settings.hapticsEnabled = true
        XCTAssertTrue(HapticManager.isEnabled)
    }

    func testSettingsAndVictoryRenderAtSmallAndAccessibleSizes() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.movesLeft = 0
        game.score = 1000
        game.level.levelGoal.levelTarget = LevelTarget()
        await game.beginNextTurn()
        for accessible in [false, true] {
            let size = CGSize(width: 375, height: 812)
            let name = accessible ? "accessible" : "regular"
            try await snapshot(name: "Settings-\(name)", size: size) { ready in
                NavigationStack {
                    SettingsView().environmentObject(SettingModel())
                }
                .environment(\.dynamicTypeSize, accessible ? .accessibility3 : .large)
                .environment(\.colorScheme, .light)
                .onAppear(perform: ready)
            }
            try await snapshot(name: "Victory-\(name)", size: size) { ready in
                LevelCompleteView(onRevealComplete: ready)
                    .environmentObject(game)
                    .environment(\.dynamicTypeSize, accessible ? .accessibility3 : .large)
                    .environment(\.gameReducedEffects, accessible)
                    .background(AppTheme.festivalRedDark)
            }
        }
        try await snapshot(name: "Settings-landscape-dark", size: CGSize(width: 812, height: 375)) { ready in
            NavigationStack { SettingsView().environmentObject(SettingModel()) }
                .environment(\.colorScheme, .dark)
                .onAppear(perform: ready)
        }
        let zodiac = ZodiacRecord(zodiacType: .rat, isUnlocked: true)
        let records = (1...3).map { LevelRecord(number: $0, isUnlocked: $0 < 3, zodiacRecord: zodiac) }
        records[0].isComplete = true
        records[0].stars = 2
        let theme = ZodiacChapterTheme(zodiac: .rat)
        try await snapshot(name: "Trail-unlock", size: CGSize(width: 375, height: 812)) { ready in
            ZodiacLevelTrail(records: records, currentLevel: 2, unlockAll: false, theme: theme,
                             celebratingLevel: 2, newlyUnlockedLevel: 2, revealProgress: 1, select: { _ in })
                .background(ZodiacChapterScenery(theme: theme))
                .onAppear(perform: ready)
        }
    }

    private func combinationFixture(_ combination: PowerUpCombination, vertical: Bool = false,
                                    edge: Bool = false, reversed: Bool = false) throws -> (Level, Swap) {
        let level = try XCTUnwrap(Level(filename: "Debug_Elements"))
        let pieces = level.shuffle()
        let colors: [SymbolType] = [.bowl, .dumpling, .firecracker, .redPocket, .lantern, .zodiac]
        for piece in pieces {
            piece.type = colors[(piece.column + piece.row * 2) % colors.count]
            piece.iceLayer = 0
            piece.armorLayers = 0
            piece.armorHitThisTurn = false
        }
        let coordinate = edge ? 0 : 3
        let a = try XCTUnwrap(level.symbol(atColumn: coordinate, row: coordinate))
        let b = try XCTUnwrap(level.symbol(atColumn: coordinate + (vertical ? 0 : 1), row: coordinate + (vertical ? 1 : 0)))
        a.type = combination.demoTypes.0
        b.type = combination.demoTypes.1
        let swap = Swap(symbolA: reversed ? b : a, symbolB: reversed ? a : b)
        level.performSwap(swap)
        return (level, swap)
    }

    func testCombinationsBeatIndependentEffectsInBothOrdersAndAtEdges() throws {
        for kind in PowerUpCombination.allCases {
            for vertical in [false, true] {
                for edge in [false, true] {
                    var previousFootprint: Set<String>?
                    for reversed in [false, true] {
                        let (level, swap) = try combinationFixture(kind, vertical: vertical, edge: edge, reversed: reversed)
                        let pieces = (0..<level.numRows).flatMap { row in
                            (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
                        }
                        let planned = level.makeCombinationChain(kind, for: swap)
                        let sources = planned.combinationSources
                        let enhanced = sources.first { $0.type.isEnhanced }
                        let lightning = sources.first { $0.type == .lightning }
                        func cross(_ piece: Symbol, _ source: Symbol) -> Bool {
                            piece.row == source.row || piece.column == source.column
                        }
                        let independent = Set(pieces.filter { piece in
                            if sources.contains(where: { $0 === piece }) { return true }
                            switch kind {
                            case .fiveFive: return false
                            case .fiveLightning:
                                return planned.blastCenters.contains(where: { $0 === piece }) || cross(piece, lightning!)
                            case .lightningLightning: return sources.contains { cross(piece, $0) }
                            case .enhancedLightning:
                                return cross(piece, lightning!) || (abs(piece.row - enhanced!.row) <= 1 && abs(piece.column - enhanced!.column) <= 1)
                            case .enhancedFive:
                                return piece.type.isMatchableTo(enhanced!.type) || (abs(piece.row - enhanced!.row) <= 1 && abs(piece.column - enhanced!.column) <= 1)
                            }
                        }.map(ObjectIdentifier.init))
                        let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
                        let chain = try XCTUnwrap(chains.first)
                        XCTAssertEqual(chains.count, 1)
                        XCTAssertEqual(chain.combination, kind)
                        let actual = Set(chain.clearedSymbols.map(ObjectIdentifier.init))
                        XCTAssertTrue(actual.isSuperset(of: independent), kind.title)
                        XCTAssertGreaterThan(actual.count, independent.count, kind.title)
                        XCTAssertEqual(actual.count, chain.symbols.count, "Overlapping lanes only count once")
                        XCTAssertEqual(chain.score, actual.count * (kind == .fiveFive ? 300 : 240))
                        let footprint = Set(chain.symbols.map { "\($0.column),\($0.row)" })
                        if let previousFootprint { XCTAssertEqual(footprint, previousFootprint, "Swap order must not change the effect") }
                        previousFootprint = footprint
                        for piece in pieces {
                            XCTAssertEqual(level.symbol(atColumn: piece.column, row: piece.row) == nil,
                                           actual.contains(ObjectIdentifier(piece)))
                        }
                    }
                }
            }
        }
    }

    func testDoubleFiveClearsProtectionAndAllGoalsWithoutDoubleCredit() throws {
        let (level, swap) = try combinationFixture(.fiveFive)
        let armor = try XCTUnwrap(level.symbol(atColumn: 0, row: 0))
        armor.armorLayers = 1
        armor.armorHitThisTurn = true
        armor.iceLayer = 2
        let lock = try XCTUnwrap(level.symbol(atColumn: 1, row: 0))
        lock.type = .vaultLock
        let gift = try XCTUnwrap(level.symbol(atColumn: 2, row: 0))
        gift.type = .ingredient
        var jelly = 0
        for row in 0..<level.numRows {
            for column in 0..<level.numColumns {
                level.tileAt(column: column, row: row)?.jellyCount = 2
                jelly += 2
            }
        }
        level.levelGoal.levelTarget = LevelTarget(lock: 1, jelly: jelly, ingredient: 1,
                                                  lightningCombos: 3, fiveCombos: 2, enhancedCombos: 3)
        let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
        XCTAssertEqual(chains.first?.clearedSymbols.count, level.numRows * level.numColumns)
        XCTAssertTrue(chains.first?.resistedSymbols.isEmpty == true)
        level.updateLevelTarget(by: chains)
        XCTAssertEqual(level.levelGoal.levelTarget.lock, 0)
        XCTAssertEqual(level.levelGoal.levelTarget.ingredient, 0)
        XCTAssertEqual(level.levelGoal.levelTarget.jelly, 0)
        XCTAssertEqual(level.levelGoal.levelTarget.fiveCombos, 0)
        XCTAssertEqual(level.levelGoal.levelTarget.lightningCombos, 3)
        XCTAssertEqual(level.levelGoal.levelTarget.enhancedCombos, 3)
        XCTAssertTrue(level.explodeSpecialSymbols(for: chains).isEmpty)
    }

    func testCombinationGoalsCreditBothSourcesAndArmorStillResistsOtherPairs() throws {
        for kind in PowerUpCombination.allCases where kind != .fiveFive {
            let (level, swap) = try combinationFixture(kind)
            level.levelGoal.levelTarget = LevelTarget(lightningCombos: 10, fiveCombos: 10, enhancedCombos: 10)
            let planned = level.makeCombinationChain(kind, for: swap)
            let protected = try XCTUnwrap(planned.symbols.first { piece in
                !planned.combinationSources.contains { $0 === piece }
                    && !planned.transformedSymbols.contains { $0 === piece }
            })
            protected.armorLayers = 1
            let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
            XCTAssertTrue(level.symbol(atColumn: protected.column, row: protected.row) === protected)
            XCTAssertEqual(protected.armorLayers, 0)
            XCTAssertFalse(chains.first!.clearedSymbols.contains { $0 === protected })
            XCTAssertTrue(level.explodeSpecialSymbols(for: chains).isEmpty, "Combined enhanced source cannot explode twice")
            level.updateLevelTarget(by: chains)
            XCTAssertEqual(level.levelGoal.levelTarget.fiveCombos, 10 - kind.fiveCount)
            let converted = chains.first!.transformedSymbols.filter { symbol in
                !chains.first!.combinationSources.contains { $0 === symbol }
            }
            XCTAssertEqual(level.levelGoal.levelTarget.lightningCombos,
                           max(0, 10 - kind.lightningCount - converted.filter { $0.type == .lightning }.count))
            XCTAssertEqual(level.levelGoal.levelTarget.enhancedCombos,
                           max(0, 10 - kind.enhancedCount - converted.filter { $0.type.isEnhanced }.count))
        }
    }

    func testConversionsTransformMatchingTilesAndKeepTheirColorCredit() throws {
        for kind in [PowerUpCombination.enhancedFive, .fiveLightning] {
            for reversed in [false, true] {
                let (level, swap) = try combinationFixture(kind, reversed: reversed)
                let pieces = (0..<level.numRows).flatMap { row in
                    (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
                }
                let original = Dictionary(uniqueKeysWithValues: pieces.map { (ObjectIdentifier($0), $0.type) })
                let plan = level.makeCombinationChain(kind, for: swap)
                let color = try XCTUnwrap(plan.sourceType)
                let protected = try XCTUnwrap(plan.transformedSymbols.first { piece in
                    !plan.combinationSources.contains { $0 === piece }
                })
                protected.armorLayers = 1
                let expected = pieces.filter { $0.type.isMatchableTo(color) && $0.armorLayers == 0 }
                level.levelGoal.levelTarget = LevelTarget(firecracker: 100, redPocket: 100, dumpling: 100,
                                                          bowl: 100, lantern: 100, zodiac: 100)
                let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
                let chain = try XCTUnwrap(chains.first)
                XCTAssertEqual(Set(chain.transformedSymbols.map(ObjectIdentifier.init)), Set(expected.map(ObjectIdentifier.init)))
                XCTAssertFalse(chain.transformedSymbols.isEmpty)
                for piece in expected {
                    XCTAssertEqual(piece.type, kind == .fiveLightning ? .lightning : color.enhancedType)
                    XCTAssertEqual(piece.collectionType, original[ObjectIdentifier(piece)])
                }
                XCTAssertNil(protected.convertedFromType)
                XCTAssertEqual(protected.type, original[ObjectIdentifier(protected)])
                // This also checks the exact ordinary 3x3 / row+column union, without an extra wide cross.
                let expectedFootprint = pieces.filter { piece in
                    if chain.combinationSources.contains(where: { $0 === piece }) { return true }
                    if kind == .enhancedFive {
                        return expected.contains { abs(piece.column - $0.column) <= 1 && abs(piece.row - $0.row) <= 1 }
                    }
                    let bolts = expected + chain.combinationSources.filter { $0.type == .lightning }
                    return bolts.contains { piece.column == $0.column || piece.row == $0.row }
                }
                XCTAssertEqual(Set(chain.symbols.map(ObjectIdentifier.init)), Set(expectedFootprint.map(ObjectIdentifier.init)))
                level.updateLevelTarget(by: chains)
                let clearedColors = chain.clearedSymbols.compactMap { original[ObjectIdentifier($0)] }
                let goals = level.levelGoal.levelTarget
                for (type, count) in [(SymbolType.firecracker, goals.firecracker), (.redPocket, goals.redPocket),
                                      (.dumpling, goals.dumpling), (.bowl, goals.bowl), (.lantern, goals.lantern), (.zodiac, goals.zodiac)] {
                    XCTAssertEqual(count, 100 - clearedColors.filter { $0.isMatchableTo(type) }.count)
                }
            }
        }
    }

    func testRecursiveBlastsTriggerEveryPowerOnceAndCarrySourceColor() throws {
        let (level, _) = try combinationFixture(.enhancedFive)
        for row in 0..<level.numRows {
            for column in 0..<level.numColumns { level.symbol(atColumn: column, row: row)?.type = .bowl }
        }
        func piece(_ column: Int, _ row: Int, _ type: SymbolType) throws -> Symbol {
            let symbol = try XCTUnwrap(level.symbol(atColumn: column, row: row))
            symbol.type = type
            return symbol
        }
        let first = try piece(1, 1, .redPocketEnhanced)
        let bolt = try piece(2, 1, .lightning)
        let five = try piece(2, 5, .five)
        let remoteColor = try piece(7, 7, .redPocket)
        let remoteBlast = try piece(7, 6, .redPocketEnhanced)
        let secondBolt = try piece(6, 6, .lightning)
        let lastTarget = try piece(6, 0, .lantern)
        let untouched = try piece(0, 7, .lantern)
        let protected = try piece(6, 1, .five)
        protected.armorLayers = 2
        level.levelGoal.levelTarget = LevelTarget(lightningCombos: 10, fiveCombos: 10, enhancedCombos: 10)
        let initial = try XCTUnwrap(level.useHammer(atColumn: first.column, row: first.row))
        let reactions = level.explodeSpecialSymbols(for: [initial])
        let activations = reactions.flatMap(\.detonations)
        XCTAssertEqual(Set(activations.map { ObjectIdentifier($0.symbol) }),
                       Set([first, bolt, five, remoteBlast, secondBolt].map(ObjectIdentifier.init)))
        XCTAssertEqual(activations.count, 5, "Overlapping and returning blasts must not fire a power twice")
        XCTAssertTrue(activations.allSatisfy { $0.sourceType.isMatchableTo(.redPocket) })
        let fiveActivation = try XCTUnwrap(activations.first { $0.type == .five })
        XCTAssertTrue(fiveActivation.targets.contains { $0 === remoteColor })
        XCTAssertTrue(fiveActivation.targets.allSatisfy { $0.collectionType.isMatchableTo(.redPocket) })
        XCTAssertNil(level.symbol(atColumn: lastTarget.column, row: lastTarget.row))
        XCTAssertTrue(level.symbol(atColumn: untouched.column, row: untouched.row) === untouched)
        XCTAssertTrue(level.symbol(atColumn: protected.column, row: protected.row) === protected)
        XCTAssertEqual(protected.armorLayers, 1, "Overlapping blasts hit armor once per turn")
        XCTAssertFalse(activations.contains { $0.symbol === protected })
        let all = reactions.union([initial])
        let cleared = all.flatMap(\.clearedSymbols)
        XCTAssertEqual(cleared.count, Set(cleared.map(ObjectIdentifier.init)).count)
        level.updateLevelTarget(by: all)
        XCTAssertEqual(level.levelGoal.levelTarget.lightningCombos, 8)
        XCTAssertEqual(level.levelGoal.levelTarget.fiveCombos, 9)
        XCTAssertEqual(level.levelGoal.levelTarget.enhancedCombos, 8)
        XCTAssertTrue(level.explodeSpecialSymbols(for: all).isEmpty)
    }

    func testLightningAndConversionsTriggerHitSpecialsWithInheritedColor() throws {
        for kind in [PowerUpCombination.enhancedFive, .fiveLightning] {
            let (level, swap) = try combinationFixture(kind)
            let plan = level.makeCombinationChain(kind, for: swap)
            let candidates = plan.symbols.filter { piece in
                !plan.combinationSources.contains { $0 === piece }
                    && !plan.transformedSymbols.contains { $0 === piece }
            }
            XCTAssertGreaterThanOrEqual(candidates.count, 3)
            candidates[0].type = .lightning
            candidates[1].type = .five
            candidates[2].type = candidates[2].type.enhancedType
            let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
            let reaction = level.explodeSpecialSymbols(for: chains)
            let activations = reaction.flatMap(\.detonations)
            for hit in candidates.prefix(3) {
                XCTAssertEqual(activations.filter { $0.symbol === hit }.count, 1)
            }
            let source = try XCTUnwrap(chains.first?.sourceType)
            XCTAssertTrue(activations.allSatisfy { $0.sourceType == source })
            let five = try XCTUnwrap(activations.first { $0.type == .five })
            XCTAssertTrue(five.targets.allSatisfy { $0.collectionType.isMatchableTo(source) })
        }
        // A regular Lightning swap also starts the same recursive resolver.
        let (level, swap) = try combinationFixture(.fiveLightning)
        swap.symbolA.type = .redPocket
        swap.symbolB.type = .lightning
        let hit = try XCTUnwrap(level.symbol(atColumn: swap.symbolB.column, row: 0))
        hit.type = .five
        let chains = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
        let reactions = level.explodeSpecialSymbols(for: chains)
        XCTAssertTrue(reactions.flatMap(\.detonations).contains { $0.symbol === hit && $0.sourceType == .redPocket })
        level.levelGoal.levelTarget = LevelTarget(lightningCombos: 10, fiveCombos: 10)
        level.updateLevelTarget(by: chains.union(reactions))
        XCTAssertEqual(level.levelGoal.levelTarget.lightningCombos, 9, "A row and column are one activation")
    }

    func testCombinationDemosPreservePairOnRestart() async throws {
        let game = makeGame()
        for kind in PowerUpCombination.allCases {
            game.debugLaunchCombinationDemo(kind)
            await game.setupNewGame()
            for _ in 0..<2 {
                let a = try XCTUnwrap(game.level.symbol(atColumn: game.numColumns / 2 - 1, row: game.numRows / 2))
                let b = try XCTUnwrap(game.level.symbol(atColumn: game.numColumns / 2, row: game.numRows / 2))
                XCTAssertEqual(PowerUpCombination(a.type, b.type), kind)
                await game.onTapRestartLevel()
            }
        }
    }

    func testAllCombinationAnimationsAndAurasCleanUpWithReducedEffects() async throws {
        for reduced in [false, true] {
            for kind in PowerUpCombination.allCases {
                let game = makeGame()
                await game.setupNewGame()
                let (level, swap) = try combinationFixture(kind)
                if kind == .fiveLightning || kind == .enhancedFive {
                    let plan = level.makeCombinationChain(kind, for: swap)
                    let hits = plan.symbols.filter { symbol in
                        !plan.combinationSources.contains { $0 === symbol }
                            && !plan.transformedSymbols.contains { $0 === symbol }
                    }
                    hits.first?.type = .lightning
                    hits.dropFirst().first?.type = .five
                }
                game.level = level
                let settings = SettingModel()
                settings.playSoundEffect = false
                settings.screenShakeEnabled = false
                settings.idleHintsEnabled = false
                let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                                      themeModel: ThemeModel(), settingModel: settings, feedback: GameFeedback(), reduceMotion: reduced)
                scene.setupLayerPosition()
                scene.addTiles()
                scene.gameLayer.isHidden = false
                let view = try presentTestScene(scene)
                let pieces = (0..<level.numRows).flatMap { row in
                    (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
                }
                await scene.addSymbols(for: Set(pieces), shouldAnimate: false)
                func hasActions(_ node: SKNode) -> Bool { node.hasActions() || node.children.contains(where: hasActions) }
                for symbol in [swap.symbolA, swap.symbolB] where symbol.isSpecialPowerUp {
                    let aura = try XCTUnwrap(symbol.sprite?.childNode(withName: "powerAura"))
                    XCTAssertEqual(hasActions(aura), !reduced)
                }
                let initial = try XCTUnwrap(level.tryActivateSpecialSwap(swap))
                let chains = initial.union(level.explodeSpecialSymbols(for: initial))
                var captured = false
                var capturedRelease = false
                if !reduced {
                    scene.run(.customAction(withDuration: 1.08) { _, elapsed in
                        if elapsed > 0.86, !capturedRelease {
                            capturedRelease = true
                            if let texture = view.texture(from: scene, crop: CGRect(x: -187.5, y: -406, width: 375, height: 812)) {
                                let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
                                attachment.name = "Combination-release-\(kind.rawValue)"
                                attachment.lifetime = .keepAlways
                                self.add(attachment)
                            }
                        }
                        guard elapsed > 0.40, !captured else { return }
                        captured = true
                        for chain in chains where chain.transformationType != nil {
                            for symbol in chain.transformedSymbols {
                                XCTAssertNotNil(symbol.sprite?.parent, "Conversion must remain visible before release")
                                XCTAssertTrue(symbol.sprite?.texture === TileArtwork.texture(for: symbol.type, zodiac: game.zodiac))
                                XCTAssertEqual(scene.combinationDelay(for: symbol, chain: chain), 0.52)
                            }
                        }
                        if let texture = view.texture(from: scene, crop: CGRect(x: -187.5, y: -406, width: 375, height: 812)) {
                            let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
                            attachment.name = "Combination-\(kind.rawValue)"
                            attachment.lifetime = .keepAlways
                            self.add(attachment)
                        }
                    }, withKey: "comboSnapshot")
                }
                await scene.animateMatchedSymbols(for: chains)
                XCTAssertTrue(scene.effectsLayer.children.isEmpty)
                XCTAssertTrue(scene.removingSprites.isEmpty)
                XCTAssertTrue(chains.flatMap(\.clearedSymbols).allSatisfy { $0.sprite?.parent == nil })
                scene.removeAction(forKey: "comboSnapshot")
                scene.removeAllSymbols()
            }
        }
    }

    func testPauseRestartResetsAttemptAndPreservesInventory() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let initialLevel = try XCTUnwrap(game.level)
        let initialMoves = initialLevel.maximumMoves
        let initialGoals = game.createLevelTargetDatas().map(\.targetNum)
        let inventory = (game.hammerCharges, game.shuffleCharges, game.lives, game.coins)
        game.score = 1200
        game.movesLeft = 2
        game.pendingExtraMoves = 5
        game.hammerModeActive = true
        await game.onTapRestartLevel()
        XCTAssertFalse(game.level === initialLevel)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(game.currentLevel, 1)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.movesLeft, initialMoves)
        XCTAssertEqual(game.createLevelTargetDatas().map(\.targetNum), initialGoals)
        XCTAssertFalse(game.hammerModeActive)
        XCTAssertEqual(game.hammerCharges, inventory.0)
        XCTAssertEqual(game.shuffleCharges, inventory.1)
        XCTAssertEqual(game.lives, inventory.2)
        XCTAssertEqual(game.coins, inventory.3)

        for special in [true, false] {
            if special { game.debugLaunchSpecialDemo() } else { game.debugLaunchElementsDemo() }
            await game.setupNewGame()
            let oldLevel = game.level
            game.movesLeft = 1
            game.secondsLeft = 1
            await game.onTapRestartLevel()
            XCTAssertFalse(game.level === oldLevel)
            XCTAssertEqual(game.gameState, .inProgress)
            XCTAssertEqual(game.movesLeft, special ? 30 : 40)
            XCTAssertEqual(game.secondsLeft, special ? nil : 240)
            XCTAssertTrue(game.shouldPresentDebugDemo)
        }
    }

    func testPauseRestartDuringClearInvalidatesOldMove() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.grantRewardedHammer()
        game.hammerModeActive = true
        let tile = try XCTUnwrap(game.level.symbol(atColumn: 0, row: 0))
        var restarted = false
        game.invokeCommandAsync = { command in
            if case .onMatchedSymbols = command, !restarted {
                restarted = true
                await game.onTapRestartLevel()
            }
        }
        await game.useHammer(atColumn: tile.column, row: tile.row)
        XCTAssertTrue(restarted)
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.movesLeft, game.level.maximumMoves)
        XCTAssertFalse(game.isResolvingBoard)
    }

    func testDebugDemosStartPlayableFreshAttempts() async throws {
        let game = makeGame()
        for specialDemo in [true, false] {
            game.gameState = .win
            game.pendingExtraMoves = 5
            game.hammerModeActive = true
            if specialDemo { game.debugLaunchSpecialDemo() }
            else { game.debugLaunchElementsDemo() }
            XCTAssertEqual(game.gameState, .loading)
            XCTAssertFalse(game.hammerModeActive)
            XCTAssertEqual(game.pendingExtraMoves, 0)
            await game.setupNewGame()
            XCTAssertEqual(game.gameState, .inProgress)
            XCTAssertEqual(game.movesLeft, specialDemo ? 30 : 40)
            XCTAssertEqual(game.secondsLeft, specialDemo ? nil : 240)
            XCTAssertNil(game.currentLevelRecord)
            let symbols = (0..<game.numRows).flatMap { row in
                (0..<game.numColumns).compactMap { game.level.symbol(atColumn: $0, row: row) }
            }
            XCTAssertEqual(symbols.count, game.numRows * game.numColumns)
            if specialDemo {
                XCTAssertEqual(symbols.filter { $0.type == .lightning }.count, 2)
                XCTAssertEqual(symbols.filter { $0.type == .five }.count, 2)
                XCTAssertEqual(symbols.filter { $0.type.isEnhanced }.count, 1)
            }
            game.onTapBack()
            XCTAssertFalse(game.shouldPresentDebugDemo)
        }
    }

    func testTileArtworkIsTransparentAndUsesOneCachedTexture() throws {
        let names = ["firecracker", "redPocket", "dumpling", "bowl", "lantern", "RatTile", "OxTile", "TigerTile", "StarTile", "LockTile", "LightningTile", "FiveTile"]
        for name in names {
            let image = try XCTUnwrap(UIImage(named: name), name)
            let cg = try XCTUnwrap(image.cgImage)
            XCTAssertEqual(cg.width, 256, name)
            XCTAssertEqual(cg.height, 256, name)
            XCTAssertLessThan(alpha(image, at: .zero), 0.01, name)
        }
        for zodiac in Zodiac.all.prefix(3) {
            let first = TileArtwork.texture(for: .zodiac, zodiac: zodiac)
            XCTAssertFalse(first === TileArtwork.texture(for: .zodiacEnhanced, zodiac: zodiac))
            XCTAssertTrue(first === TileArtwork.texture(for: .zodiac, zodiac: zodiac))
            XCTAssertNotNil(zodiac.tileAssetName)
        }
        XCTAssertFalse(TileArtwork.texture(for: .firecracker, zodiac: Zodiac.all[0]) ===
                      TileArtwork.texture(for: .firecrackerEnhanced, zodiac: Zodiac.all[0]))
    }

    func testBoardSurfaceKeepsHolesTransparentAndFitsAvailableSpace() {
        let image = BoardSurface.image(columns: 3, rows: 3, tileSize: CGSize(width: 48, height: 48)) { column, row in
            !(column == 1 && row == 1)
        }
        XCTAssertEqual(image.size, CGSize(width: 158, height: 158))
        XCTAssertLessThan(alpha(image, at: CGPoint(x: 79, y: 79)), 0.01)
        XCTAssertGreaterThan(alpha(image, at: CGPoint(x: 31, y: 31)), 0.99)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Board-with-hole"
        attachment.lifetime = .keepAlways
        add(attachment)
        let game = makeGame()
        for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 812), CGSize(width: 812, height: 375)] {
            game.screenSize = size
            XCTAssertGreaterThan(game.tileSize.width, 0)
            XCTAssertLessThanOrEqual(game.tileSize.width * CGFloat(game.numColumns), size.width - 40)
            XCTAssertLessThanOrEqual(game.tileSize.height * CGFloat(game.numRows), max(120, size.height - 360))
        }
    }

    func testNewBoardRendersAcrossPlayableChapters() async throws {
        for (index, width, height) in [(0, 375.0, 812.0), (1, 375.0, 812.0), (2, 375.0, 812.0), (0, 320.0, 568.0)] {
            let game = makeGame()
            game.zodiac = Zodiac.all[index]
            game.selectLevel(1)
            await game.setupNewGame()
            let settings = SettingModel()
            settings.isPlayBackgroundMusic = false
            settings.playSoundEffect = false
            settings.idleHintsEnabled = false
            let size = CGSize(width: width, height: height)
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
            let controller = UIViewController()
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            controller.view = view
            window.rootViewController = controller
            window.makeKeyAndVisible()
            view.presentScene(scene)
            defer {
                view.presentScene(nil)
                window.isHidden = true
                previousWindow?.makeKeyAndVisible()
                game.onTapBack()
            }
            XCTAssertEqual(scene.tilesLayer.children.count, 1)
            XCTAssertEqual(scene.maskLayer.children.count, symbols.count)
            let selected = try XCTUnwrap(symbols.first)
            let texture = selected.sprite?.texture
            scene.showSelectionIndicator(of: selected)
            XCTAssertNotNil(selected.sprite?.childNode(withName: "tileSelection"))
            XCTAssertTrue(selected.sprite?.texture === texture)
            let rendered = try XCTUnwrap(view.texture(from: scene,
                crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)))
            let image = UIImage(cgImage: rendered.cgImage())
            let attachment = XCTAttachment(image: image)
            attachment.name = "Board-\(game.zodiac.zodiacType.name)-\(Int(width))"
            attachment.lifetime = .keepAlways
            add(attachment)

            // Review charged pieces in context, including adjacent enhanced tiles
            // and selection; the power marking must not replace the selection ring.
            let charged = Array(symbols.filter { $0.row == 2 && $0.type.isNormalMatchable }.prefix(2))
                + Array(symbols.filter { $0.row == 4 && $0.type.isNormalMatchable }.prefix(1))
            for symbol in charged {
                symbol.sprite?.removeFromParent()
                symbol.enhance()
            }
            await scene.addSymbols(for: Set(charged), shouldAnimate: false)
            let selectedCharge = try XCTUnwrap(charged.first)
            XCTAssertTrue(selectedCharge.type.isEnhanced)
            scene.showSelectionIndicator(of: selectedCharge)
            XCTAssertNotNil(selectedCharge.sprite?.childNode(withName: "tileSelection"))
            let chargedRender = try XCTUnwrap(view.texture(from: scene,
                crop: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)))
            let chargedAttachment = XCTAttachment(image: UIImage(cgImage: chargedRender.cgImage()))
            chargedAttachment.name = "Enhanced-board-\(game.zodiac.zodiacType.name)-\(Int(width))"
            chargedAttachment.lifetime = .keepAlways
            add(chargedAttachment)
        }
    }

    func testEnhancedAppearanceIsPersistentCachedAndParticleFree() {
        let types: [SymbolType] = [.firecracker, .redPocket, .dumpling, .bowl, .lantern, .zodiac]
        for zodiac in Zodiac.all {
            for type in types {
                let enhanced = type.enhancedType
                let baseTexture = TileArtwork.texture(for: type, zodiac: zodiac)
                let texture = TileArtwork.texture(for: enhanced, zodiac: zodiac)
                XCTAssertFalse(baseTexture === texture)
                XCTAssertTrue(texture === TileArtwork.texture(for: enhanced, zodiac: zodiac))
                let sprite = Symbol(column: 0, row: 0, symbolType: enhanced).createSpriteNode(zodiac: zodiac)
                XCTAssertTrue(sprite.children.isEmpty, "Resting enhanced tiles need no particle/overlay nodes")
                XCTAssertFalse(sprite.hasActions(), "The power marker cannot depend on an idle animation")
                let image = UIImage(cgImage: texture.cgImage())
                XCTAssertLessThan(alpha(image, at: .zero), 0.01)
                XCTAssertGreaterThan(alpha(image, at: CGPoint(x: 128, y: 20)), 0.99)
                XCTAssertTrue(enhanced.isMatchableTo(type))
            }
        }
    }

    func testEnhancedPowerStillClearsEightSurroundingCells() throws {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        _ = level.shuffle()
        let symbol = try XCTUnwrap(level.symbol(atColumn: 3, row: 3))
        let originalType = symbol.type
        symbol.enhance()
        XCTAssertTrue(symbol.type.isEnhanced)
        XCTAssertTrue(symbol.type.isMatchableTo(originalType))
        let affected = level.detectSpecialElimination(for: symbol).flatMap(\.symbols)
        XCTAssertEqual(affected.count, 8)
        XCTAssertFalse(affected.contains { $0.column == 3 && $0.row == 3 })
        XCTAssertTrue(affected.allSatisfy { abs($0.column - 3) <= 1 && abs($0.row - 3) <= 1 })
    }

    func testEnhancedArtworkComparisonAtGameSizes() {
        let entries: [(String, SymbolType, Zodiac)] = [
            ("Firecracker", .firecracker, Zodiac.all[0]), ("Red envelope", .redPocket, Zodiac.all[0]),
            ("Dumpling", .dumpling, Zodiac.all[0]), ("Bowl", .bowl, Zodiac.all[0]),
            ("Lantern", .lantern, Zodiac.all[0]), ("Rat", .zodiac, Zodiac.all[0]),
            ("Ox", .zodiac, Zodiac.all[1]), ("Tiger", .zodiac, Zodiac.all[2])
        ]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 460, height: 690)).image { _ in
            UIColor(hex: 0x203C46).setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 460, height: 690)).fill()
            func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 13) {
                text.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: UIColor.white])
            }
            label("ENHANCED TILES · STATIC / REDUCED EFFECTS", 16, 16, 16)
            label("Original", 140, 51); label("64 pt", 235, 51); label("48 pt", 321, 51); label("32 pt", 394, 51)
            for (index, entry) in entries.enumerated() {
                let y = CGFloat(82 + index * 74)
                label(entry.0, 16, y + 23)
                let normal = UIImage(cgImage: TileArtwork.texture(for: entry.1, zodiac: entry.2).cgImage())
                let enhanced = UIImage(cgImage: TileArtwork.texture(for: entry.1.enhancedType, zodiac: entry.2).cgImage())
                normal.draw(in: CGRect(x: 136, y: y, width: 64, height: 64))
                enhanced.draw(in: CGRect(x: 229, y: y, width: 64, height: 64))
                enhanced.draw(in: CGRect(x: 316, y: y + 8, width: 48, height: 48))
                enhanced.draw(in: CGRect(x: 392, y: y + 16, width: 32, height: 32))
            }
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Enhanced-tile-comparison"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAllPowerBirthsAndClearsReturnToRestWithoutFloatingScores() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let settings = SettingModel()
        settings.playSoundEffect = false
        settings.idleHintsEnabled = false
        settings.screenShakeEnabled = false
        let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                              themeModel: ThemeModel(), settingModel: settings, feedback: GameFeedback())
        scene.setupLayerPosition()
        scene.addTiles()
        scene.gameLayer.isHidden = false
        let view = try presentTestScene(scene)
        let powerTypes: [SymbolType] = [.firecrackerEnhanced, .redPocketEnhanced, .dumplingEnhanced,
                                       .bowlEnhanced, .lanternEnhanced, .zodiacEnhanced, .five, .lightning]
        let moves = game.movesLeft
        let score = game.score
        for reduced in [false, true] {
            scene.reduceMotion = reduced
            let powers = powerTypes.enumerated().map { index, type in
                Symbol(column: index % 4 + 1, row: index / 4 + 2, symbolType: type)
            }
            await scene.animateCreatingSpecialSymbols(for: powers)
            for symbol in powers {
                let sprite = try XCTUnwrap(symbol.sprite)
                XCTAssertEqual(sprite.xScale, 1)
                XCTAssertEqual(sprite.alpha, 1)
                XCTAssertTrue(sprite.children.allSatisfy { $0.name == "powerAura" })
                XCTAssertFalse(sprite.hasActions())
            }
            scene.removeAllSymbols()
            for kind: Chain.ChainType in [.horizontal3, .enhanced, .single, .lightning, .fiveEffect, .locks] {
                let symbols = (0..<5).map { Symbol(column: $0 + 1, row: 3, symbolType: .bowl) }
                if kind == .fiveEffect { symbols[0].type = .five }
                else if kind == .lightning { symbols[0].type = .lightning }
                else if kind == .enhanced { symbols[0].type = .bowlEnhanced }
                else if kind == .locks { symbols.forEach { $0.type = .lock } }
                await scene.addSymbols(for: Set(symbols), shouldAnimate: false)
                let chain = Chain(chainType: kind)
                chain.add(symbols: symbols)
                let overlap = Chain(chainType: .vertical3)
                overlap.add(symbols: Array(symbols.prefix(3)))
                // Record a frame at a known point in SpriteKit's animation timeline;
                // test completion still awaits the real clear, never a wall-clock sleep.
                var captured = Set<Int>()
                if !reduced {
                    let frames: [CGFloat] = kind == .fiveEffect ? [0.16, 0.32, 0.52] : [0.08]
                    scene.run(.customAction(withDuration: kind == .fiveEffect ? 0.7 : 0.2) { _, elapsed in
                        guard let index = frames.indices.first(where: { elapsed >= frames[$0] && !captured.contains($0) }) else { return }
                        captured.insert(index)
                        if let texture = view.texture(from: scene, crop: CGRect(x: -187.5, y: -406, width: 375, height: 812)) {
                            let attachment = XCTAttachment(image: UIImage(cgImage: texture.cgImage()))
                            attachment.name = "Clear-\(kind)-\(index)"
                            attachment.lifetime = .keepAlways
                            self.add(attachment)
                        }
                    }, withKey: "clearSnapshot")
                }
                await scene.animateMatchedSymbols(for: [chain, overlap])
                XCTAssertTrue(symbols.allSatisfy { $0.sprite?.parent == nil })
                XCTAssertTrue(scene.effectsLayer.children.isEmpty)
                XCTAssertTrue(scene.removingSprites.isEmpty)
                XCTAssertFalse(scene.symbolsLayer.children.contains { $0 is SKLabelNode })
                scene.removeAction(forKey: "clearSnapshot")
            }
        }
        XCTAssertEqual(game.movesLeft, moves)
        XCTAssertEqual(game.score, score)
    }

    func testRestartDuringFiveAnimationKeepsFreshSpritesAndClearsEffects() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let settings = SettingModel()
        settings.playSoundEffect = false
        settings.idleHintsEnabled = false
        settings.screenShakeEnabled = false
        let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                              themeModel: ThemeModel(), settingModel: settings, feedback: GameFeedback())
        scene.setupLayerPosition()
        scene.addTiles()
        scene.gameLayer.isHidden = false
        _ = try presentTestScene(scene)
        let oldSymbols = (0..<5).map { Symbol(column: $0 + 1, row: 3, symbolType: $0 == 0 ? .five : .bowl) }
        await scene.addSymbols(for: Set(oldSymbols), shouldAnimate: false)
        let chain = Chain(chainType: .fiveEffect)
        chain.add(symbols: oldSymbols)
        let finished = expectation(description: "Interrupted Five clear completes")
        let clear = Task { @MainActor in
            await scene.animateMatchedSymbols(for: [chain])
            finished.fulfill()
        }
        await scene.run(.wait(forDuration: 0.2))
        await game.onTapRestartLevel()
        await fulfillment(of: [finished], timeout: 3)
        clear.cancel()
        XCTAssertEqual(game.gameState, .inProgress)
        XCTAssertEqual(game.score, 0)
        XCTAssertEqual(game.movesLeft, game.level.maximumMoves)
        XCTAssertTrue(scene.effectsLayer.children.isEmpty)
        XCTAssertTrue(scene.removingSprites.isEmpty)
        for row in 0..<game.numRows {
            for column in 0..<game.numColumns {
                if let symbol = game.level.symbol(atColumn: column, row: row) {
                    XCTAssertTrue(symbol.sprite?.parent === scene.symbolsLayer)
                    XCTAssertEqual(symbol.sprite?.alpha, 1)
                }
            }
        }
    }

    func testRestartDuringConversionDiscardsOldBlasts() async throws {
        for kind in [PowerUpCombination.enhancedFive, .fiveLightning] {
            let game = makeGame()
            game.debugLaunchCombinationDemo(kind)
            await game.setupNewGame()
            let settings = SettingModel()
            settings.playSoundEffect = false
            settings.screenShakeEnabled = false
            settings.idleHintsEnabled = false
            let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                                  themeModel: ThemeModel(), settingModel: settings, feedback: GameFeedback())
            scene.setupLayerPosition()
            scene.addTiles()
            scene.gameLayer.isHidden = false
            _ = try presentTestScene(scene)
            let level = try XCTUnwrap(game.level)
            let pieces = (0..<level.numRows).flatMap { row in
                (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
            }
            await scene.addSymbols(for: Set(pieces), shouldAnimate: false)
            let a = try XCTUnwrap(level.symbol(atColumn: level.numColumns / 2 - 1, row: level.numRows / 2))
            let b = try XCTUnwrap(level.symbol(atColumn: level.numColumns / 2, row: level.numRows / 2))
            let initial = try XCTUnwrap(level.tryActivateSpecialSwap(Swap(symbolA: a, symbolB: b)))
            let chains = initial.union(level.explodeSpecialSymbols(for: initial))
            async let clearing: Void = scene.animateMatchedSymbols(for: chains)
            await scene.run(.wait(forDuration: 0.30))
            await game.onTapRestartLevel()
            await clearing
            XCTAssertEqual(game.gameState, .inProgress)
            XCTAssertEqual(game.score, 0)
            XCTAssertTrue(scene.effectsLayer.children.isEmpty)
            XCTAssertTrue(scene.removingSprites.isEmpty)
            for row in 0..<game.numRows {
                for column in 0..<game.numColumns {
                    if let symbol = game.level.symbol(atColumn: column, row: row) {
                        XCTAssertNil(symbol.convertedFromType)
                        XCTAssertTrue(symbol.sprite?.parent === scene.symbolsLayer)
                        XCTAssertEqual(symbol.sprite?.alpha, 1)
                    }
                }
            }
        }
    }

    func testLockArtworkTracksAllDamageStages() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                              themeModel: ThemeModel(), settingModel: SettingModel(), feedback: GameFeedback(), reduceMotion: true)
        let symbol = try XCTUnwrap(game.level.symbol(atColumn: 3, row: 3))
        symbol.type = .vaultLock
        await scene.addSymbols(for: [symbol], shouldAnimate: false)
        let sprite = try XCTUnwrap(symbol.sprite)
        let threeHit = try XCTUnwrap(sprite.texture)
        _ = game.level.useHammer(atColumn: 3, row: 2)
        _ = game.level.resolveBlockers()
        game.invokeCommand?(.refreshOverlays)
        XCTAssertEqual(game.level.symbol(atColumn: 3, row: 3)?.type, .heavyLock)
        XCTAssertTrue(sprite.texture === TileArtwork.texture(for: .heavyLock, zodiac: game.zodiac))
        XCTAssertFalse(sprite.texture === threeHit)
        _ = game.level.resolveBlockers()
        game.invokeCommand?(.refreshOverlays)
        XCTAssertEqual(game.level.symbol(atColumn: 3, row: 3)?.type, .lock)
        XCTAssertTrue(sprite.texture === TileArtwork.texture(for: .lock, zodiac: game.zodiac))
        let cleared = try XCTUnwrap(game.level.resolveBlockers())
        XCTAssertTrue(cleared.symbols.contains { $0.column == 3 && $0.row == 3 })
        XCTAssertNil(game.level.symbol(atColumn: 3, row: 3))
    }

    func testBonusWaveRefillAndResultResetPreserveState() async throws {
        let game = makeGame()
        await game.setupNewGame()
        let settings = SettingModel()
        settings.playSoundEffect = false
        settings.idleHintsEnabled = false
        let scene = GameScene(size: CGSize(width: 375, height: 812), gameModel: game,
                              themeModel: ThemeModel(), settingModel: settings, feedback: GameFeedback())
        scene.setupLayerPosition()
        _ = try presentTestScene(scene)
        for reduced in [false, true] {
            scene.reduceMotion = reduced
            let symbols = (0..<4).map { Symbol(column: $0, row: 2, symbolType: .firecrackerEnhanced) }
            let moves = game.movesLeft
            await scene.animateEnhancedSymbols(for: symbols)
            XCTAssertEqual(game.movesLeft, moves - 4)
            for symbol in symbols {
                let position = try XCTUnwrap(symbol.sprite?.position)
                let expected = scene.pointFor(column: symbol.column, row: symbol.row)
                XCTAssertEqual(position.x, expected.x, accuracy: 0.001)
                XCTAssertEqual(position.y, expected.y, accuracy: 0.001)
                XCTAssertEqual(symbol.sprite?.xScale, 1)
            }
            await scene.animateFallingSymbols(in: [symbols])
            await scene.animateNewSymbols(in: [[], [Symbol(column: 0, row: 5, symbolType: .bowl)]])
            await scene.animateGameOver()
            XCTAssertEqual(scene.gameLayer.position, .zero)
            XCTAssertEqual(scene.gameLayer.alpha, 0.65, accuracy: 0.01)
            await scene.animateBeginGame()
            XCTAssertEqual(scene.gameLayer.position, .zero)
            XCTAssertEqual(scene.gameLayer.alpha, 1)
            XCTAssertEqual(scene.gameLayer.xScale, 1)
            scene.removeAllSymbols()
        }
        scene.reduceMotion = false
        let movesBeforeExit = game.movesLeft
        scene.run(.run { game.onTapBack() }, withKey: "exitDuringBonus")
        await scene.animateEnhancedSymbols(for: [Symbol(column: 0, row: 0, symbolType: .bowlEnhanced)])
        XCTAssertEqual(game.gameState, .notStart)
        XCTAssertEqual(game.movesLeft, movesBeforeExit)
    }

    func testResultScreensAndFiniteConfettiAtAccessibleSizes() async throws {
        let game = makeGame()
        await game.setupNewGame()
        game.movesLeft = 0
        game.score = 1000
        game.level.levelGoal.levelTarget = LevelTarget()
        await game.beginNextTurn()
        for (size, accessible, dark) in [(CGSize(width: 320, height: 568), false, false),
                                          (CGSize(width: 375, height: 812), true, true),
                                          (CGSize(width: 812, height: 375), false, true)] {
            try await snapshot(name: "Defeat-\(Int(size.width))-\(accessible)", size: size) { ready in
                LevelFailedView(onRevealComplete: ready)
                    .environmentObject(game)
                    .environment(\.dynamicTypeSize, accessible ? .accessibility3 : .large)
                    .environment(\.gameReducedEffects, accessible)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .background(AppTheme.festivalRedDark)
            }
            try await snapshot(name: "New-Victory-\(Int(size.width))-\(accessible)", size: size) { ready in
                LevelCompleteView(onRevealComplete: ready)
                    .environmentObject(game)
                    .environment(\.dynamicTypeSize, accessible ? .accessibility3 : .large)
                    .environment(\.gameReducedEffects, accessible)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .background(AppTheme.festivalRedDark)
            }
        }
        for reduced in [false, true] {
            try await snapshot(name: "Confetti-finished-\(reduced)", size: CGSize(width: 375, height: 812)) { ready in
                CelebrationBurstView(onComplete: ready).environment(\.gameReducedEffects, reduced)
            }
        }
    }

    private func presentTestScene(_ scene: GameScene) throws -> SKView {
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let window = UIWindow(windowScene: windowScene)
        let controller = UIViewController()
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
        view.presentScene(scene)
        addTeardownBlock { @MainActor in
            view.presentScene(nil)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        return view
    }

    private func alpha(_ image: UIImage, at point: CGPoint) -> CGFloat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pixel = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(at: CGPoint(x: -point.x, y: -point.y))
        }
        guard let cg = pixel.cgImage, let data = cg.dataProvider?.data else { return -1 }
        let bytes = CFDataGetBytePtr(data)!
        return CGFloat(bytes[3]) / 255
    }

    /// Native hosting is required here: ImageRenderer cannot snapshot the live ScrollView
    /// and SpriteKit-backed app window. Wait on appearance/reveal completion, not sleeps.
    private func snapshot<Content: View>(name: String, size: CGSize,
                                        content: (@escaping () -> Void) -> Content) async throws {
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = windowScene.keyWindow
        let ready = expectation(description: "\(name) ready")
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: content { ready.fulfill() })
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        await fulfillment(of: [ready], timeout: 5)
        host.view.layoutIfNeeded()
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, size)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if name.hasPrefix("Map-progress-19-") {
            func findScroll(in view: UIView) -> UIScrollView? {
                if let scroll = view as? UIScrollView { return scroll }
                return view.subviews.lazy.compactMap { findScroll(in: $0) }.first
            }
            let scroll = try XCTUnwrap(findScroll(in: host.view))
            XCTAssertGreaterThan(scroll.contentOffset.y, 2000, "Map must open near level 19, not level 1")
        }
        if name.hasPrefix("Defeat-") || name.hasPrefix("New-Victory-") {
            func scrollViews(in view: UIView) -> [UIScrollView] {
                (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
            }
            let scroll = try XCTUnwrap(scrollViews(in: host.view).first)
            let bottom = max(-scroll.adjustedContentInset.top,
                             scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            scroll.layoutIfNeeded()
            window.layoutIfNeeded()
            XCTAssertEqual(scroll.contentOffset.y, bottom, accuracy: 0.5)
            let bottomImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let bottomAttachment = XCTAttachment(image: bottomImage)
            bottomAttachment.name = "\(name)-scrolled-controls"
            bottomAttachment.lifetime = .keepAlways
            add(bottomAttachment)
        }
    }
}
