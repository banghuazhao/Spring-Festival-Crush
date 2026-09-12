import SwiftUI

struct VictoryRewardView: View {
    let coins: Int
    let balance: Int
    let revealed: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    var body: some View {
        HStack(spacing: 12) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.festivalGold)
                    .overlay(Image(systemName: "star.fill").font(.caption.bold()).foregroundStyle(AppTheme.festivalGoldDark))
                    .scaleEffect(reduceMotion || revealed ? 1 : 0.7)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("+\(revealed ? coins : 0) coins")
                    .font(.title3.bold().monospacedDigit())
                    .contentTransition(.numericText())
                Text("Balance: \(balance)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.festivalRed)
                    .opacity(revealed ? 1 : 0)
            }
        }
        .padding(12)
        .background(AppTheme.festivalGold.opacity(0.15), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins earned. Balance \(balance)")
    }
}
