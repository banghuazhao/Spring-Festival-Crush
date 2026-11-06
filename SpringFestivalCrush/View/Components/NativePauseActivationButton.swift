import SwiftUI
import UIKit

/// A native activation surface for the Mac HUD's existing Pause artwork.
/// UIKit delivers AX actions through Objective-C without SwiftUI's ButtonAction
/// executor check. Enter the main queue before calling back into the SwiftUI view.
@MainActor
struct NativePauseActivationButton: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale
    let action: @MainActor () -> Void

    func makeUIView(context: Context) -> Control {
        Control(frame: .zero)
    }

    func updateUIView(_ button: Control, context: Context) {
        button.configure(action: action, isEnabled: isEnabled,
                         accessibilityLabel: String(localized: "Pause", locale: locale))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: Control, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height,
              width.isFinite, height.isFinite else { return nil }
        return CGSize(width: width, height: height)
    }

    static func dismantleUIView(_ button: Control, coordinator: ()) {
        button.action = nil
        button.removeTarget(nil, action: nil, for: .allEvents)
    }

    @MainActor
    final class Control: UIButton {
        var action: (@MainActor () -> Void)?

        func configure(action: @escaping @MainActor () -> Void, isEnabled: Bool, accessibilityLabel: String) {
            self.action = action
            self.isEnabled = isEnabled
            self.accessibilityLabel = accessibilityLabel
            accessibilityTraits = isEnabled ? .button : [.button, .notEnabled]
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isAccessibilityElement = true
            accessibilityLabel = String(localized: "Pause")
            accessibilityIdentifier = "game-pause"
            accessibilityTraits = .button
            addTarget(self, action: #selector(activate(_:)), for: .primaryActionTriggered)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("Use init(frame:) to create the Pause control")
        }

        @objc private nonisolated func activate(_ sender: UIButton) {
            enqueueActivation()
        }

        nonisolated override func accessibilityActivate() -> Bool {
            enqueueActivation()
            return true
        }

        private nonisolated func enqueueActivation() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isEnabled else { return }
                self.action?()
            }
        }
    }
}
