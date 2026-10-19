import XCTest
@testable import SpringFestivalCrush

@MainActor
final class ExpansionContentTests: XCTestCase {
    /// An inert board makes spread choices and adjacent clears independent of a random deal.
    private func isolatedGarden() throws -> Level {
        let level = try XCTUnwrap(Level(filename: "Rabbit_Level_16"))
        for symbol in level.shuffle() {
            symbol.type = .five
            symbol.iceLayer = 0
            symbol.armorLayers = 0
            symbol.armorHitThisTurn = false
            level.tileAt(column: symbol.column, row: symbol.row)?.type = .normal
            level.tileAt(column: symbol.column, row: symbol.row)?.jellyCount = 0
        }
        level.levelGoal.levelTarget = LevelTarget()
        return level
    }

    private func piece(_ level: Level, column: Int, row: Int, type: SymbolType) throws -> Symbol {
        let symbol = try XCTUnwrap(level.symbol(atColumn: column, row: row))
        symbol.type = type
        level.tileAt(column: column, row: row)?.type = type == .chocolate ? .chocolate : .normal
        return symbol
    }

    private func pieces(_ level: Level) -> [Symbol] {
        (0..<level.numRows).flatMap { row in
            (0..<level.numColumns).compactMap { level.symbol(atColumn: $0, row: row) }
        }
    }

    func testChocolateSpreadsToOneNormalNeighbourWithoutReplacingAnyPiece() throws {
        let level = try isolatedGarden()
        _ = try piece(level, column: 1, row: 1, type: .chocolate)
        _ = try piece(level, column: 3, row: 3, type: .chocolate)
        let candidates = [
            try piece(level, column: 1, row: 2, type: .bowl),
            try piece(level, column: 3, row: 4, type: .lantern)
        ]
        let identities = Set(pieces(level).map(ObjectIdentifier.init))

        let spread = try XCTUnwrap(level.spreadChocolateIfNeeded())

        XCTAssertTrue(candidates.contains { $0 === spread })
        XCTAssertEqual(candidates.filter { $0.type == .chocolate }.count, 1)
        XCTAssertEqual(pieces(level).filter { $0.type == .chocolate }.count, 3,
                       "Multiple sources still convert only one cell per world step")
        XCTAssertEqual(Set(pieces(level).map(ObjectIdentifier.init)), identities)
    }

    func testChocolateCannotOverwriteProtectedTilesSpecialsIngredientsOrLocks() throws {
        let cases: [(type: SymbolType, ice: Int, armor: Int)] = [
            (.bowl, 1, 0), (.bowl, 0, 1), (.five, 0, 0), (.lightning, 0, 0),
            (.bowlEnhanced, 0, 0), (.ingredient, 0, 0), (.lock, 0, 0),
            (.heavyLock, 0, 0), (.vaultLock, 0, 0)
        ]
        for testCase in cases {
            let level = try isolatedGarden()
            _ = try piece(level, column: 3, row: 3, type: .chocolate)
            let protected = try piece(level, column: 3, row: 4, type: testCase.type)
            protected.iceLayer = testCase.ice
            protected.armorLayers = testCase.armor

            XCTAssertNil(level.spreadChocolateIfNeeded(), "Must preserve \(testCase.type)")
            XCTAssertTrue(level.symbol(atColumn: 3, row: 4) === protected)
            XCTAssertEqual(protected.type, testCase.type)
            XCTAssertEqual(protected.iceLayer, testCase.ice)
            XCTAssertEqual(protected.armorLayers, testCase.armor)
        }
    }

    func testAdjacentMatchClearsChocolateAndOneBlossomLayerWithoutLockCredit() throws {
        let level = try isolatedGarden()
        let chocolate = try piece(level, column: 3, row: 3, type: .chocolate)
        level.tileAt(column: 3, row: 3)?.jellyCount = 2
        level.levelGoal.levelTarget = LevelTarget(lock: 1, jelly: 2)
        for column in 2...4 { _ = try piece(level, column: column, row: 2, type: .bowl) }

        let matches = level.removeMatches()
        XCTAssertEqual(matches.flatMap(\.clearedSymbols).count, 3)
        level.updateLevelTarget(by: matches)
        XCTAssertEqual(level.levelGoal.levelTarget.jelly, 2)

        let clear = try XCTUnwrap(level.resolveBlockers())
        XCTAssertEqual(clear.clearedSymbols.count, 1)
        XCTAssertTrue(clear.clearedSymbols.contains { $0 === chocolate })
        level.updateLevelTarget(by: [clear])

        XCTAssertNil(level.symbol(atColumn: 3, row: 3))
        XCTAssertEqual(level.tileAt(column: 3, row: 3)?.type, .normal)
        XCTAssertEqual(level.tileAt(column: 3, row: 3)?.jellyCount, 1)
        XCTAssertEqual(level.levelGoal.levelTarget.jelly, 1)
        XCTAssertEqual(level.levelGoal.levelTarget.lock, 1,
                       "Chocolate is a blocker, but it is not a lock goal")
        XCTAssertNil(level.spreadChocolateIfNeeded(), "Removing the last source stops the spread")
    }

    func testChocolateSpreadLeavesBlossomsAndCollectionCountersUntouched() throws {
        let level = try isolatedGarden()
        _ = try piece(level, column: 3, row: 3, type: .chocolate)
        let target = try piece(level, column: 3, row: 4, type: .lantern)
        level.tileAt(column: 3, row: 4)?.jellyCount = 2
        level.levelGoal.levelTarget = LevelTarget(lantern: 1, jelly: 2)

        XCTAssertTrue(try XCTUnwrap(level.spreadChocolateIfNeeded()) === target)

        XCTAssertEqual(target.type, .chocolate)
        XCTAssertEqual(level.tileAt(column: 3, row: 4)?.jellyCount, 2)
        XCTAssertEqual(level.levelGoal.levelTarget.lantern, 1)
        XCTAssertEqual(level.levelGoal.levelTarget.jelly, 2)
    }

    func testChocolateIsFirstTaughtAndUnlockedAtRabbitSixteen() {
        let curriculum = RuleCurriculum.shared
        let introduction = LevelRef(zodiac: .rabbit, number: 16)
        XCTAssertEqual(curriculum.introductions[.chocolate], introduction)
        XCTAssertTrue(curriculum.introduces(.chocolate, at: introduction))
        XCTAssertEqual(curriculum.order.filter { curriculum.lessons(for: $0).contains(.chocolate) },
                       [introduction])
        XCTAssertFalse(curriculum.isUnlocked(.chocolate) { ref in
            ref.zodiac == .rabbit && ref.number <= 15
        })
        XCTAssertTrue(curriculum.isUnlocked(.chocolate) { $0 == introduction })
    }

    func testPreplacedEnhancedTilesMatchTheNewBoardsColorPalettes() throws {
        for chapter in ["Rat", "Ox", "Tiger", "Rabbit"] {
            for number in 16...17 {
                let name = "\(chapter)_Level_\(number)"
                let data = try XCTUnwrap(LevelData.loadFrom(file: name))
                if data.tiles.joined().contains(Tile.TileType.enhanced.rawValue) {
                    XCTAssertTrue(data.possibleSymbols?.contains("firecracker") == true,
                                  "\(name) preplaces a firecracker Enhanced tile, so it needs a matching color")
                }
            }
        }
    }

    func testExpansionGuidanceIsLocalizedInEverySupportedLanguage() throws {
        let keys = [
            "Chocolate",
            "Match beside chocolate to clear it. Any chocolate left can spread to one neighboring unprotected tile after each move.",
            "Power-up blast previews",
            "Drag a power-up to a neighbor to preview its direct hits. Release to swap, or return to the starting tile to cancel. Chain reactions and falling tiles can extend the effect.",
            "Direct hits · Release to swap; return to start to cancel."
        ]
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: "Localizable", ofType: "strings",
                                                      inDirectory: nil, forLocalization: language))
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let table = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                as? [String: String])
            for key in keys {
                let translation = try XCTUnwrap(table[key], "\(language) is missing \(key)")
                XCTAssertFalse(translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if language != "en" { XCTAssertNotEqual(translation, key, "\(language) must translate \(key)") }
            }
        }
    }

    func testClaimedStarChestsStayOpenedWhenChaptersGrowToSeventeenLevels() throws {
        let suite = "ExpansionContentTests.chests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let oldTrack = StarChestTrack(levelCount: 15)
        let expandedTrack = StarChestTrack(levelCount: 17)
        let oldStars = oldTrack.maxStars
        XCTAssertEqual(expandedTrack.chests.map(\.threshold), [17, 34, 51])
        XCTAssertEqual(expandedTrack.maxStars, 51)

        for zodiac in [ChineseZodiac.rat, .ox, .tiger, .rabbit] {
            let previouslyClaimed: Set<Int> = [0, 2]
            for index in previouslyClaimed {
                XCTAssertTrue(StarChestStore.markClaimed(index, for: zodiac, defaults: defaults))
            }
            let claims = StarChestStore.claimed(for: zodiac, defaults: defaults)
            XCTAssertEqual(claims, previouslyClaimed)
            XCTAssertEqual(expandedTrack.chests.map { expandedTrack.state(of: $0, stars: oldStars, claimed: claims) },
                           [.opened, .ready, .opened],
                           "An already opened third chest stays open below the expanded threshold")
            XCTAssertEqual(expandedTrack.readyChests(stars: oldStars, claimed: claims).map(\.index), [1])
            for index in previouslyClaimed {
                XCTAssertFalse(StarChestStore.markClaimed(index, for: zodiac, defaults: defaults),
                               "Expansion must not allow an old chest reward to be claimed twice")
            }
            XCTAssertEqual(StarChestStore.claimed(for: zodiac, defaults: defaults), previouslyClaimed)
        }
    }
}
