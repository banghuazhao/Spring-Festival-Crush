import SpriteKit

extension GameScene {
    /// Piece-local, bounded accents stay inside a cell and pause with SpriteKit.
    func configurePowerAura(on sprite: SKSpriteNode, type: SymbolType) {
        sprite.childNode(withName: "powerAura")?.removeFromParent()
        guard type == .five || type == .lightning else { return }
        let aura = SKNode()
        aura.name = "powerAura"
        aura.userData = ["kind": type == .five ? "five" : "lightning"]
        aura.zPosition = -1
        sprite.addChild(aura)
        let radius = min(sprite.size.width, sprite.size.height) * 0.45
        if type == .five {
            let orbit = SKNode()
            aura.addChild(orbit)
            let halo = SKShapeNode(circleOfRadius: radius)
            halo.strokeColor = UIColor(hex: 0xFFE4A2)
            halo.lineWidth = 1.1
            halo.alpha = 0.55
            orbit.addChild(halo)
            for index in 0..<5 {
                let angle = CGFloat(index) * .pi * 2 / 5
                let glint = SKShapeNode(circleOfRadius: radius * 0.075)
                glint.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                glint.fillColor = UIColor(hex: 0xFFF2C9)
                glint.strokeColor = UIColor(hex: 0xFF8262)
                glint.lineWidth = 0.7
                orbit.addChild(glint)
            }
            if !reduceMotion {
                orbit.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.8)), withKey: "powerOrbit")
                halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.28, duration: 1),
                                                   .fadeAlpha(to: 0.68, duration: 1)])), withKey: "powerGlow")
            }
        } else {
            let path = CGMutablePath()
            for side in 0..<4 {
                let angle = CGFloat(side) * .pi / 2 + .pi / 4
                let next = angle + .pi / 2
                let start = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                let end = CGPoint(x: cos(next) * radius, y: sin(next) * radius)
                path.move(to: start)
                path.addLine(to: CGPoint(x: start.x * 0.55 + end.x * 0.45, y: start.y * 0.55 + end.y * 0.45))
                path.addLine(to: CGPoint(x: (start.x + end.x) * 0.28, y: (start.y + end.y) * 0.28))
                path.addLine(to: end)
            }
            let arc = SKShapeNode(path: path)
            arc.strokeColor = UIColor(hex: 0xFFE17E)
            arc.lineWidth = 1.3
            arc.glowWidth = reduceMotion ? 0 : 0.5
            arc.alpha = 0.7
            aura.addChild(arc)
            if !reduceMotion {
                arc.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.5),
                                                  .fadeAlpha(to: 0.8, duration: 0.5),
                                                  .wait(forDuration: 0.3)])), withKey: "powerCrackle")
            }
        }
    }

    func refreshPowerAura(on sprite: SKSpriteNode) {
        guard let kind = sprite.childNode(withName: "powerAura")?.userData?["kind"] as? String else { return }
        configurePowerAura(on: sprite, type: kind == "five" ? .five : .lightning)
    }
}
