import GameplayKit
import SpriteKit
import SwiftUI

class GameScene: SKScene {
    // MARK: - Dependencies
    let gameModel: GameModel
    let themeModel: ThemeModel
    let settingModel: SettingModel

    // MARK: - Layers
    let gameLayer = SKNode()
    let tilesLayer = SKNode()
    let maskLayer = SKNode()
    let cropLayer = SKCropNode()
    let symbolsLayer = SKNode()

    // MARK: - State
    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    private var selectionSprite = SKSpriteNode()
    private var tutorialHintNodes: [SKNode] = []

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder) is not used in this app")
    }

    init(
        size: CGSize,
        gameModel: GameModel,
        themeModel: ThemeModel,
        settingModel: SettingModel
    ) {
        self.gameModel = gameModel
        self.themeModel = themeModel
        self.settingModel = settingModel

        super.init(size: size)

        self.gameModel.screenSize = size

        setupScene()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupScene() {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let background = SKSpriteNode(imageNamed: gameModel.gameBackground)
        background.size = size
        background.aspectFillToSize(fillSize: size)
        addChild(background)

        addChild(gameLayer)
        gameLayer.isHidden = true
        cropLayer.maskNode = maskLayer
        gameLayer.addChild(tilesLayer)
        gameLayer.addChild(cropLayer)
        cropLayer.addChild(symbolsLayer)

        _ = SKLabelNode(fontNamed: "GillSans-BoldItalic")
    }
    
    private func setupBindings() {
        gameModel.invokeCommand = { [weak self] command in
            guard let self else { return }
            executeCommand(command)
        }

        gameModel.invokeCommandAsync = { [weak self] command in
            guard let self else { return }
            await executeCommandAsync(command)
        }
        Task { @MainActor in
            await gameModel.setupNewGame()
        }
    }

    private func executeCommand(_ command: GameModel.Command) {
        switch command {
        case .setupLayers:
            setupLayerPosition()
        case .setupTiles:
            removeAllTiles()
            addTiles()
        case let .setUserInteraction(shouldEnable):
            setUserInteraction(enabled: shouldEnable)
        case let .showTutorialHint(swap):
            showTutorialHint(for: swap)
        case .hideTutorialHint:
            hideTutorialHint()
        }
    }

    private func executeCommandAsync(_ command: GameModel.CommandAsync) async {
        switch command {
        case let .setupSymbols(newSprites):
            removeAllSymbols()
            await addSymbols(for: newSprites, shouldAnimate: false)
        case let .onValidSwap(swap):
            await animateSwap(swap)
        case let .onInvalidSwap(swap):
            await animateInvalidSwap(swap)
        case let .onMatchedSymbols(chains):
            await animateMatchedSymbols(for: chains)
        case let .onCreatingSpecialSymbols(symbols):
            await animateCreatingSpecialSymbols(for: symbols)
        case let .onFallingSymbols(symbols):
            await animateFallingSymbols(in: symbols)
        case let .onNewSprites(symbols):
            await animateNewSymbols(in: symbols)
        case let .onEnhanceSymbols(symbols):
            await animateEnhancedSymbols(for: symbols)
        case .onGameBegin:
            setupBgMusic()
            await animateBeginGame()
        case .onGameOver:
            await animateGameOver()
        case let .shuffle(newSprites):
            await shuffle(by: newSprites)
        }
    }

    func setupBgMusic() {
        if let bgMusic = gameModel.level.bgMusic {
            Task {
                await BackgroundMusicManager.shared.playBackgroundMusic(filename: bgMusic, repeatForever: true)
            }
        }
    }

    func setupLayerPosition() {
        let layerPosition = CGPoint(
            x: -gameModel.tileSize.width * CGFloat(gameModel.numColumns) / 2,
            y: -gameModel.tileSize.height * CGFloat(gameModel.numRows) / 2)
        tilesLayer.position = layerPosition
        maskLayer.position = layerPosition
        symbolsLayer.position = layerPosition
    }

    func shuffle(by newSymbols: Set<Symbol>) async {
        removeAllSymbols()
        await addSymbols(for: newSymbols)
    }

    func addTiles() {
        for row in 0 ..< gameModel.numRows {
            for column in 0 ..< gameModel.numColumns {
                if gameModel.level.tileAt(column: column, row: row) != nil {
                    let tileNode = SKSpriteNode(imageNamed: "MaskTile")
                    tileNode.size = gameModel.tileSize
                    tileNode.position = pointFor(column: column, row: row)
                    maskLayer.addChild(tileNode)
                }
            }
        }

        for row in 0 ... gameModel.numRows {
            for column in 0 ... gameModel.numColumns {
                let topLeft = (column > 0) && (row < gameModel.numRows)
                    && gameModel.level.tileAt(column: column - 1, row: row) != nil
                let bottomLeft = (column > 0) && (row > 0)
                    && gameModel.level.tileAt(column: column - 1, row: row - 1) != nil
                let topRight = (column < gameModel.numColumns) && (row < gameModel.numRows)
                    && gameModel.level.tileAt(column: column, row: row) != nil
                let bottomRight = (column < gameModel.numColumns) && (row > 0)
                    && gameModel.level.tileAt(column: column, row: row - 1) != nil

                var value = (topLeft ? 1 : 0)
                value = value | (topRight ? 1 : 0) << 1
                value = value | (bottomLeft ? 1 : 0) << 2
                value = value | (bottomRight ? 1 : 0) << 3

                // Values 0 (no tiles), 6 and 9 (two opposite tiles) are not drawn.
                if value != 0 && value != 6 && value != 9 {
                    let name = String(format: "Tile_%ld", value)
                    let tileNode = SKSpriteNode(imageNamed: name)
                    tileNode.size = gameModel.tileSize
                    var point = pointFor(column: column, row: row)
                    point.x -= gameModel.tileSize.width / 2
                    point.y -= gameModel.tileSize.height / 2
                    tileNode.position = point
                    tilesLayer.addChild(tileNode)
                }
            }
        }
    }

    func addSymbols(for symbols: Set<Symbol>, shouldAnimate: Bool = true) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in symbols {
                taskGroup.addTask {
                    await self.createSpriteForSymbol(symbol, shouldAnimate: shouldAnimate)
                }
            }
        }
    }

    private func createSpriteForSymbol(_ symbol: Symbol, shouldAnimate: Bool = true) async {
        let sprite = symbol.createSpriteNode(zodiac: gameModel.zodiac)
        sprite.size = gameModel.tileSize
        sprite.position = pointFor(column: symbol.column, row: symbol.row)
        symbolsLayer.addChild(sprite)
        symbol.sprite = sprite

        guard shouldAnimate else { return }

        // Give each symbol sprite a small, random delay. Then fade them in.
        sprite.alpha = 0
        sprite.xScale = 0.5
        sprite.yScale = 0.5

        await sprite.run(
            SKAction.sequence([
                SKAction.group([
                    SKAction.fadeIn(withDuration: 0.2),
                    SKAction.scale(to: 1.0, duration: 0.2),
                ]),
            ]))
    }

    private func pointFor(column: Int, row: Int) -> CGPoint {
        let tileWidth = gameModel.tileSize.width
        let tileHeight = gameModel.tileSize.height
        return CGPoint(
            x: CGFloat(column) * tileWidth + tileWidth / 2,
            y: CGFloat(row) * tileHeight + tileHeight / 2)
    }

    private func convertPoint(_ point: CGPoint) -> (success: Bool, column: Int, row: Int) {
        let tileWidth = gameModel.tileSize.width
        let tileHeight = gameModel.tileSize.height
        if point.x >= 0 && point.x < CGFloat(gameModel.numColumns) * tileWidth &&
            point.y >= 0 && point.y < CGFloat(gameModel.numRows) * tileHeight {
            return (true, Int(point.x / tileWidth), Int(point.y / tileHeight))
        } else {
            return (false, 0, 0) // invalid location
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: symbolsLayer)

        let (success, column, row) = convertPoint(location)

        if success {
            if gameModel.hammerModeActive {
                Task { @MainActor in
                    await gameModel.useHammer(atColumn: column, row: row)
                }
                return
            }
            if let symbol = gameModel.level.symbol(atColumn: column, row: row),
               symbol.isMovable() {
                swipeFromColumn = column
                swipeFromRow = row
                showSelectionIndicator(of: symbol)
                HapticManager.tileSelected()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1
        guard swipeFromColumn != nil else { return }

        // 2
        guard let touch = touches.first else { return }
        let location = touch.location(in: symbolsLayer)

        let (success, column, row) = convertPoint(location)
        if success {
            // 3
            var horizontalDelta = 0, verticalDelta = 0
            if column < swipeFromColumn! { // swipe left
                horizontalDelta = -1
            } else if column > swipeFromColumn! { // swipe right
                horizontalDelta = 1
            } else if row < swipeFromRow! { // swipe down
                verticalDelta = -1
            } else if row > swipeFromRow! { // swipe up
                verticalDelta = 1
            }

            // 4
            if horizontalDelta != 0 || verticalDelta != 0 {
                trySwap(horizontalDelta: horizontalDelta, verticalDelta: verticalDelta)
                hideSelectionIndicator()
                // 5
                swipeFromColumn = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if selectionSprite.parent != nil && swipeFromColumn != nil {
            hideSelectionIndicator()
        }

        swipeFromColumn = nil
        swipeFromRow = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func trySwap(horizontalDelta: Int, verticalDelta: Int) {
        // 1
        let toColumn = swipeFromColumn! + horizontalDelta
        let toRow = swipeFromRow! + verticalDelta
        // 2
        guard toColumn >= 0 && toColumn < gameModel.numColumns else { return }
        guard toRow >= 0 && toRow < gameModel.numRows else { return }
        // 3
        if let toSymbol = gameModel.level.symbol(atColumn: toColumn, row: toRow),
           toSymbol.isMovable(),
           let fromSymbol = gameModel.level.symbol(atColumn: swipeFromColumn!, row: swipeFromRow!),
           fromSymbol.isMovable() {
            // 4
            let swap = Swap(symbolA: fromSymbol, symbolB: toSymbol)
            Task { @MainActor in
                await gameModel.handleSwipe(swap)
            }
        }
    }

    func animateSwap(_ swap: Swap) async {
        let spriteA = swap.symbolA.sprite!
        let spriteB = swap.symbolB.sprite!

        spriteA.zPosition = 100
        spriteB.zPosition = 90

        HapticManager.swap()

        let duration: TimeInterval = 0.3

        let moveA = SKAction.move(to: spriteB.position, duration: duration)
        moveA.timingMode = .easeOut

        let moveB = SKAction.move(to: spriteA.position, duration: duration)
        moveB.timingMode = .easeOut

        async let runMoveA: Void = spriteA.run(moveA)
        async let runMoveB: Void = spriteB.run(moveB)

        await _ = [runMoveA, runMoveB]

        landingSquash(spriteA)
        landingSquash(spriteB)

        if settingModel.playSoundEffect {
            await run(themeModel.swapSound)
        }
    }

    func animateInvalidSwap(_ swap: Swap) async {
        let spriteA = swap.symbolA.sprite!
        let spriteB = swap.symbolB.sprite!

        spriteA.zPosition = 100
        spriteB.zPosition = 90

        HapticManager.invalidSwap()

        let duration: TimeInterval = 0.2

        let moveA = SKAction.move(to: spriteB.position, duration: duration)
        moveA.timingMode = .easeOut

        let moveB = SKAction.move(to: spriteA.position, duration: duration)
        moveB.timingMode = .easeOut

        async let runMoveA: Void = spriteA.run(SKAction.sequence([moveA, moveB]))
        async let runMoveB: Void = spriteB.run(SKAction.sequence([moveB, moveA]))

        await _ = [runMoveA, runMoveB]

        if settingModel.playSoundEffect {
            await run(themeModel.invalidSwapSound)
        }
    }

    func showSelectionIndicator(of symbol: Symbol) {
        if selectionSprite.parent != nil {
            selectionSprite.removeFromParent()
        }

        if let sprite = symbol.sprite {
            if symbol.type == .zodiac || symbol.type == .zodiacEnhanced {
                selectionSprite = SKSpriteNode.highLightSprite(for: symbol, zodiac: gameModel.zodiac, size: gameModel.tileSize.width)
                selectionSprite.size = gameModel.tileSize
            } else if let emoji = symbol.type.emojiForHighlight,
                      let texture = SKTexture.texture(from: emoji, fontSize: gameModel.tileSize.width) {
                selectionSprite = SKSpriteNode(texture: texture)
                selectionSprite.size = gameModel.tileSize
                selectionSprite.color = UIColor.orange.withAlphaComponent(0.5)
                selectionSprite.colorBlendFactor = 0.6
            } else {
                selectionSprite = SKSpriteNode()
                let texture = SKTexture(imageNamed: symbol.type.highlightedSpriteName)
                selectionSprite.size = gameModel.tileSize
                selectionSprite.run(SKAction.setTexture(texture))
            }
            sprite.addChild(selectionSprite)
            selectionSprite.alpha = 1.0
        }
    }

    func hideSelectionIndicator() {
        selectionSprite.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()]))
        selectionSprite.colorBlendFactor = 0
    }

    func animateMatchedSymbols(for chains: Set<Chain>) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for chain in chains {
                animateScore(for: chain)
                triggerHaptic(for: chain)
                switch chain.chainType {
                case .fiveEffect:
                    taskGroup.addTask { await self.animateFiveChainEffect(for: chain) }
                case .lightning:
                    taskGroup.addTask { await self.animateLightningChainEffect(for: chain) }
                case .enhanced:
                    taskGroup.addTask { await self.animateEnhancedChainEffect(for: chain) }
                case .single:
                    taskGroup.addTask { await self.animateSingleExplosionEffect(for: chain) }
                default:
                    // An enhanced tile swapped into a normal match must still explode.
                    if let enhancedSymbol = chain.symbols.first(where: { $0.type.isEnhanced }),
                       let sprite = enhancedSymbol.sprite {
                        fireShockwave(at: sprite.position)
                        for symbol in chain.symbols {
                            taskGroup.addTask { await self.popExplode(symbol: symbol) }
                        }
                    } else {
                        for symbol in chain.symbols {
                            guard let sprite = symbol.sprite else { continue }
                            guard sprite.action(forKey: "removing") == nil else { continue }
                            let anticipate = SKAction.scale(to: 1.15, duration: 0.06)
                            let scaleAction = SKAction.scale(to: 0.1, duration: 0.22)
                            scaleAction.timingMode = .easeIn
                            taskGroup.addTask {
                                await sprite.run(
                                    SKAction.sequence([anticipate, scaleAction, SKAction.removeFromParent()]),
                                    withKey: "removing"
                                )
                            }
                        }
                    }
                }
            }
            if settingModel.playSoundEffect {
                taskGroup.addTask {
                    await self.run(self.themeModel.matchSound)
                }
            }
        }
    }

    /// Scales haptic intensity (and adds screen shake for the biggest moments) to the size/kind of match.
    private func triggerHaptic(for chain: Chain) {
        switch chain.chainType {
        case .fiveEffect, .enhanced:
            HapticManager.explosion()
            screenShake()
        case .lightning:
            HapticManager.bigMatch()
            screenShake(magnitude: 4, duration: 0.2)
        case .single, .locks:
            break
        default:
            if chain.length >= 4 {
                HapticManager.bigMatch()
            } else {
                HapticManager.match()
            }
        }
    }

    // Five-universal effect: glowing link lines shoot from each tile to the five, then tiles fly in.
    private func animateFiveChainEffect(for chain: Chain) async {
        guard let fiveSymbol = chain.symbols.first,
              let fiveSprite = fiveSymbol.sprite else { return }
        let center = fiveSprite.position

        // Phase 1 (fire-and-forget): draw glowing beam lines from every tile to the five center.
        for symbol in chain.symbols.dropFirst() {
            guard let sprite = symbol.sprite else { continue }
            let path = CGMutablePath()
            path.move(to: sprite.position)
            path.addLine(to: center)
            let line = SKShapeNode(path: path)
            line.strokeColor = UIColor.cyan.withAlphaComponent(0.95)
            line.lineWidth   = 2.5
            line.glowWidth   = 5
            line.zPosition   = 230
            symbolsLayer.addChild(line)
            line.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.42),
                SKAction.removeFromParent()
            ]), completion: {})
        }

        // Phase 2: each tile flashes cyan then flies toward center with staggered delay.
        await withTaskGroup(of: Void.self) { taskGroup in
            for (index, symbol) in chain.symbols.enumerated() {
                guard let sprite = symbol.sprite else { continue }
                guard sprite.action(forKey: "removing") == nil else { continue }

                if index == 0 {
                    taskGroup.addTask {
                        let flash = SKAction.group([
                            SKAction.colorize(with: .cyan, colorBlendFactor: 0.9, duration: 0.12),
                            SKAction.scale(to: 1.5, duration: 0.12)
                        ])
                        let vanish = SKAction.group([
                            SKAction.scale(to: 0.0, duration: 0.22),
                            SKAction.fadeOut(withDuration: 0.22)
                        ])
                        await sprite.run(
                            SKAction.sequence([flash, vanish, SKAction.removeFromParent()]),
                            withKey: "removing"
                        )
                    }
                } else {
                    let delay = 0.04 * TimeInterval(index)
                    taskGroup.addTask {
                        let flash  = SKAction.group([
                            SKAction.colorize(with: .cyan, colorBlendFactor: 0.7, duration: 0.08),
                            SKAction.scale(to: 1.15, duration: 0.08)
                        ])
                        let move   = SKAction.move(to: center, duration: 0.28)
                        move.timingMode = .easeIn
                        let shrink = SKAction.scale(to: 0.0, duration: 0.28)
                        let fade   = SKAction.fadeOut(withDuration: 0.22)
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                flash,
                                SKAction.group([move, shrink, fade]),
                                SKAction.removeFromParent()
                            ]),
                            withKey: "removing"
                        )
                    }
                }
            }
        }

        // Phase 3: starburst ring at the five center after all tiles arrive.
        let ring = SKShapeNode(circleOfRadius: gameModel.tileSize.width * 0.6)
        ring.fillColor   = .clear
        ring.strokeColor = UIColor.cyan.withAlphaComponent(0.95)
        ring.lineWidth   = 4
        ring.glowWidth   = 6
        ring.position    = center
        ring.zPosition   = 250
        symbolsLayer.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 3.0, duration: 0.4),
                            SKAction.fadeOut(withDuration: 0.4)]),
            SKAction.removeFromParent()
        ]), completion: {})
    }

    // Lightning effect: flash a yellow bar across the chain's row or column, then tiles vanish.
    private func animateLightningChainEffect(for chain: Chain) async {
        let sprites = chain.symbols.compactMap { $0.sprite }
        guard !sprites.isEmpty else { return }

        let positions = sprites.map { $0.position }
        let isHorizontal = Set(chain.symbols.map { $0.row }).count == 1

        if isHorizontal {
            let minX = positions.map { $0.x }.min()!
            let maxX = positions.map { $0.x }.max()!
            let midY = positions[0].y
            let barW = maxX - minX + gameModel.tileSize.width
            let bar  = SKShapeNode(rectOf: CGSize(width: barW, height: gameModel.tileSize.height * 0.85), cornerRadius: 6)
            bar.fillColor  = UIColor.yellow.withAlphaComponent(0.82)
            bar.strokeColor = .white
            bar.lineWidth   = 2
            bar.position    = CGPoint(x: (minX + maxX) / 2, y: midY)
            bar.zPosition   = 220
            symbolsLayer.addChild(bar)
            bar.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.removeFromParent()
            ]), completion: {})
        } else {
            let minY = positions.map { $0.y }.min()!
            let maxY = positions.map { $0.y }.max()!
            let midX = positions[0].x
            let barH = maxY - minY + gameModel.tileSize.height
            let bar  = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * 0.85, height: barH), cornerRadius: 6)
            bar.fillColor  = UIColor.yellow.withAlphaComponent(0.82)
            bar.strokeColor = .white
            bar.lineWidth   = 2
            bar.position    = CGPoint(x: midX, y: (minY + maxY) / 2)
            bar.zPosition   = 220
            symbolsLayer.addChild(bar)
            bar.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.removeFromParent()
            ]), completion: {})
        }

        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in chain.symbols {
                guard let sprite = symbol.sprite else { continue }
                guard sprite.action(forKey: "removing") == nil else { continue }
                taskGroup.addTask {
                    let scale = SKAction.scale(to: 0.1, duration: 0.25)
                    scale.timingMode = .easeOut
                    await sprite.run(
                        SKAction.sequence([SKAction.wait(forDuration: 0.1),
                                           scale,
                                           SKAction.removeFromParent()]),
                        withKey: "removing"
                    )
                }
            }
        }
    }

    // Enhanced explosion: large shockwave ring from the enhanced tile's center, all tiles pop.
    private func animateEnhancedChainEffect(for chain: Chain) async {
        if let sprite = chain.symbols.first?.sprite {
            fireShockwave(at: sprite.position)
        }
        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in chain.symbols {
                taskGroup.addTask { await self.popExplode(symbol: symbol) }
            }
        }
    }

    private func fireShockwave(at position: CGPoint) {
        let shockwave = SKShapeNode(circleOfRadius: gameModel.tileSize.width * 0.5)
        shockwave.fillColor   = UIColor.orange.withAlphaComponent(0.35)
        shockwave.strokeColor = UIColor.orange.withAlphaComponent(0.95)
        shockwave.lineWidth   = 4
        shockwave.glowWidth   = 6
        shockwave.position    = position
        shockwave.zPosition   = 210
        symbolsLayer.addChild(shockwave)
        shockwave.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 5.0, duration: 0.38),
                            SKAction.fadeOut(withDuration: 0.38)]),
            SKAction.removeFromParent()
        ]), completion: {})
    }

    // Tiles cleared by an enhanced explosion (single chains) also pop.
    private func animateSingleExplosionEffect(for chain: Chain) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in chain.symbols {
                taskGroup.addTask { await self.popExplode(symbol: symbol) }
            }
        }
    }

    // Shared pop-explode: white flash scale-up then collapse to zero.
    private func popExplode(symbol: Symbol) async {
        guard let sprite = symbol.sprite else { return }
        guard sprite.action(forKey: "removing") == nil else { return }
        let pop = SKAction.group([
            SKAction.scale(to: 1.3, duration: 0.1),
            SKAction.colorize(with: .white, colorBlendFactor: 0.85, duration: 0.1)
        ])
        let explode = SKAction.group([
            SKAction.scale(to: 0.0, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.2)
        ])
        await sprite.run(
            SKAction.sequence([pop, explode, SKAction.removeFromParent()]),
            withKey: "removing"
        )
    }

    func animateCreatingSpecialSymbols(for specialSymbols: [Symbol]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for specialSymbol in specialSymbols {
                taskGroup.addTask {
                    await self.createSpriteForSymbol(specialSymbol)
                }
            }
        }
    }

    func animateFallingSymbols(in columns: [[Symbol]]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for array in columns {
                for (index, symbol) in array.enumerated() {
                    let newPosition = pointFor(column: symbol.column, row: symbol.row)
                    let delay = 0.05 + 0.02 * TimeInterval(index)
                    let sprite = symbol.sprite! // sprite always exists at this point
                    let duration = TimeInterval(((sprite.position.y - newPosition.y) / gameModel.tileSize.height) * 0.1)
                    let moveAction = SKAction.move(to: newPosition, duration: duration)
                    moveAction.timingMode = .easeIn
                    taskGroup.addTask {
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                moveAction]
                            )
                        )
                        self.landingSquash(sprite)
                    }
                }
            }
            if settingModel.playSoundEffect {
                taskGroup.addTask {
                    await self.run(self.themeModel.fallingSymbolSound)
                }
            }
        }
    }

    func animateNewSymbols(in columns: [[Symbol]]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for array in columns {
                let startRow = array[0].row + 1
                for (index, symbol) in array.enumerated() {
                    let sprite = symbol.createSpriteNode(zodiac: gameModel.zodiac)
                    sprite.size = gameModel.tileSize
                    sprite.position = pointFor(column: symbol.column, row: startRow)
                    symbolsLayer.addChild(sprite)
                    symbol.sprite = sprite
                    let delay = 0.1 + 0.2 * TimeInterval(array.count - index - 1)
                    let duration = TimeInterval(startRow - symbol.row) * 0.1
                    // 6
                    let newPosition = pointFor(column: symbol.column, row: symbol.row)
                    let moveAction = SKAction.move(to: newPosition, duration: duration)
                    moveAction.timingMode = .easeIn
                    sprite.alpha = 0
                    taskGroup.addTask {
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                SKAction.group([
                                    SKAction.fadeIn(withDuration: 0.05),
                                    moveAction,
                                ]),
                            ]))
                        self.landingSquash(sprite)
                        if self.settingModel.playSoundEffect {
                            await sprite.run(self.themeModel.addSymbolSound)
                        }
                    }
                }
            }
        }
    }

    func animateEnhancedSymbols(for symbols: [Symbol]) async {
        for symbol in symbols {
            symbol.sprite?.removeFromParent()
            let sprite = symbol.createSpriteNode(zodiac: gameModel.zodiac)
            sprite.size = gameModel.tileSize
            sprite.position = pointFor(column: symbol.column, row: symbol.row)
            symbolsLayer.addChild(sprite)
            symbol.sprite = sprite

            await sprite.run(
                SKAction.sequence(
                    [
                        SKAction.group(
                            [
                                SKAction.fadeIn(withDuration: 0.2),
                            ]
                        ),
                    ]
                )
            )
            gameModel.decreaseMove()
        }
    }

    func animateScore(for chain: Chain) {
        // Figure out what the midpoint of the chain is.
        guard chain.chainType != .locks else { return }
        let firstSprite = chain.firstSymbol().sprite!
        let lastSprite = chain.lastSymbol().sprite!
        let centerPosition = CGPoint(
            x: (firstSprite.position.x + lastSprite.position.x) / 2,
            y: (firstSprite.position.y + lastSprite.position.y) / 2 - 8)

        // Bigger chains get a bigger, warmer-colored label so combos read as more rewarding.
        let isBigChain = chain.length >= 4 || chain.chainType == .enhanced || chain.chainType == .lightning || chain.chainType == .fiveEffect

        let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
        scoreLabel.fontSize = isBigChain ? 24 : 17
        scoreLabel.fontColor = isBigChain ? UIColor(hex: 0xFFB238) : .white
        scoreLabel.text = "+\(chain.score)"
        scoreLabel.position = centerPosition
        scoreLabel.zPosition = 300
        scoreLabel.setScale(0.3)
        scoreLabel.alpha = 0
        symbolsLayer.addChild(scoreLabel)

        // Pop in with a slight overshoot, hold, then float up and fade — classic combo-counter feel.
        let popIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.sequence([
                SKAction.scale(to: isBigChain ? 1.25 : 1.1, duration: 0.14),
                SKAction.scale(to: 1.0, duration: 0.08),
            ]),
        ])
        let float = SKAction.move(by: CGVector(dx: 0, dy: 30), duration: 0.6)
        float.timingMode = .easeOut
        let fadeOut = SKAction.fadeOut(withDuration: 0.35)
        scoreLabel.run(SKAction.sequence([
            popIn,
            SKAction.group([float, SKAction.sequence([SKAction.wait(forDuration: 0.25), fadeOut])]),
            SKAction.removeFromParent(),
        ]))
    }

    func animateGameOver() async {
        let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
        action.timingMode = .easeIn
        await gameLayer.run(action)
    }

    func animateBeginGame() async {
        gameLayer.isHidden = false
        gameLayer.position = CGPoint(x: 0, y: size.height)
        let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
        action.timingMode = .easeOut
        await gameLayer.run(action)
    }

    func removeAllTiles() {
        maskLayer.removeAllChildren()
        tilesLayer.removeAllChildren()
    }

    func removeAllSymbols() {
        symbolsLayer.removeAllChildren()
    }

    func setUserInteraction(enabled: Bool) {
        isUserInteractionEnabled = enabled
    }

    // MARK: - Tutorial hint

    /// Draws pulsing rings around the two hinted tiles plus a hand icon miming the swipe.
    private func showTutorialHint(for swap: Swap) {
        hideTutorialHint()
        guard let spriteA = swap.symbolA.sprite, let spriteB = swap.symbolB.sprite else { return }
        let posA = spriteA.position
        let posB = spriteB.position

        for pos in [posA, posB] {
            let ring = SKShapeNode(circleOfRadius: gameModel.tileSize.width * 0.55)
            ring.strokeColor = .white
            ring.lineWidth = 3
            ring.glowWidth = 4
            ring.fillColor = .clear
            ring.position = pos
            ring.zPosition = 400
            ring.alpha = 0.4
            symbolsLayer.addChild(ring)
            ring.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([SKAction.fadeAlpha(to: 0.9, duration: 0.5), SKAction.scale(to: 1.1, duration: 0.5)]),
                SKAction.group([SKAction.fadeAlpha(to: 0.4, duration: 0.5), SKAction.scale(to: 0.95, duration: 0.5)]),
            ])))
            tutorialHintNodes.append(ring)
        }

        let hand = SKLabelNode(text: "👆")
        hand.fontSize = gameModel.tileSize.width * 0.7
        hand.zPosition = 401
        hand.position = posA
        symbolsLayer.addChild(hand)
        let moveToB = SKAction.move(to: posB, duration: 0.6)
        moveToB.timingMode = .easeInEaseOut
        let moveToA = SKAction.move(to: posA, duration: 0.6)
        moveToA.timingMode = .easeInEaseOut
        let pause = SKAction.wait(forDuration: 0.3)
        hand.run(SKAction.repeatForever(SKAction.sequence([pause, moveToB, pause, moveToA])))
        tutorialHintNodes.append(hand)
    }

    private func hideTutorialHint() {
        for node in tutorialHintNodes {
            node.removeFromParent()
        }
        tutorialHintNodes.removeAll()
    }

    // MARK: - Juice helpers

    /// Quick squash-and-stretch settle used when a tile lands (falling, new tiles, swap arrival).
    private func landingSquash(_ sprite: SKSpriteNode) {
        let squash = SKAction.scaleX(to: 1.18, y: 0.82, duration: 0.06)
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeOut
        sprite.run(SKAction.sequence([squash, settle]), completion: {})
    }

    /// Small camera-shake for big explosions/combos — the board itself kicks.
    private func screenShake(magnitude: CGFloat = 6, duration: TimeInterval = 0.28) {
        let originalPosition = gameLayer.position
        var actions: [SKAction] = []
        let steps = 6
        for i in 0 ..< steps {
            let progress = 1.0 - CGFloat(i) / CGFloat(steps)
            let dx = CGFloat.random(in: -magnitude ... magnitude) * progress
            let dy = CGFloat.random(in: -magnitude ... magnitude) * progress
            actions.append(SKAction.move(to: CGPoint(x: originalPosition.x + dx, y: originalPosition.y + dy), duration: duration / TimeInterval(steps)))
        }
        actions.append(SKAction.move(to: originalPosition, duration: duration / TimeInterval(steps)))
        gameLayer.run(SKAction.sequence(actions), withKey: "screenShake")
    }
}
