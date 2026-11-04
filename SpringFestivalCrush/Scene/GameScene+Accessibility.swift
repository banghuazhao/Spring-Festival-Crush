import SpriteKit

extension GameScene {
    /// VoiceOver swaps commit explicitly, without a drag or a visual preview. They use
    /// the same live-pair validation and queued dispatch as touch input.
    func performAccessibleSwap(from source: BoardAccessibilityCell,
                               to destination: BoardAccessibilityCell) -> Task<Void, Never>? {
        guard canHandleBoardTouch, !boardSwapDispatchPending, !gameModel.hammerModeActive,
              let level = gameModel.level,
              source.column >= 0, source.column < level.numColumns,
              source.row >= 0, source.row < level.numRows,
              destination.column >= 0, destination.column < level.numColumns,
              destination.row >= 0, destination.row < level.numRows,
              let first = level.symbol(atColumn: source.column, row: source.row),
              let second = level.symbol(atColumn: destination.column, row: destination.row) else { return nil }
        let swap = Swap(symbolA: first, symbolB: second)
        guard isLiveSwap(swap, in: level, fromColumn: source.column, fromRow: source.row,
                         toColumn: destination.column, toRow: destination.row) else { return nil }
        cancelIdleHint()
        return dispatchBoardSwap(swap, in: level, fromColumn: source.column, fromRow: source.row,
                                 toColumn: destination.column, toRow: destination.row, requiresPreview: false)
    }

    func performAccessibleHammer(at cell: BoardAccessibilityCell) -> Task<Void, Never>? {
        guard canHandleBoardTouch, !boardSwapDispatchPending,
              gameModel.hammerModeActive, gameModel.hammerCharges > 0,
              let level = gameModel.level,
              cell.column >= 0, cell.column < level.numColumns,
              cell.row >= 0, cell.row < level.numRows,
              let symbol = level.symbol(atColumn: cell.column, row: cell.row) else { return nil }
        cancelBlastPreview()
        cancelIdleHint()
        let generation = boardInputGeneration
        boardSwapDispatchPending = true
        return Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.boardInputGeneration == generation { self.boardSwapDispatchPending = false }
            }
            guard self.boardInputGeneration == generation, self.canHandleBoardTouch,
                  self.gameModel.level === level, self.gameModel.hammerModeActive,
                  level.symbol(atColumn: cell.column, row: cell.row) === symbol,
                  symbol.sprite?.parent === self.symbolsLayer else { return }
            await self.gameModel.useHammer(atColumn: cell.column, row: cell.row)
            if self.gameModel.level === level { self.scheduleIdleHint() }
        }
    }
}
