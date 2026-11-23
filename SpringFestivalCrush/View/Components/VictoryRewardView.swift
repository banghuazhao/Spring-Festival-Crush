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
        HStack(spacing: AppTheme.Space.sm) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.goldGradient)
                    .overlay(Image(systemName: "star.fill").font(.caption2.bold()).foregroundStyle(AppTheme.festivalGoldDark))
                    .scaleEffect(reduceMotion || revealed ? 1 : 0.7)
                    .accessibilityHidden(true)
            }
            Text("+\(revealed ? coins : 0) coins")
                .font(.system(.headline, design: .rounded, weight: .black).monospacedDigit())
                .contentTransition(.numericText())
            Spacer(minLength: AppTheme.Space.sm)
            Text("Balance: \(balance)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .gameInset(padding: AppTheme.Space.sm, radius: AppTheme.Radius.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins earned. Balance \(balance)")
    }
}
