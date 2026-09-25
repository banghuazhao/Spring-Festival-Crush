import SpriteKit
import SwiftUI

extension GameScene {
    func animateGoalProgress(_ progress: [GoalProgress]) {
        guard let view, gameModel.gameState == .inProgress else { return }
        let targets = gameModel.createLevelTargetDatas()
        for receipt in progress {
            guard let target = targets.first(where: { $0.id == receipt.goalID }) else { continue }
            let scenePoint = symbolsLayer.convert(pointFor(column: receipt.column, row: receipt.row), to: self)
            let windowPoint = view.convert(convertPoint(toView: scenePoint), to: nil)
            feedback.collect(receipt, image: target.image, source: windowPoint, reduceMotion: reduceMotion)
        }
    }

    func animateCascade(depth: Int) {
        let cue = CascadeFeedback(depth: depth)
        playSound(.match, volume: cue.volume * 0.7, rate: cue.playbackRate)
        // Each cascade climbs one guzheng string, so long chains literally sound richer.
        playSound(.note(cue.noteStep), volume: 0.75)
        if depth >= 2 { HapticManager.cascade(depth: depth) }
        guard let title = cue.title else { return }
        childNode(withName: "cascadeCaption")?.removeFromParent()
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.name = "cascadeCaption"
        label.text = String(localized: "\(title)  ·  \(depth) cascades")
        label.fontSize = min(CGFloat(17 + cue.tier), gameModel.tileSize.width * 0.55)
        label.fontColor = UIColor(hex: 0xFFE4A3)
        label.position = CGPoint(x: 0, y: gameModel.tileSize.height * CGFloat(gameModel.numRows) / 2 + 12)
        label.zPosition = 500
        label.alpha = 0
        addChild(label)
        let entrance: SKAction = reduceMotion ? .fadeIn(withDuration: 0.12) : .group([
            .fadeIn(withDuration: 0.1),
            .sequence([.scale(to: 1.08, duration: 0.12), .scale(to: 1, duration: 0.1)])
        ])
        label.run(.sequence([entrance, .wait(forDuration: 0.3), .fadeOut(withDuration: 0.18), .removeFromParent()]))
        if depth >= 4 { screenShake(magnitude: 2, duration: 0.12) }
    }

    func animateHammerImpact(_ symbol: Symbol) async {
        let position = symbolsLayer.convert(pointFor(column: symbol.column, row: symbol.row), to: gameLayer)
        let radius = gameModel.tileSize.width * 0.48
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = position
        ring.strokeColor = UIColor(hex: 0xFFD477)
        ring.lineWidth = 3
        ring.fillColor = UIColor(hex: 0xFFD477).withAlphaComponent(0.12)
        ring.zPosition = 600
        gameLayer.addChild(ring)

        if !reduceMotion {
            let hammer = SKSpriteNode(imageNamed: "HammerBoosterIcon")
            hammer.size = CGSize(width: radius * 3, height: radius * 3)
            hammer.anchorPoint = CGPoint(x: 0.7, y: 0.2)
            hammer.position = CGPoint(x: position.x + radius * 0.7, y: position.y + radius * 0.3)
            hammer.zPosition = 601
            hammer.zRotation = -0.25
            gameLayer.addChild(hammer)
            let windup = SKAction.rotate(toAngle: -0.85, duration: 0.12)
            windup.timingMode = .easeOut
            let strike = SKAction.rotate(toAngle: 0.35, duration: 0.1)
            strike.timingMode = .easeIn
            await hammer.run(.sequence([windup, strike]))
            hammer.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]), completion: {})
            screenShake(magnitude: 3, duration: 0.16)
        }
        HapticManager.bigMatch()
        playSound(.hammer)
        let release: SKAction = reduceMotion ? .fadeOut(withDuration: 0.16) : .group([
            .scale(to: 1.5, duration: 0.18), .fadeOut(withDuration: 0.18)
        ])
        ring.run(.sequence([release, .removeFromParent()]), completion: {})
    }

    func animateShuffle(_ symbols: Set<Symbol>) async {
        // The model has changed cell coordinates; sprites still occupy their old cells.
        // Keep identity, specials, frozen tiles and authored blockers intact.
        let moving = symbols.compactMap { symbol -> (SKSpriteNode, CGPoint)? in
            guard let sprite = symbol.sprite else { return nil }
            let destination = pointFor(column: symbol.column, row: symbol.row)
            guard sprite.position != destination else { return nil }
            return (sprite, destination)
        }
        guard !moving.isEmpty else { return }
        HapticManager.swap()
        playSound(.swap)
        let shuffleLayer = SKNode()
        shuffleLayer.position = symbolsLayer.position
        shuffleLayer.zPosition = 400
        gameLayer.addChild(shuffleLayer)
        let duration = reduceMotion ? 0.2 : 0.48
        for (index, entry) in moving.enumerated() {
            let (sprite, destination) = entry
            sprite.removeFromParent()
            shuffleLayer.addChild(sprite)
            if reduceMotion {
                sprite.run(.sequence([
                    .fadeAlpha(to: 0.25, duration: 0.1), .move(to: destination, duration: 0),
                    .fadeIn(withDuration: 0.1)
                ]), withKey: "shuffle")
            } else {
                let source = sprite.position
                let bend = CGFloat(index.isMultiple(of: 2) ? 1 : -1) * gameModel.tileSize.width * 0.75
                let path = CGMutablePath()
                path.move(to: source)
                path.addQuadCurve(to: destination, control: CGPoint(
                    x: (source.x + destination.x) / 2 + bend,
                    y: (source.y + destination.y) / 2 + gameModel.tileSize.height * 0.6
                ))
                let travel = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.32)
                travel.timingMode = .easeInEaseOut
                sprite.run(.sequence([
                    .scale(to: 0.78, duration: 0.06), travel,
                    .scale(to: 1, duration: 0.1)
                ]), withKey: "shuffle")
            }
        }
        await run(.wait(forDuration: duration))
        for (sprite, destination) in moving {
            sprite.removeAction(forKey: "shuffle")
            sprite.position = destination
            sprite.setScale(1)
            sprite.alpha = 1
            sprite.removeFromParent()
            symbolsLayer.addChild(sprite)
        }
        shuffleLayer.removeFromParent()
        HapticManager.match()
    }
}
