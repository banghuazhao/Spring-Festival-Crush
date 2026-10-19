import XCTest
@testable import SpringFestivalCrush

@MainActor
final class GoalAwareHintTests: XCTestCase {
    private struct Fixture {
        let level: Level
        let first: Swap
        let second: Swap
    }

    private func fixture() throws -> Fixture {
        let level = try XCTUnwrap(Level(filename: "Rat_Level_1"))
        level.noShuffle = true
        _ = level.shuffle()
        for row in 0..<level.numRows {
            for column in 0..<level.numColumns {
                let piece = try XCTUnwrap(level.symbol(atColumn: column, row: row))
                piece.type = .lock
                piece.iceLayer = 0
                piece.armorLayers = 0
                piece.armorHitThisTurn = false
            }
        }
        func matchingSwap(column: Int, row: Int, color: SymbolType) throws -> Swap {
            let a = try XCTUnwrap(level.symbol(atColumn: column, row: row))
            let b = try XCTUnwrap(level.symbol(atColumn: column, row: row + 1))
            a.type = color
            b.type = .lantern
            level.symbol(atColumn: column - 1, row: row + 1)?.type = color
            level.symbol(atColumn: column + 1, row: row + 1)?.type = color
            return Swap(symbolA: a, symbolB: b)
        }
        let first = try matchingSwap(column: 1, row: 1, color: .redPocket)
        let second = try matchingSwap(column: 4, row: 3, color: .dumpling)
        level.possibleSwaps = [first, second]
        level.levelGoal.levelTarget = LevelTarget()
        return Fixture(level: level, first: first, second: second)
    }

    private func snapshot(_ level: Level) throws -> [String] {
        var result: [String] = []
        for row in 0..<level.numRows {
            for column in 0..<level.numColumns {
                let piece = try XCTUnwrap(level.symbol(atColumn: column, row: row))
                result.append("\(ObjectIdentifier(piece)):\(piece.column),\(piece.row):\(piece.type.rawValue):"
                    + "\(piece.convertedFromType?.rawValue ?? "none"):\(piece.armorLayers):\(piece.armorHitThisTurn):\(piece.iceLayer):"
                    + "\(level.tileAt(column: column, row: row)?.jellyCount ?? 0)")
            }
        }
        return result
    }

    func testHintPrefersUnfinishedColorAndIgnoresCompletedOrNegativeGoals() throws {
        let f = try fixture()
        f.level.levelGoal.levelTarget = LevelTarget(redPocket: 0, dumpling: 3)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.levelGoal.levelTarget = LevelTarget(redPocket: 3, dumpling: -2)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)
        f.level.levelGoal.levelTarget = LevelTarget()
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first, "No direct goal benefit keeps the old first hint")
    }

    func testGoalCreditIsCappedAndTiesKeepCoordinateOrderInEitherSwapOrientation() throws {
        let f = try fixture()
        f.second.symbolA.type = .redPocket
        for column in [2, 3, 5, 6] { f.level.symbol(atColumn: column, row: 4)?.type = .redPocket }
        f.level.levelGoal.levelTarget = LevelTarget(redPocket: 1)
        let reversedFirst = Swap(symbolA: f.first.symbolB, symbolB: f.first.symbolA)
        f.level.possibleSwaps = [f.second, reversedFirst]
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first,
                       "Five matching tiles cannot earn extra credit when only one is needed")
        f.level.levelGoal.levelTarget.redPocket = 4
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
    }

    func testBlossomLockAndProtectionProgressCanGuideAHint() throws {
        let f = try fixture()
        f.level.tileAt(column: 3, row: 4)?.jellyCount = 2
        f.level.levelGoal.levelTarget = LevelTarget(jelly: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.levelGoal.levelTarget.jelly = 0
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)

        // Chocolate neighbors do not count as locks; only the later move opens the lock.
        for row in 0..<f.level.numRows {
            for column in 0..<f.level.numColumns {
                if f.level.symbol(atColumn: column, row: row)?.type == .lock {
                    f.level.symbol(atColumn: column, row: row)?.type = .chocolate
                }
            }
        }
        f.level.symbol(atColumn: 4, row: 5)?.type = .lock
        f.level.levelGoal.levelTarget = LevelTarget(lock: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)

        f.level.levelGoal.levelTarget = LevelTarget(zodiac: 10)
        f.second.symbolA.armorLayers = 1
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second, "Cracking a frame opens future matching space")
    }

    func testGiftHintRewardsAnOpenLowerPathWithoutClaimingDeliveryFromClearsAboveIt() throws {
        let f = try fixture()
        f.level.levelGoal.levelTarget = LevelTarget(ingredient: 1)
        f.level.symbol(atColumn: 1, row: 0)?.type = .ingredient
        f.level.symbol(atColumn: 4, row: 6)?.type = .ingredient
        f.level.symbol(atColumn: 4, row: 5)?.type = .zodiac
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.symbol(atColumn: 4, row: 5)?.type = .lock
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first,
                       "A blocked path and clears above the other gift do not predict delivery")
    }

    func testActivationGoalsPreferTheNeededPowerAndRecognizeACombinedPair() throws {
        let f = try fixture()
        f.first.symbolA.type = .lightning
        f.second.symbolA.type = .five
        f.level.levelGoal.levelTarget = LevelTarget(fiveCombos: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.levelGoal.levelTarget = LevelTarget(lightningCombos: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)
        f.second.symbolB.type = .lightning
        f.level.levelGoal.levelTarget = LevelTarget(lightningCombos: 1, fiveCombos: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.first.symbolA.armorLayers = 1
        f.level.levelGoal.levelTarget = LevelTarget(lightningCombos: 1)
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second, "Protected powers cannot advertise an active blast")
    }

    func testKnownGuardianWeaknessesInfluenceHintsWithoutForecastingCascades() throws {
        let f = try fixture()
        f.level.boss = BossEncounter(configuration: .init(kind: .rat, health: 20))
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)
        for _ in 0..<3 { _ = f.level.boss?.advanceTurn() }
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second, "The Rat's current tribute is dumplings")
        f.level.boss = BossEncounter(configuration: .init(kind: .tiger, health: 20))
        f.second.symbolA.type = .firecracker
        for column in [3, 5] { f.level.symbol(atColumn: column, row: 4)?.type = .firecracker }
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.boss = BossEncounter(configuration: .init(kind: .rabbit, health: 20))
        f.second.symbolA.type = .lantern
        for column in [3, 5] { f.level.symbol(atColumn: column, row: 4)?.type = .lantern }
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
        f.level.boss = BossEncounter(configuration: .init(kind: .ox, health: 20))
        f.second.symbolA.type = .lightning
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.second)
    }

    func testRepeatedHintsNeverMutateTheBoardGoalsPossibleSwapsOrGuardian() throws {
        let f = try fixture()
        f.level.levelGoal.levelTarget = LevelTarget(dumpling: 3, jelly: 2)
        f.level.tileAt(column: 3, row: 4)?.jellyCount = 2
        f.level.boss = BossEncounter(configuration: .init(kind: .rat, health: 40))
        let before = try snapshot(f.level)
        let swaps = f.level.possibleSwaps
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let goal = try encoder.encode(f.level.levelGoal)
        for _ in 0..<20 { XCTAssertEqual(f.level.goalAwareHintSwap(), f.second) }
        XCTAssertEqual(try snapshot(f.level), before)
        XCTAssertEqual(f.level.possibleSwaps, swaps)
        XCTAssertEqual(try encoder.encode(f.level.levelGoal), goal)
        XCTAssertEqual(f.level.boss?.health, 40)
        XCTAssertEqual(f.level.boss?.turns, 0)
        XCTAssertNil(f.level.lastSwappedSymbols)
    }

    func testStaleNonAdjacentFrozenAndBlockedCandidatesAreRejectedSafely() throws {
        let f = try fixture()
        f.second.symbolA.iceLayer = 1
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)
        f.second.symbolA.iceLayer = 0
        f.second.symbolB.type = .lock
        XCTAssertEqual(f.level.goalAwareHintSwap(), f.first)
        let stale = Symbol(column: .max, row: .min, symbolType: .redPocket)
        f.level.possibleSwaps = [Swap(symbolA: stale, symbolB: f.first.symbolB)]
        XCTAssertNil(f.level.goalAwareHintSwap())
        f.level.possibleSwaps = [Swap(symbolA: f.first.symbolA, symbolB: f.second.symbolA)]
        XCTAssertNil(f.level.goalAwareHintSwap())
        f.level.possibleSwaps = []
        XCTAssertNil(f.level.goalAwareHintSwap())
    }

    func testModelKeepsExistingStateAndToolHintGatesAndHandlesMissingLevel() throws {
        let f = try fixture()
        let game = GameModel()
        game.level = f.level
        game.gameState = .inProgress
        XCTAssertEqual(game.suggestedIdleSwap(), f.first)
        game.hammerModeActive = true
        XCTAssertNil(game.suggestedIdleSwap())
        game.hammerModeActive = false
        game.swapModeActive = true
        XCTAssertNil(game.suggestedIdleSwap())
        game.swapModeActive = false
        game.isTutorialHintActive = true
        XCTAssertNil(game.suggestedIdleSwap())
        game.isTutorialHintActive = false
        for state in [GameModel.GameState.loading, .finishing, .offeringContinue, .lose, .win, .notStart] {
            game.gameState = state
            XCTAssertNil(game.suggestedIdleSwap())
        }
        game.gameState = .inProgress
        game.level = nil
        XCTAssertNil(game.suggestedIdleSwap())
    }
}
