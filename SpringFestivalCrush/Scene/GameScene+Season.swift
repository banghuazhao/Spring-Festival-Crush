import SpriteKit

extension GameScene {
    /// Sparse, deterministic snow stays behind the board and pauses with the SpriteKit scene.
    func refreshSeason() {
        childNode(withName: "season")?.removeFromParent()
        guard gameModel.level.hasSnow else { return }
        let season = SKNode()
        season.name = "season"
        season.zPosition = 0.5
        addChild(season)
        let wash = SKSpriteNode(color: UIColor(red: 0.65, green: 0.84, blue: 0.94, alpha: 0.22), size: size)
        season.addChild(wash)
        for index in 0..<32 {
            let flake = SKShapeNode(circleOfRadius: CGFloat(1 + index % 3))
            flake.fillColor = .white.withAlphaComponent(0.75)
            flake.strokeColor = .clear
            let x = -size.width / 2 + CGFloat((index * 73) % 997) / 997 * size.width
            let y = -size.height / 2 + CGFloat((index * 137) % 991) / 991 * size.height
            flake.position = CGPoint(x: x, y: y)
            season.addChild(flake)
            if !reduceMotion {
                let distance = y + size.height / 2 + 8
                let speed = CGFloat(18 + index % 11)
                flake.run(.sequence([
                    .moveBy(x: 12, y: -distance, duration: Double(distance / speed)),
                    .repeatForever(.sequence([
                        .move(to: CGPoint(x: x, y: size.height / 2 + 8), duration: 0),
                        .moveBy(x: 24, y: -size.height - 16, duration: Double((size.height + 16) / speed))
                    ]))
                ]))
            }
        }
        // Snow caps sit outside the playable surface so colors and hit targets stay clear.
        for column in 0..<gameModel.numColumns {
            guard gameModel.level.tileAt(column: column, row: gameModel.numRows - 1) != nil else { continue }
            let cap = SKShapeNode(ellipseOf: CGSize(width: gameModel.tileSize.width + 1, height: 9))
            cap.fillColor = .white.withAlphaComponent(0.92)
            cap.strokeColor = .clear
            cap.position = CGPoint(
                x: gameModel.tileSize.width * (CGFloat(column) + 0.5 - CGFloat(gameModel.numColumns) / 2),
                y: tilesLayer.position.y + gameModel.tileSize.height * CGFloat(gameModel.numRows) + 3)
            season.addChild(cap)
        }
    }

    func refreshArmor(on symbol: Symbol, sprite: SKSpriteNode) {
        sprite.childNode(withName: "armor")?.removeFromParent()
        guard symbol.armorLayers > 0 || symbol.armorHitThisTurn || symbol.isFrozen else { return }
        let shell = SKShapeNode(rectOf: CGSize(width: sprite.size.width * 0.9, height: sprite.size.height * 0.9), cornerRadius: 9)
        shell.name = "armor"
        shell.strokeColor = symbol.armorLayers > 0 ? UIColor(red: 1, green: 0.79, blue: 0.28, alpha: 1) : .white.withAlphaComponent(0.65)
        if symbol.isFrozen { shell.strokeColor = .cyan }
        shell.lineWidth = symbol.armorLayers > 0 || symbol.isFrozen ? 2.5 : 1
        shell.fillColor = .clear
        shell.zPosition = 30
        let badge = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        badge.text = symbol.isFrozen ? "❄" : (symbol.armorLayers > 0 ? "2" : "1")
        badge.fontSize = max(10, sprite.size.height * 0.25)
        badge.fontColor = .white
        badge.position = CGPoint(x: sprite.size.width * 0.3, y: -sprite.size.height * 0.32)
        let backing = SKShapeNode(circleOfRadius: max(7, sprite.size.height * 0.15))
        backing.fillColor = UIColor(red: 0.38, green: 0.16, blue: 0.03, alpha: 1)
        backing.strokeColor = shell.strokeColor
        backing.position = CGPoint(x: badge.position.x, y: badge.position.y + badge.fontSize * 0.32)
        shell.addChild(backing)
        shell.addChild(badge)
        sprite.addChild(shell)
    }
}
