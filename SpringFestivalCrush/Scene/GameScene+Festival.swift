import SpriteKit

/// Game-feel layer added in 3.3: hit-stop, the Ruyi Swap arc, guardian reactions and the
/// end-of-level fireworks finale. Everything here is presentation only — no rewards,
/// scores or state changes — and every effect is skipped or shortened with reduced motion.
extension GameScene {
    // MARK: - Hit-stop

    /// Freezes the board for a few frames on a big impact, then lets it snap forward.
    /// Only the board layer stops; sounds and the scene clock keep running, so a freeze
    /// can never stall the model's async flow.
    func hitStop(_ duration: TimeInterval) {
        guard !reduceMotion, !feedbackPaused, duration > 0 else { return }
        hitStopToken &+= 1
        let token = hitStopToken
        gameLayer.speed = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + min(duration, Self.maxHitStop)) { [weak self] in
            guard let self, self.hitStopToken == token else { return }
            self.gameLayer.speed = 1
        }
    }

    /// Used by teardown paths (restart, results) so a pending freeze never outlives its board.
    func cancelHitStop() {
        hitStopToken &+= 1
        gameLayer.speed = 1
    }

    static let maxHitStop: TimeInterval = 0.12

    // MARK: - Ruyi Swap

    /// Both tiles float over each other on opposite arcs, trailing a gold ribbon.
    func animateFreeSwap(_ swap: Swap) async {
        guard let spriteA = swap.symbolA.sprite, let spriteB = swap.symbolB.sprite else { return }
        HapticManager.swap()
        playSound(.glissando, volume: 0.8)
        let start = (spriteA.position, spriteB.position)
        let depths = (spriteA.zPosition, spriteB.zPosition)
        defer {
            spriteA.zPosition = depths.0
            spriteB.zPosition = depths.1
        }
        spriteA.zPosition = 100
        spriteB.zPosition = 90

        if reduceMotion {
            async let fadeA: Void = spriteA.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.08),
                                                           .move(to: start.1, duration: 0), .fadeIn(withDuration: 0.08)]))
            async let fadeB: Void = spriteB.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.08),
                                                           .move(to: start.0, duration: 0), .fadeIn(withDuration: 0.08)]))
            await _ = [fadeA, fadeB]
            HapticManager.match()
            return
        }

        let tile = gameModel.tileSize.width
        let dx = start.1.x - start.0.x, dy = start.1.y - start.0.y
        let length = max(1, hypot(dx, dy))
        // Perpendicular to the swap direction, so the two arcs bow away from each other.
        let normal = CGPoint(x: -dy / length * tile * 0.7, y: dx / length * tile * 0.7)
        let mid = CGPoint(x: (start.0.x + start.1.x) / 2, y: (start.0.y + start.1.y) / 2)
        let pathA = CGMutablePath()
        pathA.move(to: start.0)
        pathA.addQuadCurve(to: start.1, control: CGPoint(x: mid.x + normal.x, y: mid.y + normal.y))
        let pathB = CGMutablePath()
        pathB.move(to: start.1)
        pathB.addQuadCurve(to: start.0, control: CGPoint(x: mid.x - normal.x, y: mid.y - normal.y))

        for (path, color) in [(pathA, UIColor(hex: 0xFFD979)), (pathB, UIColor(hex: 0xFF7055))] {
            let ribbon = SKShapeNode(path: path)
            ribbon.strokeColor = color
            ribbon.lineWidth = max(1.5, tile * 0.06)
            ribbon.glowWidth = 1
            ribbon.lineCap = .round
            ribbon.alpha = 0
            ribbon.zPosition = 80
            symbolsLayer.addChild(ribbon)
            ribbon.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.06), .wait(forDuration: 0.2),
                                  .fadeOut(withDuration: 0.2), .removeFromParent()]), completion: {})
        }

        let travelA = SKAction.follow(pathA, asOffset: false, orientToPath: false, duration: 0.3)
        travelA.timingMode = .easeInEaseOut
        let travelB = SKAction.follow(pathB, asOffset: false, orientToPath: false, duration: 0.3)
        travelB.timingMode = .easeInEaseOut
        let lift = SKAction.sequence([.scale(to: 1.18, duration: 0.15), .scale(to: 1, duration: 0.15)])
        async let moveA: Void = spriteA.run(.group([travelA, lift]))
        async let moveB: Void = spriteB.run(.group([travelB, lift]))
        await _ = [moveA, moveB]
        spriteA.position = start.1
        spriteB.position = start.0
        for point in [start.0, start.1] {
            addClearSparks(at: point, color: UIColor(hex: 0xFFE5A1), count: 6, to: effectsLayer)
        }
        HapticManager.bigMatch()
    }

    // MARK: - Guardian reactions

    func animateBossHit(damage: Int) {
        guard damage > 0 else { return }
        playSound(.drum, volume: min(1, 0.55 + Float(damage) * 0.04), rate: damage >= 8 ? 0.9 : 1)
        HapticManager.bossHit(damage: damage)
        if damage >= 6 { hitStop(0.07) }
        guard !reduceMotion else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "-\(damage)"
        label.fontSize = min(34, 20 + CGFloat(damage))
        label.fontColor = UIColor(hex: 0xFF5A45)
        label.zPosition = 520
        let boardTop = gameModel.tileSize.height * CGFloat(gameModel.numRows) / 2
        label.position = CGPoint(x: CGFloat.random(in: -40...40), y: tilesLayer.position.y + boardTop * 2 + 18)
        let outline = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        outline.text = label.text
        outline.fontSize = label.fontSize
        outline.fontColor = UIColor(hex: 0x4A2213)
        outline.position = CGPoint(x: 1.5, y: -1.5)
        outline.zPosition = -1
        label.addChild(outline)
        label.setScale(0.4)
        addChild(label)
        let pop = SKAction.scale(to: 1.15, duration: 0.1)
        pop.timingMode = .easeOut
        label.run(.sequence([pop, .scale(to: 1, duration: 0.08),
                             .group([.moveBy(x: 0, y: 36, duration: 0.55), .fadeOut(withDuration: 0.55)]),
                             .removeFromParent()]))
    }

    func animateBossAttack(_ kind: BossConfiguration.Kind) {
        playSound(.gong, volume: 0.9)
        HapticManager.bossAttack()
        let width = gameModel.tileSize.width * CGFloat(gameModel.numColumns)
        let height = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        let tint: UIColor = switch kind {
        case .rat: UIColor(hex: 0xFFC947)
        case .ox: UIColor(hex: 0x8C97A6)
        case .tiger: UIColor(hex: 0x9BE8FF)
        }
        let flash = SKSpriteNode(color: tint, size: CGSize(width: width, height: height))
        flash.position = CGPoint(x: width / 2, y: height / 2)
        flash.zPosition = 300
        flash.alpha = 0
        effectsLayer.addChild(flash)
        let peak: CGFloat = reduceMotion ? 0.18 : 0.34
        flash.run(.sequence([.wait(forDuration: reduceMotion ? 0 : 0.3), .fadeAlpha(to: peak, duration: 0.08),
                             .fadeOut(withDuration: 0.4), .removeFromParent()]))
        guard !reduceMotion else { return }
        // The shake lands with the haptic blow, after the rumble builds.
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in
            self?.screenShake(magnitude: 6, duration: 0.32)
        }]), withKey: "bossAttackShake")
    }

    // MARK: - Festival finale

    /// Opens the victory bonus: a banner over the board and a volley of fireworks,
    /// one rocket for every couple of moves the player saved.
    func beginFinale(movesLeft: Int) {
        childNode(withName: "festivalFinale")?.removeFromParent()
        let finale = SKNode()
        finale.name = "festivalFinale"
        finale.zPosition = 650
        addChild(finale)
        finale.run(.sequence([.wait(forDuration: 3.2), .removeFromParent()]))

        let boardHeight = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        let boardCenterY = tilesLayer.position.y + boardHeight / 2
        let banner = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        banner.text = String(localized: "FESTIVAL FINALE!")
        banner.fontSize = min(38, gameModel.tileSize.width * 0.8)
        banner.fontColor = UIColor(hex: 0xFFE4A3)
        banner.verticalAlignmentMode = .center
        banner.position = CGPoint(x: 0, y: boardCenterY + gameModel.tileSize.height * 0.6)
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = banner.text
        shadow.fontSize = banner.fontSize
        shadow.fontColor = UIColor(hex: 0x8F201C)
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 2, y: -2.5)
        shadow.zPosition = -1
        banner.addChild(shadow)
        finale.addChild(banner)
        if movesLeft > 0 {
            let subtitle = SKLabelNode(fontNamed: "AvenirNext-Bold")
            subtitle.text = String(localized: "\(movesLeft) moves → fireworks!")
            subtitle.fontSize = banner.fontSize * 0.45
            subtitle.fontColor = .white
            subtitle.verticalAlignmentMode = .center
            subtitle.position = CGPoint(x: 0, y: -banner.fontSize * 0.75)
            banner.addChild(subtitle)
        }
        if reduceMotion {
            banner.alpha = 0
            banner.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 1.1), .fadeOut(withDuration: 0.25)]))
            playSound(.chime, volume: 0.7)
            return
        }
        banner.setScale(0.3)
        banner.alpha = 0
        let slam = SKAction.group([.fadeIn(withDuration: 0.1), .scale(to: 1.12, duration: 0.16)])
        slam.timingMode = .easeOut
        banner.run(.sequence([slam, .scale(to: 1, duration: 0.1), .wait(forDuration: 1.0),
                              .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 24, duration: 0.3)])]))
        playSound(.firecracker, volume: 0.8)
        HapticManager.firecracker()

        let width = gameModel.tileSize.width * CGFloat(gameModel.numColumns)
        let rockets = min(7, 2 + movesLeft / 2)
        for index in 0 ..< rockets {
            let delay = 0.25 + Double(index) * 0.2
            let x = CGFloat.random(in: -width * 0.42 ... width * 0.42)
            let apex = CGPoint(x: x, y: boardCenterY + CGFloat.random(in: -boardHeight * 0.1 ... boardHeight * 0.35))
            let launch = CGPoint(x: x * 0.8, y: boardCenterY - boardHeight / 2 - 20)
            finale.run(.sequence([.wait(forDuration: delay), .run { [weak self, weak finale] in
                guard let self, let finale, finale.parent != nil else { return }
                self.launchFirework(from: launch, to: apex, in: finale, index: index)
            }]))
        }
    }

    private func launchFirework(from launch: CGPoint, to apex: CGPoint, in parent: SKNode, index: Int) {
        let palette = [UIColor(hex: 0xFFD979), UIColor(hex: 0xFF654F), UIColor(hex: 0xFFF3D2), UIColor(hex: 0x7FE0C3)]
        let color = palette[index % palette.count]
        let rocket = SKShapeNode(circleOfRadius: 2.6)
        rocket.fillColor = color
        rocket.strokeColor = .white
        rocket.glowWidth = 2
        rocket.position = launch
        parent.addChild(rocket)
        if index.isMultiple(of: 2) { playSound(.firework, volume: 0.55) }
        let rise = SKAction.move(to: apex, duration: 0.42)
        rise.timingMode = .easeOut
        rocket.run(.sequence([rise, .run { [weak self, weak parent] in
            guard let self, let parent else { return }
            HapticManager.fireworkBurst()
            self.burstFirework(at: apex, color: color, in: parent)
        }, .removeFromParent()]))
    }

    private func burstFirework(at point: CGPoint, color: UIColor, in parent: SKNode) {
        let count = 16
        let reach = gameModel.tileSize.width * CGFloat.random(in: 1.4 ... 2.1)
        let flash = SKShapeNode(circleOfRadius: reach * 0.25)
        flash.fillColor = color.withAlphaComponent(0.35)
        flash.strokeColor = .clear
        flash.position = point
        parent.addChild(flash)
        flash.run(.sequence([.group([.scale(to: 2.2, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
        for spark in 0 ..< count {
            let angle = CGFloat(spark) / CGFloat(count) * 2 * .pi + CGFloat.random(in: -0.08 ... 0.08)
            let dot = SKShapeNode(circleOfRadius: 2)
            dot.fillColor = spark.isMultiple(of: 3) ? .white : color
            dot.strokeColor = .clear
            dot.position = point
            parent.addChild(dot)
            let out = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach, duration: 0.5)
            out.timingMode = .easeOut
            // A little gravity after the burst makes the sparks read as falling embers.
            let droop = SKAction.moveBy(x: 0, y: -reach * 0.35, duration: 0.45)
            droop.timingMode = .easeIn
            dot.run(.sequence([out, .group([droop, .fadeOut(withDuration: 0.45), .scale(to: 0.3, duration: 0.45)]),
                               .removeFromParent()]))
        }
    }

    /// One pluck per converted tile during the finale, climbing the pentatonic ladder.
    func playFinaleNote(_ index: Int) {
        playSound(.note(index % GameSound.pentatonic.count), volume: 0.7)
    }
}
