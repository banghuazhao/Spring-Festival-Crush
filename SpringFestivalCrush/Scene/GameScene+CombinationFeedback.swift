import SpriteKit

extension GameScene {
    func combinationCenter(_ chain: Chain) -> CGPoint {
        let points = chain.combinationSources.compactMap { $0.sprite?.position }
        guard !points.isEmpty else { return .zero }
        return CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                       y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
    }

    func combinationDelay(for symbol: Symbol, chain: Chain) -> TimeInterval {
        guard !reduceMotion, let combination = chain.combination else { return 0 }
        if combination == .enhancedFive || combination == .fiveLightning { return 0.52 }
        if chain.combinationSources.contains(where: { $0 === symbol }) { return 0 }
        let position = symbol.sprite?.position ?? pointFor(column: symbol.column, row: symbol.row)
        let center = combinationCenter(chain)
        let width = gameModel.tileSize.width * CGFloat(gameModel.numColumns)
        let height = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        let distance = hypot(position.x - center.x, position.y - center.y) / max(1, hypot(width, height) / 2)
        switch combination {
        case .fiveFive: return 0.34 + min(1, Double(distance)) * 0.38
        case .fiveLightning: return 0.25 + Double(position.y / max(1, height)) * 0.32
        case .lightningLightning:
            return 0.24 + min(0.3, Double(min(abs(position.x - center.x), abs(position.y - center.y)) / max(1, width)) * 0.5)
        case .enhancedLightning: return 0.28 + min(1, Double(distance)) * 0.30
        case .enhancedFive:
            let nearest = chain.blastCenters.map { hypot(CGFloat(symbol.column - $0.column), CGFloat(symbol.row - $0.row)) }.min() ?? 0
            return 0.3 + min(0.25, Double(nearest) * 0.06)
        }
    }

    func addCombinationCelebration(for chain: Chain, to batch: SKNode) {
        guard let combination = chain.combination, !reduceMotion else { return }
        let center = combinationCenter(chain)
        let tile = gameModel.tileSize.width
        let width = tile * CGFloat(gameModel.numColumns)
        let height = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        let gold = UIColor(hex: 0xFFE294)
        let red = UIColor(hex: 0xFF7055)
        let effect = SKNode()
        effect.name = "combination-\(combination.rawValue)"
        batch.addChild(effect)

        // The two recognisable pieces converge before their combined footprint releases.
        for (index, source) in chain.combinationSources.enumerated() {
            guard let sprite = source.sprite else { continue }
            let charm = SKSpriteNode(texture: sprite.texture)
            charm.size = sprite.size
            charm.position = sprite.position
            charm.zPosition = 5
            effect.addChild(charm)
            let path = CGMutablePath()
            path.move(to: charm.position)
            path.addQuadCurve(to: center, control: CGPoint(x: center.x,
                y: center.y + tile * (index.isMultiple(of: 2) ? 0.85 : -0.85)))
            let gather = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.26)
            gather.timingMode = .easeInEaseOut
            charm.run(.sequence([.group([gather, .scale(to: 1.35, duration: 0.26)]),
                                  .group([.scale(to: combination == .fiveFive ? 2.2 : 1.7, duration: 0.18),
                                          .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        }

        let release: TimeInterval = chain.transformationType == nil ? 0.26 : 0.52
        effect.run(.sequence([.wait(forDuration: release), .run { [weak self, weak effect] in
            guard let self, let effect, effect.parent?.parent != nil, !self.reduceMotion else { return }
            HapticManager.explosion()
            self.playSound(.match, volume: 0.9, rate: combination == .fiveFive ? 0.8 : 1.2)
            if combination.lightningCount > 0 { self.playSound(.firecracker, volume: 0.75) }
            if combination == .fiveFive { self.playSound(.gong, volume: 0.6, rate: 1.4) }
            self.hitStop(combination == .fiveFive ? 0.11 : 0.09)
            self.screenShake(magnitude: combination == .fiveFive ? 4 : 3, duration: 0.24)
            self.addClearSparks(at: center, color: gold, count: 12, to: effect)
        }]), withKey: "combinationImpact")

        switch combination {
        case .fiveFive:
            // Twin stars open a board-sized sun with sixteen firework spokes.
            for index in 0..<3 {
                combinationRing(at: center, radius: tile * 0.45, reach: hypot(width, height),
                                color: index.isMultiple(of: 2) ? gold : red,
                                delay: 0.26 + Double(index) * 0.10, to: effect)
            }
            for index in 0..<16 {
                let angle = CGFloat(index) * .pi / 8
                let end = CGPoint(x: center.x + cos(angle) * width, y: center.y + sin(angle) * height)
                combinationBeam(from: center, to: end, color: gold, width: 1.8, delay: 0.34, jagged: false, parent: effect)
            }
        case .fiveLightning:
            // Every converted charm is visible before all rows and columns fire together.
            for seed in chain.blastCenters {
                combinationBeam(from: center, to: pointFor(column: seed.column, row: seed.row),
                                color: red, width: 1.6, delay: 0.10, jagged: true, parent: effect)
            }
            let bolts = chain.blastCenters + chain.combinationSources.filter { $0.type == .lightning }
            for row in Set(bolts.map(\.row)).sorted() {
                let y = pointFor(column: 0, row: row).y
                combinationBeam(from: CGPoint(x: 0, y: y), to: CGPoint(x: width, y: y),
                                color: gold, width: 2.2, delay: release, jagged: true, parent: effect)
            }
            for column in Set(bolts.map(\.column)).sorted() {
                let x = pointFor(column: column, row: 0).x
                combinationBeam(from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: height),
                                color: gold, width: 2.2, delay: release, jagged: true, parent: effect)
            }
        case .lightningLightning:
            // Broad crossing lanes and diagonal forks form an eight-way thunder sigil.
            for offset in -1...1 {
                let delta = CGFloat(offset) * tile
                combinationBeam(from: CGPoint(x: 0, y: center.y + delta), to: CGPoint(x: width, y: center.y + delta),
                                color: gold, width: 3.5, delay: 0.22 + Double(abs(offset)) * 0.08, jagged: true, parent: effect)
                combinationBeam(from: CGPoint(x: center.x + delta, y: 0), to: CGPoint(x: center.x + delta, y: height),
                                color: gold, width: 3.5, delay: 0.22 + Double(abs(offset)) * 0.08, jagged: true, parent: effect)
            }
            for sign: CGFloat in [-1, 1] {
                combinationBeam(from: CGPoint(x: center.x - width, y: center.y - height * sign),
                                to: CGPoint(x: center.x + width, y: center.y + height * sign),
                                color: red, width: 2.5, delay: 0.38, jagged: true, parent: effect)
            }
        case .enhancedLightning:
            // A red firecracker shockwave drives five thick gold lanes in each direction.
            combinationRing(at: center, radius: tile * 0.3, reach: tile * 3.4, color: red, delay: 0.2, to: effect)
            for offset in -2...2 {
                let delta = CGFloat(offset) * tile
                let delay = 0.22 + Double(abs(offset)) * 0.07
                combinationBeam(from: CGPoint(x: 0, y: center.y + delta), to: CGPoint(x: width, y: center.y + delta),
                                color: offset.isMultiple(of: 2) ? red : gold, width: tile * 0.15, delay: delay, jagged: false, parent: effect)
                combinationBeam(from: CGPoint(x: center.x + delta, y: 0), to: CGPoint(x: center.x + delta, y: height),
                                color: gold, width: tile * 0.12, delay: delay, jagged: false, parent: effect)
            }
        case .enhancedFive:
            // The conversion lands first; every three-by-three blast blooms on one beat.
            for seed in chain.blastCenters {
                let point = pointFor(column: seed.column, row: seed.row)
                combinationBeam(from: center, to: point, color: red, width: 2, delay: 0.10, jagged: false, parent: effect)
                combinationRing(at: point, radius: tile * 0.25, reach: tile * 1.5,
                                color: gold, delay: release, to: effect)
            }
        }
    }

    func addReactionCelebration(for chain: Chain, to batch: SKNode) {
        let tile = gameModel.tileSize.width
        let width = tile * CGFloat(gameModel.numColumns)
        let height = gameModel.tileSize.height * CGFloat(gameModel.numRows)
        let gold = UIColor(hex: 0xFFE294)
        for activation in chain.detonations {
            let point = pointFor(column: activation.symbol.column, row: activation.symbol.row)
            if activation.type == .lightning {
                combinationBeam(from: CGPoint(x: 0, y: point.y), to: CGPoint(x: width, y: point.y),
                                color: gold, width: 2.2, delay: chain.reactionDelay, jagged: true, parent: batch)
                combinationBeam(from: CGPoint(x: point.x, y: 0), to: CGPoint(x: point.x, y: height),
                                color: gold, width: 2.2, delay: chain.reactionDelay, jagged: true, parent: batch)
            } else {
                combinationRing(at: point, radius: tile * 0.25,
                                reach: tile * (activation.type == .five ? 2.5 : 1.5),
                                color: gold, delay: chain.reactionDelay, to: batch)
                if activation.type == .five {
                    for target in activation.targets.prefix(24) {
                        combinationBeam(from: point, to: pointFor(column: target.column, row: target.row),
                                        color: gold, width: 1.5, delay: chain.reactionDelay,
                                        jagged: false, parent: batch)
                    }
                }
            }
        }
    }

    private func combinationRing(at point: CGPoint, radius: CGFloat, reach: CGFloat, color: UIColor,
                                 delay: TimeInterval, to parent: SKNode) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = point
        ring.strokeColor = color
        ring.fillColor = color.withAlphaComponent(0.08)
        ring.lineWidth = 2.5
        ring.alpha = 0
        parent.addChild(ring)
        let expand = SKAction.scale(to: reach / max(1, radius), duration: 0.48)
        expand.timingMode = .easeOut
        ring.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.04),
                            .group([expand, .fadeOut(withDuration: 0.48)]), .removeFromParent()]))
    }

    private func combinationBeam(from start: CGPoint, to end: CGPoint, color: UIColor, width: CGFloat,
                                 delay: TimeInterval, jagged: Bool, parent: SKNode) {
        let path = CGMutablePath()
        path.move(to: start)
        let dx = end.x - start.x, dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        for index in 1...14 {
            let t = CGFloat(index) / 14
            let offset: CGFloat = !jagged || index == 14 ? 0 : (index.isMultiple(of: 2) ? 4 : -4)
            path.addLine(to: CGPoint(x: start.x + dx * t - dy / length * offset,
                                    y: start.y + dy * t + dx / length * offset))
        }
        let beam = SKShapeNode(path: path)
        beam.strokeColor = color
        beam.lineWidth = width
        beam.glowWidth = 0.8
        beam.alpha = 0
        parent.addChild(beam)
        beam.run(.sequence([.wait(forDuration: delay), .fadeAlpha(to: 0.85, duration: 0.06),
                            .fadeOut(withDuration: 0.28), .removeFromParent()]))
    }
}
