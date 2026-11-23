import SwiftUI

struct SettingsSoundControl: View {
    let title: String
    let icon: String
    @Binding var enabled: Bool
    @Binding var volume: Double
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(title: LocalizedStringKey(title), icon: icon) {
                Toggle(isOn: $enabled) { Text(LocalizedStringKey(title)) }
                    .labelsHidden()
            }
            // The slider only earns its space while the sound is on.
            if enabled {
                HStack(spacing: AppTheme.Space.sm) {
                    Slider(value: $volume, in: 0...1, step: 0.05) {
                        Text("\(String(localized: String.LocalizationValue(title))) volume")
                    }
                    .accessibilityValue(volume.formatted(.percent.precision(.fractionLength(0))))
                    Text(volume, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.ink.opacity(0.7))
                        .frame(minWidth: 38, alignment: .trailing)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 35)
                .padding(.bottom, 6)
                .transition(.opacity)
            }
        }
        .animation(systemReduceMotion || reducedEffects ? nil : .easeOut(duration: 0.18), value: enabled)
    }
}
