import SpriteKit

extension GameScene {
    func configureAmbientMotion(_ sprite: SKSpriteNode) {
        sprite.action(forKey: "ambientEffect")?.speed = reduceMotion ? 0 : 1
        if reduceMotion { sprite.setScale(1) }
        for emitter in sprite.children.compactMap({ $0 as? SKEmitterNode }) {
            if emitter.userData == nil { emitter.userData = NSMutableDictionary() }
            if emitter.userData?["normalBirthRate"] == nil { emitter.userData?["normalBirthRate"] = emitter.particleBirthRate }
            emitter.particleBirthRate = reduceMotion ? 0 : (emitter.userData?["normalBirthRate"] as? CGFloat ?? 20)
            if reduceMotion { emitter.resetSimulation() }
        }
    }

    func applyMotionPreferences() {
        for sprite in symbolsLayer.children.compactMap({ $0 as? SKSpriteNode }) { configureAmbientMotion(sprite) }
    }

    /// Cached, bounded voices make the effects slider apply to every gameplay sound.
    func playSound(_ sound: GameSound, volume: Float = 1, rate: Float = 1) {
        guard settingModel.playSoundEffect, settingModel.soundEffectsVolume > 0,
              let voice = soundVoices[sound] else { return }
        let now = CACurrentMediaTime()
        if sound == .landing || sound == .falling {
            guard now - (lastSoundTimes[sound] ?? 0) > 0.06 else { return }
        }
        lastSoundTimes[sound] = now
        voice.run(.sequence([
            .stop(), .changePlaybackRate(to: rate, duration: 0),
            .changeVolume(to: volume * Float(min(1, max(0, settingModel.soundEffectsVolume))), duration: 0),
            .play()
        ]))
    }

    func setFeedbackPaused(_ paused: Bool) {
        feedbackPaused = paused
        cancelIdleHint()
        if !paused { scheduleIdleHint() }
    }

    func cancelIdleHint() {
        removeAction(forKey: "idleHintDelay")
        idleHintLayer.removeAllChildren()
    }

    func scheduleIdleHint() {
        cancelIdleHint()
        guard !feedbackPaused, settingModel.idleHintsEnabled,
              gameModel.suggestedIdleSwap() != nil else { return }
        // Scene-time pauses with gameplay. Resume starts a fresh quiet interval.
        run(.sequence([
            .wait(forDuration: 7),
            .run { [weak self] in self?.showIdleHint() }
        ]), withKey: "idleHintDelay")
    }

    func showIdleHint() {
        guard !feedbackPaused, settingModel.idleHintsEnabled,
              let swap = gameModel.suggestedIdleSwap() else { return }
        idleHintLayer.removeAllChildren()
        for symbol in [swap.symbolA, swap.symbolB] {
            guard let sprite = symbol.sprite, sprite.parent === symbolsLayer else { continue }
            let ring = SKShapeNode(rectOf: CGSize(width: gameModel.tileSize.width * 0.93,
                                                 height: gameModel.tileSize.height * 0.93), cornerRadius: 8)
            ring.position = symbolsLayer.convert(sprite.position, to: idleHintLayer)
            ring.strokeColor = UIColor(hex: 0xFFE4A3)
            ring.lineWidth = 2.5
            ring.fillColor = .clear
            ring.alpha = 0
            idleHintLayer.addChild(ring)
            // Two quiet highlights, once per idle period. No hand, sound or haptic nag.
            ring.run(.sequence([
                .fadeAlpha(to: 0.85, duration: 0.3), .fadeAlpha(to: 0.3, duration: 0.35),
                .fadeAlpha(to: 0.85, duration: 0.35), .fadeOut(withDuration: 0.45),
                .removeFromParent()
            ]))
        }
    }
}
