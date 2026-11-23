import SwiftUI

/// A static authored map, with no guessed candy colors or interaction with the live board.
struct BoardScoutingView: View {
    let layout: BoardScoutingLayout
    /// Drops the caption for side-by-side briefings; its sentence moves to the card's "?".
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            Group {
                if isCompact {
                    Label { GameSectionLabel("Board scout") } icon: {
                        Image(systemName: "map")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(AppTheme.ink.opacity(0.62))
                    }
                } else {
                    Label("Board scout", systemImage: "map")
                        .font(.subheadline.bold())
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Board scout") + Text(verbatim: ". ") + accessibilitySummary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("board-scouting-summary")
            BoardScoutingGridView(layout: layout)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board-scouting-layout")
            if !isCompact {
                Text("Layout only. Plain spaces receive random tiles when you play.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .gameInset(padding: isCompact ? AppTheme.Space.sm : 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("level-briefing-board-scout")
    }

    private var accessibilitySummary: Text {
        let separator = Text(verbatim: " ")
        var summary = Text("Rows: \(layout.rows). Columns: \(layout.columns). Playable spaces: \(layout.playableCount). Holes: \(layout.holeCount).")
        if layout.randomTileCount > 0 {
            summary = summary + separator + Text("Random tile spaces: \(layout.randomTileCount).")
        }
        if layout.lockCount > 0 || layout.iceCount > 0 || layout.armorCount > 0 {
            summary = summary + separator + Text("Locks: \(layout.lockCount). Ice tiles: \(layout.iceCount). Gold frames: \(layout.armorCount).")
        }
        if layout.blossomLayerCount > 0 {
            summary = summary + separator + Text("Moon blossom layers: \(layout.blossomLayerCount).")
        }
        if layout.chocolateCount > 0 {
            summary = summary + separator + Text("Chocolate tiles: \(layout.chocolateCount).")
        }
        if layout.powerUpCount > 0 {
            summary = summary + separator + Text("Pre-placed power-ups: \(layout.powerUpCount).")
        }
        if layout.giftCount > 0 || !layout.exitColumns.isEmpty {
            summary = summary + separator + Text("Gifts: \(layout.giftCount). Bottom-row exits: \(layout.exitColumns.count).")
        }
        return summary
    }
}
