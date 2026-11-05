import SpriteKit
import SwiftUI

/// Owns the native SpriteKit surface and its spatial accessibility container together.
struct GameBoardView: UIViewRepresentable {
    @ObservedObject var gameModel: GameModel
    let scene: GameScene
    let isPaused: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoardAccessibilityView {
        let view = BoardAccessibilityView(frame: .zero)
        context.coordinator.install(on: view)
        context.coordinator.present(scene, in: view, isPaused: isPaused)
        return view
    }

    func updateUIView(_ view: BoardAccessibilityView, context: Context) {
        context.coordinator.present(scene, in: view, isPaused: isPaused)
        // A Dynamic Type layout change can rehost the same scene in a fresh view.
        // Its previous owner paused feedback during teardown; synchronize even when
        // the new view's default `gameplayPaused` already equals `isPaused`.
        if scene.feedbackPaused != isPaused { scene.setFeedbackPaused(isPaused) }
        view.gameplayPaused = isPaused
        view.isPaused = isPaused
        view.refreshAccessibility()
    }

    static func dismantleUIView(_ view: BoardAccessibilityView, coordinator: Coordinator) {
        view.pendingAction?.cancel()
        if let scene = view.scene as? GameScene, scene.view === view {
            scene.setFeedbackPaused(true)
            scene.cancelBlastPreview()
        }
        view.presentScene(nil)
        view.gameplayPaused = true
        coordinator.remove(from: view)
    }

    /// Owns single-finger drags that start on the board while leaving the SpriteKit
    /// touch stream intact. The enclosing large-text page scrolls from its HUD/tools.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let boardPan = UIPanGestureRecognizer()

        func present(_ scene: GameScene, in view: BoardAccessibilityView, isPaused: Bool = false) {
            guard view.scene !== scene || scene.view !== view else { return }
            // SKView can retain a stale scene reference after another view presents
            // it. Detach the previous owner first so its later SwiftUI teardown
            // cannot clear the new owner's scene.view association.
            if let previousView = scene.view, previousView !== view {
                previousView.presentScene(nil)
            }
            view.presentScene(scene)
            // Detaching cancels idle hints through willMove(from:). Reapply the
            // desired state once per attachment, including an already-active scene.
            scene.setFeedbackPaused(isPaused)
        }

        func install(on view: BoardAccessibilityView) {
            boardPan.name = "board-direct-drag"
            boardPan.maximumNumberOfTouches = 1
            boardPan.cancelsTouchesInView = false
            boardPan.delaysTouchesBegan = false
            boardPan.delaysTouchesEnded = false
            boardPan.delegate = self
            view.addGestureRecognizer(boardPan)
        }

        func remove(from view: BoardAccessibilityView) {
            view.removeGestureRecognizer(boardPan)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = gestureRecognizer.view as? BoardAccessibilityView,
                  let scene = view.scene as? GameScene else { return false }
            return !view.gameplayPaused && scene.canHandleBoardTouch
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === boardPan,
                  let board = gestureRecognizer.view,
                  let scroll = otherGestureRecognizer.view as? UIScrollView,
                  otherGestureRecognizer === scroll.panGestureRecognizer else { return false }
            // A dynamic failure requirement handles SwiftUI's lazily inserted scroll
            // ancestors without changing their delegates or persisting dependencies.
            return board.isDescendant(of: scroll)
        }
    }
}
