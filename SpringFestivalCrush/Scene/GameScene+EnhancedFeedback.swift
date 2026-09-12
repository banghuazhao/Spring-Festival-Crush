import SpriteKit

extension GameScene {
    /// A short birth accent, not an idle loop. Its lifetime is owned by the tile.
    func animateEnhancedBirth(on sprite: SKSpriteNode) async {
        guard !reduceMotion else {
            sprite.alpha = 0
            await sprite.run(.fadeIn(withDuration: 0.16))
            return
        }
        let accent = SKNode()
        accent.name = "enhancedBirth"
        accent.zPosition = 15
        sprite.addChild(accent)
        defer { accent.removeFromParent() }

        let radius = min(sprite.size.width, sprite.size.height) * 0.43
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = UIColor(hex: 0xFFE5A1)
        ring.lineWidth = 2
        ring.fillColor = .clear
        accent.addChild(ring)
        ring.run(.group([.scale(to: 1.12, duration: 0.24), .fadeOut(withDuration: 0.24)]), withKey: "birthRing")
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2 + .pi / 4
            let spark = SKShapeNode(circleOfRadius: max(1, radius * 0.07))
            spark.fillColor = UIColor(hex: 0xFFF1C0)
            spark.strokeColor = .clear
            spark.position = CGPoint(x: cos(angle) * radius * 0.55, y: sin(angle) * radius * 0.55)
            accent.addChild(spark)
            let move = SKAction.move(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius), duration: 0.24)
            move.timingMode = .easeOut
            spark.run(.group([move, .fadeOut(withDuration: 0.24)]), withKey: "birthSpark")
        }
        // Await the visual completion; never award progress from effect callbacks.
        sprite.setScale(0.86)
        let expand = SKAction.scale(to: 1.04, duration: 0.12)
        expand.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeInEaseOut
        await sprite.run(.sequence([expand, settle]))
    }
}
