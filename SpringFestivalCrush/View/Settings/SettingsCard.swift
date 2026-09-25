import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey(title), systemImage: icon)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.festivalRed)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .font(.body)
        .foregroundStyle(AppTheme.ink)
        .tint(AppTheme.festivalRed)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cream, in: .rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.festivalGold.opacity(0.9), lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 5)
    }
}
