import XCTest
@testable import SpringFestivalCrush

@MainActor
final class BoardAccessibilityBlastSummaryTests: XCTestCase {
    private struct PieceState: Equatable {
        let identity: ObjectIdentifier
        let column: Int
        let row: Int
        let type: SymbolType
        let ice: Int
        let armor: Int
        let armorHit: Bool
        let blossoms: Int
    }

    private func board(_ name: String = "Debug_Elements") throws -> Level {
        let level = try XCTUnwrap(Level(filename: name))
        let colors: [SymbolType] = [.bowl, .dumpling, .firecracker, .redPocket, .lantern, .zodiac]
        for piece in level.shuffle() {
            piece.type = colors[(piece.column + piece.row * 2) % colors.count]
            piece.iceLayer = 0
            piece.armorLayers = 0
            piece.armorHitThisTurn = false
            piece.convertedFromType = nil
        }
        return level
    }

    private func states(_ level: Level) -> [PieceState] {
        (0..<level.numRows).flatMap { row in
            (0..<level.numColumns).compactMap { column in
                guard let piece = level.symbol(atColumn: column, row: row) else { return nil }
                return PieceState(identity: ObjectIdentifier(piece), column: piece.column, row: piece.row,
                                  type: piece.type, ice: piece.iceLayer, armor: piece.armorLayers,
                                  armorHit: piece.armorHitThisTurn,
                                  blossoms: level.tileAt(column: column, row: row)?.jellyCount ?? 0)
            }
        }
    }

    private func pair(_ level: Level, at column: Int = 3, row: Int = 3,
                      types: (SymbolType, SymbolType)) throws -> Swap {
        let a = try XCTUnwrap(level.symbol(atColumn: column, row: row))
        let b = try XCTUnwrap(level.symbol(atColumn: column + 1, row: row))
        a.type = types.0
        b.type = types.1
        return Swap(symbolA: a, symbolB: b)
    }

    func testLightningDescriptionReportsVirtualDirectFootprintWithoutMutatingAnything() throws {
        let level = try board()
        let swap = try pair(level, types: (.lightning, .dumpling))
        let protected = try XCTUnwrap(level.symbol(atColumn: 4, row: 1))
        protected.armorLayers = 2
        protected.iceLayer = 1
        let before = states(level)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let goalsBefore = try encoder.encode(level.levelGoal)
        let possibleBefore = level.possibleSwaps
        let summary = try XCTUnwrap(BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: Zodiac.all[0]))
        let preview = try XCTUnwrap(level.blastPreview(for: swap))
        XCTAssertEqual(Set(summary.affectedCells.map { BlastPreview.Cell(column: $0.column, row: $0.row) }), preview.affectedCells)
        XCTAssertTrue(summary.summaryDescription.contains(String(localized: "Swap right")))
        XCTAssertTrue(summary.summaryDescription.contains(summary.source.positionLabel(in: level)))
        XCTAssertTrue(summary.summaryDescription.contains(summary.destination.positionLabel(in: level)))
        XCTAssertEqual(summary.protectedTileCount, 1)
        XCTAssertEqual(summary.affectedCells.count, level.numColumns + level.numRows - 1)
        XCTAssertEqual(states(level), before)
        XCTAssertEqual(try encoder.encode(level.levelGoal), goalsBefore)
        XCTAssertEqual(level.possibleSwaps, possibleBefore)
        XCTAssertNil(level.lastSwappedSymbols)
    }

    func testFiveAndAllCombinedPowersUseTheExactEngineFootprintInBothOrders() throws {
        let pairs: [(SymbolType, SymbolType)] = [(.five, .lantern)] + PowerUpCombination.allCases.map(\.demoTypes)
        for types in pairs {
            let level = try board()
            let original = try pair(level, types: types)
            for swap in [original, Swap(symbolA: original.symbolB, symbolB: original.symbolA)] {
                let before = states(level)
                let summary = try XCTUnwrap(BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: Zodiac.all[0]))
                let preview = try XCTUnwrap(level.blastPreview(for: swap))
                XCTAssertEqual(summary.combination, preview.combination)
                XCTAssertEqual(Set(summary.affectedCells.map { BlastPreview.Cell(column: $0.column, row: $0.row) }), preview.affectedCells)
                XCTAssertEqual(states(level), before)
                let expectedDirection = swap.symbolA.column < swap.symbolB.column
                    ? String(localized: "Swap right") : String(localized: "Swap left")
                XCTAssertTrue(summary.summaryDescription.contains(expectedDirection))
            }
        }
    }

    func testEnhancedPreviewExistsOnlyWhenTheEnhancedTileWillMatch() throws {
        let level = try board()
        let swap = try pair(level, types: (.bowlEnhanced, .dumpling))
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: Zodiac.all[0]))
        // The enhanced bowl lands at (4,3), completing the vertical group there.
        level.symbol(atColumn: 4, row: 2)?.type = .bowl
        level.symbol(atColumn: 4, row: 4)?.type = .bowl
        let before = states(level)
        let summary = try XCTUnwrap(BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: Zodiac.all[0]))
        XCTAssertEqual(summary.affectedCells.count, 9)
        XCTAssertTrue(summary.summaryDescription.contains(String(localized: "Direct-hit area: \(9) tiles.")))
        XCTAssertEqual(states(level), before)
    }

    func testNonneighborsOrdinaryFrozenAndProtectedPowerPairsHaveNoPreview() throws {
        let level = try board()
        let ordinary = try pair(level, types: (.bowl, .dumpling))
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: ordinary, zodiac: Zodiac.all[0]))
        ordinary.symbolA.type = .lightning
        let distant = try XCTUnwrap(level.symbol(atColumn: 6, row: 3))
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level,
                                                   swap: Swap(symbolA: ordinary.symbolA, symbolB: distant), zodiac: Zodiac.all[0]))
        ordinary.symbolB.iceLayer = 1
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: ordinary, zodiac: Zodiac.all[0]))
        ordinary.symbolB.iceLayer = 0
        ordinary.symbolA.armorLayers = 1
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: ordinary, zodiac: Zodiac.all[0]))
        ordinary.symbolA.armorLayers = 0
        ordinary.symbolA.armorHitThisTurn = true
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: ordinary, zodiac: Zodiac.all[0]))
        ordinary.symbolA.armorHitThisTurn = false
        ordinary.symbolB.type = .vaultLock
        XCTAssertNil(BoardAccessibilityBlastSummary(level: level, swap: ordinary, zodiac: Zodiac.all[0]))
    }

    func testAllAffectedPositionsAreOrderedAndClippedToPlayableCellsOnShapedBoard() throws {
        let level = try board("Rabbit_Level_17")
        let candidates = (0..<level.numRows).reversed().flatMap { row in
            (0..<(level.numColumns - 1)).compactMap { column -> Swap? in
                guard let a = level.symbol(atColumn: column, row: row),
                      let b = level.symbol(atColumn: column + 1, row: row) else { return nil }
                return Swap(symbolA: a, symbolB: b)
            }
        }
        let swap = try XCTUnwrap(candidates.first)
        swap.symbolA.type = .five
        swap.symbolB.type = .five
        let summary = try XCTUnwrap(BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: Zodiac.all[3]))
        let expected = (0..<level.numRows).reversed().flatMap { row in
            (0..<level.numColumns).compactMap { column -> BoardAccessibilityCell? in
                guard level.tileAt(column: column, row: row) != nil else { return nil }
                return BoardAccessibilityCell(column: column, row: row)
            }
        }
        XCTAssertEqual(summary.affectedCells, expected)
        XCTAssertLessThan(summary.affectedCells.count, level.numRows * level.numColumns)
        XCTAssertTrue(summary.affectedCellsDescription.contains(String(localized: "Row \(1), Columns \(3) through \(7)")))
        for cell in summary.affectedCells {
            XCTAssertNotNil(level.tileAt(column: cell.column, row: cell.row))
        }
    }
}
