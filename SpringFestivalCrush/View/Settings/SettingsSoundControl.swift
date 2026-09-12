import SwiftUI

struct SettingsSoundControl: View {
    let title: String
    let icon: String
    @Binding var enabled: Bool
    @Binding var volume: Double

    var body: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $enabled) { Label(title, systemImage: icon) }
            HStack(spacing: 12) {
                Slider(value: $volume, in: 0...1, step: 0.05) {
                    Text("\(title) volume")
                }
                .accessibilityValue(volume.formatted(.percent.precision(.fractionLength(0))))
                Text(volume, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.monospacedDigit())
                    .frame(minWidth: 44)
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
    }
}
