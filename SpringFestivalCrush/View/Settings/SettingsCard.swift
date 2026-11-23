import SwiftUI

/// A titled group of settings: the label sits on the backdrop, the rows on one paper card.
struct SettingsCard<Content: View, HeaderAccessory: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let headerAccessory: HeaderAccessory
    @ViewBuilder let content: Content

    init(title: String, icon: String,
         @ViewBuilder headerAccessory: () -> HeaderAccessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(LocalizedStringKey(title), systemImage: icon)
                    .font(.footnote.weight(.heavy))
                    .fontDesign(.rounded)
                    .foregroundStyle(AppTheme.festivalGold)
                    .accessibilityAddTraits(.isHeader)
                headerAccessory
            }
            .padding(.leading, AppTheme.Space.xs)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.ink)
            .tint(AppTheme.festivalRed)
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.paper, in: .rect(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
            )
        }
    }
}

extension SettingsCard where HeaderAccessory == EmptyView {
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, icon: icon, headerAccessory: { EmptyView() }, content: content)
    }
}

/// One setting on one line: icon, name, an optional "?" for the explanation, then its control.
struct SettingsRow<Accessory: View>: View {
    let title: LocalizedStringKey
    let icon: String
    var help: LocalizedStringKey? = nil
    @ViewBuilder let accessory: Accessory
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: AppTheme.Space.sm))
        layout {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.festivalRed)
                    .frame(width: 26, height: 26)
                    .background(AppTheme.cream, in: .rect(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let help {
                    HelpTipButton(Text(help), size: 15)
                }
            }
            .layoutPriority(1)
            if !isStacked { Spacer(minLength: AppTheme.Space.xs) }
            accessory
        }
        .frame(minHeight: 44)
    }
}

/// The row separator, inset to line up with the row titles.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline.opacity(0.7))
            .frame(height: 0.5)
            .padding(.leading, 35)
    }
}
