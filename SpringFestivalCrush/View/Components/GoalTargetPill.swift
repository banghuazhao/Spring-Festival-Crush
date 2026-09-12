import SwiftUI

struct GoalTargetPill: View {
    let target: LevelTargetData
    var pendingAmount = 0
    var impact = 0
    var reportsFrame = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    private var remaining: Int { max(0, target.targetNum) + pendingAmount }

    var body: some View {
        HStack(spacing: 3) {
            target.image
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .background {
                    if reportsFrame {
                        GeometryReader { geometry in
                            Color.clear.preference(key: GoalFramePreference.self, value: [target.id: geometry.frame(in: .global)])
                        }
                    }
                }
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.creamHighlight)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 3)
        .phaseAnimator([false, true, false], trigger: impact) { content, highlighted in
            content
                .scaleEffect(highlighted && !reduceMotion ? 1.12 : 1)
                .background(Capsule().fill(AppTheme.festivalGold.opacity(highlighted ? 0.28 : 0)))
        } animation: { _ in
            .easeOut(duration: 0.14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(target.id.replacingOccurrences(of: "Combos", with: " combos"))
        .accessibilityValue(remaining > 0 ? "\(remaining) remaining" : "Complete")
    }
}
