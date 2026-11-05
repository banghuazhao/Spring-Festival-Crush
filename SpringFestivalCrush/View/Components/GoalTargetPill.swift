import SwiftUI

struct GoalTargetPill: View {
    let target: LevelTargetData
    var pendingAmount = 0
    var impact = 0
    var reportsFrame = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @ScaledMetric(relativeTo: .body) private var textSize = 16
    @ScaledMetric(relativeTo: .body) private var iconSize = 26
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    private var remaining: Int { max(0, target.targetNum) + pendingAmount }

    var body: some View {
        HStack(spacing: 3) {
            target.image
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .background {
                    if reportsFrame {
                        GeometryReader { geometry in
                            Color.clear.preference(key: GoalFramePreference.self, value: [target.id: geometry.frame(in: .global)])
                        }
                    }
                }
            if remaining > 0 {
                Text("\(remaining)")
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: textSize, weight: .bold))
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
        .accessibilityLabel(goalLabel)
        .accessibilityValue(remaining > 0 ? Text("\(remaining) remaining") : Text("Complete"))
    }

    private var goalLabel: Text {
        switch target.id {
        case "firecracker": Text("firecrackers")
        case "redPocket": Text("red envelopes")
        case "dumpling": Text("dumplings")
        case "bowl": Text("bowls")
        case "lantern": Text("lanterns")
        case "zodiac": Text("Zodiac tiles")
        case "lock": Text("locks")
        case "jelly": Text("moon blossoms")
        case "ingredient": Text("gifts to deliver")
        case "lightningCombos": Text("Lightning activations")
        case "fiveCombos": Text("Lucky Five activations")
        case "enhancedCombos": Text("Blast Tile activations")
        default: Text(verbatim: target.id)
        }
    }
}
