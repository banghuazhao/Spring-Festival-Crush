import SwiftUI

struct BoardScoutingCellView: View {
    let cell: BoardScoutingLayout.Cell
    let size: CGFloat
    let spokenLabel: String
    let readingPriority: Double

    var body: some View {
        ZStack {
            // A transparent backing gives holes a spatial accessibility target while
            // leaving the authored board artwork unchanged.
            Color.clear
            if cell.kind != .empty {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color(UIColor(hex: 0x2E4A50)))
                artwork
                if cell.blossomLayers > 0 {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(Color(AppTheme.blossom(layers: cell.blossomLayers)), lineWidth: max(1, size * 0.1))
                    Text(verbatim: "\(cell.blossomLayers)")
                        .font(.system(size: size * 0.23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.33, height: size * 0.33)
                        .background(Color(AppTheme.blossom(layers: cell.blossomLayers)), in: Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                if cell.armorLayers > 0 {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(AppTheme.festivalGold, lineWidth: max(1.5, size * 0.08))
                        .padding(size * 0.03)
                    RoundedRectangle(cornerRadius: size * 0.15)
                        .stroke(AppTheme.festivalGold.opacity(0.7), lineWidth: 0.8)
                        .padding(size * 0.13)
                }
                if cell.iceLayers > 0 {
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .fill(Color.cyan.opacity(0.25))
                    RoundedRectangle(cornerRadius: size * 0.2)
                        .stroke(Color.cyan, lineWidth: max(1, size * 0.06))
                    Image(systemName: "snowflake")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
        .accessibilityAddTraits(.isStaticText)
        .accessibilitySortPriority(readingPriority)
        .accessibilityIdentifier("board-scout-row-\(cell.row)-column-\(cell.column)")
    }

    @ViewBuilder
    private var artwork: some View {
        switch cell.kind {
        case .empty:
            EmptyView()
        case .normal:
            Circle()
                .fill(AppTheme.creamHighlight.opacity(0.5))
                .frame(width: size * 0.16, height: size * 0.16)
        case .lock:
            PictoTile(asset: "LockTile", size: size)
        case .doubleLock:
            PictoTile(asset: "LockTile", overlay: .lockStrength(2), size: size)
        case .vaultLock:
            PictoTile(asset: "LockTile", overlay: .lockStrength(3), size: size)
        case .five:
            PictoTile(asset: "FiveTile", size: size)
        case .lightning:
            PictoTile(asset: "LightningTile", size: size)
        case .enhanced:
            PictoTile(asset: "firecracker", overlay: .enhanced, size: size)
        case .chocolate, .ingredient:
            Text(verbatim: cell.kind == .chocolate ? "🍫" : "🎁")
                .font(.system(size: size * 0.68))
        }
    }
}
