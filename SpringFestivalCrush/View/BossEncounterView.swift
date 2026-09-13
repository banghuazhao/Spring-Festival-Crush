import SwiftUI

struct BossEncounterView: View {
    let encounter: BossEncounter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(encounter.configuration.kind.title)
                    .font(.subheadline.bold())
                Spacer(minLength: 4)
                Text("\(encounter.health) / \(encounter.configuration.health)")
                    .font(.caption.monospacedDigit().bold())
            }
            ProgressView(value: Double(encounter.health), total: Double(encounter.configuration.health))
                .tint(AppTheme.festivalGold)
                .accessibilityLabel("Boss health")
                .accessibilityValue("\(encounter.health) of \(encounter.configuration.health)")
            Text(encounter.cue)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.22), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
