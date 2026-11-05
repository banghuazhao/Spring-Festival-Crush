import UIKit

/// A row that Switch Control can scan as a group before entering its tiles.
final class BoardAccessibilityRowElement: UIAccessibilityElement {
    let row: Int
    private weak var board: BoardAccessibilityView?
    private var spokenRow = 1
    private(set) var elements: [BoardAccessibilityElement] = []

    init(row: Int, board: BoardAccessibilityView) {
        self.row = row
        self.board = board
        super.init(accessibilityContainer: board)
        isAccessibilityElement = false
        shouldGroupAccessibilityChildren = true
        accessibilityContainerType = .semanticGroup
        accessibilityElementsHidden = true
        accessibilityIdentifier = "board-row-group-\(row)"
    }

    /// Call after the board has assigned each tile's current geometry. Screen frames
    /// stay valid when a non-view accessibility container becomes the tile's parent.
    func update(elements: [BoardAccessibilityElement], spokenRow: Int) {
        let liveElements = elements.filter { element in
            element.cell.row == row && board?.tileElements.contains(where: { $0 === element }) == true
        }.sorted { $0.cell.column < $1.cell.column }
        let frames = liveElements.map(\.accessibilityFrame)
        for oldElement in self.elements where !liveElements.contains(where: { $0 === oldElement }) {
            if let parent = oldElement.accessibilityContainer as? BoardAccessibilityRowElement,
               parent === self, let board {
                let screenFrame = oldElement.accessibilityFrame
                oldElement.accessibilityContainer = board
                oldElement.accessibilityFrame = screenFrame
            }
        }
        self.elements = liveElements
        self.spokenRow = spokenRow
        accessibilityLabel = String(localized: "Row \(spokenRow)")
        accessibilityElementsHidden = liveElements.isEmpty
        for (element, frame) in zip(liveElements, frames) {
            element.accessibilityContainer = self
            element.accessibilityFrame = frame
        }
        accessibilityFrame = frames.reduce(nil as CGRect?) { result, frame in
            result.map { $0.union(frame) } ?? frame
        } ?? .zero
    }

    private var exposesChildren: Bool {
        guard !accessibilityElementsHidden, let board,
              !board.accessibilityElementsHidden, board.groupsRowsForSwitchControl else { return false }
        return board.accessibilityElements?.contains { ($0 as AnyObject) === self } == true
    }

    override var accessibilityElements: [Any]? {
        get { exposesChildren ? elements : [] }
        set {
            update(elements: (newValue ?? []).compactMap { $0 as? BoardAccessibilityElement },
                   spokenRow: spokenRow)
        }
    }

    override func accessibilityElementCount() -> Int {
        exposesChildren ? elements.count : 0
    }

    override func accessibilityElement(at index: Int) -> Any? {
        guard exposesChildren, elements.indices.contains(index) else { return nil }
        return elements[index]
    }

    override func index(ofAccessibilityElement element: Any) -> Int {
        guard exposesChildren else { return NSNotFound }
        let object = element as AnyObject
        return elements.firstIndex { $0 === object } ?? NSNotFound
    }
}
