import SpriteKit

extension GameScene {
    /// Captures board positions as well as identities: Symbol coordinates change during swaps.
    struct BlastPreviewCandidate {
        let level: Level
        let swap: Swap
        let fromColumn: Int
        let fromRow: Int
        let toColumn: Int
        let toRow: Int
        let preview: BlastPreview
    }

    private var canHandleBoardTouch: Bool {
        isUserInteractionEnabled && !isPaused && !feedbackPaused
            && gameModel.gameState == .inProgress && !gameModel.isResolvingBoard
            && gameModel.movesLeft > 0 && (gameModel.secondsLeft.map { $0 > 0 } ?? true)
    }

    private var canPreviewBlast: Bool {
        canHandleBoardTouch && settingModel.powerUpPreviewsEnabled
            && !gameModel.hammerModeActive && !gameModel.swapModeActive
            && !gameModel.isTutorialHintActive
    }

    /// Shared coordinate handlers let touch routing and native regression checks use the same path.
    @discardableResult
    func beginBoardTouch(column: Int, row: Int) -> Bool {
        guard !boardSwapDispatchPending else { return false }
        cancelBlastPreview()
        cancelIdleHint()
        guard canHandleBoardTouch, let level = gameModel.level,
              isBoardCell(column: column, row: row, in: level) else { return false }

        if gameModel.hammerModeActive {
            let generation = boardInputGeneration
            Task { @MainActor [weak self] in
                guard let self, self.boardInputGeneration == generation,
                      self.canHandleBoardTouch, self.gameModel.level === level,
                      self.gameModel.hammerModeActive else { return }
                await self.gameModel.useHammer(atColumn: column, row: row)
                if self.gameModel.level === level { self.scheduleIdleHint() }
            }
            return false
        }

        guard let symbol = level.symbol(atColumn: column, row: row), symbol.isMovable() else { return false }
        swipeFromColumn = column
        swipeFromRow = row
        swipeFromSymbol = symbol
        swipeLevel = level
        showSelectionIndicator(of: symbol)
        HapticManager.tileSelected()
        return true
    }

    @discardableResult
    func moveBoardTouch(column: Int?, row: Int?) -> Task<Void, Never>? {
        guard swipeFromColumn != nil else { return nil }
        guard let level = swipeLevel, let fromColumn = swipeFromColumn, let fromRow = swipeFromRow,
              let fromSymbol = swipeFromSymbol, isLiveOrigin(in: level), !gameModel.hammerModeActive else {
            cancelBlastPreview()
            return nil
        }
        guard let column, let row, isWithinBoard(column: column, row: row, in: level),
              column != fromColumn || row != fromRow else {
            clearBlastPreviewCandidate()
            return nil
        }

        // Ordinary input keeps its original directional swipe behavior.
        let horizontalDelta = column == fromColumn ? 0 : (column < fromColumn ? -1 : 1)
        let verticalDelta = horizontalDelta == 0 ? (row < fromRow ? -1 : 1) : 0
        let toColumn = fromColumn + horizontalDelta
        let toRow = fromRow + verticalDelta
        guard isBoardCell(column: toColumn, row: toRow, in: level),
              let toSymbol = level.symbol(atColumn: toColumn, row: toRow), toSymbol.isMovable() else {
            clearBlastPreviewCandidate()
            return nil
        }
        let swap = Swap(symbolA: fromSymbol, symbolB: toSymbol)
        let involvesPowerUp = fromSymbol.isSpecialPowerUp || fromSymbol.type.isEnhanced
            || toSymbol.isSpecialPowerUp || toSymbol.type.isEnhanced

        if canPreviewBlast, involvesPowerUp {
            // Preview only the neighboring cell under the finger, never a distant inferred target.
            guard abs(column - fromColumn) + abs(row - fromRow) == 1 else {
                clearBlastPreviewCandidate()
                return nil
            }
            if let preview = level.blastPreview(for: swap) {
                let candidate = BlastPreviewCandidate(level: level, swap: swap,
                    fromColumn: fromColumn, fromRow: fromRow, toColumn: toColumn, toRow: toRow,
                    preview: preview)
                if pendingBlastPreview?.swap.symbolA !== fromSymbol
                    || pendingBlastPreview?.swap.symbolB !== toSymbol
                    || pendingBlastPreview?.preview != preview {
                    renderBlastPreview(preview, in: level)
                }
                pendingBlastPreview = candidate
                return nil
            }
        }

        // Enhanced tiles that do not activate still follow the existing ordinary/invalid-swap path.
        return dispatchBoardSwap(swap, in: level, fromColumn: fromColumn, fromRow: fromRow,
                                 toColumn: toColumn, toRow: toRow, requiresPreview: false)
    }

    @discardableResult
    func endBoardTouch(column: Int?, row: Int?) -> Task<Void, Never>? {
        guard swipeFromColumn != nil else { return nil }
        guard let candidate = pendingBlastPreview, let column, let row,
              canPreviewBlast, isLiveOrigin(in: candidate.level),
              column == candidate.toColumn, row == candidate.toRow,
              isLiveSwap(candidate.swap, in: candidate.level,
                         fromColumn: candidate.fromColumn, fromRow: candidate.fromRow,
                         toColumn: candidate.toColumn, toRow: candidate.toRow),
              candidate.level.blastPreview(for: candidate.swap) == candidate.preview else {
            cancelBlastPreview()
            scheduleIdleHint()
            return nil
        }
        return dispatchBoardSwap(candidate.swap, in: candidate.level,
                                 fromColumn: candidate.fromColumn, fromRow: candidate.fromRow,
                                 toColumn: candidate.toColumn, toRow: candidate.toRow, requiresPreview: true)
    }

    /// Cancelling never calls the commit path, including when SpriteKit cancels a touch at pause.
    func cancelBlastPreview() {
        boardInputGeneration &+= 1
        boardSwapDispatchPending = false
        boardTouchID = nil
        swipeFromColumn = nil
        swipeFromRow = nil
        swipeFromSymbol = nil
        swipeLevel = nil
        clearBlastPreviewCandidate()
        selectionSprite.removeAllActions()
        selectionSprite.removeFromParent()
    }

    private func clearBlastPreviewCandidate() {
        pendingBlastPreview = nil
        blastPreviewLayer.removeAllChildren()
        if feedback.blastPreviewVisible { feedback.blastPreviewVisible = false }
    }

    private func renderBlastPreview(_ preview: BlastPreview, in level: Level) {
        blastPreviewLayer.removeAllChildren()
        for cell in preview.affectedCells where isBoardCell(column: cell.column, row: cell.row, in: level) {
            let source = preview.sourceCells.contains(cell)
            let outline = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * 0.84,
                                                     height: gameModel.tileSize.height * 0.84), cornerRadius: 6)
            outline.name = "blast-preview-\(cell.column)-\(cell.row)"
            outline.position = pointFor(column: cell.column, row: cell.row)
            outline.strokeColor = source ? UIColor(hex: 0xFFCE54) : UIColor(hex: 0xFFF0B7)
            outline.fillColor = .clear
            outline.lineWidth = source ? 3 : 1.8
            outline.alpha = 0.9
            blastPreviewLayer.addChild(outline)
        }
        feedback.blastPreviewVisible = !blastPreviewLayer.children.isEmpty
    }

    private func isBoardCell(column: Int, row: Int, in level: Level) -> Bool {
        isWithinBoard(column: column, row: row, in: level) && level.tileAt(column: column, row: row) != nil
    }

    private func isWithinBoard(column: Int, row: Int, in level: Level) -> Bool {
        column >= 0 && column < level.numColumns && row >= 0 && row < level.numRows
    }

    private func isLiveOrigin(in level: Level) -> Bool {
        guard canHandleBoardTouch, gameModel.level === level,
              let column = swipeFromColumn, let row = swipeFromRow, let symbol = swipeFromSymbol,
              isBoardCell(column: column, row: row, in: level) else { return false }
        return level.symbol(atColumn: column, row: row) === symbol && symbol.isMovable()
    }

    private func isLiveSwap(_ swap: Swap, in level: Level,
                            fromColumn: Int, fromRow: Int, toColumn: Int, toRow: Int) -> Bool {
        guard isBoardCell(column: fromColumn, row: fromRow, in: level),
              isBoardCell(column: toColumn, row: toRow, in: level),
              abs(fromColumn - toColumn) + abs(fromRow - toRow) == 1 else { return false }
        return level.symbol(atColumn: fromColumn, row: fromRow) === swap.symbolA
            && level.symbol(atColumn: toColumn, row: toRow) === swap.symbolB
            && swap.symbolA.isMovable() && swap.symbolB.isMovable()
            && swap.symbolA.sprite?.parent === symbolsLayer && swap.symbolB.sprite?.parent === symbolsLayer
    }

    private func dispatchBoardSwap(_ swap: Swap, in level: Level,
                                   fromColumn: Int, fromRow: Int, toColumn: Int, toRow: Int,
                                   requiresPreview: Bool) -> Task<Void, Never> {
        let usingRuyiSwap = gameModel.swapModeActive
        cancelBlastPreview()
        let generation = boardInputGeneration
        boardSwapDispatchPending = true
        return Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.boardInputGeneration == generation { self.boardSwapDispatchPending = false }
            }
            guard self.boardInputGeneration == generation,
                  self.canHandleBoardTouch, self.gameModel.level === level,
                  !self.gameModel.hammerModeActive, self.gameModel.swapModeActive == usingRuyiSwap,
                  !requiresPreview || self.canPreviewBlast,
                  self.isLiveSwap(swap, in: level, fromColumn: fromColumn, fromRow: fromRow,
                                  toColumn: toColumn, toRow: toRow) else { return }
            self.boardSwapDispatchPending = false
            if usingRuyiSwap {
                await self.gameModel.useRuyiSwap(swap)
            } else {
                await self.gameModel.handleSwipe(swap)
            }
            if self.gameModel.level === level { self.scheduleIdleHint() }
        }
    }
}
