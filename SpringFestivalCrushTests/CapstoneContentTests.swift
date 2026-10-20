import XCTest
@testable import SpringFestivalCrush

@MainActor
final class CapstoneContentTests: XCTestCase {
    private let chapters = ["Rat", "Ox", "Tiger", "Rabbit"]

    func testCapstonesMixTwoGiftsWithAvailablePowerActivationGoals() throws {
        for chapter in chapters {
            let name = "\(chapter)_Level_20"
            let data = try XCTUnwrap(LevelData.loadFrom(file: name))
            let target = data.levelGoal.levelTarget
            XCTAssertEqual(target.ingredient, 2)
            XCTAssertEqual(data.tiles.joined().filter { $0 == Tile.TileType.ingredient.rawValue }.count, 2)
            let powers: [(Int?, Tile.TileType)] = [
                (target.lightningCombos, .lightning),
                (target.fiveCombos, .five),
                (target.enhancedCombos, .enhanced)
            ]
            XCTAssertGreaterThanOrEqual(powers.filter { ($0.0 ?? 0) > 0 }.count, 2)
            for (count, type) in powers where (count ?? 0) > 0 {
                XCTAssertTrue(data.tiles.joined().contains(type.rawValue),
                              "\(name) must start with every power its goal asks players to activate")
            }
            XCTAssertNil(data.boss)
            XCTAssertNil(data.timeLimit)
            XCTAssertFalse(data.tiles.joined().contains(Tile.TileType.chocolate.rawValue))
            XCTAssertEqual(data.difficulty, 5)
        }
    }

    func testCapstoneGiftRoutesStayOpenAndProtectionDoesNotHidePowers() throws {
        for chapter in chapters {
            let name = "\(chapter)_Level_20"
            let data = try XCTUnwrap(LevelData.loadFrom(file: name))
            let bottom = try XCTUnwrap(data.tiles.last)
            XCTAssertTrue(bottom.allSatisfy { $0 == Tile.TileType.normal.rawValue })
            for row in data.tiles.indices {
                for column in data.tiles[row].indices {
                    let tile = data.tiles[row][column]
                    let ice = data.ice?[row][column] ?? 0
                    let armor = data.armor?[row][column] ?? 0
                    if ice > 0 || armor > 0 {
                        XCTAssertEqual(tile, Tile.TileType.normal.rawValue)
                        XCTAssertFalse(ice > 0 && armor > 0)
                    }
                    if tile == Tile.TileType.ingredient.rawValue {
                        XCTAssertLessThan(row, data.tiles.count - 1)
                        for pathRow in (row + 1)..<data.tiles.count {
                            XCTAssertEqual(data.tiles[pathRow][column], Tile.TileType.normal.rawValue,
                                           "\(name) needs an open starting route beneath each gift")
                            XCTAssertEqual(data.ice?[pathRow][column] ?? 0, 0)
                            XCTAssertEqual(data.armor?[pathRow][column] ?? 0, 0)
                        }
                    }
                }
            }
            if data.tiles.joined().contains(Tile.TileType.enhanced.rawValue) {
                XCTAssertTrue(data.possibleSymbols?.contains("firecracker") == true)
            }
            let lockTypes = [Tile.TileType.lock, .doubleLock, .vaultLock].map(\.rawValue)
            let locks = data.tiles.joined().filter { lockTypes.contains($0) }.count
            XCTAssertLessThanOrEqual(data.levelGoal.levelTarget.lock ?? 0, locks)
        }
    }

    func testCapstoneCompletionRequiresBothDeliveryAndActivationProgress() throws {
        for chapter in chapters {
            let level = try XCTUnwrap(Level(filename: "\(chapter)_Level_20"))
            XCTAssertGreaterThan(level.levelGoal.levelTarget.lightningCombos ?? 0, 0)
            level.levelGoal.levelTarget = LevelTarget(ingredient: 1, lightningCombos: 1)
            XCTAssertFalse(level.doesReachLevelTarget())
            level.levelGoal.levelTarget.ingredient = 0
            XCTAssertFalse(level.doesReachLevelTarget(), "Delivered gifts do not waive an activation goal")
            level.levelGoal.levelTarget.ingredient = 1
            level.levelGoal.levelTarget.lightningCombos = 0
            XCTAssertFalse(level.doesReachLevelTarget(), "Completed power goals do not waive gift delivery")
            level.levelGoal.levelTarget.ingredient = 0
            XCTAssertTrue(level.doesReachLevelTarget())
        }
    }
}
