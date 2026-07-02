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
                levelData = try decoder.decode(LevelData.self, from: data)
            } catch {
                print("Level file '\(filename)' is not valid JSON: \(error)")
                return nil
            }
        }
        return levelData
    }
}
