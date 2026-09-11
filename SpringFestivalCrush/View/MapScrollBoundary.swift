import SwiftUI
import UIKit

/// SwiftUI on iOS 17 has no "never bounce" option for oversized scroll content.
/// Configure only the enclosing map scroll view; other screens keep their usual behavior.
struct MapScrollBoundary: UIViewRepresentable {
    func makeUIView(context: Context) -> BoundaryView {
        let view = BoundaryView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: BoundaryView, context: Context) {
        uiView.constrainEnclosingScrollView()
    }

    final class BoundaryView: UIView {
        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            constrainEnclosingScrollView()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            constrainEnclosingScrollView()
        }

        func constrainEnclosingScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    scrollView.bounces = false
                    scrollView.alwaysBounceHorizontal = false
                    scrollView.alwaysBounceVertical = false
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
