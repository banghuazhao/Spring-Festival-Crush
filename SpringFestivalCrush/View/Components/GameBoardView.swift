import SpriteKit
import SwiftUI

/// Owns the native SpriteKit surface and its spatial accessibility container together.
struct GameBoardView: UIViewRepresentable {
    @ObservedObject var gameModel: GameModel
    let scene: GameScene
    let isPaused: Bool

    func makeUIView(context: Context) -> BoardAccessibilityView {
        let view = BoardAccessibilityView(frame: .zero)
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: BoardAccessibilityView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        view.gameplayPaused = isPaused
        view.isPaused = isPaused
        view.refreshAccessibility()
    }

    static func dismantleUIView(_ view: BoardAccessibilityView, coordinator: ()) {
        view.gameplayPaused = true
        view.pendingAction?.cancel()
        (view.scene as? GameScene)?.cancelBlastPreview()
        view.presentScene(nil)
    }
}
