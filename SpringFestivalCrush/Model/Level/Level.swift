import Foundation
import SpriteKit

class Level {
    let numColumns: Int
    let numRows: Int

    let maximumMoves: Int
    var possibleSymbols: [String]?
    var bgMusic: String?
    let timeLimit: Int?
    let hasSnow: Bool
    let mechanicHint: String?
    let difficulty: Int
    let armorGrid: [[Int]]?
    var boss: BossEncounter?

    var levelGoal: LevelGoal
    var noShuffle: Bool = false
    // Tracks the two tiles involved in the most recent swap so createSpecialSymbols
    // can place the new enhanced/special tile at the swapped position.
    private(set) var lastSwappedSymbols: (Symbol, Symbol)? = nil

    var possibleSwaps: Set<Swap> = []

    private var tiles: Array2D<Tile>
    private var symbols: Array2D<Symbol>
    // Ice layers to apply to freshly-spawned symbols, keyed by board position. Consumed in
    // createInitialSymbols(); only applies once, at level start (ice never re-forms later).
    private var iceGrid: Array2D<Int>

    init?(filename: String) {
        // 1
        guard let levelData = LevelData.loadFrom(file: filename) else { return nil }
        // 2
        let tilesArray = levelData.tiles

        numRows = tilesArray.count
        numColumns = tilesArray[0].count

        tiles = Array2D<Tile>(columns: numColumns, rows: numRows)
        symbols = Array2D<Symbol>(columns: numColumns, rows: numRows)
        iceGrid = Array2D<Int>(columns: numColumns, rows: numRows)

        maximumMoves = levelData.moves
        possibleSymbols = levelData.possibleSymbols
        timeLimit = levelData.timeLimit
        hasSnow = levelData.snow ?? false
        mechanicHint = levelData.mechanicHint
        difficulty = levelData.difficulty ?? 1
        armorGrid = levelData.armor
        boss = levelData.boss.map(BossEncounter.init)
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

        // Jelly is authored as a grid in the same JSON row order as `tiles`; total layers
        // placed becomes the win-condition count so authors don't have to keep two numbers
        // in sync.
        var totalJelly = 0
        if let jellyArray = levelData.jelly {
            for (row, rowArray) in jellyArray.enumerated() {
                let tileRow = numRows - row - 1
                for (column, value) in rowArray.enumerated() where value > 0 {
                    tiles[column, tileRow]?.jellyCount = value
                    totalJelly += value
                }
            }
        }
        levelGoal.levelTarget.jelly = totalJelly > 0 ? totalJelly : nil

        // Ice grid uses the same row order as `tiles`; applied to freshly-spawned symbols
        // in createInitialSymbols().
        if let iceArray = levelData.ice {
            for (row, rowArray) in iceArray.enumerated() {
                let tileRow = numRows - row - 1
                for (column, value) in rowArray.enumerated() where value > 0 {
                    iceGrid[column, tileRow] = value
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
        } while possibleSwaps.count == 0 || hasAnyExistingMatch()
        return set
    }

    /// Rearrange the live board, never recreate it from the authored level layout.
    /// Fixed blockers, ice, ingredients, specials, and objective progress are preserved.
    /// A bounded search avoids hanging on constrained boards; failure restores the board.
    func reshuffleExistingSymbols() -> Set<Symbol>? {
        guard !noShuffle else { return nil }
        var all: [Symbol] = []
        for row in 0..<numRows {
            for column in 0..<numColumns {
                if let symbol = symbols[column, row] { all.append(symbol) }
            }
        }
        let movable = all.filter { $0.isMovable() && !$0.isFrozen && $0.type != .ingredient }
        guard movable.count > 1 else { return nil }
        let positions = movable.map { (column: $0.column, row: $0.row) }
        for _ in 0..<200 {
            for (symbol, position) in zip(movable.shuffled(), positions) {
                symbol.column = position.column
                symbol.row = position.row
                symbols[position.column, position.row] = symbol
            }
            // With few colors a random permutation almost always lines up three, so repair
            // the permutation instead of relying on 200 lucky draws.
            guard repairExistingMatches(using: movable) else { continue }
            detectPossibleSwaps()
            if !possibleSwaps.isEmpty && !hasAnyExistingMatch() {
                lastSwappedSymbols = nil
                return Set(all)
            }
        }
        for (symbol, position) in zip(movable, positions) {
            symbol.column = position.column
            symbol.row = position.row
            symbols[position.column, position.row] = symbol
        }
        detectPossibleSwaps()
        return nil
    }

    // A freshly dealt board should never already contain a match — real match-3 games always
    // reshuffle until the initial deal is match-free, so tiles never evaporate with no player
    // action. This also closes a real risk for fixed Enhanced tiles specifically: Enhanced is
    // matchable (isMatchableTo treats it as equivalent to its base candy type), so a coincidental
    // pair of same-type random neighbors lining up with it would otherwise auto-explode it
    // before the player ever gets to see or trigger it deliberately.
    private func hasAnyExistingMatch() -> Bool {
        !detectHorizontalMatches().isEmpty || !detectVerticalMatches().isEmpty
    }

    /// Breaks every existing match by swapping a matched piece with a differently colored
    /// movable piece, accepting a swap only when neither cell is left in a match.
    private func repairExistingMatches(using movable: [Symbol]) -> Bool {
        for _ in 0..<(movable.count * 4) {
            let chains = detectHorizontalMatches().union(detectVerticalMatches())
            guard let chain = chains.first else { return true }
            let offender = chain.symbols[chain.symbols.count / 2]
            var repaired = false
            for partner in movable.shuffled() where !partner.type.isMatchableTo(offender.type) {
                exchangePositions(offender, partner)
                if !isPartOfMatch(atColumn: offender.column, row: offender.row),
                   !isPartOfMatch(atColumn: partner.column, row: partner.row) {
                    repaired = true
                    break
                }
                exchangePositions(offender, partner)
            }
            if !repaired { return false }
        }
        return !hasAnyExistingMatch()
    }

    private func exchangePositions(_ first: Symbol, _ second: Symbol) {
        let (column, row) = (first.column, first.row)
        first.column = second.column
        first.row = second.row
        second.column = column
        second.row = row
        symbols[first.column, first.row] = first
        symbols[second.column, second.row] = second
    }

    private func isPartOfMatch(atColumn column: Int, row: Int) -> Bool {
        guard let symbol = symbols[column, row], symbol.isMatchable() else { return false }
        func matches(_ column: Int, _ row: Int) -> Bool {
            guard isPositionInside(column: column, row: row), let other = symbols[column, row] else { return false }
            return other.isMatchable() && other.type.isMatchableTo(symbol.type)
        }
        var horizontal = 1
        var step = column - 1
        while matches(step, row) { horizontal += 1; step -= 1 }
        step = column + 1
        while matches(step, row) { horizontal += 1; step += 1 }
        var vertical = 1
        step = row - 1
        while matches(column, step) { vertical += 1; step -= 1 }
        step = row + 1
        while matches(column, step) { vertical += 1; step += 1 }
        return horizontal >= 3 || vertical >= 3
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
                var isPlainRandomTile = false
                switch tileType {
                case .lock:
                    symbolType = SymbolType.lock
                case .doubleLock:
                    symbolType = SymbolType.heavyLock
                case .vaultLock:
                    symbolType = SymbolType.vaultLock
                case .chocolate:
                    symbolType = SymbolType.chocolate
                case .ingredient:
                    symbolType = SymbolType.ingredient
                case .five:
                    symbolType = .five
                case .lightning:
                    symbolType = .lightning
                case .enhanced:
                    symbolType = .firecrackerEnhanced
                default:
                    isPlainRandomTile = true
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
                // Ice only ever wraps a normal randomly-spawned symbol, never a lock/special.
                if isPlainRandomTile, let iceLayers = iceGrid[column, row], iceLayers > 0 {
                    symbol.iceLayer = iceLayers
                }
                if isPlainRandomTile, let armorGrid {
                    symbol.armorLayers = armorGrid[numRows - row - 1][column]
                }
                symbols[column, row] = symbol

                set.insert(symbol)
            }
        }
        return set
    }

    private func hasChain(atColumn column: Int, row: Int) -> Bool {
        guard let anchor = symbols[column, row], anchor.isMatchable() else { return false }
        let symbolType = anchor.type

        // Horizontal chain check
        var horizontalLength = 1

        // Left
        var i = column - 1
        while i >= 0,
              let symbol = symbols[i, row],
              symbol.isMatchable(), symbol.type.isMatchableTo(symbolType) {
            i -= 1
            horizontalLength += 1
        }

        // Right
        i = column + 1
        while i < numColumns,
              let symbol = symbols[i, row],
              symbol.isMatchable(), symbol.type.isMatchableTo(symbolType) {
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
              symbol.isMatchable(), symbol.type.isMatchableTo(symbolType) {
            i -= 1
            verticalLength += 1
        }

        // Up
        i = row + 1
        while i < numRows,
              let symbol = symbols[column, i],
              symbol.isMatchable(), symbol.type.isMatchableTo(symbolType) {
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

        lastSwappedSymbols = (swap.symbolA, swap.symbolB)
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
        guard swap.symbolA.isMovable(), swap.symbolB.isMovable(),
              abs(swap.symbolA.column - swap.symbolB.column) + abs(swap.symbolA.row - swap.symbolB.row) == 1 else { return nil }
        if let combination = PowerUpCombination(swap.symbolA.type, swap.symbolB.type) {
            let chain = makeCombinationChain(combination, for: swap)
            if let type = chain.transformationType {
                for symbol in chain.transformedSymbols {
                    symbol.convertedFromType = symbol.type
                    symbol.type = type
                }
            }
            if combination == .fiveFive {
                // The rare double Five explicitly clears every protection layer.
                for symbol in chain.symbols {
                    symbol.armorLayers = 0
                    symbol.armorHitThisTurn = false
                    symbol.iceLayer = 0
                }
            }
            removeSymbols(in: [chain])
            chain.score = (combination == .fiveFive ? 300 : 240) * chain.clearedSymbols.count
            return [chain]
        }
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
        chain.sourceType = targetType
        chain.activatedSpecials = [fiveSymbol]
        chain.add(symbol: fiveSymbol)
        for c in 0 ..< numColumns {
            for r in 0 ..< numRows {
                if let sym = symbols[c, r], sym != fiveSymbol,
                   sym.type.isMatchableTo(targetType) {
                    chain.add(symbol: sym)
                }
            }
        }
        removeSymbols(in: [chain])
        chain.score = 200 * chain.clearedSymbols.count
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

        let sourceType = swap.symbolA === ls ? swap.symbolB.type : swap.symbolA.type
        for chain in chains {
            chain.sourceType = sourceType.isNormalMatchable || sourceType.isEnhanced
                ? sourceType : dominantSourceType(in: symbols.nonNilElements())
            chain.activatedSpecials = [ls]
        }
        removeSymbols(in: chains)
        for chain in chains { chain.score = 150 * chain.clearedSymbols.count }
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
                      symbol1.isMatchable(), symbol1.type.isMatchableTo(matchType),
                      let symbol2 = symbols[column + 2, row],
                      symbol2.isMatchable(), symbol2.type.isMatchableTo(matchType) else {
                    column += 1
                    continue
                }

                let chain = Chain(chainType: .horizontal3)
                var symbolsToAdd = [symbol, symbol1, symbol2]
                column += 3

                if column < numColumns,
                   let symbol3 = symbols[column, row],
                   symbol3.isMatchable(), symbol3.type.isMatchableTo(matchType) {
                    chain.chainType = .horizontal4
                    symbolsToAdd.append(symbol3)
                    column += 1
                }

                if column < numColumns,
                   let symbol4 = symbols[column, row],
                   symbol4.isMatchable(), symbol4.type.isMatchableTo(matchType) {
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
                      symbol1.isMatchable(), symbol1.type.isMatchableTo(matchType),
                      let symbol2 = symbols[column, row + 2],
                      symbol2.isMatchable(), symbol2.type.isMatchableTo(matchType) else {
                    row += 1
                    continue
                }

                let chain = Chain(chainType: .vertical3)
                var symbolsToAdd = [symbol, symbol1, symbol2]
                row += 3

                if row < numRows,
                   let symbol3 = symbols[column, row],
                   symbol3.isMatchable(), symbol3.type.isMatchableTo(matchType) {
                    chain.chainType = .vertical4
                    symbolsToAdd.append(symbol3)
                    row += 1
                }

                if row < numRows,
                   let symbol4 = symbols[column, row],
                   symbol4.isMatchable(), symbol4.type.isMatchableTo(matchType) {
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

    /// Resolve the entire connected reaction against one snapshot. A special fires once,
    /// while every newly reached piece belongs to only one scoring/removal batch.
    func explodeSpecialSymbols(for chains: Set<Chain>) -> Set<Chain> {
        let roots = chains.filter { !$0.specialsResolved }.sorted {
            let a = $0.symbols.first, b = $1.symbols.first
            return (a?.row ?? -1, a?.column ?? -1) < (b?.row ?? -1, b?.column ?? -1)
        }
        guard !roots.isEmpty else { return [] }
        roots.forEach { $0.specialsResolved = true }
        if roots.contains(where: { $0.combination == .fiveFive }) { return [] }
        let remaining = symbols.nonNilElements().sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        let removed = roots.flatMap(\.clearedSymbols)
        let universe = Array(Set(remaining + removed)).sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        var activated = Set(roots.flatMap(\.activatedSpecials).map(ObjectIdentifier.init))
        var claimed = Set(removed.map(ObjectIdentifier.init))
        var queue: [(Symbol, SymbolType)] = []
        func enqueue(_ symbol: Symbol, source: SymbolType) {
            guard symbol.type.isEnhanced || symbol.isSpecialPowerUp,
                  activated.insert(ObjectIdentifier(symbol)).inserted else { return }
            queue.append((symbol, source))
        }
        for chain in roots {
            let source = chain.sourceType
                ?? chain.symbols.first(where: { $0.type.isNormalMatchable || $0.type.isEnhanced })?.type
                ?? dominantSourceType(in: universe)
            for symbol in chain.clearedSymbols { enqueue(symbol, source: source) }
        }
        let reaction = Chain(chainType: .single)
        reaction.specialsResolved = true
        reaction.reactionDelay = roots.contains { $0.combination != nil } ? 0.52 : 0.12
        var index = 0
        while index < queue.count {
            let (source, color) = queue[index]
            index += 1
            let targets = universe.filter { target in
                if source.type == .five { return target.collectionType.isMatchableTo(color) }
                if source.type == .lightning { return target.row == source.row || target.column == source.column }
                return abs(target.row - source.row) <= 1 && abs(target.column - source.column) <= 1
            }
            reaction.detonations.append(PowerUpDetonation(symbol: source, type: source.type,
                                                         sourceType: color, targets: targets))
            for target in targets {
                guard claimed.insert(ObjectIdentifier(target)).inserted else { continue }
                reaction.add(symbol: target)
                // A protected tile absorbs this hit, so its power does not fire yet.
                if target.armorLayers == 0 && !target.armorHitThisTurn { enqueue(target, source: color) }
            }
        }
        guard !reaction.detonations.isEmpty else { return [] }
        removeSymbols(in: [reaction])
        reaction.score = reaction.clearedSymbols.reduce(0) { $0 + ($1.type.isEnhanced ? 100 : 20) }
        return [reaction]
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
            for symbol in chain.clearedSymbols {
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
        var resisted = Set<ObjectIdentifier>()
        for symbol in Set(chains.flatMap(\.symbols)) {
            guard symbols[symbol.column, symbol.row] === symbol else { continue }
            if symbol.armorLayers > 0 || symbol.armorHitThisTurn {
                if !symbol.armorHitThisTurn { symbol.armorLayers = max(0, symbol.armorLayers - 1) }
                symbol.armorHitThisTurn = true
                resisted.insert(ObjectIdentifier(symbol))
            } else {
                symbols[symbol.column, symbol.row] = nil
            }
        }
        for chain in chains {
            chain.resistedSymbols.formUnion(resisted)
        }
    }

    func finishArmorTurn() {
        for symbol in symbols.nonNilElements() { symbol.armorHitThisTurn = false }
    }

    /// Boss hazards never replace goals, gifts, specials or existing protected tiles.
    /// Limit protected pieces to keep a usable board, even after a long battle.
    func advanceBossTurn() {
        guard var encounter = boss, encounter.health > 0 else { return }
        let attacks = encounter.advanceTurn()
        boss = encounter
        guard attacks else { return }
        let all = symbols.nonNilElements()
        let budget = max(0, 12 - all.filter { $0.isFrozen || $0.armorLayers > 0 }.count)
        let candidates = all.filter {
            $0.type.isNormalMatchable && !$0.isFrozen && $0.armorLayers == 0
        }.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
        let targets: [Symbol]
        switch encounter.configuration.kind {
        case .rat:
            targets = candidates.filter { $0.type == .redPocket || $0.type == .dumpling }
        case .ox:
            targets = candidates.sorted {
                let lane = encounter.attackLane % numColumns
                return abs($0.column - lane) < abs($1.column - lane)
            }
        case .tiger:
            targets = candidates.filter { $0.row == encounter.attackLane % numRows }
        }
        for target in targets.prefix(min(budget, encounter.configuration.kind == .ox ? 3 : 2)) {
            if encounter.configuration.kind == .tiger { target.iceLayer = 1 }
            else { target.armorLayers = 1 }
        }
    }

    // Booster: instantly clears a single tile without requiring a match, at no move cost.
    func useHammer(atColumn column: Int, row: Int) -> Chain? {
        guard isPositionInside(column: column, row: row),
              let symbol = symbols[column, row] else { return nil }
        let chain = Chain(chainType: .single)
        chain.add(symbol: symbol)
        removeSymbols(in: [chain])
        calculateScores(for: [chain])
        return chain
    }

    // Handles every "adjacent-cleared" blocker: vaultLock -> heavyLock -> lock -> cleared,
    // and chocolate -> cleared (single hit). Also decrements ice one layer per adjacent clear
    // on any frozen symbol, blocker or not, in the same pass (same trigger, same timing —
    // this runs before fillHoles/topUp, so "adjacent cell is nil" genuinely means "just cleared").
    func resolveBlockers() -> Chain? {
        struct Downgrade {
            let column: Int
            let row: Int
            let newType: SymbolType
            let newTileType: Tile.TileType
        }

        var toDowngrade: [Downgrade] = []
        var toClear = Set<[Int]>()

        for column in 0 ..< numColumns {
            for row in 0 ..< numRows {
                guard let symbol = symbols[column, row] else { continue }
                let isBlocker = symbol.type == .lock || symbol.type == .heavyLock
                    || symbol.type == .vaultLock || symbol.type == .chocolate
                guard isBlocker else { continue }

                let adj = adjacentPositions(column: column, row: row)
                let hasAdjacentCleared = adj.contains {
                    let c = $0[0]; let r = $0[1]
                    return isPositionInside(column: c, row: r) && tiles[c, r] != nil && symbols[c, r] == nil
                }
                guard hasAdjacentCleared else { continue }

                switch symbol.type {
                case .vaultLock:
                    toDowngrade.append(Downgrade(column: column, row: row, newType: .heavyLock, newTileType: .doubleLock))
                case .heavyLock:
                    toDowngrade.append(Downgrade(column: column, row: row, newType: .lock, newTileType: .lock))
                case .lock, .chocolate:
                    toClear.insert([column, row])
                default:
                    break
                }
            }
        }

        // Ice: decrement independently of the blocker pass above — any frozen symbol
        // (locked or a normal candy) loses one layer when a neighboring cell clears.
        for column in 0 ..< numColumns {
            for row in 0 ..< numRows {
                guard let symbol = symbols[column, row], symbol.isFrozen else { continue }
                let adj = adjacentPositions(column: column, row: row)
                let hasAdjacentCleared = adj.contains {
                    let c = $0[0]; let r = $0[1]
                    return isPositionInside(column: c, row: r) && tiles[c, r] != nil && symbols[c, r] == nil
                }
                if hasAdjacentCleared {
                    symbol.iceLayer -= 1
                }
            }
        }

        guard !toDowngrade.isEmpty || !toClear.isEmpty else { return nil }

        let chain = Chain(chainType: .locks)

        for downgrade in toDowngrade {
            guard let symbol = symbols[downgrade.column, downgrade.row] else { continue }
            let downgraded = Symbol(column: downgrade.column, row: downgrade.row, symbolType: downgrade.newType)
            downgraded.sprite = symbol.sprite
            symbols[downgrade.column, downgrade.row] = downgraded
            tiles[downgrade.column, downgrade.row]?.type = downgrade.newTileType
            // Scene refresh applies the cached artwork for the new strength.
        }

        for pos in toClear {
            let column = pos[0]; let row = pos[1]
            if let symbol = symbols[column, row] {
                chain.add(symbol: symbol)
                symbols[column, row] = nil
                tiles[column, row]?.type = .normal
            }
        }

        return chain.symbols.isEmpty ? nil : chain
    }

    // Called once per player move (after the board settles). Chocolate spreads to a random
    // adjacent matchable candy, converting it in place. Returns the converted symbol (if any)
    // so the caller can swap its sprite texture.
    func spreadChocolateIfNeeded() -> Symbol? {
        let chocolateSymbols = symbols.nonNilElements().filter { $0.type == .chocolate }
        guard !chocolateSymbols.isEmpty else { return nil }
        for chocolate in chocolateSymbols.shuffled() {
            let candidates = adjacentPositions(column: chocolate.column, row: chocolate.row)
                .filter { isPositionInside(column: $0[0], row: $0[1]) }
                .compactMap { pos -> Symbol? in
                    guard let sym = symbols[pos[0], pos[1]], sym.type.isNormalMatchable, !sym.isFrozen, sym.armorLayers == 0 else { return nil }
                    return sym
                }
            if let target = candidates.randomElement() {
                target.type = .chocolate
                return target
            }
        }
        return nil
    }

    // Called after every fillHoles() pass. Any ingredient symbol that has settled at the
    // bottom row is considered delivered — removed from the board (the next topUpSymbols
    // pass refills the hole) and reported so the caller can update the escort target/score.
    func collectIngredientsAtBottom() -> [Symbol] {
        var collected: [Symbol] = []
        for column in 0 ..< numColumns {
            guard let symbol = symbols[column, 0], symbol.type == .ingredient else { continue }
            collected.append(symbol)
            symbols[column, 0] = nil
        }
        if let ingredient = levelGoal.levelTarget.ingredient {
            levelGoal.levelTarget.ingredient = max(0, ingredient - collected.count)
        }
        return collected
    }

    func createSpecialSymbols(for chains: Set<Chain>) -> [Symbol] {
        var specialSymbols = [Symbol]()
        for chain in chains {
            guard !chain.clearedSymbols.isEmpty else { continue }
            switch chain.chainType {
            case .horizontal4, .vertical4:
                guard let first = chain.clearedSymbols.first else { continue }
                // Prefer the position of whichever swapped symbol landed in this chain.
                let anchor: Symbol
                if let (a, b) = lastSwappedSymbols,
                   let swapped = chain.clearedSymbols.first(where: { $0 == a || $0 == b }) {
                    anchor = swapped
                } else {
                    anchor = first
                }
                let special = Symbol(column: anchor.column, row: anchor.row,
                                     symbolType: anchor.type.enhancedType)
                symbols[anchor.column, anchor.row] = special
                specialSymbols.append(special)

            case .five:
                // Place universal (five) symbol at the centre of the matched row/column.
                guard chain.symbols.count >= 3 else { continue }
                let mid = chain.clearedSymbols[chain.clearedSymbols.count / 2]
                let universal = Symbol(column: mid.column, row: mid.row, symbolType: .five)
                symbols[mid.column, mid.row] = universal
                specialSymbols.append(universal)

            case .lShape:
                // First symbol in the chain is the pivot (intersection).
                guard let pivot = chain.clearedSymbols.first else { continue }
                let lightning = Symbol(column: pivot.column, row: pivot.row, symbolType: .lightning)
                symbols[pivot.column, pivot.row] = lightning
                specialSymbols.append(lightning)

            default:
                continue
            }
        }
        return specialSymbols
    }

    // Fills every hole by straight-down gravity where possible. When a hole's own column is
    // blocked directly above by a genuine obstacle, a candy from the cell diagonally above
    // (one row up, one column left or right) slides in — the Candy Crush rule. Crucially the
    // donor is always strictly ABOVE the hole, never on the same row: every move lowers the
    // moving candy, which is both the physically-correct look and the termination guarantee.
    // (The previous same-row sideways pull could oscillate forever when two adjacent cells
    // were BOTH blocked from above — each stole the same candy back from the other, hanging
    // the game. A strictly-downward move can never revisit a state.)
    func fillHoles() -> [[Symbol]] {
        // True only when the first non-empty cell directly above is a genuine obstacle —
        // distinguishes "blocked, allow a diagonal slide" from "just not filled yet,
        // topUpSymbols will backfill it from the top."
        func isBlockedAbove(column: Int, row: Int) -> Bool {
            for lookup in (row + 1) ..< numRows {
                guard let symbol = symbols[column, lookup] else { continue }
                return !symbol.isMovable()
            }
            return false
        }

        // Symbols can move more than once across passes (down, then diagonally, then down
        // again...), so track each by identity and keep only its final resting position —
        // Symbol's Hashable/Equatable are position-based, which would break a Set/Dictionary
        // keyed on the symbol itself once it moves, so ObjectIdentifier is used instead.
        var movedOrder: [Symbol] = []
        var movedIds: Set<ObjectIdentifier> = []
        func move(_ symbol: Symbol, toColumn column: Int, row: Int) {
            symbols[symbol.column, symbol.row] = nil
            symbols[column, row] = symbol
            symbol.column = column
            symbol.row = row
            let id = ObjectIdentifier(symbol)
            if movedIds.insert(id).inserted {
                movedOrder.append(symbol)
            }
        }

        var madeProgress = true
        while madeProgress {
            madeProgress = false

            // Phase 1 — straight-down settle in every column, stopping at any obstacle
            // (never passing through it).
            for column in 0 ..< numColumns {
                for row in 0 ..< numRows {
                    guard tiles[column, row] != nil, symbols[column, row] == nil else { continue }
                    for lookup in (row + 1) ..< numRows {
                        guard let candidate = symbols[column, lookup] else { continue }
                        guard candidate.isMovable() else { break } // obstacle — phase 2 handles this hole
                        move(candidate, toColumn: column, row: row)
                        madeProgress = true
                        break
                    }
                }
            }

            // Phase 2 — a hole still empty specifically because it's blocked directly above
            // takes the candy diagonally above it (top-left first, then top-right). The
            // donor's old cell becomes a new hole that phase 1 resettles vertically on the
            // next loop iteration, so the flow cascades naturally — and if the diagonal cells
            // are empty too, this hole simply waits until their own columns refill them.
            for row in 0 ..< numRows {
                for column in 0 ..< numColumns {
                    guard tiles[column, row] != nil, symbols[column, row] == nil else { continue }
                    guard row + 1 < numRows, isBlockedAbove(column: column, row: row) else { continue }

                    if column > 0, let topLeft = symbols[column - 1, row + 1], topLeft.isMovable() {
                        move(topLeft, toColumn: column, row: row)
                        madeProgress = true
                    } else if column < numColumns - 1, let topRight = symbols[column + 1, row + 1], topRight.isMovable() {
                        move(topRight, toColumn: column, row: row)
                        madeProgress = true
                    }
                }
            }
        }

        var columns: [Int: [Symbol]] = [:]
        for symbol in movedOrder {
            columns[symbol.column, default: []].append(symbol)
        }
        return columns.keys.sorted().compactMap { columns[$0] }
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
            case .combination:
                chain.score = (chain.combination == .fiveFive ? 300 : 240) * chain.length
            }
            if !chain.symbols.isEmpty {
                chain.score = chain.score * chain.clearedSymbols.count / chain.symbols.count
            }
        }
    }

    func doesReachLevelTarget() -> Bool {
        (boss?.health ?? 0) <= 0
            && levelGoal.levelTarget.firecracker ?? 0 <= 0
            && levelGoal.levelTarget.redPocket ?? 0 <= 0
            && levelGoal.levelTarget.dumpling ?? 0 <= 0
            && levelGoal.levelTarget.bowl ?? 0 <= 0
            && levelGoal.levelTarget.lantern ?? 0 <= 0
            && levelGoal.levelTarget.zodiac ?? 0 <= 0
            && levelGoal.levelTarget.lock ?? 0 <= 0
            && levelGoal.levelTarget.jelly ?? 0 <= 0
            && levelGoal.levelTarget.ingredient ?? 0 <= 0
            && levelGoal.levelTarget.lightningCombos ?? 0 <= 0
            && levelGoal.levelTarget.fiveCombos ?? 0 <= 0
            && levelGoal.levelTarget.enhancedCombos ?? 0 <= 0
    }

    func updateLevelTarget(by chains: Set<Chain>) {
        let allSymbols = allSymbolsFor(for: chains)
        for symbol in allSymbols {
            switch symbol.collectionType {
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
            case .lock, .heavyLock, .vaultLock:
                if let lock = levelGoal.levelTarget.lock {
                    levelGoal.levelTarget.lock = lock - 1
                }
            case .ingredient:
                if let count = levelGoal.levelTarget.ingredient {
                    levelGoal.levelTarget.ingredient = max(0, count - 1)
                }
            default: continue
            }
        }

        // Jelly is positional, not symbol-typed: any cell that had jelly and got cleared
        // this batch loses one layer, regardless of what was cleared there.
        if levelGoal.levelTarget.jelly != nil {
            let fullClear = chains.contains { $0.combination == .fiveFive }
            var jellyCleared = 0
            for symbol in allSymbols {
                if let tile = tiles[symbol.column, symbol.row], tile.jellyCount > 0 {
                    let layers = fullClear ? tile.jellyCount : 1
                    tile.jellyCount -= layers
                    jellyCleared += layers
                }
            }
            if jellyCleared > 0, let jelly = levelGoal.levelTarget.jelly {
                levelGoal.levelTarget.jelly = max(0, jelly - jellyCleared)
            }
        }

        // Credit activations once even when one Lightning is represented by two lanes.
        var creditedDirect = Set<ObjectIdentifier>()
        for chain in chains {
            // Converted pieces and recursively hit powers each represent a real activation.
            // The initiating pair is credited separately below.
            let converted = chain.transformedSymbols.filter { symbol in
                !chain.combinationSources.contains { $0 === symbol }
            }
            let extraTypes = converted.map(\.type) + chain.detonations.map(\.type)
            if let count = levelGoal.levelTarget.enhancedCombos {
                levelGoal.levelTarget.enhancedCombos = max(0, count - extraTypes.filter(\.isEnhanced).count)
            }
            if let count = levelGoal.levelTarget.lightningCombos {
                levelGoal.levelTarget.lightningCombos = max(0, count - extraTypes.filter { $0 == .lightning }.count)
            }
            if let count = levelGoal.levelTarget.fiveCombos {
                levelGoal.levelTarget.fiveCombos = max(0, count - extraTypes.filter { $0 == .five }.count)
            }
            if let combination = chain.combination {
                if let count = levelGoal.levelTarget.fiveCombos {
                    levelGoal.levelTarget.fiveCombos = max(0, count - combination.fiveCount)
                }
                if let count = levelGoal.levelTarget.lightningCombos {
                    levelGoal.levelTarget.lightningCombos = max(0, count - combination.lightningCount)
                }
                if let count = levelGoal.levelTarget.enhancedCombos {
                    levelGoal.levelTarget.enhancedCombos = max(0, count - combination.enhancedCount)
                }
                continue
            }
            if !chain.activatedSpecials.isEmpty {
                let fresh = chain.activatedSpecials.filter { creditedDirect.insert(ObjectIdentifier($0)).inserted }
                if fresh.isEmpty { continue }
            }
            switch chain.chainType {
            case .lightning:
                if let count = levelGoal.levelTarget.lightningCombos {
                    levelGoal.levelTarget.lightningCombos = max(0, count - 1)
                }
            case .fiveEffect:
                if let count = levelGoal.levelTarget.fiveCombos {
                    levelGoal.levelTarget.fiveCombos = max(0, count - 1)
                }
            default:
                break
            }
        }
    }

    func enhanceSymbols(num: Int) -> [Symbol] {
        var enhancedSymbols = [Symbol]()
        var remaining = num
        while remaining > 0 {
            let normalCandidates = symbols.nonNilElements().filter {
                $0.type.isNormalMatchable && $0.armorLayers == 0 && !$0.armorHitThisTurn && !$0.isFrozen
            }
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
