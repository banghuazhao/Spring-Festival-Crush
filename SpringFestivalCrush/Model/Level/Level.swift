import Foundation

class Level {
    let numColumns: Int
    let numRows: Int

    let maximumMoves: Int
    var possbileSymbols: [String]?
    var bgMusic: String?

    var levelGoal: LevelGoal

    var possibleSwaps: Set<Swap> = []

    private var tiles: Array2D<Tile>
    private var symbols: Array2D<Symbol>

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
        if let bgMusic = levelData.bgMusic {
            self.bgMusic = bgMusic
        } else {
            bgMusic = "Chinatown.mp3"
        }

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
        guard let symbolType = symbols[column, row]?.type else { return false }

        // Horizontal chain check
        var horizontalLength = 1

        // Left
        var i = column - 1
        while i >= 0,
              let symbol = symbols[i, row],
              symbol.type.isMatchableTo(symbolType) {
            i -= 1
            horizontalLength += 1
        }

        // Right
        i = column + 1
        while i < numColumns,
              let symbol = symbols[i, row],
              symbol.type.isMatchableTo(symbolType) {
            i += 1
            horizontalLength += 1
        }
        if horizontalLength >= 3 { return true }

        // Vertical chain check
        var verticalLength = 1

        // Down
        i = row - 1
        while i >= 0,
              let symbol = symbols[column, i],
              symbol.type.isMatchableTo(symbolType) {
            i -= 1
            verticalLength += 1
        }

        // Up
        i = row + 1
        while i < numRows,
              let symbol = symbols[column, i],
              symbol.type.isMatchableTo(symbolType) {
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
                guard let symbol = symbols[column, row], symbol.isMatchable() else {
                    column += 1
                    continue
                }
                let matchType = symbol.type

                guard let symbol1 = symbols[column + 1, row],
                      symbol1.type.isMatchableTo(matchType),
                      let symbol2 = symbols[column + 2, row],
                      symbol2.type.isMatchableTo(matchType) else {
                    column += 1
                    continue
                }

                let chain = Chain(chainType: .horizontal3)
                var symbolsToAdd = [symbol, symbol1, symbol2]
                column += 3

                if column < numColumns,
                   let symbol3 = symbols[column, row],
                   symbol3.type.isMatchableTo(matchType) {
                    chain.chainType = .horizontal4
                    symbolsToAdd.append(symbol3)
                    column += 1
                }

                if column < numColumns,
                   let symbol4 = symbols[column, row],
                   symbol4.type.isMatchableTo(matchType) {
                    chain.chainType = .five
                    symbolsToAdd.append(symbol4)
                    column += 1
                }

                chain.add(symbols: symbolsToAdd)
                set.insert(chain)
            }
        }
        return set
    }

    private func detectVerticalMatches() -> Set<Chain> {
        var set: Set<Chain> = []

        for column in 0 ..< numColumns {
            var row = 0
            while row < numRows - 2 {
                guard let symbol = symbols[column, row], symbol.isMatchable() else {
                    row += 1
                    continue
                }
                let matchType = symbol.type

                guard let symbol1 = symbols[column, row + 1],
                      symbol1.type.isMatchableTo(matchType),
                      let symbol2 = symbols[column, row + 2],
                      symbol2.type.isMatchableTo(matchType) else {
                    row += 1
                    continue
                }

                let chain = Chain(chainType: .vertical3)
                var symbolsToAdd = [symbol, symbol1, symbol2]
                row += 3

                if row < numRows,
                   let symbol3 = symbols[column, row],
                   symbol3.type.isMatchableTo(matchType) {
                    chain.chainType = .vertical4
                    symbolsToAdd.append(symbol3)
                    row += 1
                }

                if row < numRows,
                   let symbol4 = symbols[column, row],
                   symbol4.type.isMatchableTo(matchType) {
                    chain.chainType = .five
                    symbolsToAdd.append(symbol4)
                    row += 1
                }

                chain.add(symbols: symbolsToAdd)
                set.insert(chain)
            }
        }
        return set
    }

    func explodeSpecialSymbols(for chains: Set<Chain>) -> Set<Chain> {
        var newChains = Set<Chain>()
        let symbols = allSymbolsFor(for: chains)
        for symbol in symbols {
            if symbol.type.isEnhanced {
                newChains = newChains.union(detectSpecialElimination(for: symbol))
            }
        }
        newChains.subtract(chains)
        removeSymbols(in: newChains)
        calculateScores(for: newChains)
        return newChains
    }

    func detectSpecialElimination(for symbol: Symbol) -> Set<Chain> {
        guard symbol.type.isEnhanced else { return Set<Chain>() }
        var set = Set<Chain>()
        let surroundingPositions = surroundingPositions(
            column: symbol.column,
            row: symbol.row
        )
        for position in surroundingPositions {
            let column = position[0]
            let row = position[1]
            if isPositionInside(column: column, row: row),
               let symbol = symbols[column, row] {
                let chainType: Chain.ChainType = if symbol.type.isEnhanced {
                    .enhanced
                } else {
                    .single
                }
                let chain = Chain(chainType: chainType)
                chain.add(symbol: symbol)
                set.insert(chain)
            }
        }
        return set
    }

    func allSymbolsFor(for chains: Set<Chain>) -> Set<Symbol> {
        var set = Set<Symbol>()
        for chain in chains {
            for symbol in chain.symbols {
                set.insert(symbol)
            }
        }
        return set
    }

    func detectElimination(for chains: Set<Chain>) -> Set<Chain> {
        var set = Set<Chain>()
        var eliminationSymbols = [Symbol]()
        for chain in chains {
            for symbol in chain.symbols {
                guard symbol.type.isEnhanced else { continue }
                let surroundingPositions = surroundingPositions(
                    column: symbol.column,
                    row: symbol.row
                )
                for position in surroundingPositions {
                    let column = position[0]
                    let row = position[1]
                    if isPositionInside(column: column, row: row),
                       let symbol = symbols[column, row] {
                        eliminationSymbols.append(symbol)
                    }
                }
            }
        }

        if eliminationSymbols.count > 0 {
            let chain = Chain(chainType: .single)
            chain.add(symbols: eliminationSymbols)
            set.insert(chain)
        }
        return set
    }

    private func surroundingPositions(column: Int, row: Int) -> [[Int]] {
        return [
            [column + 1, row],
            [column - 1, row],
            [column + 1, row + 1],
            [column - 1, row + 1],
            [column + 1, row - 1],
            [column - 1, row - 1],
            [column, row + 1],
            [column, row - 1],
        ]
    }

    private func adjacentPositions(column: Int, row: Int) -> [[Int]] {
        [
            [column + 1, row],
            [column - 1, row],
            [column, row + 1],
            [column, row - 1],
        ]
    }

    private func isPositionInside(column: Int, row: Int) -> Bool {
        column >= 0 && column < numColumns &&
            row >= 0 && row < numRows
    }

    func removeMatches() -> Set<Chain> {
        let horizontalChains = detectHorizontalMatches()
        let verticalChains = detectVerticalMatches()

        let matchChains = horizontalChains.union(verticalChains)

        removeSymbols(in: matchChains)
        calculateScores(for: matchChains)

        return matchChains
    }

    func removeSpecialSymbols() -> Set<Chain> {
        let enhancedChains = detectEnhancedChains()
        removeSymbols(in: enhancedChains)
        calculateScores(for: enhancedChains)
        return enhancedChains
    }

    private func detectEnhancedChains() -> Set<Chain> {
        var chains = Set<Chain>()
        for row in 0 ..< numRows {
            for column in 0 ..< numColumns {
                if let symbol = symbols[column, row],
                   symbol.type.isEnhanced {
                    let chain = Chain(chainType: .enhanced)
                    chain.add(symbol: symbol)
                    chains.insert(chain)
                }
            }
        }
        return chains
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
                    let adjacentPositions = adjacentPositions(
                        column: symbol.column,
                        row: symbol.row
                    )
                    for adjacentPosition in adjacentPositions {
                        let adjacentColumn = adjacentPosition[0]
                        let adjacentRow = adjacentPosition[1]
                        if isPositionInside(column: adjacentColumn, row: adjacentRow)
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

    func createSpecialSymbols(for chains: Set<Chain>) -> [Symbol] {
        var specialSymbols = [Symbol]()
        for chain in chains {
            guard chain.chainType == .horizontal4 ||
                chain.chainType == .vertical4 else {
                continue
            }
            guard let firstSymbol = chain.symbols.first else { continue }
            let column = firstSymbol.column
            let row = firstSymbol.row
            let specialSymbol = Symbol(
                column: column,
                row: row,
                symbolType: firstSymbol.type.enhancedType
            )
            symbols[column, row] = specialSymbol
            specialSymbols.append(specialSymbol)
        }
        return specialSymbols
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
        // elimination-chain: 20 pts
        // 3-chain: 60 pts
        // 4-chain: 120 pts
        // 5-chain: 180 pts
        // Enhanced symbol: 100 pts
        for chain in chains {
            switch chain.chainType {
            case .horizontal3:
                chain.score = 60
            case .vertical3:
                chain.score = 60
            case .locks:
                chain.score = 20
            case .horizontal4:
                chain.score = 120
            case .vertical4:
                chain.score = 120
            case .five:
                chain.score = 200
            case .single:
                chain.score = 20
            case .enhanced:
                chain.score = 100
            }
        }
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

    func updateLevelTarget(by chains: Set<Chain>) {
        let allSymbols = allSymbolsFor(for: chains)
        for symbol in allSymbols {
            switch symbol.type {
            case .firecracker, .firecrackerEnhanced:
                if let firecracker = levelGoal.levelTarget.firecracker {
                    levelGoal.levelTarget.firecracker = firecracker - 1
                }
            case .redPocket, .redPocketEnhanced:
                if let redPocket = levelGoal.levelTarget.redPocket {
                    levelGoal.levelTarget.redPocket = redPocket - 1
                }
            case .dumpling, .dumplingEnhanced:
                if let dumpling = levelGoal.levelTarget.dumpling {
                    levelGoal.levelTarget.dumpling = dumpling - 1
                }
            case .bowl, .bowlEnhanced:
                if let bowl = levelGoal.levelTarget.bowl {
                    levelGoal.levelTarget.bowl = bowl - 1
                }
            case .lantern, .lanternEnhanced:
                if let lantern = levelGoal.levelTarget.lantern {
                    levelGoal.levelTarget.lantern = lantern - 1
                }
            case .zodiac, .zodiacEnhanced:
                if let zodiac = levelGoal.levelTarget.zodiac {
                    levelGoal.levelTarget.zodiac = zodiac - 1
                }
            case .lock:
                if let lock = levelGoal.levelTarget.lock {
                    levelGoal.levelTarget.lock = lock - 1
                }
            default: continue
            }
        }
    }

    func enhanceSymbols(num: Int) -> [Symbol] {
        var enhancedSymbols = [Symbol]()
        var remaining = num
        while remaining > 0 {
            guard symbols.normalMatchableElements() > 0 else {
                break
            }

            let symbolCandidates = symbols.nonNilElements()

            var symbolToEnhance: Symbol?
            while symbolToEnhance == nil {
                guard let symbol = symbolCandidates.randomElement(),
                      !symbol.type.isEnhanced else { continue }
                symbolToEnhance = symbol
            }
            if let symbolToEnhance {
                symbolToEnhance.enhance()
                enhancedSymbols.append(symbolToEnhance)
            }
            remaining -= 1
        }
        return enhancedSymbols
    }
}
