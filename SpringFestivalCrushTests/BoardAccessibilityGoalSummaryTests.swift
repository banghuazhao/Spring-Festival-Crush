import XCTest
import SwiftUI
@testable import SpringFestivalCrush

@MainActor
final class BoardAccessibilityGoalSummaryTests: XCTestCase {
    private func target(_ id: String, _ remaining: Int) -> LevelTargetData {
        LevelTargetData(image: Image(systemName: "circle"), imageName: id, targetNum: remaining)
    }

    func testStatusNamesEverySupportedGoalWithoutInternalIdentifiers() {
        let cases = [
            ("firecracker", "firecrackers"), ("redPocket", "red envelopes"), ("dumpling", "dumplings"),
            ("bowl", "bowls"), ("lantern", "lanterns"), ("zodiac", "Zodiac tiles"), ("lock", "locks"),
            ("jelly", "moon blossoms"), ("ingredient", "gifts to deliver"),
            ("lightningCombos", "Lightning activations"), ("fiveCombos", "Lucky Five activations"),
            ("enhancedCombos", "Blast Tile activations")
        ]
        for (id, name) in cases {
            let summary = BoardAccessibilityGoalSummary(targets: [target(id, 2)])
            // GoalTargetPill uses these same keys; the speech formatter must use the
            // player-facing name even for technical ids such as lightningCombos.
            let localizedName = Bundle.main.localizedString(forKey: name, value: name, table: nil)
            XCTAssertEqual(summary.remainingDescription, String(localized: "\(localizedName): \(2) remaining."))
        }
    }

    func testOneSettledMoveReportsEveryChangedGoalIncludingCompletion() {
        let before = BoardAccessibilityGoalSummary(targets: [
            target("firecracker", 5), target("lock", 1), target("lightningCombos", 2), target("bowl", 4)
        ])
        let after = BoardAccessibilityGoalSummary(targets: [
            target("firecracker", 2), target("lock", 0), target("lightningCombos", 1), target("bowl", 4)
        ])
        let firecrackers = String(localized: "firecrackers")
        let locks = String(localized: "locks")
        let activations = String(localized: "Lightning activations")
        let expected = [
            String(localized: "\(firecrackers): \(2) remaining, \(3) completed this move."),
            String(localized: "\(locks): complete, \(1) completed this move."),
            String(localized: "\(activations): \(1) remaining, \(1) completed this move.")
        ].joined(separator: " ")
        XCTAssertEqual(after.changes(since: before), expected)
        XCTAssertFalse(after.changes(since: before).contains(String(localized: "bowls")))
        XCTAssertFalse(after.changes(since: before).contains("collected"), "Activation goals are completed, not collected")
    }

    func testSnapshotRetainsStartingCountersAfterInputArrayChanges() {
        var targets = [target("dumpling", 6)]
        let before = BoardAccessibilityGoalSummary(targets: targets)
        targets[0] = target("dumpling", 1)
        let after = BoardAccessibilityGoalSummary(targets: targets)
        let name = String(localized: "dumplings")
        XCTAssertEqual(before.remainingDescription, String(localized: "\(name): \(6) remaining."))
        XCTAssertEqual(after.changes(since: before), String(localized: "\(name): \(1) remaining, \(5) completed this move."))
    }

    func testNegativeCountersClampToCompletionAndCannotInventExtraProgress() {
        let before = BoardAccessibilityGoalSummary(targets: [target("jelly", 2)])
        let after = BoardAccessibilityGoalSummary(targets: [target("jelly", -4)])
        let name = String(localized: "moon blossoms")
        XCTAssertEqual(after.remainingDescription, String(localized: "\(name): complete."))
        XCTAssertEqual(after.changes(since: before), String(localized: "\(name): complete, \(2) completed this move."))
        let alreadyComplete = BoardAccessibilityGoalSummary(targets: [target("jelly", -1)])
        XCTAssertEqual(after.changes(since: alreadyComplete), "")
    }

    func testUnchangedAndUnrelatedGoalChangesDoNotClaimProgress() {
        let before = BoardAccessibilityGoalSummary(targets: [target("ingredient", 1), target("lock", 3)])
        XCTAssertEqual(before.changes(since: before), "")
        let changed = BoardAccessibilityGoalSummary(targets: [target("ingredient", 3), target("fiveCombos", 1)])
        let name = String(localized: "gifts to deliver")
        XCTAssertEqual(changed.changes(since: before), String(localized: "\(name): \(3) remaining."))
        XCTAssertEqual(BoardAccessibilityGoalSummary(targets: []).changes(since: before), "")
    }

    func testUnknownGoalUsesSafeNameAndDuplicateIdsAreSpokenOnce() {
        let summary = BoardAccessibilityGoalSummary(targets: [
            target("internal.futureGoal", 2), target("internal.futureGoal", 9)
        ])
        let name = String(localized: "Other goal")
        XCTAssertEqual(summary.remainingDescription, String(localized: "\(name): \(2) remaining."))
        XCTAssertFalse(summary.remainingDescription.contains("internal.futureGoal"))
    }

    func testGuardianDamageDefeatAndNegativeHealthAreSpokenWithoutCollectionGoals() {
        let before = BoardAccessibilityGoalSummary(targets: [], guardianHealth: 10)
        let damaged = BoardAccessibilityGoalSummary(targets: [], guardianHealth: 4)
        XCTAssertEqual(damaged.remainingDescription, String(localized: "Guardian health \(4)."))
        XCTAssertEqual(damaged.changes(since: before), String(localized: "Guardian: \(6) damage, \(4) health remaining."))
        let defeated = BoardAccessibilityGoalSummary(targets: [], guardianHealth: -2)
        XCTAssertEqual(defeated.remainingDescription, String(localized: "Guardian defeated!"))
        XCTAssertEqual(defeated.changes(since: damaged), String(localized: "Guardian defeated!"))
        XCTAssertEqual(defeated.changes(since: BoardAccessibilityGoalSummary(targets: [], guardianHealth: 0)), "")
        XCTAssertEqual(damaged.changes(since: BoardAccessibilityGoalSummary(targets: [])), "")
    }
}
