import SpriteKit

/// SpriteKit draws the board; this container exposes its actual cells to VoiceOver.
/// Frames are projected through SKView, including the scene's scale and board offset.
final class BoardAccessibilityView: SKView {
    // SpriteKit supplies its own accessibility container. Own the complete container
    // contract so it cannot substitute the scene for the board's spatial tile elements.
    private var boardAccessibilityElements: [Any] = []
    override var accessibilityElements: [Any]? {
        get { accessibilityElementsHidden ? [] : boardAccessibilityElements }
        set { boardAccessibilityElements = newValue ?? [] }
    }

    override func accessibilityElementCount() -> Int {
        accessibilityElementsHidden ? 0 : boardAccessibilityElements.count
    }

    override func accessibilityElement(at index: Int) -> Any? {
        guard !accessibilityElementsHidden, boardAccessibilityElements.indices.contains(index) else { return nil }
        return boardAccessibilityElements[index]
    }

    override func index(ofAccessibilityElement element: Any) -> Int {
        guard !accessibilityElementsHidden else { return NSNotFound }
        let object = element as AnyObject
        return boardAccessibilityElements.firstIndex { ($0 as AnyObject) === object } ?? NSNotFound
    }

    var gameplayPaused = false {
        didSet {
            guard oldValue != gameplayPaused else { return }
            if gameplayPaused { cancelKeyboardResponderRequest() }
            (scene as? GameScene)?.setFeedbackPaused(gameplayPaused)
            clearSelection()
            refreshAccessibility()
        }
    }
    private(set) var tileElements: [BoardAccessibilityElement] = []
    private(set) var pendingAction: Task<Void, Never>?
    private(set) var lastAnnouncement: String?
    private(set) var lastAnnouncementIsQueued = false
    private(set) var focusedCell: BoardAccessibilityCell?
    private(set) weak var lastFocusRestoration: UIAccessibilityElement?
    private(set) var keyboardCell: BoardAccessibilityCell?
    private let keyboardFocusRing = CAShapeLayer()
    private var keyboardResponderRequested = false
    private var keyboardResponderTask: Task<Void, Never>?
    private struct MoveReceipt {
        let brief: String
        let detailed: String
    }
    private var lastMoveReceipt: MoveReceipt?
    private var rowElements: [Int: BoardAccessibilityRowElement] = [:]
    /// A testable override; production follows the current assistive technology.
    var groupsRowsForSwitchControl = UIAccessibility.isSwitchControlRunning {
        didSet { refreshAccessibility() }
    }
    private struct SpokenPreview {
        let level: Level
        let generation: UInt
        let usingRuyi: Bool
        let source: Symbol
        let destination: Symbol
        let summary: BoardAccessibilityBlastSummary
    }
    private var spokenPreview: SpokenPreview?
    var lastSpokenPreview: BoardAccessibilityBlastSummary? { currentPreview()?.summary }
    private var actionInFlight = false
    private var elementsByCell: [BoardAccessibilityCell: BoardAccessibilityElement] = [:]
    private lazy var instructionsElement = UIAccessibilityElement(accessibilityContainer: self)
    private var selectedCell: BoardAccessibilityCell?
    private weak var selectedSymbol: Symbol?
    private weak var selectedLevel: Level?
    private weak var displayedLevel: Level?
    private var lastHammerMode = false
    private var lastSwapMode = false
    private lazy var boardRotors = BoardAccessibilityRotor.allCases.map { kind in
        UIAccessibilityCustomRotor(name: kind.title) { [weak self] predicate in
            // UIKit documents an absent current item as a search from the beginning/end.
            let currentItem: UIAccessibilityCustomRotorItemResult? = predicate.currentItem
            let current = currentItem?.targetElement as? BoardAccessibilityElement
            guard let element = self?.rotorElement(for: kind, from: current,
                                                   forward: predicate.searchDirection == .next) else { return nil }
            return UIAccessibilityCustomRotorItemResult(targetElement: element, targetRange: nil)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        observeSwitchControl()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeSwitchControl()
    }

    private func observeSwitchControl() {
        NotificationCenter.default.addObserver(self, selector: #selector(switchControlChanged),
                                              name: UIAccessibility.switchControlStatusDidChangeNotification, object: nil)
    }

    @objc private func switchControlChanged() {
        groupsRowsForSwitchControl = UIAccessibility.isSwitchControlRunning
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshAccessibility()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelKeyboardResponderRequest()
            keyboardResponderRequested = false
        }
        refreshAccessibility()
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        guard canAct else { return [] }
        let definitions: [(String, String)] = [
            (UIKeyCommand.inputUpArrow, String(localized: "Move to tile above")),
            (UIKeyCommand.inputDownArrow, String(localized: "Move to tile below")),
            (UIKeyCommand.inputLeftArrow, String(localized: "Move to tile on left")),
            (UIKeyCommand.inputRightArrow, String(localized: "Move to tile on right")),
            ("\r", String(localized: "Select or swap tile")),
            (" ", String(localized: "Select or swap tile")),
            (UIKeyCommand.inputEscape, String(localized: "Cancel selection"))
        ]
        return definitions.map { input, title in
            let command = UIKeyCommand(title: title, action: #selector(handleBoardKey(_:)),
                                       input: input, modifierFlags: [])
            // Keep VoiceOver, Full Keyboard Access, and system shortcuts first.
            command.wantsPriorityOverSystemBehavior = false
            return command
        }
    }

    @objc private func handleBoardKey(_ command: UIKeyCommand) {
        guard command.modifierFlags.isEmpty else { return }
        switch command.input {
        case UIKeyCommand.inputUpArrow: moveKeyboardFocus(columnDelta: 0, rowDelta: 1)
        case UIKeyCommand.inputDownArrow: moveKeyboardFocus(columnDelta: 0, rowDelta: -1)
        case UIKeyCommand.inputLeftArrow: moveKeyboardFocus(columnDelta: -1, rowDelta: 0)
        case UIKeyCommand.inputRightArrow: moveKeyboardFocus(columnDelta: 1, rowDelta: 0)
        case "\r", " ": activateKeyboardCell()
        case UIKeyCommand.inputEscape: cancelKeyboardSelection()
        default: break
        }
    }

    func refreshAccessibility() {
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        accessibilityCustomRotors = boardRotors
        guard let scene = scene as? GameScene, let level = scene.gameModel.level else {
            spokenPreview = nil
            accessibilityElements = []
            return
        }
        let game = scene.gameModel
        let changedLevel = displayedLevel !== level
        let changedMode = lastHammerMode != game.hammerModeActive || lastSwapMode != game.swapModeActive
        if changedLevel || changedMode || gameplayPaused || !scene.canHandleBoardTouch {
            clearSelection()
        } else if let cell = selectedCell,
                  selectedLevel !== level || level.symbol(atColumn: cell.column, row: cell.row) !== selectedSymbol {
            clearSelection()
        }
        if changedLevel {
            elementsByCell.removeAll()
            rowElements.removeAll()
            focusedCell = nil
            keyboardCell = nil
            lastMoveReceipt = nil
        }
        if changedLevel || changedMode || currentPreview() == nil { spokenPreview = nil }
        displayedLevel = level
        lastHammerMode = game.hammerModeActive
        lastSwapMode = game.swapModeActive
        let wasHidden = accessibilityElementsHidden
        accessibilityElementsHidden = gameplayPaused || game.gameState != .inProgress
        guard !accessibilityElementsHidden else {
            accessibilityElements = []
            tileElements = []
            keyboardFocusRing.isHidden = true
            cancelKeyboardResponderRequest()
            if isFirstResponder { resignFirstResponder() }
            keyboardResponderRequested = false
            return
        }

        let enabled = canAct
        // Keep the existing accessibility tree while SpriteKit removes and refills
        // pieces. Otherwise a focused cell disappears in the middle of a cascade.
        if !changedLevel, !tileElements.isEmpty, game.isResolvingBoard || actionInFlight {
            for element in tileElements {
                element.accessibilityContainer = self
                element.accessibilityTraits.remove(.selected)
                element.accessibilityTraits.insert(.notEnabled)
                element.accessibilityCustomActions = []
                element.accessibilityFrameInContainerSpace = frame(for: element.cell, in: scene)
            }
            updateAccessibilityTree()
            updateKeyboardFocusRing()
            return
        }
        var elements: [BoardAccessibilityElement] = []
        for row in (0..<level.numRows).reversed() {
            for column in 0..<level.numColumns {
                guard level.tileAt(column: column, row: row) != nil,
                      let symbol = level.symbol(atColumn: column, row: row) else { continue }
                let cell = BoardAccessibilityCell(column: column, row: row)
                let element = elementsByCell[cell] ?? BoardAccessibilityElement(cell: cell, board: self)
                elementsByCell[cell] = element
                element.accessibilityContainer = self
                element.level = level
                element.accessibilityLabel = cell.label(in: level, zodiac: game.zodiac)
                element.accessibilityFrameInContainerSpace = frame(for: cell, in: scene)
                element.accessibilityTraits = symbol.isMovable() || game.hammerModeActive ? .button : .staticText
                if !enabled { element.accessibilityTraits.insert(.notEnabled) }
                if selectedCell == cell { element.accessibilityTraits.insert(.selected) }
                element.accessibilityHint = game.hammerModeActive
                    ? String(localized: "Double-tap to use Festival Hammer on this tile.")
                    : String(localized: "Double-tap to select, then double-tap a neighboring tile to swap. Or use the Actions rotor.")
                element.accessibilityCustomActions = actions(for: element, movable: symbol.isMovable(), enabled: enabled)
                elements.append(element)
            }
        }
        tileElements = elements
        instructionsElement.accessibilityLabel = BoardAccessibilityCell.instructions
        instructionsElement.accessibilityHint = [
            String(localized: "Choose Rows, Power-ups, or Goal tiles in the rotor to explore the board faster. Swipe up or down to move between matches."),
            String(localized: "Use Preview up, down, left, or right before a power-up swap. Read preview details lists the direct-hit positions. Preview never spends a move or uses a tool."),
            String(localized: "With a keyboard, use arrow keys to explore, Return or Space to select and swap, and Escape to cancel.")
        ].joined(separator: " ")
        instructionsElement.accessibilityTraits = [.header, .staticText]
        if let boardFrame = elements.map(\.accessibilityFrameInContainerSpace).reduce(nil as CGRect?, { result, frame in
            result.map { $0.union(frame) } ?? frame
        }) {
            instructionsElement.accessibilityFrameInContainerSpace = CGRect(
                x: boardFrame.minX, y: boardFrame.minY - 24,
                width: boardFrame.width, height: 22)
        }
        instructionsElement.accessibilityCustomActions = [statusAction(), hintAction()]
        if lastMoveReceipt != nil { instructionsElement.accessibilityCustomActions?.append(repeatMoveAction()) }
        if spokenPreview != nil { instructionsElement.accessibilityCustomActions?.append(previewDetailsAction()) }
        updateAccessibilityTree()
        updateKeyboardFocusRing()
        if enabled, !keyboardResponderRequested, keyboardResponderTask == nil, window != nil {
            // UIKit focus can update SwiftUI's hosting hierarchy. Request it after
            // the current representable update, then recheck the live modal state.
            keyboardResponderTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled, let self else { return }
                self.keyboardResponderTask = nil
                guard self.canAct, self.window != nil else { return }
                self.keyboardResponderRequested = self.isFirstResponder || self.becomeFirstResponder()
            }
        }
        if changedLevel || wasHidden {
            let target = focusedCell.flatMap { elementsByCell[$0] }.flatMap { focused in
                elements.contains(where: { $0 === focused }) ? focused : nil
            } ?? instructionsElement
            lastFocusRestoration = target
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .layoutChanged, argument: target)
            }
        }
        if changedMode, enabled {
            if game.hammerModeActive {
                announce(String(localized: "Festival Hammer selected. Double-tap a tile to clear it."))
            } else if game.swapModeActive {
                announce(String(localized: "Ruyi Swap selected. Select two neighboring tiles or use a swap action."))
            } else {
                announce(String(localized: "Tool cancelled."))
            }
        }
    }

    private func cancelKeyboardResponderRequest() {
        keyboardResponderTask?.cancel()
        keyboardResponderTask = nil
    }

    private func updateAccessibilityTree() {
        guard groupsRowsForSwitchControl, let level = (scene as? GameScene)?.gameModel.level else {
            for element in tileElements { element.accessibilityContainer = self }
            accessibilityElements = [instructionsElement] + tileElements
            return
        }
        let rows = Set(tileElements.map { $0.cell.row }).sorted(by: >)
        let groups = rows.map { row in
            let group = rowElements[row] ?? BoardAccessibilityRowElement(row: row, board: self)
            rowElements[row] = group
            group.update(elements: tileElements.filter { $0.cell.row == row }, spokenRow: level.numRows - row)
            return group
        }
        accessibilityElements = [instructionsElement] + groups
    }

    func rememberFocus(on element: BoardAccessibilityElement) {
        guard !accessibilityElementsHidden, let scene = scene as? GameScene,
              element.level === scene.gameModel.level,
              tileElements.contains(where: { $0 === element }) else { return }
        focusedCell = element.cell
        if keyboardCell != nil {
            keyboardCell = element.cell
            updateKeyboardFocusRing()
        }
    }

    /// Keyboard movement only explores live cells. Holes are skipped in the chosen
    /// direction, edges stop, and Enter uses the same validated action as VoiceOver.
    @discardableResult
    func moveKeyboardFocus(columnDelta: Int, rowDelta: Int) -> Bool {
        let horizontal = rowDelta == 0 && (columnDelta == -1 || columnDelta == 1)
        let vertical = columnDelta == 0 && (rowDelta == -1 || rowDelta == 1)
        guard canAct, horizontal || vertical,
              let level = (scene as? GameScene)?.gameModel.level else { return false }
        guard let current = keyboardCell ?? focusedCell,
              tileElements.contains(where: { $0.cell == current }) else {
            return focusKeyboardCell(tileElements.first?.cell)
        }
        var column = current.column + columnDelta
        var row = current.row + rowDelta
        while column >= 0, column < level.numColumns, row >= 0, row < level.numRows {
            let cell = BoardAccessibilityCell(column: column, row: row)
            if tileElements.contains(where: { $0.cell == cell }) { return focusKeyboardCell(cell) }
            column += columnDelta
            row += rowDelta
        }
        return false
    }

    @discardableResult
    private func focusKeyboardCell(_ cell: BoardAccessibilityCell?) -> Bool {
        guard let cell, let element = tileElements.first(where: { $0.cell == cell }) else { return false }
        keyboardCell = cell
        updateKeyboardFocusRing()
        if let scene = scene as? GameScene {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    scroll.scrollRectToVisible(convert(frame(for: cell, in: scene).insetBy(dx: -8, dy: -8), to: scroll),
                                               animated: !scene.reduceMotion && !UIAccessibility.isReduceMotionEnabled)
                    break
                }
                ancestor = view.superview
            }
        }
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
        return true
    }

    @discardableResult
    func activateKeyboardCell() -> Bool {
        guard canAct else { return false }
        if keyboardCell == nil { _ = focusKeyboardCell(focusedCell ?? tileElements.first?.cell) }
        guard let keyboardCell else { return false }
        return activate(keyboardCell)
    }

    @discardableResult
    func cancelKeyboardSelection() -> Bool {
        guard canAct, let scene = scene as? GameScene else { return false }
        clearSelection()
        spokenPreview = nil
        scene.cancelBlastPreview()
        scene.gameModel.hammerModeActive = false
        scene.gameModel.swapModeActive = false
        lastHammerMode = false
        lastSwapMode = false
        refreshAccessibility()
        announce(String(localized: "Selection cancelled."))
        return true
    }

    private func updateKeyboardFocusRing() {
        guard !accessibilityElementsHidden, let cell = keyboardCell,
              tileElements.contains(where: { $0.cell == cell }), let scene = scene as? GameScene else {
            keyboardFocusRing.isHidden = true
            return
        }
        if keyboardFocusRing.superlayer == nil {
            keyboardFocusRing.fillColor = UIColor.clear.cgColor
            keyboardFocusRing.strokeColor = UIColor.white.cgColor
            keyboardFocusRing.lineWidth = 3
            keyboardFocusRing.shadowColor = UIColor.black.cgColor
            keyboardFocusRing.shadowOpacity = 1
            keyboardFocusRing.shadowRadius = 2
            keyboardFocusRing.shadowOffset = .zero
            layer.addSublayer(keyboardFocusRing)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        keyboardFocusRing.path = UIBezierPath(roundedRect: frame(for: cell, in: scene).insetBy(dx: 2, dy: 2),
                                             cornerRadius: 7).cgPath
        keyboardFocusRing.isHidden = false
        CATransaction.commit()
    }

    private var canAct: Bool {
        guard !gameplayPaused, !isPaused, !accessibilityElementsHidden, !actionInFlight,
              let scene = scene as? GameScene, let level = scene.gameModel.level,
              displayedLevel === level else { return false }
        return scene.canHandleBoardTouch && !scene.boardSwapDispatchPending
    }

    /// Returns a live, existing element for VoiceOver to focus. Searches never wrap,
    /// select a tile, or dispatch gameplay, including while a turn is still resolving.
    func rotorElement(for kind: BoardAccessibilityRotor, from current: BoardAccessibilityElement?,
                      forward: Bool) -> BoardAccessibilityElement? {
        guard canAct, !isPaused, !accessibilityElementsHidden,
              let scene = scene as? GameScene, let level = scene.gameModel.level,
              displayedLevel === level else { return nil }
        let elements = tileElements.filter { element in
            let cell = element.cell
            return element.level === level
                && cell.column >= 0 && cell.column < level.numColumns
                && cell.row >= 0 && cell.row < level.numRows
                && level.tileAt(column: cell.column, row: cell.row) != nil
                && level.symbol(atColumn: cell.column, row: cell.row) != nil
        }
        guard let current else {
            let matches = elements.filter { kind.matches($0.cell, in: level) }
            return forward ? matches.first : matches.last
        }
        guard let index = elements.firstIndex(where: { $0 === current }) else { return nil }
        if kind == .rows {
            let rows = Set(elements.map { $0.cell.row })
            let nextRow = forward
                ? rows.filter { $0 < current.cell.row }.max()
                : rows.filter { $0 > current.cell.row }.min()
            guard let nextRow else { return nil }
            // Shaped boards can have holes. Keep the column when possible, otherwise
            // use the closest playable cell, breaking an equal-distance tie to the left.
            return elements.filter { $0.cell.row == nextRow }.min { first, second in
                let firstDistance = abs(first.cell.column - current.cell.column)
                let secondDistance = abs(second.cell.column - current.cell.column)
                return firstDistance == secondDistance
                    ? first.cell.column < second.cell.column : firstDistance < secondDistance
            }
        }
        if forward {
            return elements.dropFirst(index + 1).first { kind.matches($0.cell, in: level) }
        }
        return elements.prefix(index).reversed().first { kind.matches($0.cell, in: level) }
    }

    @discardableResult
    func activate(_ cell: BoardAccessibilityCell) -> Bool {
        guard canAct, let scene = scene as? GameScene, let level = scene.gameModel.level,
              displayedLevel === level,
              cell.column >= 0, cell.column < level.numColumns,
              cell.row >= 0, cell.row < level.numRows,
              let element = elementsByCell[cell], tileElements.contains(where: { $0 === element }),
              let symbol = level.symbol(atColumn: cell.column, row: cell.row) else { return false }
        if scene.gameModel.hammerModeActive {
            clearSelection()
            guard let task = scene.performAccessibleHammer(at: cell) else {
                announce(String(localized: "This tile cannot be cleared with Festival Hammer."))
                return false
            }
            observe(task, in: scene, level: level, invalidSwap: false)
            return true
        }
        guard symbol.isMovable() else {
            announce(String(localized: "This tile cannot be swapped. Clear it with a nearby match or Festival Hammer."))
            return false
        }
        if selectedCell == cell {
            clearSelection()
            refreshAccessibility()
            announce(String(localized: "Selection cancelled."))
            return true
        }
        if let source = selectedCell, selectedLevel === level,
           level.symbol(atColumn: source.column, row: source.row) === selectedSymbol,
           abs(source.column - cell.column) + abs(source.row - cell.row) == 1 {
            return commitSwap(from: source, to: cell, in: scene, level: level)
        }
        let replacingSelection = selectedCell != nil
        clearSelection()
        selectedCell = cell
        selectedSymbol = symbol
        selectedLevel = level
        scene.cancelBlastPreview()
        scene.cancelIdleHint()
        scene.showSelectionIndicator(of: symbol)
        refreshAccessibility()
        let prefix = replacingSelection ? String(localized: "New selection.") : String(localized: "Selected.")
        announce("\(prefix) \(cell.label(in: level, zodiac: scene.gameModel.zodiac))")
        return true
    }

    @discardableResult
    func swap(_ cell: BoardAccessibilityCell, columnDelta: Int, rowDelta: Int) -> Bool {
        guard canAct, let scene = scene as? GameScene, let level = scene.gameModel.level,
              abs(columnDelta) + abs(rowDelta) == 1 else { return false }
        return commitSwap(from: cell, to: BoardAccessibilityCell(column: cell.column + columnDelta,
                                                                row: cell.row + rowDelta), in: scene, level: level)
    }

    /// An explicit inspection action, independent of the optional drag preview.
    /// Reading a preview preserves selection and never enters the move dispatch path.
    @discardableResult
    func preview(_ cell: BoardAccessibilityCell, columnDelta: Int, rowDelta: Int) -> Bool {
        let horizontalNeighbor = rowDelta == 0 && (columnDelta == -1 || columnDelta == 1)
        let verticalNeighbor = columnDelta == 0 && (rowDelta == -1 || rowDelta == 1)
        guard canAct, let scene = scene as? GameScene, let level = scene.gameModel.level,
              displayedLevel === level, !scene.gameModel.hammerModeActive,
              cell.column >= 0, cell.column < level.numColumns, cell.row >= 0, cell.row < level.numRows,
              horizontalNeighbor || verticalNeighbor else { return false }
        let destination = BoardAccessibilityCell(column: cell.column + columnDelta, row: cell.row + rowDelta)
        guard let swap = liveSwap(from: cell, to: destination, in: scene),
              let summary = BoardAccessibilityBlastSummary(level: level, swap: swap, zodiac: scene.gameModel.zodiac) else {
            spokenPreview = nil
            refreshAccessibility()
            announce(String(localized: "No direct blast is available for that swap."))
            return false
        }
        spokenPreview = SpokenPreview(level: level, generation: scene.boardInputGeneration,
                                      usingRuyi: scene.gameModel.swapModeActive,
                                      source: swap.symbolA, destination: swap.symbolB, summary: summary)
        refreshAccessibility()
        announce(summary.summaryDescription)
        return true
    }

    @discardableResult
    func readPreviewDetails() -> Bool {
        guard canAct else { return false }
        guard let preview = currentPreview() else {
            spokenPreview = nil
            refreshAccessibility()
            announce(String(localized: "Preview expired. Choose a Preview action again."))
            return false
        }
        announce(preview.summary.affectedCellsDescription)
        return true
    }

    private func liveSwap(from source: BoardAccessibilityCell, to destination: BoardAccessibilityCell,
                          in scene: GameScene) -> Swap? {
        guard let level = scene.gameModel.level,
              source.column >= 0, source.column < level.numColumns, source.row >= 0, source.row < level.numRows,
              destination.column >= 0, destination.column < level.numColumns,
              destination.row >= 0, destination.row < level.numRows,
              let first = level.symbol(atColumn: source.column, row: source.row),
              let second = level.symbol(atColumn: destination.column, row: destination.row) else { return nil }
        let swap = Swap(symbolA: first, symbolB: second)
        guard scene.isLiveSwap(swap, in: level, fromColumn: source.column, fromRow: source.row,
                               toColumn: destination.column, toRow: destination.row) else { return nil }
        return swap
    }

    private func currentPreview() -> SpokenPreview? {
        guard let preview = spokenPreview, canAct, let scene = scene as? GameScene,
              scene.gameModel.level === preview.level, displayedLevel === preview.level,
              !scene.gameModel.hammerModeActive, scene.gameModel.swapModeActive == preview.usingRuyi,
              scene.boardInputGeneration == preview.generation,
              let swap = liveSwap(from: preview.summary.source, to: preview.summary.destination, in: scene),
              swap.symbolA === preview.source, swap.symbolB === preview.destination,
              BoardAccessibilityBlastSummary(level: preview.level, swap: swap,
                                             zodiac: scene.gameModel.zodiac) == preview.summary else { return nil }
        return preview
    }

    private func commitSwap(from source: BoardAccessibilityCell, to destination: BoardAccessibilityCell,
                            in scene: GameScene, level: Level) -> Bool {
        clearSelection()
        let usingRuyiSwap = scene.gameModel.swapModeActive
        guard let task = scene.performAccessibleSwap(from: source, to: destination) else {
            refreshAccessibility()
            announce(String(localized: "No movable neighboring tile in that direction."))
            return false
        }
        let invalidSwap: Bool
        if let first = level.symbol(atColumn: source.column, row: source.row),
           let second = level.symbol(atColumn: destination.column, row: destination.row) {
            invalidSwap = !usingRuyiSwap && !level.isPossibleSwap(Swap(symbolA: first, symbolB: second))
        } else { invalidSwap = false }
        observe(task, in: scene, level: level, invalidSwap: invalidSwap)
        return true
    }

    private func observe(_ task: Task<Void, Never>, in scene: GameScene, level: Level, invalidSwap: Bool) {
        let goalsBefore = BoardAccessibilityGoalSummary(targets: scene.gameModel.createLevelTargetDatas(),
                                                       guardianHealth: level.boss?.health)
        actionInFlight = true
        refreshAccessibility()
        pendingAction = Task { @MainActor [weak self, weak scene] in
            await task.value
            guard let self else { return }
            // Consuming a targeted tool ends its mode automatically. Observe that
            // transition while input is disabled so it does not say "Tool cancelled"
            // immediately before the action's goal receipt.
            self.refreshAccessibility()
            self.actionInFlight = false
            self.refreshAccessibility()
            guard !Task.isCancelled, let scene, self.scene === scene,
                  scene.gameModel.level === level, !self.gameplayPaused, !self.isPaused,
                  !scene.isPaused, !scene.feedbackPaused else { return }
            let goalsAfter = BoardAccessibilityGoalSummary(targets: scene.gameModel.createLevelTargetDatas(),
                                                          guardianHealth: level.boss?.health)
            let changes = goalsAfter.changes(since: goalsBefore)
            let state = scene.gameModel.gameState
            if state == .inProgress, self.canAct, invalidSwap {
                let message = String(localized: "No match. Move not used.")
                self.recordMoveReceipt(brief: message, detailed: message)
            } else if state == .inProgress, self.canAct {
                let detailed = [changes, self.statusDescription(includeGoals: false, includeGuardianHealth: false)]
                    .filter { !$0.isEmpty }.joined(separator: " ")
                self.recordMoveReceipt(brief: self.briefStatusDescription(), detailed: detailed)
            } else if (state == .win || state == .lose || state == .offeringContinue), !changes.isEmpty {
                // The board is hidden now, but its final move still made progress.
                // Queue the receipt behind result speech without moving accessibility focus.
                self.recordMoveReceipt(brief: self.briefStatusDescription(), detailed: changes, queued: true)
            }
        }
    }

    private func recordMoveReceipt(brief: String, detailed: String, queued: Bool = false) {
        lastMoveReceipt = MoveReceipt(brief: brief, detailed: detailed)
        announce(currentMoveReceipt() ?? detailed, queued: queued)
        refreshAccessibility()
    }

    private func currentMoveReceipt() -> String? {
        guard let receipt = lastMoveReceipt else { return nil }
        return (scene as? GameScene)?.settingModel.boardSpeechDetail == .brief ? receipt.brief : receipt.detailed
    }

    @discardableResult
    func repeatLastMoveResult() -> Bool {
        guard canAct, displayedLevel === (scene as? GameScene)?.gameModel.level,
              let receipt = currentMoveReceipt() else { return false }
        announce(receipt)
        return true
    }

    private func clearSelection() {
        if selectedCell != nil {
            (scene as? GameScene)?.selectionSprite.removeFromParent()
        }
        selectedCell = nil
        selectedSymbol = nil
        selectedLevel = nil
    }

    private func actions(for element: BoardAccessibilityElement, movable: Bool, enabled: Bool) -> [UIAccessibilityCustomAction] {
        guard enabled else { return [] }
        var actions: [UIAccessibilityCustomAction] = []
        if movable, (scene as? GameScene)?.gameModel.hammerModeActive == false {
            let directions: [(String, Int, Int)] = [
                (String(localized: "Swap up"), 0, 1), (String(localized: "Swap down"), 0, -1),
                (String(localized: "Swap left"), -1, 0), (String(localized: "Swap right"), 1, 0)
            ]
            actions = directions.map { name, dc, dr in
                UIAccessibilityCustomAction(name: name) { [weak self, weak element] _ in
                    guard let self, let element, let scene = self.scene as? GameScene,
                          scene.gameModel.level === element.level,
                          self.tileElements.contains(where: { $0 === element }) else { return false }
                    return self.swap(element.cell, columnDelta: dc, rowDelta: dr)
                }
            }
            let previews: [(String, Int, Int)] = [
                (String(localized: "Preview up"), 0, 1), (String(localized: "Preview down"), 0, -1),
                (String(localized: "Preview left"), -1, 0), (String(localized: "Preview right"), 1, 0)
            ]
            for (name, dc, dr) in previews {
                guard let scene = scene as? GameScene,
                      let swap = liveSwap(from: element.cell,
                                          to: BoardAccessibilityCell(column: element.cell.column + dc,
                                                                     row: element.cell.row + dr), in: scene),
                      swap.symbolA.isSpecialPowerUp || swap.symbolA.type.isEnhanced
                        || swap.symbolB.isSpecialPowerUp || swap.symbolB.type.isEnhanced else { continue }
                actions.append(UIAccessibilityCustomAction(name: name) { [weak self, weak element] _ in
                    guard let self, let element, let scene = self.scene as? GameScene,
                          scene.gameModel.level === element.level,
                          self.tileElements.contains(where: { $0 === element }) else { return false }
                    return self.preview(element.cell, columnDelta: dc, rowDelta: dr)
                })
            }
        }
        if selectedCell != nil {
            actions.append(UIAccessibilityCustomAction(name: String(localized: "Cancel selection")) { [weak self] _ in
                self?.clearSelection()
                self?.refreshAccessibility()
                self?.announce(String(localized: "Selection cancelled."))
                return true
            })
        }
        actions.append(statusAction())
        actions.append(hintAction())
        if lastMoveReceipt != nil { actions.append(repeatMoveAction()) }
        if spokenPreview != nil { actions.append(previewDetailsAction()) }
        return actions
    }

    private func previewDetailsAction() -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: "Read preview details")) { [weak self] _ in
            self?.readPreviewDetails() ?? false
        }
    }

    private func repeatMoveAction() -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: "Repeat last move result")) { [weak self] _ in
            self?.repeatLastMoveResult() ?? false
        }
    }

    private func statusAction() -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: "Read board status")) { [weak self] _ in
            guard let self, self.canAct, !self.accessibilityElementsHidden else { return false }
            self.announce(self.statusDescription())
            return true
        }
    }

    private func hintAction() -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: "Suggest a move")) { [weak self] _ in
            guard let self, self.canAct, let scene = self.scene as? GameScene,
                  !scene.gameModel.hammerModeActive, !scene.gameModel.swapModeActive,
                  let level = scene.gameModel.level, let swap = level.goalAwareHintSwap() else { return false }
            let first = BoardAccessibilityCell(column: swap.symbolA.column, row: swap.symbolA.row)
            let second = BoardAccessibilityCell(column: swap.symbolB.column, row: swap.symbolB.row)
            self.announce(String(localized: "Try swapping \(first.positionLabel(in: level)) with \(second.positionLabel(in: level))."))
            return true
        }
    }

    private func statusDescription(includeGoals: Bool = true, includeGuardianHealth: Bool = true) -> String {
        guard let game = (scene as? GameScene)?.gameModel else { return "" }
        var parts = [String(localized: "Score \(game.score). \(game.movesLeft) moves left. \(game.remainingGoalPieces) goal pieces remaining.")]
        if includeGoals {
            let goals = BoardAccessibilityGoalSummary(targets: game.createLevelTargetDatas()).remainingDescription
            if !goals.isEmpty { parts.append(goals) }
        }
        if let seconds = game.secondsLeft {
            parts.append(String(localized: "\(seconds) seconds left."))
        } else if game.level.timeLimit != nil, game.attemptTimerMode == .untimed {
            parts.append(String(localized: "Untimed"))
        }
        if let boss = game.bossStatus {
            if includeGuardianHealth { parts.append(String(localized: "Guardian health \(boss.health).")) }
            parts.append(boss.cue)
        }
        if let notice = game.toolNotice { parts.append(notice) }
        return parts.joined(separator: " ")
    }

    private func briefStatusDescription() -> String {
        guard let game = (scene as? GameScene)?.gameModel else { return "" }
        var parts = [String(localized: "\(game.movesLeft) moves left. \(game.remainingGoalPieces) goal pieces remaining.")]
        if let seconds = game.secondsLeft { parts.append(String(localized: "\(seconds) seconds left.")) }
        if let boss = game.bossStatus { parts.append(String(localized: "Guardian health \(boss.health).")) }
        return parts.joined(separator: " ")
    }

    private func frame(for cell: BoardAccessibilityCell, in scene: GameScene) -> CGRect {
        let center = scene.pointFor(column: cell.column, row: cell.row)
        let halfWidth = scene.gameModel.tileSize.width / 2
        let halfHeight = scene.gameModel.tileSize.height / 2
        let first = convert(scene.convert(CGPoint(x: center.x - halfWidth, y: center.y - halfHeight),
                                          from: scene.symbolsLayer), from: scene)
        let second = convert(scene.convert(CGPoint(x: center.x + halfWidth, y: center.y + halfHeight),
                                           from: scene.symbolsLayer), from: scene)
        return CGRect(x: min(first.x, second.x), y: min(first.y, second.y),
                      width: abs(first.x - second.x), height: abs(first.y - second.y))
    }

    private func announce(_ message: String, queued: Bool = false) {
        lastAnnouncement = message
        lastAnnouncementIsQueued = queued
        guard UIAccessibility.isVoiceOverRunning, !gameplayPaused else { return }
        if queued {
            let speech = NSAttributedString(string: message, attributes: [.accessibilitySpeechQueueAnnouncement: NSNumber(value: true)])
            UIAccessibility.post(notification: .announcement, argument: speech)
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
