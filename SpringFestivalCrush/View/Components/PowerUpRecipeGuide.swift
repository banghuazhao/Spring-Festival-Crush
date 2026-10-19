import SwiftUI

/// A static reference for existing combinations; opening it never starts a game or uses a move.
struct PowerUpRecipeGuide: View {
    @State private var isExpanded: Bool

    init(initiallyExpanded: Bool = false) {
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Swap neighboring power-ups in either order. A regular swap uses one move.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(PowerUpCombination.allCases) { combination in
                    PowerUpRecipeRow(combination: combination)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Combo recipes", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
        .tint(AppTheme.festivalRed)
        .padding(12)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.festivalGold, lineWidth: 1.5))
        .transaction { $0.animation = nil }
        .accessibilityIdentifier("combo-recipes-disclosure")
    }
}
