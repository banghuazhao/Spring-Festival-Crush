import GameplayKit
import SpriteKit
import SwiftUI

class GameScene: SKScene {
    let gameModel: GameModel
    let themeModel: ThemeModel
    let settingModel: SettingModel

    let gameLayer = SKNode()
    let tilesLayer = SKNode()
    // A crop node only draws its children where the mask contains pixels. This lets you draw the cookies only where there is a tile, but never on the background.
    let maskLayer = SKNode()
    let cropLayer = SKCropNode()
    let symbolsLayer = SKNode()

    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    private var selectionSprite = SKSpriteNode()

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
            y: -gameModel.tileSize.width * CGFloat(gameModel.numRows) / 2)
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
            if let symbol = gameModel.level.symbol(atColumn: column, row: row),
               symbol.isMovable() {
                swipeFromColumn = column
                swipeFromRow = row
                showSelectionIndicator(of: symbol)
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
           toSymbol.isMovable() {
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

        let duration: TimeInterval = 0.3

        let moveA = SKAction.move(to: spriteB.position, duration: duration)
        moveA.timingMode = .easeOut

        let moveB = SKAction.move(to: spriteA.position, duration: duration)
        moveB.timingMode = .easeOut

        async let runMoveA: Void = spriteA.run(moveA)
        async let runMoveB: Void = spriteB.run(moveB)

        await _ = [runMoveA, runMoveB]

        if settingModel.playSoundEffect {
            await run(themeModel.swapSound)
        }
    }

    func animateInvalidSwap(_ swap: Swap) async {
        let spriteA = swap.symbolA.sprite!
        let spriteB = swap.symbolB.sprite!

        spriteA.zPosition = 100
        spriteB.zPosition = 90

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
            if symbol.type == .zodiac {
                selectionSprite = SKSpriteNode.highLightSprite(for: symbol, zodiac: gameModel.zodiac, size: gameModel.tileSize.width)
                selectionSprite.size = gameModel.tileSize
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
                for symbol in chain.symbols {
                    guard let sprite = symbol.sprite else { continue }
                    guard sprite.action(forKey: "removing") == nil else { continue }
                    let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
                    scaleAction.timingMode = .easeOut
                    taskGroup.addTask {
                        await sprite.run(SKAction.sequence([scaleAction, SKAction.removeFromParent()]),
                                         withKey: "removing")
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

    func animateEliminatedSymbols(for symbols: Set<Symbol>) async {
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
                    moveAction.timingMode = .easeInEaseOut
                    taskGroup.addTask {
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                moveAction]
                            )
                        )
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
                    moveAction.timingMode = .easeOut
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

        // Add a label for the score that slowly floats up.
        let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
        scoreLabel.fontSize = 16
        scoreLabel.text = String(format: "%ld", chain.score)
        scoreLabel.position = centerPosition
        scoreLabel.zPosition = 300
        symbolsLayer.addChild(scoreLabel)

        let moveAction = SKAction.move(by: CGVector(dx: 0, dy: 3), duration: 0.7)
        moveAction.timingMode = .easeOut
        scoreLabel.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
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

    func removeAllBarriers() {
    }

    func removeAllSymbols() {
        symbolsLayer.removeAllChildren()
    }

    func setUserInteraction(enabled: Bool) {
        isUserInteractionEnabled = enabled
    }
}
