import Combine
import GameplayKit
import SpriteKit

class GameScene: SKScene {
    // Sound FX
    let swapSound = SKAction.playSoundFileNamed("swap.mp3", waitForCompletion: false)
    let invalidSwapSound = SKAction.playSoundFileNamed("Error.wav", waitForCompletion: false)
    let matchSound = SKAction.playSoundFileNamed("Ka-Ching.wav", waitForCompletion: false)
    let fallingCookieSound = SKAction.playSoundFileNamed("Scrape.wav", waitForCompletion: false)
    let addCookieSound = SKAction.playSoundFileNamed("Drip.wav", waitForCompletion: false)
    let tilesLayer = SKNode()
    let cropLayer = SKCropNode()
    let maskLayer = SKNode()

    var gameModel: GameModel

    let tileWidth: CGFloat = {
        if Constants.isIPhone {
            if UIScreen.main.bounds.width <= 330 {
                return 32.0
            } else {
                return 40.0
            }
        } else {
            return 60.0
        }
    }()

    let tileHeight: CGFloat = {
        if Constants.isIPhone {
            if UIScreen.main.bounds.width <= 330 {
                return 32.0
            } else {
                return 40.0
            }
        } else {
            return 60.0
        }
    }()

    let gameLayer = SKNode()
    let cookiesLayer = SKNode()
    var swipeHandler: ((Swap) -> Void)?

    private var swipeFromColumn: Int?
    private var swipeFromRow: Int?
    private var selectionSprite = SKSpriteNode()

    private var cancellables = Set<AnyCancellable>()

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder) is not used in this app")
    }

    init(size: CGSize, gameModel: GameModel) {
        self.gameModel = gameModel
        super.init(size: size)

        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        let background = SKSpriteNode(imageNamed: gameModel.gameBackground)
        background.size = size
        background.aspectFillToSize(fillSize: size)

        addChild(background)
        addChild(gameLayer)
        gameLayer.isHidden = true

        let layerPosition = CGPoint(
            x: -tileWidth * CGFloat(gameModel.numColumns) / 2,
            y: -tileHeight * CGFloat(gameModel.numRows) / 2)
        tilesLayer.position = layerPosition
        maskLayer.position = layerPosition
        cropLayer.maskNode = maskLayer
        gameLayer.addChild(tilesLayer)
        gameLayer.addChild(cropLayer)

        cookiesLayer.position = layerPosition
        cropLayer.addChild(cookiesLayer)
        _ = SKLabelNode(fontNamed: "GillSans-BoldItalic")

        gameModel.invokeCommand = { [weak self] command in
            guard let self else { return }
            executeCommand(command)
        }

        gameModel.invokeCommandAsync = { [weak self] command in
            guard let self else { return }
            await executeCommandAsync(command)
        }
        gameModel.onGameSceneLoad()
    }

    private func executeCommand(_ command: GameModel.Command) {
        switch command {
        case .addTiles:
            removeAllTiles()
            addTiles()
            animateBeginGame {}
        case let .shuffle(newSprites):
            shuffle(by: newSprites)
        }
    }

    private func executeCommandAsync(_ command: GameModel.CommandAsync) async {
        switch command {
        case let .onValidSwap(swap):
            await animate(swap)
        case let .onInvalidSwap(swap):
            await animateInvalidSwap(swap)
        case let .onMatchedSprites(sprites):
            await animateMatchedCookies(for: sprites)
        case let .onFallingCookies(sprites):
            await animateFallingCookies(in: sprites)
        case let .onNewSprites(sprites):
            await animateNewCookies(in: sprites)
        case .onGameOver:
            await animateGameOver()
        }
    }

    func shuffle(by newSprites: Set<Cookie>) {
        removeAllSprites()
        addSprites(for: newSprites)
    }

    func addSprites(for cookies: Set<Cookie>) {
        for cookie in cookies {
            let sprite = SKSpriteNode.sprite(for: cookie, zodiac: gameModel.zodiac, size: tileWidth)
            sprite.size = CGSize(width: tileWidth, height: tileHeight)
            sprite.position = pointFor(column: cookie.column, row: cookie.row)
            cookiesLayer.addChild(sprite)
            cookie.sprite = sprite

            // Give each cookie sprite a small, random delay. Then fade them in.
            sprite.alpha = 0
            sprite.xScale = 0.5
            sprite.yScale = 0.5

            sprite.run(
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.25, withRange: 0.5),
                    SKAction.group([
                        SKAction.fadeIn(withDuration: 0.25),
                        SKAction.scale(to: 1.0, duration: 0.25),
                    ]),
                ]))
        }
    }

    func addTiles() {
        for row in 0 ..< gameModel.numRows {
            for column in 0 ..< gameModel.numColumns {
                if gameModel.level.tileAt(column: column, row: row) != nil {
                    let tileNode = SKSpriteNode(imageNamed: "MaskTile")
                    tileNode.size = CGSize(width: tileWidth, height: tileHeight)
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
                    tileNode.size = CGSize(width: tileWidth, height: tileHeight)
                    var point = pointFor(column: column, row: row)
                    point.x -= tileWidth / 2
                    point.y -= tileHeight / 2
                    tileNode.position = point
                    tilesLayer.addChild(tileNode)
                }
            }
        }
    }

    private func pointFor(column: Int, row: Int) -> CGPoint {
        return CGPoint(
            x: CGFloat(column) * tileWidth + tileWidth / 2,
            y: CGFloat(row) * tileHeight + tileHeight / 2)
    }

    private func convertPoint(_ point: CGPoint) -> (success: Bool, column: Int, row: Int) {
        if point.x >= 0 && point.x < CGFloat(gameModel.numColumns) * tileWidth &&
            point.y >= 0 && point.y < CGFloat(gameModel.numRows) * tileHeight {
            return (true, Int(point.x / tileWidth), Int(point.y / tileHeight))
        } else {
            return (false, 0, 0) // invalid location
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        let location = touch.location(in: cookiesLayer)

        let (success, column, row) = convertPoint(location)

        if success {
            if let cookie = gameModel.level.cookie(atColumn: column, row: row) {
                swipeFromColumn = column
                swipeFromRow = row
                showSelectionIndicator(of: cookie)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1
        guard swipeFromColumn != nil else { return }

        // 2
        guard let touch = touches.first else { return }
        let location = touch.location(in: cookiesLayer)

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
        if let toCookie = gameModel.level.cookie(atColumn: toColumn, row: toRow),
           let fromCookie = gameModel.level.cookie(atColumn: swipeFromColumn!, row: swipeFromRow!) {
            // 4
            let swap = Swap(cookieA: fromCookie, cookieB: toCookie)
            Task { @MainActor in
                await gameModel.handleSwipe(swap)
            }
        }
    }

    func animate(_ swap: Swap) async {
        let spriteA = swap.cookieA.sprite!
        let spriteB = swap.cookieB.sprite!

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

        await run(swapSound)
    }

    func animateInvalidSwap(_ swap: Swap) async {
        let spriteA = swap.cookieA.sprite!
        let spriteB = swap.cookieB.sprite!

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

        await run(invalidSwapSound)
    }

    func showSelectionIndicator(of cookie: Cookie) {
        if selectionSprite.parent != nil {
            selectionSprite.removeFromParent()
        }

        if let sprite = cookie.sprite {
            if cookie.cookieType == .mouse {
                selectionSprite = SKSpriteNode.highLightSprite(for: cookie, zodiac: gameModel.zodiac, size: tileWidth)
                selectionSprite.size = CGSize(width: tileWidth, height: tileHeight)
            } else {
                selectionSprite = SKSpriteNode()
                let texture = SKTexture(imageNamed: cookie.cookieType.highlightedSpriteName)
                selectionSprite.size = CGSize(width: tileWidth, height: tileHeight)
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

    func animateMatchedCookies(for chains: Set<Chain>) async {
        for chain in chains {
            animateScore(for: chain)
            for cookie in chain.cookies {
                if let sprite = cookie.sprite {
                    if sprite.action(forKey: "removing") == nil {
                        let scaleAction = SKAction.scale(to: 0.1, duration: 0.3)
                        scaleAction.timingMode = .easeOut
                        sprite.run(SKAction.sequence([scaleAction, SKAction.removeFromParent()]),
                                   withKey: "removing")
                    }
                }
            }
        }
        await run(matchSound)
        await run(SKAction.wait(forDuration: 0.3))
    }

    func animateFallingCookies(in columns: [[Cookie]]) async {
        // 1
        await withTaskGroup(of: Void.self) { taskGroup in
            for array in columns {
                for (index, cookie) in array.enumerated() {
                    let newPosition = pointFor(column: cookie.column, row: cookie.row)
                    // 2
                    let delay = 0.05 + 0.15 * TimeInterval(index)
                    // 3
                    let sprite = cookie.sprite! // sprite always exists at this point
                    let duration = TimeInterval(((sprite.position.y - newPosition.y) / tileHeight) * 0.1)
                    // 5
                    let moveAction = SKAction.move(to: newPosition, duration: duration)
                    moveAction.timingMode = .easeOut
                    taskGroup.addTask {
                        await sprite.run(
                            SKAction.sequence([
                                SKAction.wait(forDuration: delay),
                                SKAction.group([moveAction, self.fallingCookieSound])]))
                    }
                }
            }
        }
    }

    func animateNewCookies(in columns: [[Cookie]]) async {
        await withTaskGroup(of: Void.self) { taskGroup in
            for array in columns {
                // 2
                let startRow = array[0].row + 1

                for (index, cookie) in array.enumerated() {
                    // 3
                    let sprite = SKSpriteNode.sprite(for: cookie, zodiac: gameModel.zodiac, size: tileWidth)
                    sprite.size = CGSize(width: tileWidth, height: tileHeight)
                    sprite.position = pointFor(column: cookie.column, row: startRow)
                    cookiesLayer.addChild(sprite)
                    cookie.sprite = sprite
                    // 4
                    let delay = 0.1 + 0.2 * TimeInterval(array.count - index - 1)
                    // 5
                    let duration = TimeInterval(startRow - cookie.row) * 0.1
                    // 6
                    let newPosition = pointFor(column: cookie.column, row: cookie.row)
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
                                    self.addCookieSound]),
                            ]))
                    }
                }
            }
        }
    }

    func animateScore(for chain: Chain) {
        // Figure out what the midpoint of the chain is.
        let firstSprite = chain.firstCookie().sprite!
        let lastSprite = chain.lastCookie().sprite!
        let centerPosition = CGPoint(
            x: (firstSprite.position.x + lastSprite.position.x) / 2,
            y: (firstSprite.position.y + lastSprite.position.y) / 2 - 8)

        // Add a label for the score that slowly floats up.
        let scoreLabel = SKLabelNode(fontNamed: "GillSans-BoldItalic")
        scoreLabel.fontSize = 16
        scoreLabel.text = String(format: "%ld", chain.score)
        scoreLabel.position = centerPosition
        scoreLabel.zPosition = 300
        cookiesLayer.addChild(scoreLabel)

        let moveAction = SKAction.move(by: CGVector(dx: 0, dy: 3), duration: 0.7)
        moveAction.timingMode = .easeOut
        scoreLabel.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
    }

    func animateGameOver(_ completion: @escaping () -> Void) {
        let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
        action.timingMode = .easeIn
        gameLayer.run(action, completion: completion)
    }

    func animateGameOver() async {
        let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
        action.timingMode = .easeIn
        await gameLayer.run(action)
    }

    func animateBeginGame(_ completion: @escaping () -> Void) {
        gameLayer.isHidden = false
        gameLayer.position = CGPoint(x: 0, y: size.height)
        let action = SKAction.move(by: CGVector(dx: 0, dy: -size.height), duration: 0.3)
        action.timingMode = .easeOut
        gameLayer.run(action, completion: completion)
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

    func removeAllSprites() {
        cookiesLayer.removeAllChildren()
    }
}
