import SpriteKit

/// SpriteKit draws the board; this container exposes its actual cells to VoiceOver.
/// Frames are projected through SKView, including the scene's scale and board offset.
final class BoardAccessibilityView: SKView {
    var gameplayPaused = false {
        didSet {
            guard oldValue != gameplayPaused else { return }
            (scene as? GameScene)?.setFeedbackPaused(gameplayPaused)
            clearSelection()
            refreshAccessibility()
        }
    }
    private(set) var tileElements: [BoardAccessibilityElement] = []
    private(set) var pendingAction: Task<Void, Never>?
    private var actionInFlight = false
    private var elementsByCell: [BoardAccessibilityCell: BoardAccessibilityElement] = [:]
    private lazy var instructionsElement = UIAccessibilityElement(accessibilityContainer: self)
    private var selectedCell: BoardAccessibilityCell?
    private weak var selectedSymbol: Symbol?
    private weak var selectedLevel: Level?
    private weak var displayedLevel: Level?
    private var lastHammerMode = false
    private var lastSwapMode = false

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshAccessibility()
    }

    func refreshAccessibility() {
        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        guard let scene = scene as? GameScene, let level = scene.gameModel.level else {
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
        if changedLevel { elementsByCell.removeAll() }
        displayedLevel = level
        lastHammerMode = game.hammerModeActive
        lastSwapMode = game.swapModeActive
        let wasHidden = accessibilityElementsHidden
        accessibilityElementsHidden = gameplayPaused || game.gameState != .inProgress
        guard !accessibilityElementsHidden else {
            accessibilityElements = []
            tileElements = []
            return
        }

        let enabled = canAct
        // Keep the existing accessibility tree while SpriteKit removes and refills
        // pieces. Otherwise a focused cell disappears in the middle of a cascade.
        if !changedLevel, !tileElements.isEmpty, game.isResolvingBoard || actionInFlight {
            for element in tileElements {
                element.accessibilityTraits.remove(.selected)
                element.accessibilityTraits.insert(.notEnabled)
                element.accessibilityCustomActions = []
                element.accessibilityFrameInContainerSpace = frame(for: element.cell, in: scene)
            }
            accessibilityElements = [instructionsElement] + tileElements
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
        instructionsElement.accessibilityTraits = [.header, .staticText]
        if let boardFrame = elements.map(\.accessibilityFrameInContainerSpace).reduce(nil as CGRect?, { result, frame in
            result.map { $0.union(frame) } ?? frame
        }) {
            instructionsElement.accessibilityFrameInContainerSpace = CGRect(
                x: boardFrame.minX, y: boardFrame.minY - 24,
                width: boardFrame.width, height: 22)
        }
        instructionsElement.accessibilityCustomActions = [statusAction(), hintAction()]
        accessibilityElements = [instructionsElement] + elements
        if (changedLevel || wasHidden), UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: instructionsElement)
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

    private var canAct: Bool {
        guard !gameplayPaused, !actionInFlight, let scene = scene as? GameScene else { return false }
        return scene.canHandleBoardTouch && !scene.boardSwapDispatchPending
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
        actionInFlight = true
        refreshAccessibility()
        pendingAction = Task { @MainActor [weak self, weak scene] in
            await task.value
            guard let self else { return }
            self.actionInFlight = false
            self.refreshAccessibility()
            guard !Task.isCancelled, let scene, self.scene === scene,
                  scene.gameModel.level === level, self.canAct else { return }
            if invalidSwap {
                self.announce(String(localized: "No match. Move not used."))
            } else {
                self.announce(self.statusDescription())
            }
        }
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
        return actions
    }

    private func statusAction() -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: String(localized: "Read board status")) { [weak self] _ in
            guard let self, !self.accessibilityElementsHidden else { return false }
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

    private func statusDescription() -> String {
        guard let game = (scene as? GameScene)?.gameModel else { return "" }
        var parts = [String(localized: "Score \(game.score). \(game.movesLeft) moves left. \(game.remainingGoalPieces) goal pieces remaining.")]
        if let seconds = game.secondsLeft { parts.append(String(localized: "\(seconds) seconds left.")) }
        if let boss = game.bossStatus {
            parts.append(String(localized: "Guardian health \(boss.health)."))
            parts.append(boss.cue)
        }
        if let notice = game.toolNotice { parts.append(notice) }
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

    private func announce(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning, !gameplayPaused else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
