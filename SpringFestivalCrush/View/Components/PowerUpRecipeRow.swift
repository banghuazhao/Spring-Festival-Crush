import SwiftUI

/// Keeps pair art above wrapping text so every recipe fits narrow phones and large text sizes.
struct PowerUpRecipeRow: View {
    let combination: PowerUpCombination

    private var firstType: SymbolType { combination.demoTypes.0 }
    private var secondType: SymbolType { combination.demoTypes.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PictoTile(asset: asset(for: firstType), overlay: firstType.isEnhanced ? .enhanced : .none, size: 36)
                PictoArrow(systemName: "arrow.left.arrow.right", size: 16)
                PictoTile(asset: asset(for: secondType), overlay: secondType.isEnhanced ? .enhanced : .none, size: 36)
            }
            .accessibilityHidden(true)

            Text(LocalizedStringKey(combination.title))
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(combination.detail))
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.55), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("combo-recipe-\(combination.rawValue)")
    }

    private func asset(for type: SymbolType) -> String {
        switch type {
        case .five: "FiveTile"
        case .lightning: "LightningTile"
        default: type.spriteName
        }
    }
}
