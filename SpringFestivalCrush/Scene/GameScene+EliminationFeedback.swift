import SpriteKit

extension GameScene {
    /// One bounded feedback batch per cascade. A tile shared by chains clears once.
    func animateMatchedSymbols(for chains: Set<Chain>) async {
        let batch = SKNode()
        batch.name = "clearFeedback"
        effectsLayer.addChild(batch)
        defer { batch.removeFromParent() }
        let ordered = chains.sorted { clearPriority($0) > clearPriority($1) }
        let enhanced = Set(chains.filter { $0.combination == nil && $0.detonations.isEmpty }.flatMap(\.clearedSymbols).filter { $0.type.isEnhanced })
        let origins = enhanced.compactMap { $0.sprite?.position }
        if !reduceMotion {
            // Cap overlapping area rings when a whole board of bonus tiles detonates.
            for origin in origins.sorted(by: { $0.y == $1.y ? $0.x < $1.x : $0.y < $1.y }).prefix(6) {
                addClearRing(at: origin, radius: gameModel.tileSize.width * 0.42,
                             expansion: 3.1, color: UIColor(hex: 0xFFD987), to: batch)
            }
        }
        if let strongest = ordered.first { triggerClearHaptic(for: strongest, enhanced: !enhanced.isEmpty) }
        var claimed = Set<ObjectIdentifier>()
        var sparkleBudget = 64
        await withTaskGroup(of: Void.self) { group in
            let lifetime = ordered.map { chain in
                max(chain.combination?.duration ?? 0, chain.detonations.isEmpty ? 0 : chain.reactionDelay + 0.56)
            }.max() ?? 0
            if !reduceMotion, lifetime > 0 {
                group.addTask { @MainActor in await self.run(.wait(forDuration: lifetime)) }
            }
            if !reduceMotion, ordered.contains(where: { $0.chainType == .fiveEffect }) {
                // Keep the visual batch alive through its final ribbon and tile pulse.
                group.addTask { @MainActor in await self.run(.wait(forDuration: 0.76)) }
            }
            for chain in ordered {
                let source = chain.symbols.first(where: { $0.type == .five }) ?? chain.symbols.first
                let center = chain.combination == nil ? (source?.sprite?.position ?? .zero) : combinationCenter(chain)
                if !reduceMotion {
                    if chain.combination != nil { addCombinationCelebration(for: chain, to: batch) }
                    if !chain.detonations.isEmpty { addReactionCelebration(for: chain, to: batch) }
                    if chain.chainType == .lightning { addLightningTrail(for: chain, to: batch) }
                    if chain.chainType == .fiveEffect {
                        addFiveCelebration(for: chain, to: batch)
                    }
                }
                for (index, symbol) in chain.clearedSymbols.enumerated() {
                    guard let sprite = symbol.sprite, sprite.parent != nil,
                          claimed.insert(ObjectIdentifier(sprite)).inserted else { continue }
                    let isBlast = symbol.type.isEnhanced || chain.chainType == .single || chain.chainType == .enhanced
                    let isStar = chain.chainType == .fiveEffect
                    let isLightning = chain.chainType == .lightning
                    let color = isStar ? UIColor(hex: 0xFFD979) : UIColor(hex: 0xFFE5A1)
                    let distance = origins.map { hypot(sprite.position.x - $0.x, sprite.position.y - $0.y) }.min() ?? 0
                    let delay = chain.combination != nil ? combinationDelay(for: symbol, chain: chain)
                        : (reduceMotion ? 0 : (!chain.detonations.isEmpty ? chain.reactionDelay : (isLightning ? min(0.12, Double(index) * 0.016)
                        : (isStar ? (symbol === source ? 0 : fiveClearDelay(at: sprite.position, origin: center))
                           : (isBlast ? min(0.08, Double(distance / max(1, gameModel.tileSize.width)) * 0.035) : 0)))))
                    if !reduceMotion && sparkleBudget > 0 {
                        let count = min(sparkleBudget, isBlast || isStar ? 4 : 2)
                        sparkleBudget -= count
                        addClearSparks(at: sprite.position, color: color, count: count,
                                       delay: delay, to: batch)
                    }
                    let action: SKAction
                    let converts = chain.transformedSymbols.contains { $0 === symbol }
                    let conversionTexture = converts ? TileArtwork.texture(for: symbol.type, zodiac: gameModel.zodiac) : nil
                    if reduceMotion {
                        if let conversionTexture { sprite.texture = conversionTexture }
                        action = .sequence([.fadeOut(withDuration: 0.16), .removeFromParent()])
                    } else {
                        let isFiveSource = isStar && symbol === source
                        let anticipation = SKAction.scale(to: isFiveSource ? 1.5 : (isBlast || isStar ? 1.12 : 1.06),
                                                         duration: isFiveSource ? 0.24 : 0.06)
                        anticipation.timingMode = .easeOut
                        let collapse = SKAction.scale(to: 0.08, duration: 0.18)
                        collapse.timingMode = .easeIn
                        var release: [SKAction] = [collapse, .fadeOut(withDuration: 0.18)]
                        if (isStar && !isFiveSource) || chain.combination == .fiveFive {
                            // A short inward tug communicates collection without dragging
                            // distant tiles across the entire board or covering other pieces.
                            let travel = SKAction.move(to: CGPoint(x: sprite.position.x + (center.x - sprite.position.x) * 0.18,
                                                                   y: sprite.position.y + (center.y - sprite.position.y) * 0.18), duration: 0.18)
                            travel.timingMode = .easeIn
                            release.append(travel)
                        }
                        var charge: [SKAction] = [.wait(forDuration: delay)]
                        if let conversionTexture {
                            charge = [.wait(forDuration: 0.18), .setTexture(conversionTexture),
                                      .scale(to: 1.16, duration: 0.10), .scale(to: 1, duration: 0.10),
                                      .wait(forDuration: max(0, delay - 0.38))]
                        }
                        action = .sequence(charge + [anticipation,
                                            .wait(forDuration: isFiveSource ? 0.26 : 0),
                                            .group(release), .removeFromParent()])
                    }
                    group.addTask { @MainActor in await self.animateRemoval(of: sprite, action: action) }
                }
            }
        }
    }

    private func clearPriority(_ chain: Chain) -> Int {
        switch chain.chainType {
        case .combination: 5
        case .fiveEffect: 4
        case .lightning: 3
        case .enhanced: 2
        default: chain.symbols.contains { $0.type.isEnhanced } ? 2 : 1
        }
    }

    private func triggerClearHaptic(for chain: Chain, enhanced: Bool) {
        if chain.combination != nil {
            if reduceMotion { HapticManager.explosion() }
        } else if chain.chainType == .fiveEffect {
            // Full effects synchronize impact with the charge release; reduced effects
            // keep one immediate haptic with the short fade.
            if reduceMotion { HapticManager.explosion() }
        } else if enhanced {
            HapticManager.explosion()
            screenShake(magnitude: 3, duration: 0.20)
            hitStop(0.045)
        } else if chain.chainType == .lightning {
            // Lightning bolts are strings of firecrackers: crackle in sound and in the hand.
            HapticManager.firecracker()
            playSound(.firecracker, volume: 0.55)
            screenShake(magnitude: 2, duration: 0.16)
        } else if chain.length >= 4 {
            HapticManager.bigMatch()
        } else if chain.chainType != .locks && chain.chainType != .single {
            HapticManager.match()
        }
    }

    func addClearRing(at position: CGPoint, radius: CGFloat, expansion: CGFloat, color: UIColor, to parent: SKNode) {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = position
        ring.strokeColor = color
        ring.lineWidth = max(1.2, gameModel.tileSize.width * 0.045)
        ring.fillColor = .clear
        parent.addChild(ring)
        let expand = SKAction.scale(to: expansion, duration: 0.24)
        expand.timingMode = .easeOut
        ring.run(.sequence([.group([expand, .fadeOut(withDuration: 0.24)]), .removeFromParent()]), withKey: "clearRing")
    }

    func addClearSparks(at position: CGPoint, color: UIColor, count: Int, delay: TimeInterval = 0, to parent: SKNode) {
        for index in 0..<count {
            let spark = SKSpriteNode(color: color, size: CGSize(width: 2.2, height: 4.4))
            spark.position = position
            spark.zRotation = CGFloat(index) * .pi / 2 + .pi / 4
            spark.alpha = 0
            parent.addChild(spark)
            let angle = CGFloat(index) * 2 * .pi / CGFloat(count) + .pi / 4
            let reach = gameModel.tileSize.width * 0.6
            let move = SKAction.moveBy(x: cos(angle) * reach, y: sin(angle) * reach, duration: 0.22)
            move.timingMode = .easeOut
            spark.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: 0.02),
                                 .group([move, .fadeOut(withDuration: 0.22), .scale(to: 0.3, duration: 0.22)]),
                                 .removeFromParent()]), withKey: "clearSpark")
        }
    }

    private func addLightningTrail(for chain: Chain, to parent: SKNode) {
        let positions = chain.symbols.compactMap { $0.sprite?.position }
        guard let first = positions.first, let last = positions.last, positions.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: first)
        let horizontal = Set(chain.symbols.map(\.row)).count == 1
        for index in 1...12 {
            let t = CGFloat(index) / 12
            let bend: CGFloat = index == 12 ? 0 : (index.isMultiple(of: 2) ? 2.5 : -2.5)
            path.addLine(to: CGPoint(x: first.x + (last.x - first.x) * t + (horizontal ? 0 : bend),
                                    y: first.y + (last.y - first.y) * t + (horizontal ? bend : 0)))
        }
        let line = SKShapeNode(path: path)
        line.strokeColor = UIColor(hex: 0xFFF0B2)
        line.lineWidth = max(2, gameModel.tileSize.width * 0.07)
        line.glowWidth = 1
        parent.addChild(line)
        line.run(.sequence([.fadeOut(withDuration: 0.24), .removeFromParent()]), withKey: "lightningTrail")
    }

    private func animateRemoval(of sprite: SKSpriteNode, action: SKAction) async {
        let id = ObjectIdentifier(sprite)
        guard sprite.parent != nil, removingSprites.insert(id).inserted else { return }
        defer { removingSprites.remove(id) }
        sprite.removeAction(forKey: "landing")
        sprite.removeAction(forKey: "ambientEffect")
        sprite.childNode(withName: "tileSelection")?.removeFromParent()
        sprite.childNode(withName: "powerAura")?.removeFromParent()
        sprite.run(action, withKey: "tileRemoval")
        // Restart detaches old sprites. Await the scene clock so an old clear still
        // completes and releases its task group even after its sprite leaves the board.
        await run(.wait(forDuration: action.duration))
        // A hit-stop froze the board but not the scene clock; give the clear its frames back.
        if sprite.parent != nil, sprite.action(forKey: "tileRemoval") != nil {
            await run(.wait(forDuration: Self.maxHitStop))
        }
        sprite.removeFromParent()
    }
}
