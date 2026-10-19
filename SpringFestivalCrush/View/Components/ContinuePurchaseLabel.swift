import SwiftUI

/// Keeps the price intact when benefit text needs more room at accessibility sizes.
struct ContinuePurchaseLabel: View {
    let grant: Text
    let coinCost: Int
    let grantsMoves: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Label {
                grant
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: grantsMoves ? "plus.circle.fill" : "clock.fill")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 3) {
                Image(systemName: "circle.inset.filled").accessibilityHidden(true)
                Text(coinCost, format: .number).monospacedDigit()
            }
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.22), in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }
}
