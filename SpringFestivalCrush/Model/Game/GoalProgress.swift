import Foundation

/// A visual receipt for an already-applied objective change. Never changes game rules.
struct GoalProgress {
    let goalID: String
    let amount: Int
    let column: Int
    let row: Int

    static func changes(
        before: [LevelTargetData], after: [LevelTargetData], symbols: [Symbol]
    ) -> [GoalProgress] {
        let sources = symbols.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        return after.compactMap { target in
            guard let previous = before.first(where: { $0.id == target.id }) else { return nil }
            let amount = max(0, previous.targetNum) - max(0, target.targetNum)
            guard amount > 0 else { return nil }
            let source = sources.first { symbol in
                switch target.id {
                case "lightningCombos": symbol.type == .lightning
                case "fiveCombos": symbol.type == .five
                case "enhancedCombos": symbol.type.isEnhanced
                default: symbol.collectionType.spriteName == target.id
                }
            } ?? sources.first
            guard let source else { return nil }
            return GoalProgress(goalID: target.id, amount: amount, column: source.column, row: source.row)
        }
    }
}
