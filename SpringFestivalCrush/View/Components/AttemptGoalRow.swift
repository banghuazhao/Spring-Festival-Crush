import SwiftUI

struct AttemptGoalRow: View {
    let target: LevelTargetData
    let title: Text
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 10))
        layout {
            HStack(alignment: .center, spacing: 10) {
                target.image.resizable().scaledToFit()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                title
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(target.targetNum, format: .number)
                .font(.headline.bold().monospacedDigit())
                .fixedSize()
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.55), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
