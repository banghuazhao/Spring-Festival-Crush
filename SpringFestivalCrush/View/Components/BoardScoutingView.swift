import SwiftUI

/// A static authored map, with no guessed candy colors or interaction with the live board.
struct BoardScoutingView: View {
    let layout: BoardScoutingLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Board scout", systemImage: "map")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.ink)
            BoardScoutingGridView(layout: layout)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityIdentifier("board-scouting-layout")
            Text("Layout only. Plain spaces receive random tiles when you play.")
                .font(.footnote)
                .foregroundStyle(AppTheme.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 12))
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
