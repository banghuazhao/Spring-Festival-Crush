import XCTest
@testable import SpringFestivalCrush

@MainActor
final class MasteryDeliveryContentTests: XCTestCase {
    private let chapters = ["Rat", "Ox", "Tiger", "Rabbit"]

    func testMasteryGoalsStartWithEveryRequestedKindOfPower() throws {
        for chapter in chapters {
            let name = "\(chapter)_Level_18"
            let data = try XCTUnwrap(LevelData.loadFrom(file: name))
            let target = data.levelGoal.levelTarget
            let powers: [(Int?, Tile.TileType)] = [
                (target.lightningCombos, .lightning),
                (target.fiveCombos, .five),
                (target.enhancedCombos, .enhanced)
            ]
            XCTAssertGreaterThanOrEqual(powers.filter { ($0.0 ?? 0) > 0 }.count, 2)
            for (count, tile) in powers where (count ?? 0) > 0 {
                XCTAssertTrue(data.tiles.joined().contains(tile.rawValue),
                              "\(name) must provide the type of power its activation goal teaches")
            }
            XCTAssertNil(target.ingredient)
            XCTAssertNil(data.boss)
            XCTAssertNil(data.timeLimit)
            XCTAssertEqual(data.difficulty, 5)
        }
    }

    func testGiftsStartAboveRealBottomExitsWithOpenVerticalRoutes() throws {
        for chapter in chapters {
            let name = "\(chapter)_Level_19"
            let data = try XCTUnwrap(LevelData.loadFrom(file: name))
            let bottom = try XCTUnwrap(data.tiles.last)
            XCTAssertTrue(bottom.allSatisfy { $0 == Tile.TileType.normal.rawValue },
                          "Every bottom-row cell must provide a real delivery exit")
            let gifts = data.tiles.enumerated().flatMap { row, values in
                values.enumerated().compactMap { column, value in
                    value == Tile.TileType.ingredient.rawValue ? (row, column) : nil
                }
            }
            XCTAssertEqual(gifts.count, 2)
            XCTAssertEqual(data.levelGoal.levelTarget.ingredient, gifts.count)
            for (row, column) in gifts {
                XCTAssertLessThan(row, data.tiles.count - 1, "A gift must need to travel before delivery")
                for pathRow in (row + 1)..<data.tiles.count {
                    XCTAssertEqual(data.tiles[pathRow][column], Tile.TileType.normal.rawValue,
                                   "\(name) must start with an open route underneath each gift")
                    XCTAssertEqual(data.ice?[pathRow][column] ?? 0, 0)
                    XCTAssertEqual(data.armor?[pathRow][column] ?? 0, 0)
                }
            }
            XCTAssertFalse(data.tiles.joined().contains(Tile.TileType.chocolate.rawValue))
            XCTAssertNil(data.boss)
            XCTAssertNil(data.timeLimit)
            XCTAssertEqual(data.difficulty, 5)
        }
    }

    func testNewChallengeProtectionAndPreplacedColorsAreCompatible() throws {
        for chapter in chapters {
            for number in 18...19 {
                let name = "\(chapter)_Level_\(number)"
                let data = try XCTUnwrap(LevelData.loadFrom(file: name))
                for row in data.tiles.indices {
                    for column in data.tiles[row].indices {
                        let ice = data.ice?[row][column] ?? 0
                        let armor = data.armor?[row][column] ?? 0
                        if ice > 0 || armor > 0 {
                            XCTAssertEqual(data.tiles[row][column], Tile.TileType.normal.rawValue,
                                           "Protection must not hide a gift or a preplaced power in \(name)")
                            XCTAssertFalse(ice > 0 && armor > 0)
                        }
                    }
                }
                if data.tiles.joined().contains(Tile.TileType.enhanced.rawValue) {
                    XCTAssertTrue(data.possibleSymbols?.contains("firecracker") == true,
                                  "A preplaced Enhanced tile uses the firecracker color")
                }
                let authoredLocks = data.tiles.joined().filter {
                    [Tile.TileType.lock, .doubleLock, .vaultLock].map(\.rawValue).contains($0)
                }.count
                XCTAssertLessThanOrEqual(data.levelGoal.levelTarget.lock ?? 0, authoredLocks)
            }
        }
    }

    func testClaimedChestsRemainOpenedAtNineteenLevelThresholds() throws {
        let suite = "MasteryDeliveryContentTests.chests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let previousTrack = StarChestTrack(levelCount: 17)
        let expandedTrack = StarChestTrack(levelCount: 19)
        XCTAssertEqual(expandedTrack.chests.map(\.threshold), [19, 38, 57])
        XCTAssertEqual(expandedTrack.maxStars, 57)
        for zodiac in [ChineseZodiac.rat, .ox, .tiger, .rabbit] {
            let previousClaims: Set<Int> = [0, 2]
            for index in previousClaims {
                XCTAssertTrue(StarChestStore.markClaimed(index, for: zodiac, defaults: defaults))
            }
            let claims = StarChestStore.claimed(for: zodiac, defaults: defaults)
            XCTAssertEqual(expandedTrack.chests.map {
                expandedTrack.state(of: $0, stars: previousTrack.maxStars, claimed: claims)
            }, [.opened, .ready, .opened])
            XCTAssertEqual(expandedTrack.readyChests(stars: previousTrack.maxStars, claimed: claims).map(\.index), [1])
            for index in previousClaims {
                XCTAssertFalse(StarChestStore.markClaimed(index, for: zodiac, defaults: defaults))
            }
            XCTAssertEqual(StarChestStore.claimed(for: zodiac, defaults: defaults), previousClaims)
        }
    }
}
