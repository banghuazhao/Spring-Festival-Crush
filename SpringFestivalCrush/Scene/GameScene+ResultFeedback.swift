import SpriteKit

extension GameScene {
    /// A loss settles the board in place, preserving context behind the retry panel.
    func animateGameOver() async {
        cancelHitStop()
        gameLayer.removeAction(forKey: "screenShake")
        gameLayer.position = .zero
        cancelIdleHint()
        hideSelectionIndicator()
        await gameLayer.run(.fadeAlpha(to: 0.65, duration: 0.20))
    }

    /// Presentation only: never award rewards or navigate from this effect.
    func playVictoryAccent() {
        cancelHitStop()
        gameLayer.removeAction(forKey: "screenShake")
        gameLayer.position = .zero
        cancelIdleHint()
        guard !reduceMotion else { return }
        let lift = SKAction.scale(to: 1.015, duration: 0.12)
        lift.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.20)
        settle.timingMode = .easeInEaseOut
        gameLayer.run(.sequence([lift, settle]), withKey: "victorySettle")
    }
}
