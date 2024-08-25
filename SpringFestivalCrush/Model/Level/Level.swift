import Foundation

class Level {
    let numColumns: Int
    let numRows: Int

    let maximumMoves: Int
    var possbileSymbols: [String]?
    var levelGoal: LevelGoal

    var possibleSwaps: Set<Swap> = []

    private var tiles: Array2D<Tile>
    private var symbols: Array2D<Symbol>
    private var comboMultiplier = 0

    init?(filename: String) {
        // 1
        guard let levelData = LevelData.loadFrom(file: filename) else { return nil }
        // 2
        let tilesArray = levelData.tiles

        numRows = tilesArray.count
        numColumns = tilesArray[0].count

        tiles = Array2D<Tile>(columns: numColumns, rows: numRows)
        symbols = Array2D<Symbol>(columns: numColumns, rows: numRows)

        maximumMoves = levelData.moves
        possbileSymbols = levelData.possibleSymbols
        levelGoal = levelData.levelGoal

        // 3
        for (row, rowArray) in tilesArray.enumerated() {
            // 4
            let tileRow = numRows - row - 1
            // 5
            for (column, value) in rowArray.enumerated() {
                if value != 0 {
                    tiles[column, tileRow] = Tile(type: value)
                }
            }
        }
    }

    func symbol(atColumn column: Int, row: Int) -> Symbol? {
        precondition(column >= 0 && column < numColumns)
        precondition(row >= 0 && row < numRows)
        return symbols[column, row]
    }

    func tileAt(column: Int, row: Int) -> Tile? {
        precondition(column >= 0 && column < numColumns)
        precondition(row >= 0 && row < numRows)
        return tiles[column, row]
    }

    func shuffle() -> Set<Symbol> {
        var set: Set<Symbol>
        repeat {
            set = createInitialSymbols()
            detectPossibleSwaps()
            print("possible swaps: \(possibleSwaps)")
        } while possibleSwaps.count == 0

        return set
    }

    private func createInitialSymbols() -> Set<Symbol> {
        var set: Set<Symbol> = []

        for row in 0 ..< numRows {
            for column in 0 ..< numColumns {
                guard
                    let tileType = tiles[column, row]?.type,
                    tileType != .empty
                else { continue }

                var symbolType: SymbolType
                switch tileType {
                case .lock:
                    symbolType = SymbolType.lock
                default:
                    repeat {
                        symbolType = SymbolType.randomMovableSymbolType(possbileSymbols)
                    } while (column >= 2 &&
                        symbols[column - 1, row]?.type == symbolType &&
                        symbols[column - 2, row]?.type == symbolType)
                        || (row >= 2 &&
                            symbols[column, row - 1]?.type == symbolType &&
                            symbols[column, row - 2]?.type == symbolType)
                }

                let symbol = Symbol(column: column, row: row, symbolType: symbolType)
                symbols[column, row] = symbol

                set.insert(symbol)
            }
        }
        return set
    }

    private func hasChain(atColumn column: Int, row: Int) -> Bool {
        let symbolType = symbols[column, row]!.type

        // Horizontal chain check
        var horizontalLength = 1

        // Left
        var i = column - 1
        while i >= 0,
              let symbol = symbols[i, row],
              symbol.type == symbolType {
            i -= 1
            horizontalLength += 1
        }

        // Right
        i = column + 1
        while i < numColumns && symbols[i, row]?.type == symbolType {
            i += 1
            horizontalLength += 1
        }
        if horizontalLength >= 3 { return true }

        // Vertical chain check
        var verticalLength = 1

        // Down
        i = row - 1
        while i >= 0 && symbols[column, i]?.type == symbolType {
            i -= 1
            verticalLength += 1
        }

        // Up
        i = row + 1
        while i < numRows && symbols[column, i]?.type == symbolType {
            i += 1
            verticalLength += 1
        }
        return verticalLength >= 3
    }

    func detectPossibleSwaps() {
        var set: Set<Swap> = []

        for row in 0 ..< numRows {
            for column in 0 ..< numColumns {
                if column < numColumns - 1,
                   let symbol = symbols[column, row],
                   symbol.isMovable() {
                    // Have a symbol in this spot? If there is no tile, there is no symbol.
                    if let other = symbols[column + 1, row], other.isMovable() {
                        // Swap them
                        symbols[column, row] = other
                        symbols[column + 1, row] = symbol

                        // Is either symbol now part of a chain?
                        if hasChain(atColumn: column + 1, row: row) ||
                            hasChain(atColumn: column, row: row) {
                            set.insert(Swap(symbolA: symbol, symbolB: other))
                        }

                        // Swap them back
                        symbols[column, row] = symbol
                        symbols[column + 1, row] = other
                    }

                    if row < numRows - 1,
                       let other = symbols[column, row + 1],
                       other.isMovable() {
                        symbols[column, row] = other
                        symbols[column, row + 1] = symbol

                        // Is either symbol now part of a chain?
                        if hasChain(atColumn: column, row: row + 1) ||
                            hasChain(atColumn: column, row: row) {
                            set.insert(Swap(symbolA: symbol, symbolB: other))
                        }

                        // Swap them back
                        symbols[column, row] = symbol
                        symbols[column, row + 1] = other
                    }
                } else if column == numColumns - 1,
                          let symbol = symbols[column, row],
                          symbol.isMovable() {
                    if row < numRows - 1,
                       let other = symbols[column, row + 1],
                       other.isMovable() {
                        symbols[column, row] = other
                        symbols[column, row + 1] = symbol

                        // Is either symbol now part of a chain?
                        if hasChain(atColumn: column, row: row + 1) ||
                            hasChain(atColumn: column, row: row) {
                            set.insert(Swap(symbolA: symbol, symbolB: other))
                        }

                        // Swap them back
                        symbols[column, row] = symbol
                        symbols[column, row + 1] = other
                    }
                }
            }
        }

        possibleSwaps = set
    }

    func performSwap(_ swap: Swap) {
        let columnA = swap.symbolA.column
        let rowA = swap.symbolA.row
        let columnB = swap.symbolB.column
        let rowB = swap.symbolB.row

        symbols[columnA, rowA] = swap.symbolB
        swap.symbolB.column = columnA
        swap.symbolB.row = rowA

        symbols[columnB, rowB] = swap.symbolA
        swap.symbolA.column = columnB
        swap.symbolA.row = rowB
    }

    func isPossibleSwap(_ swap: Swap) -> Bool {
        return possibleSwaps.contains(swap)
    }

    private func detectHorizontalMatches() -> Set<Chain> {
        // 1
        var set: Set<Chain> = []
        // 2
        for row in 0 ..< numRows {
            var column = 0
            while column < numColumns - 2 {
                // 3
                if let symbol = symbols[column, row], symbol.isMatchable() {
                    let matchType = symbol.type
                    // 4
                    if symbols[column + 1, row]?.type == matchType &&
                        symbols[column + 2, row]?.type == matchType {
                        // 5
                        let chain = Chain(chainType: .horizontal)
                        repeat {
                            chain.add(symbol: symbols[column, row]!)
                            column += 1
                        } while column < numColumns && symbols[column, row]?.type == matchType

                        set.insert(chain)
                        continue
                    }
                }
                // 6
                column += 1
            }
        }
        return set
    }

    private func detectVerticalMatches() -> Set<Chain> {
        var set: Set<Chain> = []

        for column in 0 ..< numColumns {
            var row = 0
            while row < numRows - 2 {
                if let symbol = symbols[column, row], symbol.isMatchable() {
                    let matchType = symbol.type

                    if symbols[column, row + 1]?.type == matchType &&
                        symbols[column, row + 2]?.type == matchType {
                        let chain = Chain(chainType: .vertical)
                        repeat {
                            chain.add(symbol: symbols[column, row]!)
                            row += 1
                        } while row < numRows && symbols[column, row]?.type == matchType

                        set.insert(chain)
                        continue
                    }
                }
                row += 1
            }
        }
        return set
    }

    func removeMatches() -> Set<Chain> {
        let horizontalChains = detectHorizontalMatches()
        let verticalChains = detectVerticalMatches()

        removeSymbols(in: horizontalChains)
        removeSymbols(in: verticalChains)

        calculateScores(for: horizontalChains)
        calculateScores(for: verticalChains)

        return horizontalChains.union(verticalChains)
    }

    private func removeSymbols(in chains: Set<Chain>) {
        for chain in chains {
            for symbol in chain.symbols {
                symbols[symbol.column, symbol.row] = nil
            }
        }
    }

    func removeLocks() -> Chain? {
        var lockPositionsToRemove = Set<[Int]>()
        for column in 0 ..< numColumns {
            for row in 0 ..< numRows {
                if let symbol = symbols[column, row], symbol.type == .lock {
                    let adjacentPositions = [
                        [column + 1, row],
                        [column - 1, row],
                        [column, row + 1],
                        [column, row - 1],
                    ]
                    for adjacentPosition in adjacentPositions {
                        let adjacentRow = adjacentPosition[1]
                        let adjacentColumn = adjacentPosition[0]
                        if (adjacentRow >= 0 && adjacentRow < numRows)
                            && (adjacentColumn >= 0 && adjacentColumn < numColumns)
                            && symbols[adjacentColumn, adjacentRow] == nil {
                            lockPositionsToRemove.insert([column, row])
                        }
                    }
                }
            }
        }
        if lockPositionsToRemove.isEmpty {
            return nil
        } else {
            let chain = Chain(chainType: .locks)
            for lockPosition in lockPositionsToRemove {
                let column = lockPosition[0]
                let row = lockPosition[1]
                if let symbol = symbols[column, row] {
                    chain.add(symbol: symbol)
                    symbols[column, row] = nil
                    tiles[column, row]?.type = .normal
                }
            }
            return chain
        }
    }

    func fillHoles() -> [[Symbol]] {
        var columns: [[Symbol]] = []
        // 1
        for column in 0 ..< numColumns {
            var array = [Symbol]()
            for row in 0 ..< numRows {
                // 2
                if tiles[column, row] != nil && symbols[column, row] == nil {
                    // 3
                    for lookup in (row + 1) ..< numRows {
                        guard let symbol = symbols[column, lookup],
                              symbol.isMovable()
                        else { continue }
                        // 4
                        symbols[column, lookup] = nil
                        symbols[column, row] = symbol
                        symbol.row = row
                        // 5
                        array.append(symbol)
                        // 6
                        break
                    }
                }
            }
            // 7
            if !array.isEmpty {
                columns.append(array)
            }
        }
        return columns
    }

    func topUpSymbols() -> [[Symbol]] {
        var columns: [[Symbol]] = []
        var symbolType: SymbolType = .unknown

        for column in 0 ..< numColumns {
            var array: [Symbol] = []

            // 1
            for row in stride(from: numRows - 1, through: 2, by: -1) {
                var tempRow = row
                while tempRow >= 0 && symbols[column, tempRow] == nil {
                    // 2
                    if tiles[column, tempRow] != nil {
                        // 3
                        var newSymbolType: SymbolType
                        repeat {
                            newSymbolType = SymbolType.randomMovableSymbolType(possbileSymbols)
                        } while newSymbolType == symbolType
                        symbolType = newSymbolType
                        // 4
                        let symbol = Symbol(column: column, row: tempRow, symbolType: symbolType)
                        symbols[column, tempRow] = symbol
                        array.append(symbol)
                    }

                    tempRow -= 1
                }
            }
            // 5
            if !array.isEmpty {
                columns.append(array)
            }
        }
        return columns
    }

    private func calculateScores(for chains: Set<Chain>) {
        // 3-chain is 60 pts, 4-chain is 120, 5-chain is 180, and so on
        for chain in chains {
            chain.score = 60 * (chain.length - 2)
            comboMultiplier += 1
        }
    }

    func resetComboMultiplier() {
        comboMultiplier = 1
    }

    func doesReachLevelTarget() -> Bool {
        levelGoal.levelTarget.firecracker ?? 0 <= 0
            && levelGoal.levelTarget.redPocket ?? 0 <= 0
            && levelGoal.levelTarget.dumpling ?? 0 <= 0
            && levelGoal.levelTarget.bowl ?? 0 <= 0
            && levelGoal.levelTarget.lantern ?? 0 <= 0
            && levelGoal.levelTarget.zodiac ?? 0 <= 0
            && levelGoal.levelTarget.lock ?? 0 <= 0
    }
}
