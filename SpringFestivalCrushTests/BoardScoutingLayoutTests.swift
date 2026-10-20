import XCTest
@testable import SpringFestivalCrush

final class BoardScoutingLayoutTests: XCTestCase {
    private func data(tiles: [[Int]] = [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 1, 1]],
                      targets: [String: Int] = ["ingredient": 1]) throws -> LevelData {
        let object: [String: Any] = [
            "tiles": tiles, "moves": 20,
            "levelGoal": ["firstStarScore": 100, "secondStarScore": 200, "thirdStarScore": 300,
                          "levelTarget": targets]
        ]
        return try JSONDecoder().decode(LevelData.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testScoutingMapsAuthoredRowsAndFixedFeaturesWithoutDealingOrdinaryTiles() throws {
        let source = try data()
        source.armor = [[0, 1, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
        source.ice = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 2, 0]]
        source.jelly = [[0, 0, 2, 0], [0, 0, 0, 0], [0, 1, 0, 0]]
        let layout = try XCTUnwrap(BoardScoutingLayout(data: source))

        XCTAssertEqual(layout.columns, 4)
        XCTAssertEqual(layout.rows, 3)
        XCTAssertEqual(layout.cells.count, 12)
        XCTAssertEqual(layout.cell(column: 0, row: 2)?.kind, .empty)
        XCTAssertEqual(layout.cell(column: 1, row: 2)?.kind, .normal)
        XCTAssertEqual(layout.cell(column: 2, row: 2)?.kind, .lock)
        XCTAssertEqual(layout.cell(column: 3, row: 2)?.kind, .doubleLock)
        XCTAssertEqual(layout.cell(column: 0, row: 1)?.kind, .five)
        XCTAssertEqual(layout.cell(column: 1, row: 1)?.kind, .lightning)
        XCTAssertEqual(layout.cell(column: 2, row: 1)?.kind, .enhanced)
        XCTAssertEqual(layout.cell(column: 3, row: 1)?.kind, .vaultLock)
        XCTAssertEqual(layout.cell(column: 0, row: 0)?.kind, .chocolate)
        XCTAssertEqual(layout.cell(column: 1, row: 0)?.kind, .ingredient)
        XCTAssertEqual(layout.cell(column: 2, row: 0)?.kind, .normal)
        XCTAssertEqual(layout.cell(column: 3, row: 0)?.kind, .normal)
        XCTAssertEqual(layout.cell(column: 1, row: 2)?.armorLayers, 1)
        XCTAssertEqual(layout.cell(column: 2, row: 0)?.iceLayers, 2)
        XCTAssertEqual(layout.cell(column: 2, row: 2)?.blossomLayers, 2)
        XCTAssertEqual(layout.cell(column: 1, row: 0)?.blossomLayers, 1)

        XCTAssertEqual(layout.playableCount, 11)
        XCTAssertEqual(layout.holeCount, 1)
        XCTAssertEqual(layout.randomTileCount, 3)
        XCTAssertEqual(layout.lockCount, 3)
        XCTAssertEqual(layout.iceCount, 1)
        XCTAssertEqual(layout.armorCount, 1)
        XCTAssertEqual(layout.blossomLayerCount, 3)
        XCTAssertEqual(layout.powerUpCount, 3)
        XCTAssertEqual(layout.giftCount, 1)
        XCTAssertEqual(layout.chocolateCount, 1)
    }

    func testScoutingUsesTheEnginesEffectiveIceRuleForFixedPieces() throws {
        let source = try data()
        // Authored ice on fixed power-ups is ignored by createInitialSymbols().
        source.ice = [[0, 2, 1, 0], [1, 2, 1, 1], [0, 1, 0, 0]]
        let layout = try XCTUnwrap(BoardScoutingLayout(data: source))
        XCTAssertEqual(layout.cell(column: 1, row: 2)?.iceLayers, 2)
        XCTAssertEqual(layout.iceCount, 1)
        for cell in layout.cells where cell.kind != .normal {
            XCTAssertEqual(cell.iceLayers, 0)
        }
    }

    func testDeliveryExitsUseEveryActualBottomCellAndExcludeHigherLedges() throws {
        let source = try data(tiles: [[1, 9, 1, 1], [1, 1, 1, 1], [0, 1, 9, 0]],
                              targets: ["ingredient": 2])
        let layout = try XCTUnwrap(BoardScoutingLayout(data: source))
        XCTAssertEqual(layout.exitColumns, [1, 2])
        XCTAssertEqual(layout.giftCount, 2)
        XCTAssertEqual(layout.cell(column: 0, row: 0)?.kind, .empty)
        XCTAssertEqual(layout.cell(column: 0, row: 1)?.kind, .normal)
        XCTAssertFalse(layout.exitColumns.contains(0), "A playable ledge above row zero must not become an exit")
        XCTAssertTrue(layout.exitColumns.contains(2), "Exit metadata is independent of where a gift started")
    }

    func testExitMarkersRequireAnActiveAuthoredDeliveryGoal() throws {
        for targets in [[:], ["ingredient": 0]] {
            let layout = try XCTUnwrap(BoardScoutingLayout(data: data(targets: targets)))
            XCTAssertEqual(layout.giftCount, 1)
            XCTAssertTrue(layout.exitColumns.isEmpty)
        }
    }

    func testRepeatedScoutingReadsDoNotMutateTheAuthoredDataAndSnapshotValuesStayIndependent() throws {
        let source = try data()
        source.ice = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 2, 0]]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(source)
        let first = try XCTUnwrap(BoardScoutingLayout(data: source))
        XCTAssertEqual(BoardScoutingLayout(data: source), first)
        XCTAssertEqual(try encoder.encode(source), before)
        source.ice?[2][2] = 1
        source.jelly = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 2, 0]]
        XCTAssertEqual(first.cell(column: 2, row: 0)?.iceLayers, 2)
        XCTAssertEqual(first.cell(column: 2, row: 0)?.blossomLayers, 0)
        XCTAssertNotEqual(BoardScoutingLayout(data: source), first)
    }

    func testUnknownAuthoredTileValuesFollowTheExistingNormalTileFallback() throws {
        let layout = try XCTUnwrap(BoardScoutingLayout(data: data(tiles: [[1, 1, 1], [1, 77, 1], [1, 1, 1]])))
        XCTAssertEqual(layout.cell(column: 1, row: 1)?.kind, .normal)
        XCTAssertEqual(layout.randomTileCount, 9)
        XCTAssertEqual(layout.powerUpCount, 0)
    }

    func testInvalidLayoutsAndOutOfBoundsLookupsFailSafely() throws {
        XCTAssertNil(BoardScoutingLayout(data: try data(tiles: [])))
        XCTAssertNil(BoardScoutingLayout(data: try data(tiles: [[1, 1, 1], [1], [1, 1, 1]])))
        let malformedOverlay = try data()
        malformedOverlay.ice = [[1]]
        XCTAssertNil(BoardScoutingLayout(data: malformedOverlay))
        let layout = try XCTUnwrap(BoardScoutingLayout(data: data()))
        XCTAssertNil(layout.cell(column: -1, row: 0))
        XCTAssertNil(layout.cell(column: layout.columns, row: 0))
        XCTAssertNil(layout.cell(column: 0, row: -1))
        XCTAssertNil(layout.cell(column: 0, row: layout.rows))
        XCTAssertNil(layout.cell(column: Int.max, row: Int.min))
    }
}
