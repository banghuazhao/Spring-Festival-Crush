import SpriteKit

extension GameScene {
    /// A short birth accent, not an idle loop. Its lifetime is owned by the tile.
    func animateEnhancedBirth(on sprite: SKSpriteNode) async {
        await animateSpecialBirth(on: sprite, type: .firecrackerEnhanced)
    }

    func animateSpecialBirth(on sprite: SKSpriteNode, type: SymbolType) async {
        sprite.removeAction(forKey: "landing")
        defer { sprite.setScale(1); sprite.alpha = 1 }
        guard !reduceMotion else {
            sprite.alpha = 0
            await sprite.run(.fadeIn(withDuration: 0.16))
            return
        }
        let accent = SKNode()
        accent.name = "specialBirth"
        accent.zPosition = 15
        sprite.addChild(accent)
        defer { accent.removeFromParent() }

        let radius = min(sprite.size.width, sprite.size.height) * 0.43
        let ring = SKShapeNode(circleOfRadius: radius)
        let tint = type == .five ? UIColor(hex: 0xBDEEFF) : UIColor(hex: 0xFFE5A1)
        ring.strokeColor = tint
        ring.lineWidth = 2
        ring.fillColor = .clear
        accent.addChild(ring)
        ring.setScale(1.15)
        ring.run(.sequence([.group([.scale(to: 0.7, duration: 0.12), .fadeAlpha(to: 0.5, duration: 0.12)]),
                            .group([.scale(to: 1.35, duration: 0.20), .fadeOut(withDuration: 0.20)])]), withKey: "birthRing")
        let count = type == .five ? 6 : 4
        for index in 0..<count {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(count) + .pi / 4
            let spark = SKShapeNode(circleOfRadius: max(1, radius * 0.06))
            spark.fillColor = tint
            spark.strokeColor = .clear
            spark.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            accent.addChild(spark)
            let gather = SKAction.move(to: CGPoint(x: cos(angle) * radius * 0.3, y: sin(angle) * radius * 0.3), duration: 0.12)
            gather.timingMode = .easeIn
            let move = SKAction.move(to: CGPoint(x: cos(angle) * radius * 1.15, y: sin(angle) * radius * 1.15), duration: 0.20)
            move.timingMode = .easeOut
            spark.run(.sequence([gather, .group([move, .fadeOut(withDuration: 0.20)])]), withKey: "birthSpark")
        }
        // Await the visual completion; never award progress from effect callbacks.
        sprite.setScale(0.84)
        let charge = SKAction.scaleX(to: 0.88, y: 0.80, duration: 0.10)
        charge.timingMode = .easeIn
        let expand = SKAction.scale(to: 1.10, duration: 0.10)
        expand.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeInEaseOut
        await sprite.run(.sequence([charge, expand, settle]))
    }
}
