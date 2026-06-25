import Foundation
import SpriteKit

class Level {
    let numColumns: Int
    let numRows: Int

    let maximumMoves: Int
    var possibleSymbols: [String]?
    var bgMusic: String?

    var levelGoal: LevelGoal
    var noShuffle: Bool = false

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
        possibleSymbols = levelData.possibleSymbols
        if let bgMusic = levelData.bgMusic {
            self.bgMusic = bgMusic
        } else {
            bgMusic = "Chinatown.mp3"
        }

        levelGoal = levelData.levelGoal
        noShuffle = levelData.noShuffle ?? false

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
        if noShuffle {
            let set = createInitialSymbols()
            detectPossibleSwaps()
            return set
        }
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
                case .doubleLock:
                    symbolType = SymbolType.heavyLock
                #if DEBUG
                case .debugFive:
                    symbolType = .five
                case .debugLightning:
                    symbolType = .lightning
                case .debugEnhanced:
                    symbolType = .firecrackerEnhanced
                #endif
                default:
                    repeat {
                        symbolType = SymbolType.randomMovableSymbolType(possibleSymbols)
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
        // Power-up symbols can always be swapped with any movable symbol.
        if swap.symbolA.isSpecialPowerUp { return swap.symbolB.isMovable() }
        if swap.symbolB.isSpecialPowerUp { return swap.symbolA.isMovable() }
        return possibleSwaps.contains(swap)
    }

    // Returns non-nil chains when the swap activates a five or lightning power-up.
    // Symbols are already removed from the board when this returns.
    func tryActivateSpecialSwap(_ swap: Swap) -> Set<Chain>? {
        if swap.symbolA.type == .five || swap.symbolB.type == .five {
            return activateFiveEffect(for: swap)
        }
        if swap.symbolA.type == .lightning || swap.symbolB.type == .lightning {
            return activateLightningEffect(for: swap)
        }
        return nil
    }

    private func activateFiveEffect(for swap: Swap) -> Set<Chain> {
        let fiveSymbol   = swap.symbolA.type == .five ? swap.symbolA : swap.symbolB
        let targetSymbol = swap.symbolA.type == .five ? swap.symbolB : swap.symbolA
        let targetType   = targetSymbol.type

        let chain = Chain(chainType: .fiveEffect)
        chain.add(symbol: fiveSymbol)
        for c in 0 ..< numColumns {
            for r in 0 ..< numRows {
                if let sym = symbols[c, r], sym != fiveSymbol,
                   sym.type.isMatchableTo(targetType) {
                    chain.add(symbol: sym)
                }
            }
        }
        chain.score = 200 * chain.symbols.count
        removeSymbols(in: [chain])
        return [chain]
    }

    private func activateLightningEffect(for swap: Swap) -> Set<Chain> {
        let ls = swap.symbolA.type == .lightning ? swap.symbolA : swap.symbolB
        var chains = Set<Chain>()

        let rowChain = Chain(chainType: .lightning)
        for c in 0 ..< numColumns {
            if let sym = symbols[c, ls.row] { rowChain.add(symbol: sym) }
        }

        let colChain = Chain(chainType: .lightning)
        for r in 0 ..< numRows {
            if let sym = symbols[ls.column, r], sym.row != ls.row {
                colChain.add(symbol: sym)
            }
        }

        if !rowChain.symbols.isEmpty { chains.insert(rowChain) }
        if !colChain.symbols.isEmpty { chains.insert(colChain) }

        for chain in chains { chain.score = 150 * chain.symbols.count }
        removeSymbols(in: chains)
        return chains
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

        let (lShapeChains, consumed) = detectLShapeMatches(
            horizontal: horizontalChains,
            vertical: verticalChains
        )

        let matchChains = horizontalChains
            .union(verticalChains)
            .subtracting(consumed)
            .union(lShapeChains)

        removeSymbols(in: matchChains)
        calculateScores(for: matchChains)
        return matchChains
    }

    // Finds pairs of exactly-3 horizontal + vertical chains that share one symbol.
    // Returns merged lShape chains (5 unique symbols, intersection first) and the consumed h/v chains.
    private func detectLShapeMatches(
        horizontal: Set<Chain>,
        vertical: Set<Chain>
    ) -> (lShapes: Set<Chain>, consumed: Set<Chain>) {
        var lShapes = Set<Chain>()
        var consumed = Set<Chain>()

        let h3 = horizontal.filter { $0.chainType == .horizontal3 }
        let v3 = vertical.filter   { $0.chainType == .vertical3   }

        for hChain in h3 {
            for vChain in v3 {
                guard !consumed.contains(hChain), !consumed.contains(vChain) else { continue }
                let hSet = Set(hChain.symbols)
                let vSet = Set(vChain.symbols)
                let shared = hSet.intersection(vSet)
                guard shared.count == 1, let pivot = shared.first else { continue }

                let lChain = Chain(chainType: .lShape)
                lChain.add(symbol: pivot)
                hChain.symbols.filter { $0 != pivot }.forEach { lChain.add(symbol: $0) }
                vChain.symbols.filter { $0 != pivot }.forEach { lChain.add(symbol: $0) }

                lShapes.insert(lChain)
                consumed.insert(hChain)
                consumed.insert(vChain)
            }
        }
        return (lShapes, consumed)
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
        var heavyLockPositionsToDowngrade = Set<[Int]>()

        for column in 0 ..< numColumns {
            for row in 0 ..< numRows {
                guard let symbol = symbols[column, row] else { continue }
                guard symbol.type == .lock || symbol.type == .heavyLock else { continue }

                let adj = adjacentPositions(column: symbol.column, row: symbol.row)
                let hasAdjacentCleared = adj.contains {
                    let c = $0[0]; let r = $0[1]
                    return isPositionInside(column: c, row: r) && symbols[c, r] == nil
                }
                guard hasAdjacentCleared else { continue }

                if symbol.type == .lock {
                    lockPositionsToRemove.insert([column, row])
                } else {
                    heavyLockPositionsToDowngrade.insert([column, row])
                }
            }
        }

        if lockPositionsToRemove.isEmpty && heavyLockPositionsToDowngrade.isEmpty {
            return nil
        }

        let chain = Chain(chainType: .locks)

        for pos in heavyLockPositionsToDowngrade {
            let column = pos[0]; let row = pos[1]
            guard let symbol = symbols[column, row] else { continue }
            // Downgrade: replace heavyLock symbol with a regular lock symbol
            let crackedLock = Symbol(column: column, row: row, symbolType: .lock)
            crackedLock.sprite = symbol.sprite
            symbols[column, row] = crackedLock
            tiles[column, row]?.type = .lock
            // Swap sprite visual to 🔒
            if let sprite = symbol.sprite {
                if let lockTexture = SKTexture.texture(from: "🔒", fontSize: 40) {
                    sprite.run(SKAction.setTexture(lockTexture))
                }
            }
        }

        for pos in lockPositionsToRemove {
            let column = pos[0]; let row = pos[1]
            if let symbol = symbols[column, row] {
                chain.add(symbol: symbol)
                symbols[column, row] = nil
                tiles[column, row]?.type = .normal
            }
        }

        return chain.symbols.isEmpty ? nil : chain
    }

    func createSpecialSymbols(for chains: Set<Chain>) -> [Symbol] {
        var specialSymbols = [Symbol]()
        for chain in chains {
            switch chain.chainType {
            case .horizontal4, .vertical4:
                guard let first = chain.symbols.first else { continue }
                let special = Symbol(column: first.column, row: first.row,
                                     symbolType: first.type.enhancedType)
                symbols[first.column, first.row] = special
                specialSymbols.append(special)

            case .five:
                // Place universal (five) symbol at the centre of the matched row/column.
                guard chain.symbols.count >= 3 else { continue }
                let mid = chain.symbols[chain.symbols.count / 2]
                let universal = Symbol(column: mid.column, row: mid.row, symbolType: .five)
                symbols[mid.column, mid.row] = universal
                specialSymbols.append(universal)

            case .lShape:
                // First symbol in the chain is the pivot (intersection).
                guard let pivot = chain.symbols.first else { continue }
                let lightning = Symbol(column: pivot.column, row: pivot.row, symbolType: .lightning)
                symbols[pivot.column, pivot.row] = lightning
                specialSymbols.append(lightning)

            default:
                continue
            }
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
                            newSymbolType = SymbolType.randomMovableSymbolType(possibleSymbols)
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
            case .lShape:
                chain.score = 120
            case .fiveEffect:
                chain.score = 200 * chain.length
            case .lightning:
                chain.score = 150 * chain.length
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
            let normalCandidates = symbols.nonNilElements().filter { $0.type.isNormalMatchable }
            guard !normalCandidates.isEmpty, let symbolToEnhance = normalCandidates.randomElement() else {
                break
            }
            symbolToEnhance.enhance()
            enhancedSymbols.append(symbolToEnhance)
            remaining -= 1
        }
        return enhancedSymbols
    }
}
