import XCTest
@testable import SpringFestivalCrush

final class RetryAdviceTests: XCTestCase {
    func testMixedGoalsChooseOneTipInStablePriorityOrder() {
        let guardian = BossEncounter(configuration: .init(kind: .ox, health: 20))
        var goals = ["ingredient": 2, "lightningCombos": 1, "lock": 3, "jelly": 4, "lantern": 5]
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: guardian), .gifts)
        goals["ingredient"] = 0
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: guardian), .activations)
        goals["lightningCombos"] = -1
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: guardian), .ox)
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: nil), .locks)
        goals["lock"] = 0
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: nil), .blossoms)
        goals["jelly"] = 0
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: nil), .colors)
    }

    func testEverySupportedPositiveGoalSelectsItsRelevantAdvice() {
        let categories: [(RetryAdvice, [String])] = [
            (.gifts, ["ingredient"]),
            (.activations, ["lightningCombos", "fiveCombos", "enhancedCombos"]),
            (.locks, ["lock"]), (.blossoms, ["jelly"]),
            (.colors, ["firecracker", "redPocket", "dumpling", "bowl", "lantern", "zodiac"])
        ]
        for (advice, keys) in categories {
            for key in keys {
                XCTAssertEqual(RetryAdvice.choose(remainingGoals: [key: 1], guardian: nil), advice, key)
                XCTAssertNil(RetryAdvice.choose(remainingGoals: [key: 0], guardian: nil), key)
                XCTAssertNil(RetryAdvice.choose(remainingGoals: [key: -1], guardian: nil), key)
            }
        }
    }

    func testMissingCompletedAndUnsupportedGoalsDoNotInventAdvice() {
        XCTAssertNil(RetryAdvice.choose(remainingGoals: [:], guardian: nil))
        XCTAssertNil(RetryAdvice.choose(remainingGoals: ["ingredient": 0, "fiveCombos": -2, "jelly": 0], guardian: nil))
        XCTAssertNil(RetryAdvice.choose(remainingGoals: ["futureGoal": 10], guardian: nil))
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: ["futureGoal": 10, "lantern": 1], guardian: nil), .colors)
    }

    func testLivingGuardiansGiveAccurateWeaknessAdviceWithoutMutatingThem() {
        let cases: [(BossConfiguration.Kind, RetryAdvice)] = [(.rat, .rat), (.ox, .ox), (.tiger, .tiger), (.rabbit, .rabbit)]
        for (kind, advice) in cases {
            let guardian = BossEncounter(configuration: .init(kind: kind, health: 24))
            for _ in 0..<10 {
                XCTAssertEqual(RetryAdvice.choose(remainingGoals: [:], guardian: guardian), advice)
            }
            XCTAssertEqual(guardian.health, 24)
            XCTAssertEqual(guardian.turns, 0)
        }
        var rat = BossEncounter(configuration: .init(kind: .rat, health: 24))
        for _ in 0..<3 { _ = rat.advanceTurn() }
        XCTAssertEqual(rat.tribute, .dumpling)
        XCTAssertEqual(RetryAdvice.choose(remainingGoals: [:], guardian: rat), .rat,
                       "Retry advice must not lock onto a tribute color that resets with the next attempt")
        XCTAssertEqual(rat.turns, 3)
    }

    func testDefeatedOrInvalidGuardiansFallBackToUnfinishedGoals() {
        var defeated = BossEncounter(configuration: .init(kind: .rabbit, health: 6))
        let hit = Chain(chainType: .horizontal3)
        hit.add(symbols: (0..<6).map { Symbol(column: $0, row: 0, symbolType: .lantern) })
        defeated.receive(chains: [hit], cascadeDepth: 1)
        XCTAssertEqual(defeated.health, 0)
        let invalid = BossEncounter(configuration: .init(kind: .tiger, health: -1))
        for guardian in [defeated, invalid] {
            XCTAssertNil(RetryAdvice.choose(remainingGoals: [:], guardian: guardian))
            XCTAssertEqual(RetryAdvice.choose(remainingGoals: ["jelly": 2], guardian: guardian), .blossoms)
        }
    }

    func testChoosingAdviceLeavesMixedGoalCountsUnchanged() {
        let goals = ["ingredient": 1, "lightningCombos": 2, "jelly": 3, "lantern": 4]
        let expected = goals
        for _ in 0..<20 { XCTAssertEqual(RetryAdvice.choose(remainingGoals: goals, guardian: nil), .gifts) }
        XCTAssertEqual(goals, expected)
    }
}
