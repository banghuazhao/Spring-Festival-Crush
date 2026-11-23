import SwiftUI

/// A goal chip at normal text sizes; a full named row once text is large enough to need it.
struct AttemptGoalRow: View {
    let target: LevelTargetData
    let title: Text
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize >= .xxLarge {
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
            .padding(.horizontal, 10)
            .background(AppTheme.cream.opacity(0.6), in: .rect(cornerRadius: AppTheme.Radius.sm))
            .accessibilityElement(children: .combine)
        } else {
            GoalChip(count: target.targetNum, label: title) {
                target.image.resizable().scaledToFit()
            }
        }
    }
}
