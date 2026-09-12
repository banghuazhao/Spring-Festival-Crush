import SpriteKit

extension GameScene {
    /// A rare, bounded festival flourish: charge, blossom, then ribbons to collected tiles.
    /// All nodes belong to the clear batch, so restarting clears the entire effect.
    func addFiveCelebration(for chain: Chain, to batch: SKNode) {
        guard !reduceMotion,
              let source = chain.symbols.first(where: { $0.type == .five })?.sprite
                ?? chain.symbols.first?.sprite else { return }
        let origin = source.position
        let tile = gameModel.tileSize.width
        let gold = UIColor(hex: 0xFFD979)
        let red = UIColor(hex: 0xFF654F)
        let crown = SKNode()
        crown.name = "fiveBlossom"
        crown.position = origin
        batch.addChild(crown)
        addFivePetals(radius: tile * 0.64, to: crown)
        crown.setScale(0.55)
        crown.alpha = 0
        let charge = SKAction.group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.24),
                                     .rotate(byAngle: .pi / 5, duration: 0.24)])
        charge.timingMode = .easeOut
        let bloom = SKAction.group([.scale(to: 2.1, duration: 0.32), .fadeOut(withDuration: 0.32),
                                    .rotate(byAngle: .pi / 5, duration: 0.32)])
        bloom.timingMode = .easeOut
        crown.run(.sequence([charge, bloom, .removeFromParent()]))

        // A warm impact, without a full-screen flash or a global time-scale change.
        batch.run(.sequence([.wait(forDuration: 0.24), .run { [weak self, weak batch] in
            guard let self, let batch, batch.parent != nil, !self.reduceMotion else { return }
            self.addClearRing(at: origin, radius: tile * 0.35, expansion: 4.2, color: gold, to: batch)
            self.addClearRing(at: origin, radius: tile * 0.6, expansion: 3.1, color: red, to: batch)
            self.addClearSparks(at: origin, color: gold, count: 10, to: batch)
            HapticManager.explosion()
            self.screenShake(magnitude: 3.5, duration: 0.22)
            self.playSound(.match, volume: 0.85, rate: 1.35)
        }]), withKey: "fiveRelease")

        let targets = chain.clearedSymbols.compactMap(\.sprite)
            .filter { $0 !== source }
            .sorted {
                hypot($0.position.x - origin.x, $0.position.y - origin.y)
                    < hypot($1.position.x - origin.x, $1.position.y - origin.y)
            }
        // Limit expensive stroked paths on very large boards; every target still pulses.
        for (index, target) in targets.prefix(24).enumerated() {
            let destination = target.position
            let dx = destination.x - origin.x, dy = destination.y - origin.y
            let distance = max(1, hypot(dx, dy))
            let bend = min(tile * 1.2, distance * 0.25) * (index.isMultiple(of: 2) ? 1 : -1)
            let path = CGMutablePath()
            path.move(to: origin)
            path.addQuadCurve(to: destination, control: CGPoint(
                x: (origin.x + destination.x) / 2 - dy / distance * bend,
                y: (origin.y + destination.y) / 2 + dx / distance * bend
            ))
            let delay = fiveClearDelay(at: destination, origin: origin)
            let ribbon = SKShapeNode(path: path)
            ribbon.name = "fiveRibbon"
            ribbon.strokeColor = index.isMultiple(of: 2) ? gold : red
            ribbon.lineWidth = max(1.2, tile * 0.035)
            ribbon.glowWidth = 0.8
            ribbon.alpha = 0
            batch.addChild(ribbon)
            ribbon.run(.sequence([.wait(forDuration: 0.18), .fadeAlpha(to: 0.65, duration: 0.08),
                                  .wait(forDuration: max(0, delay - 0.26)),
                                  .fadeOut(withDuration: 0.22), .removeFromParent()]))

            let spark = SKShapeNode(circleOfRadius: tile * 0.055)
            spark.name = "fiveComet"
            spark.fillColor = gold
            spark.strokeColor = .white
            spark.lineWidth = 0.6
            spark.alpha = 0
            batch.addChild(spark)
            let flight = SKAction.follow(path, asOffset: false, orientToPath: false, duration: delay - 0.18)
            flight.timingMode = .easeInEaseOut
            spark.run(.sequence([.wait(forDuration: 0.18), .fadeIn(withDuration: 0.02), flight,
                                 .group([.scale(to: 2.4, duration: 0.12), .fadeOut(withDuration: 0.12)]),
                                 .removeFromParent()]))
        }
    }

    func fiveClearDelay(at position: CGPoint, origin: CGPoint) -> TimeInterval {
        let diagonal = hypot(CGFloat(gameModel.numColumns), CGFloat(gameModel.numRows)) * gameModel.tileSize.width
        let fraction = min(1, hypot(position.x - origin.x, position.y - origin.y) / max(1, diagonal))
        return 0.28 + Double(fraction) * 0.16
    }

    func animateFiveBirth(on sprite: SKSpriteNode) async {
        let accent = SKNode()
        accent.name = "fiveBirth"
        accent.zPosition = 15
        sprite.addChild(accent)
        defer { accent.removeFromParent(); sprite.setScale(1); sprite.alpha = 1; sprite.zRotation = 0 }
        let radius = min(sprite.size.width, sprite.size.height) * 0.55
        addFivePetals(radius: radius, to: accent)
        accent.setScale(1.4)
        accent.alpha = 0
        accent.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), .scale(to: 0.75, duration: 0.18),
                    .rotate(byAngle: -.pi / 5, duration: 0.18)]),
            .group([.scale(to: 1.6, duration: 0.30), .fadeOut(withDuration: 0.30),
                    .rotate(byAngle: .pi / 3, duration: 0.30)])
        ]), withKey: "fiveBirthBloom")
        let charge = SKAction.scale(to: 0.78, duration: 0.14)
        charge.timingMode = .easeIn
        let reveal = SKAction.scale(to: 1.32, duration: 0.14)
        reveal.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.20)
        settle.timingMode = .easeInEaseOut
        await sprite.run(.sequence([charge, reveal, settle]))
    }

    private func addFivePetals(radius: CGFloat, to parent: SKNode) {
        for index in 0..<5 {
            let angle = CGFloat(index) * 2 * .pi / 5 + .pi / 2
            let petal = SKShapeNode(ellipseOf: CGSize(width: radius * 0.56, height: radius * 1.12))
            petal.position = CGPoint(x: cos(angle) * radius * 0.68, y: sin(angle) * radius * 0.68)
            petal.zRotation = angle - .pi / 2
            petal.strokeColor = UIColor(hex: 0xFFE3A0)
            petal.fillColor = UIColor(hex: 0xF64B36).withAlphaComponent(0.16)
            petal.lineWidth = 1.7
            parent.addChild(petal)
        }
    }
}
