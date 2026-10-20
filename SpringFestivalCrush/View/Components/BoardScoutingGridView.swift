import SwiftUI

/// Proportional spacing keeps even rectangular authored maps inside the proposed width.
struct BoardScoutingGridView: View {
    let layout: BoardScoutingLayout
    private let spacingFraction: CGFloat = 0.08
    private var widthUnits: CGFloat { CGFloat(layout.columns) + CGFloat(layout.columns - 1) * spacingFraction }
    private var heightUnits: CGFloat {
        CGFloat(layout.rows) + CGFloat(layout.rows - 1) * spacingFraction
            + (layout.exitColumns.isEmpty ? 0 : spacingFraction + 0.45)
    }

    var body: some View {
        GeometryReader { geometry in
            let cellSize = max(0, geometry.size.width / widthUnits)
            VStack(spacing: cellSize * spacingFraction) {
                ForEach((0..<layout.rows).reversed(), id: \.self) { row in
                    HStack(spacing: cellSize * spacingFraction) {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            if let cell = layout.cell(column: column, row: row) {
                                BoardScoutingCellView(cell: cell, size: cellSize)
                            }
                        }
                    }
                }
                if !layout.exitColumns.isEmpty {
                    HStack(spacing: cellSize * spacingFraction) {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: cellSize * 0.34, weight: .heavy))
                                .foregroundStyle(AppTheme.festivalGoldDark)
                                .opacity(layout.exitColumns.contains(column) ? 1 : 0)
                                .frame(width: cellSize, height: cellSize * 0.45)
                        }
                    }
                }
            }
        }
        .aspectRatio(widthUnits / heightUnits, contentMode: .fit)
        .frame(maxWidth: min(280, widthUnits * 34))
        .allowsHitTesting(false)
    }
}
