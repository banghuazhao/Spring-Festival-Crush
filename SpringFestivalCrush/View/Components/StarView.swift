import SwiftUI

struct StarView: View {
    let earned: Bool

    var body: some View {
        Image("StarTile")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)
            .saturation(earned ? 1 : 0)
            .opacity(earned ? 1 : 0.28)
            .shadow(color: earned ? AppTheme.festivalGold.opacity(0.3) : .clear, radius: 5, y: 3)
            .accessibilityLabel(earned ? "Star earned" : "Star not earned")
    }
}
