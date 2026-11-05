import XCTest
@testable import SpringFestivalCrush

final class BoardScoutingAccessibilityTests: XCTestCase {
    private func data(tiles: [[Int]] = [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 1, 1]],
                      targets: [String: Int] = ["ingredient": 1]) throws -> LevelData {
        let object: [String: Any] = [
            "tiles": tiles, "moves": 20,
            "levelGoal": ["firstStarScore": 100, "secondStarScore": 200, "thirdStarScore": 300,
                          "levelTarget": targets]
        ]
        return try JSONDecoder().decode(LevelData.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testEveryAuthoredKindHasCoordinatesAndADescriptionWithoutGuessingRandomColors() throws {
        let layout = try XCTUnwrap(BoardScoutingLayout(data: data()))
        let accessibility = BoardScoutingAccessibility(layout: layout)
        let cases: [(Int, Int, String)] = [
            (0, 2, String(localized: "Hole, no tile")),
            (1, 2, String(localized: "Random tile")),
            (2, 2, String(localized: "Lock, hits remaining: \(1)")),
            (3, 2, String(localized: "Lock, hits remaining: \(2)")),
            (0, 1, String(localized: "Lucky Five")),
            (1, 1, String(localized: "Lightning")),
            (2, 1, String(localized: "Blast Tile, random tile type")),
            (3, 1, String(localized: "Lock, hits remaining: \(3)")),
            (0, 0, String(localized: "Chocolate")),
            (1, 0, String(localized: "Gift"))
        ]
        for (column, row, description) in cases {
            let label = try XCTUnwrap(accessibility.label(column: column, row: row))
            XCTAssertTrue(label.contains(String(localized: "Row \(layout.rows - row), Column \(column + 1)")))
            XCTAssertTrue(label.contains(description))
        }
        let random = try XCTUnwrap(accessibility.label(column: 1, row: 2))
        XCTAssertFalse(random.contains(String(localized: "Firecracker")))
        XCTAssertFalse(random.contains(String(localized: "Red envelope")))
    }

    func testDescriptionsIncludeEffectiveProtectionAndBlossomLayers() throws {
        let source = try data()
        source.armor = [[0, 1, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
        source.ice = [[0, 0, 1, 0], [0, 1, 0, 0], [0, 0, 2, 0]]
        source.jelly = [[0, 1, 2, 0], [0, 0, 0, 0], [0, 1, 0, 0]]
        let layout = try XCTUnwrap(BoardScoutingLayout(data: source))
        let accessibility = BoardScoutingAccessibility(layout: layout)

        let armored = try XCTUnwrap(accessibility.label(column: 1, row: 2))
        XCTAssertTrue(armored.contains(String(localized: "Random tile")))
        XCTAssertTrue(armored.contains(String(localized: "Gold frame layers: \(1)")))
        XCTAssertTrue(armored.contains(String(localized: "Moon blossom layers: \(1)")))
        let frozen = try XCTUnwrap(accessibility.label(column: 2, row: 0))
        XCTAssertTrue(frozen.contains(String(localized: "Ice layers: \(2)")))
        let lock = try XCTUnwrap(accessibility.label(column: 2, row: 2))
        XCTAssertTrue(lock.contains(String(localized: "Moon blossom layers: \(2)")))
        XCTAssertFalse(lock.contains(String(localized: "Ice layers: \(1)")), "Fixed-piece ice is ignored by the engine")
        let lightning = try XCTUnwrap(accessibility.label(column: 1, row: 1))
        XCTAssertFalse(lightning.contains(String(localized: "Ice layers: \(1)")))
    }

    func testDeliveryExitsDescribeOnlyPlayableBottomCellsWithAnActiveDeliveryGoal() throws {
        let tiles = [[1, 9, 1, 1], [1, 1, 1, 1], [0, 1, 9, 0]]
        let layout = try XCTUnwrap(BoardScoutingLayout(data: data(tiles: tiles, targets: ["ingredient": 2])))
        let accessibility = BoardScoutingAccessibility(layout: layout)
        let exit = String(localized: "Gift delivery exit")
        for cell in accessibility.cells {
            let label = try XCTUnwrap(accessibility.label(column: cell.column, row: cell.row))
            XCTAssertEqual(label.contains(exit), cell.row == 0 && [1, 2].contains(cell.column))
        }
        for targets in [[:], ["ingredient": 0]] {
            let noGoal = try XCTUnwrap(BoardScoutingLayout(data: data(tiles: tiles, targets: targets)))
            let reader = BoardScoutingAccessibility(layout: noGoal)
            XCTAssertFalse(reader.cells.contains {
                reader.label(column: $0.column, row: $0.row)?.contains(exit) == true
            })
        }
    }

    func testAllCellsIncludingHolesFollowTopLeftReadingOrderAndBoundsAreSafe() throws {
        let layout = try XCTUnwrap(BoardScoutingLayout(data: data()))
        let accessibility = BoardScoutingAccessibility(layout: layout)
        XCTAssertEqual(accessibility.cells.count, layout.rows * layout.columns)
        XCTAssertEqual(accessibility.cells.first?.row, layout.rows - 1)
        XCTAssertEqual(accessibility.cells.first?.column, 0)
        XCTAssertEqual(accessibility.cells.last?.row, 0)
        XCTAssertEqual(accessibility.cells.last?.column, layout.columns - 1)
        let priorities = accessibility.cells.map { accessibility.sortPriority(column: $0.column, row: $0.row) }
        XCTAssertEqual(priorities, (1...layout.cells.count).reversed().map(Double.init))
        for (column, row) in [(-1, 0), (layout.columns, 0), (0, -1), (0, layout.rows), (Int.max, Int.min)] {
            XCTAssertNil(accessibility.label(column: column, row: row))
            XCTAssertEqual(accessibility.sortPriority(column: column, row: row), 0)
        }
    }

    func testRepeatedDescriptionReadsDoNotMutateAuthoredData() throws {
        let source = try data()
        source.jelly = [[0, 0, 2, 0], [0, 0, 0, 0], [0, 1, 0, 0]]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(source)
        let layout = try XCTUnwrap(BoardScoutingLayout(data: source))
        let accessibility = BoardScoutingAccessibility(layout: layout)
        let first = accessibility.cells.compactMap { accessibility.label(column: $0.column, row: $0.row) }
        let repeated = accessibility.cells.compactMap { accessibility.label(column: $0.column, row: $0.row) }
        XCTAssertEqual(first, repeated)
        XCTAssertEqual(try encoder.encode(source), before)
        XCTAssertEqual(BoardScoutingLayout(data: source), layout)
    }

    func testShippedLayoutsExposeEveryAuthoredCellAndTrueDeliveryExit() throws {
        let hole = String(localized: "Hole, no tile")
        let random = String(localized: "Random tile")
        let exit = String(localized: "Gift delivery exit")
        for zodiac in Zodiac.all where zodiac.numLevels > 0 {
            for number in 1...zodiac.numLevels {
                let name = "\(zodiac.zodiacType.name)_Level_\(number)"
                let source = try XCTUnwrap(LevelData.loadFrom(file: name))
                let layout = try XCTUnwrap(BoardScoutingLayout(data: source))
                let accessibility = BoardScoutingAccessibility(layout: layout)
                var describedExits = 0
                for cell in accessibility.cells {
                    let label = try XCTUnwrap(accessibility.label(column: cell.column, row: cell.row), name)
                    XCTAssertEqual(label.contains(hole), cell.kind == .empty, name)
                    if cell.kind == .normal { XCTAssertTrue(label.contains(random), name) }
                    if label.contains(exit) {
                        describedExits += 1
                        XCTAssertEqual(cell.row, 0, name)
                        XCTAssertTrue(layout.exitColumns.contains(cell.column), name)
                        XCTAssertNotEqual(cell.kind, .empty, name)
                    }
                }
                XCTAssertEqual(describedExits, layout.exitColumns.count, name)
            }
        }
    }
}
