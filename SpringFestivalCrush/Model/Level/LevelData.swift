import Foundation

class LevelData: Codable {
    let tiles: [[Int]]
    var possibleSymbols: [String]?
    let moves: Int
    let levelGoal: LevelGoal
    var bgMusic: String?
    var noShuffle: Bool?
    // Same shape as `tiles`. Value = jelly layers to place under that cell (0/omitted = none).
    var jelly: [[Int]]?
    // Same shape as `tiles`. Value = ice layers wrapping the symbol spawned there (0/omitted = none).
    var ice: [[Int]]?
    // Optional countdown timer, in seconds. When set, running out of time loses the level
    // in addition to running out of moves.
    var timeLimit: Int?
    var armor: [[Int]]?
    var snow: Bool?
    var mechanicHint: String?
    var difficulty: Int?
    var boss: BossConfiguration?

    var hasValidLayout: Bool {
        guard let width = tiles.first?.count, width >= 3, tiles.count >= 3,
              tiles.allSatisfy({ $0.count == width }), moves > 0 else { return false }
        for grid in [armor, ice, jelly].compactMap({ $0 }) {
            guard grid.count == tiles.count, grid.allSatisfy({ $0.count == width }) else { return false }
            for (r, row) in grid.enumerated() {
                for (c, value) in row.enumerated() where value > 0 {
                    guard tiles[r][c] != 0 else { return false }
                }
            }
        }
        if let armor {
            for (r, row) in armor.enumerated() {
                for (c, value) in row.enumerated() {
                    guard (0...1).contains(value) else { return false }
                    if value > 0, tiles[r][c] != 1 || (ice?[r][c] ?? 0) > 0 { return false }
                }
            }
        }
        return (boss?.health ?? 1) > 0 && (1...5).contains(difficulty ?? 1)
    }

    static func loadFrom(file filename: String) -> LevelData? {
        var data: Data
        var levelData: LevelData?

        if let path = Bundle.main.url(forResource: filename, withExtension: "json") {
            do {
                data = try Data(contentsOf: path)
            } catch {
                print("Could not load level file: \(filename), error: \(error)")
                return nil
            }
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(LevelData.self, from: data)
                guard decoded.hasValidLayout else {
                    print("Invalid board or protection grid in \(filename)")
                    return nil
                }
                levelData = decoded
            } catch {
                print("Level file '\(filename)' is not valid JSON: \(error)")
                return nil
            }
        }
        return levelData
    }
}
