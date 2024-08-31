import Foundation

class LevelData: Codable {
    let tiles: [[Int]]
    var possibleSymbols: [String]?
    let moves: Int
    let levelGoal: LevelGoal
    var bgMusic: String?

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
