import GameplayKit
import SpriteKit
import SwiftUI

class GameScene: SKScene {
    // MARK: - Dependencies
    let gameModel: GameModel
    let themeModel: ThemeModel
    let settingModel: SettingModel
    let feedback: GameFeedback
    var reduceMotion: Bool
    var soundVoices: [GameSound: SKAudioNode] = [:]
    var lastSoundTimes: [GameSound: TimeInterval] = [:]
    let idleHintLayer = SKNode()
    var feedbackPaused = false

    // MARK: - Layers
    let gameLayer = SKNode()
    let tilesLayer = SKNode()
    let maskLayer = SKNode()
    let cropLayer = SKCropNode()
    let symbolsLayer = SKNode()
    let effectsLayer = SKNode()
    // Jelly backing squares, behind symbolsLayer so they read as "under" the candies.
    let overlayLayer = SKNode()

    // MARK: - State
    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    private var selectionSprite = SKNode()
    private var tutorialHintNodes: [SKNode] = []
    var removingSprites = Set<ObjectIdentifier>()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder) is not used in this app")
    }

    init(
        size: CGSize,
        gameModel: GameModel,
        themeModel: ThemeModel,
        settingModel: SettingModel,
        feedback: GameFeedback,
        reduceMotion: Bool = false
    ) {
        self.gameModel = gameModel
        self.themeModel = themeModel
        self.settingModel = settingModel
        self.feedback = feedback
        self.reduceMotion = reduceMotion

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
        gameLayer.zPosition = 1
        gameLayer.isHidden = true
        cropLayer.maskNode = maskLayer
        gameLayer.addChild(tilesLayer)
        gameLayer.addChild(cropLayer)
        cropLayer.addChild(overlayLayer)
        cropLayer.addChild(symbolsLayer)
        effectsLayer.zPosition = 200
        cropLayer.addChild(effectsLayer)
        for sound in GameSound.allCases {
            let voice = SKAudioNode(fileNamed: sound.rawValue)
            voice.autoplayLooped = false
            voice.isPositional = false
            soundVoices[sound] = voice
            addChild(voice)
        }
        idleHintLayer.zPosition = 450
        gameLayer.addChild(idleHintLayer)

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
            refreshSeason()
            removeAllTiles()
            addTiles()
        case let .setUserInteraction(shouldEnable):
            setUserInteraction(enabled: shouldEnable)
        case let .showTutorialHint(swap):
            showTutorialHint(for: swap)
        case .hideTutorialHint:
            hideTutorialHint()
        case .refreshOverlays:
            refreshOverlays()
        case let .onChocolateSpread(symbol):
            animateChocolateSpread(symbol)
        case let .onGoalProgress(progress):
            animateGoalProgress(progress)
        case let .onCascade(depth):
            animateCascade(depth: depth)
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
        case let .onIngredientsCollected(symbols):
            await animateIngredientsCollected(symbols)
        case .onGameBegin:
            setupBgMusic()
            await animateBeginGame()
        case .onGameOver:
            await animateGameOver()
        case let .shuffle(newSprites):
            await shuffle(by: newSprites)
        case let .onHammerImpact(symbol):
            await animateHammerImpact(symbol)
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
        let boardHeight = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        // Boss instructions need a predictable clear area above the board, including on SE.
        let bossOffset = gameModel.level.boss == nil ? 0 : min(0, size.height / 2 - boardHeight / 2 - 280)
        let layerPosition = CGPoint(
            x: -gameModel.tileSize.width * CGFloat(gameModel.numColumns) / 2,
            y: -boardHeight / 2 + bossOffset)
        tilesLayer.position = layerPosition
        maskLayer.position = layerPosition
        symbolsLayer.position = layerPosition
        effectsLayer.position = layerPosition
        overlayLayer.position = layerPosition
    }

    func shuffle(by newSymbols: Set<Symbol>) async {
        await animateShuffle(newSymbols)
    }

    func addTiles() {
        for row in 0..<gameModel.numRows {
            for column in 0..<gameModel.numColumns where gameModel.level.tileAt(column: column, row: row) != nil {
                let mask = SKSpriteNode(color: .white, size: gameModel.tileSize)
                mask.position = pointFor(column: column, row: row)
                maskLayer.addChild(mask)
            }
        }
        let image = BoardSurface.image(columns: gameModel.numColumns, rows: gameModel.numRows,
                                       tileSize: gameModel.tileSize) { column, row in
            self.gameModel.level.tileAt(column: column, row: row) != nil
        }
        let surface = SKSpriteNode(texture: SKTexture(image: image))
        surface.name = "boardSurface"
        surface.size = image.size
        surface.position = CGPoint(x: CGFloat(gameModel.numColumns) * gameModel.tileSize.width / 2,
                                   y: CGFloat(gameModel.numRows) * gameModel.tileSize.height / 2)
        tilesLayer.addChild(surface)
    }

    func addSymbols(for symbols: Set<Symbol>, shouldAnimate: Bool = true) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in symbols {
                taskGroup.addTask { @MainActor in
                    await self.createSpriteForSymbol(symbol, shouldAnimate: shouldAnimate)
                }
            }
        }
    }

    private func createSpriteForSymbol(_ symbol: Symbol, shouldAnimate: Bool = true) async {
        let sprite = symbol.createSpriteNode(zodiac: gameModel.zodiac)
        configureAmbientMotion(sprite)
        sprite.size = gameModel.tileSize
        sprite.position = pointFor(column: symbol.column, row: symbol.row)
        symbolsLayer.addChild(sprite)
        symbol.sprite = sprite
        configurePowerAura(on: sprite, type: symbol.type)

        guard shouldAnimate else { return }
        if symbol.type.isEnhanced || symbol.type == .five || symbol.type == .lightning {
            await animateSpecialBirth(on: sprite, type: symbol.type)
            return
        }
        if reduceMotion {
            sprite.alpha = 0
            await sprite.run(.fadeIn(withDuration: 0.15))
            return
        }

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

    func pointFor(column: Int, row: Int) -> CGPoint {
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
        cancelIdleHint()
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
        scheduleIdleHint()
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

        let originalDepths = (spriteA.zPosition, spriteB.zPosition)
        defer {
            spriteA.zPosition = originalDepths.0
            spriteB.zPosition = originalDepths.1
        }

        spriteA.zPosition = 100
        spriteB.zPosition = 90

        HapticManager.swap()

        let duration: TimeInterval = reduceMotion ? 0.16 : 0.22

        let moveA = SKAction.move(to: spriteB.position, duration: duration)
        moveA.timingMode = .easeOut

        let moveB = SKAction.move(to: spriteA.position, duration: duration)
        moveB.timingMode = .easeOut

        async let runMoveA: Void = spriteA.run(moveA)
        async let runMoveB: Void = spriteB.run(moveB)

        await _ = [runMoveA, runMoveB]

        landingSquash(spriteA)
        landingSquash(spriteB)

        playSound(.swap)
    }

    func animateInvalidSwap(_ swap: Swap) async {
        let spriteA = swap.symbolA.sprite!
        let spriteB = swap.symbolB.sprite!

        let originalDepths = (spriteA.zPosition, spriteB.zPosition)
        defer {
            spriteA.zPosition = originalDepths.0
            spriteB.zPosition = originalDepths.1
        }

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

        playSound(.invalid)
    }

    func showSelectionIndicator(of symbol: Symbol) {
        selectionSprite.removeAllActions()
        selectionSprite.removeFromParent()
        guard let sprite = symbol.sprite else { return }
        let ring = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * 0.92,
                                             height: gameModel.tileSize.height * 0.92), cornerRadius: 8)
        ring.name = "tileSelection"
        ring.strokeColor = UIColor(hex: 0xFFF0B7)
        ring.fillColor = UIColor(hex: 0xFFD36C).withAlphaComponent(0.10)
        ring.lineWidth = 2.4
        ring.zPosition = 20
        selectionSprite = ring
        sprite.addChild(ring)
        // A local outline never replaces or recolors the tile's identifying artwork.
        if !reduceMotion {
            ring.setScale(0.88)
            let settle = SKAction.scale(to: 1, duration: 0.12)
            settle.timingMode = .easeOut
            ring.run(settle)
        }
    }

    func hideSelectionIndicator() {
        selectionSprite.removeAllActions()
        selectionSprite.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    func animateCreatingSpecialSymbols(for specialSymbols: [Symbol]) async {
        if !specialSymbols.isEmpty { playSound(.landing, volume: 0.6, rate: 1.2) }
        await withTaskGroup(of: Void.self) { taskGroup in
            for specialSymbol in specialSymbols {
                taskGroup.addTask { @MainActor in
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
                    let delay = reduceMotion ? 0 : 0.015 * TimeInterval(index)
                    let sprite = symbol.sprite! // sprite always exists at this point
                    let cells = abs((sprite.position.y - newPosition.y) / gameModel.tileSize.height)
                    let duration = min(0.34, 0.10 + Double(cells) * 0.035)
                    let moveAction = SKAction.move(to: newPosition, duration: duration)
                    moveAction.timingMode = .easeIn
                    let action: SKAction = reduceMotion
                        ? .sequence([.fadeAlpha(to: 0.25, duration: 0.08), .move(to: newPosition, duration: 0), .fadeIn(withDuration: 0.08)])
                        : .sequence([.wait(forDuration: delay), moveAction])
                    taskGroup.addTask { @MainActor in
                        sprite.removeAction(forKey: "landing")
                        sprite.setScale(1)
                        await sprite.run(action)
                        self.landingSquash(sprite)
                    }
                }
            }
            playSound(.falling, volume: 0.35)
        }
    }

    func animateNewSymbols(in columns: [[Symbol]]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for array in columns {
                guard let first = array.first else { continue }
                let startRow = first.row + 1
                for (index, symbol) in array.enumerated() {
                    let sprite = symbol.createSpriteNode(zodiac: gameModel.zodiac)
                    configureAmbientMotion(sprite)
                    sprite.size = gameModel.tileSize
                    sprite.position = pointFor(column: symbol.column, row: startRow)
                    symbolsLayer.addChild(sprite)
                    symbol.sprite = sprite
                    let delay = reduceMotion ? 0 : 0.025 * TimeInterval(array.count - index - 1)
                    let duration = reduceMotion ? 0.16 : min(0.34, 0.12 + Double(abs(startRow - symbol.row)) * 0.035)
                    // 6
                    let newPosition = pointFor(column: symbol.column, row: symbol.row)
                    if reduceMotion { sprite.position = newPosition }
                    let moveAction = SKAction.move(to: newPosition, duration: duration)
                    moveAction.timingMode = .easeIn
                    sprite.alpha = 0
                    taskGroup.addTask { @MainActor in
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                SKAction.group([
                                    SKAction.fadeIn(withDuration: self.reduceMotion ? 0.16 : 0.06),
                                    moveAction,
                                ]),
                            ]))
                        self.landingSquash(sprite)
                        self.playSound(.landing, volume: 0.45)
                    }
                }
            }
        }
    }

    func animateEnhancedSymbols(for symbols: [Symbol]) async {
        let level = gameModel.level
        let state = gameModel.gameState
        // A short wave, not N sequential animations on high-move victories.
        await withTaskGroup(of: Void.self) { group in
            for (index, symbol) in symbols.enumerated() {
                group.addTask { @MainActor in
                    if !self.reduceMotion { await self.run(.wait(forDuration: min(0.36, Double(index) * 0.025))) }
                    guard self.gameModel.level === level, self.gameModel.gameState == state, !Task.isCancelled else { return }
                    symbol.sprite?.removeFromParent()
                    await self.createSpriteForSymbol(symbol)
                    guard self.gameModel.level === level, self.gameModel.gameState == state, !Task.isCancelled else { return }
                    self.gameModel.decreaseMove()
                }
            }
        }
    }

    func animateBeginGame() async {
        gameLayer.removeAction(forKey: "screenShake")
        gameLayer.removeAction(forKey: "victorySettle")
        gameLayer.isHidden = false
        gameLayer.alpha = 1
        gameLayer.setScale(1)
        if reduceMotion {
            gameLayer.position = .zero
            gameLayer.alpha = 0
            await gameLayer.run(.fadeIn(withDuration: 0.15))
            return
        }
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
        effectsLayer.removeAllChildren()
    }

    func setUserInteraction(enabled: Bool) {
        isUserInteractionEnabled = enabled
        if enabled { scheduleIdleHint() }
        else { cancelIdleHint() }
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
            if !reduceMotion { ring.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([SKAction.fadeAlpha(to: 0.9, duration: 0.5), SKAction.scale(to: 1.1, duration: 0.5)]),
                SKAction.group([SKAction.fadeAlpha(to: 0.4, duration: 0.5), SKAction.scale(to: 0.95, duration: 0.5)]),
            ]))) }
            tutorialHintNodes.append(ring)
        }

        guard !reduceMotion else { return }
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

    // MARK: - Level element overlays (jelly, ice, chocolate, ingredients)

    /// Redraws jelly backing squares and ice tint for the whole board. Called after any batch
    /// of clears since either could have changed anywhere — board sizes here (<=9x9) make a
    /// full-board pass cheap enough that a more surgical diff isn't worth the complexity.
    private func refreshOverlays() {
        overlayLayer.childNode(withName: "bossThreat")?.removeFromParent()
        if let boss = gameModel.level.boss, boss.health > 0, boss.configuration.kind == .tiger {
            let marker = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * CGFloat(gameModel.numColumns), height: gameModel.tileSize.height - 2), cornerRadius: 5)
            marker.name = "bossThreat"
            marker.position = CGPoint(x: gameModel.tileSize.width * CGFloat(gameModel.numColumns) / 2,
                                      y: gameModel.tileSize.height * (CGFloat(boss.nextAttackLane % gameModel.numRows) + 0.5))
            marker.strokeColor = boss.movesUntilAttack == 1 ? .systemOrange : .cyan
            marker.fillColor = .cyan.withAlphaComponent(0.08)
            marker.lineWidth = 2
            marker.zPosition = 10
            overlayLayer.addChild(marker)
        }
        for column in 0 ..< gameModel.numColumns {
            for row in 0 ..< gameModel.numRows {
                let jellyCount = gameModel.level.tileAt(column: column, row: row)?.jellyCount ?? 0
                let jellyName = "jelly_\(column)_\(row)"
                if jellyCount > 0 {
                    let node = (overlayLayer.childNode(withName: jellyName) as? SKShapeNode)
                        ?? makeJellyNode(name: jellyName, column: column, row: row)
                    node.alpha = min(0.85, 0.3 + 0.2 * CGFloat(jellyCount))
                } else {
                    overlayLayer.childNode(withName: jellyName)?.removeFromParent()
                }

                if let symbol = gameModel.level.symbol(atColumn: column, row: row), let sprite = symbol.sprite {
                    sprite.texture = TileArtwork.texture(for: symbol.type, zodiac: gameModel.zodiac)
                    refreshArmor(on: symbol, sprite: sprite)
                    sprite.colorBlendFactor = symbol.isFrozen ? 0.55 : 0
                    if symbol.isFrozen {
                        sprite.color = UIColor.cyan
                    }
                }
            }
        }
    }

    private func makeJellyNode(name: String, column: Int, row: Int) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * 0.9, height: gameModel.tileSize.height * 0.9), cornerRadius: 6)
        node.name = name
        node.fillColor = UIColor.systemGreen.withAlphaComponent(0.5)
        node.strokeColor = .clear
        node.zPosition = 5
        node.position = pointFor(column: column, row: row)
        overlayLayer.addChild(node)
        return node
    }

    /// A chocolate blocker just consumed an adjacent candy — swap that tile's texture and
    /// give it a small "grow" pop so the spread reads as an event, not a silent swap.
    private func animateChocolateSpread(_ symbol: Symbol) {
        guard let sprite = symbol.sprite else { return }
        let texture = TileArtwork.texture(for: .chocolate, zodiac: gameModel.zodiac)
        if reduceMotion {
            sprite.texture = texture
            return
        }
        sprite.run(SKAction.sequence([
            SKAction.setTexture(texture),
            SKAction.scale(to: 1.3, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.12),
        ]))
    }

    /// The HUD owns the delivery flight; fade the original so we don't fly two gifts.
    private func animateIngredientsCollected(_ symbols: [Symbol]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for symbol in symbols {
                guard let sprite = symbol.sprite else { continue }
                taskGroup.addTask { @MainActor in
                    await sprite.run(SKAction.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
                }
            }
        }
        playSound(.match, volume: 0.55)
    }

    // MARK: - Juice helpers

    /// Quick squash-and-stretch settle used when a tile lands (falling, new tiles, swap arrival).
    private func landingSquash(_ sprite: SKSpriteNode) {
        guard !reduceMotion else { return }
        let squash = SKAction.scaleX(to: 1.10, y: 0.90, duration: 0.06)
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeOut
        sprite.run(SKAction.sequence([squash, settle]), withKey: "landing")
    }

    /// Small camera-shake for big explosions/combos — the board itself kicks.
    func screenShake(magnitude: CGFloat = 6, duration: TimeInterval = 0.28) {
        // Never restart mid-shake: the restart would read an already-offset position as the
        // rest position, so a cascade of big matches walks the board permanently off centre.
        guard !reduceMotion, settingModel.screenShakeEnabled, gameLayer.action(forKey: "screenShake") == nil else { return }
        let originalPosition = gameLayer.position
        let kick = SKAction.customAction(withDuration: duration) { node, elapsed in
            let t = min(1, CGFloat(elapsed) / CGFloat(max(0.01, duration)))
            let envelope = (1 - t) * (1 - t)
            node.position = CGPoint(x: originalPosition.x + sin(t * .pi * 4) * magnitude * envelope,
                                    y: originalPosition.y + sin(t * .pi * 3) * magnitude * 0.45 * envelope)
        }
        gameLayer.run(.sequence([kick, .move(to: originalPosition, duration: 0)]), withKey: "screenShake")
    }
}
