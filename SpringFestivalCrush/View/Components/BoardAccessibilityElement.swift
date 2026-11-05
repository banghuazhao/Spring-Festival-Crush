import UIKit

/// The element belongs to a board position, so falling pieces do not destroy focus.
final class BoardAccessibilityElement: UIAccessibilityElement {
    let cell: BoardAccessibilityCell
    weak var board: BoardAccessibilityView?
    weak var level: Level?

    init(cell: BoardAccessibilityCell, board: BoardAccessibilityView) {
        self.cell = cell
        self.board = board
        super.init(accessibilityContainer: board)
        accessibilityIdentifier = "board-row-\(cell.row)-column-\(cell.column)"
    }

    override func accessibilityActivate() -> Bool {
        guard let board, let scene = board.scene as? GameScene,
              scene.gameModel.level === level,
              board.tileElements.contains(where: { $0 === self }) else { return false }
        return board.activate(cell)
    }

    override func accessibilityElementDidBecomeFocused() {
        super.accessibilityElementDidBecomeFocused()
        board?.rememberFocus(on: self)
    }
}
