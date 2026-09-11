import SwiftUI

struct ZodiacLevelTrail: View {
    @ScaledMetric(relativeTo: .body) private var scaledRowHeight = 178
    let records: [LevelRecord]
    let currentLevel: Int?
    let unlockAll: Bool
    let theme: ZodiacChapterTheme
    let select: (LevelRecord) -> Void

    // Nodes are graphic medallions; avoid enormous gaps at accessibility text sizes.
    private var rowHeight: CGFloat { min(scaledRowHeight, 230) }

    private func fraction(at index: Int) -> CGFloat {
        [0.5, 0.24, 0.5, 0.76][index % 4]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Spacer(minLength: 0).frame(width: max(0, geometry.size.width * fraction(at: index) - 65))
                        ZodiacLevelNode(
                            number: record.number,
                            isUnlocked: record.isUnlocked || unlockAll,
                            isComplete: record.isComplete,
                            isCurrent: record.number == currentLevel,
                            isFinal: index == records.count - 1,
                            stars: record.stars,
                            theme: theme
                        ) { select(record) }
                        Spacer(minLength: 0)
                    }
                    .frame(height: geometry.size.height)
                }
                .frame(height: rowHeight)
                .id(record.number)
            }
        }
        .background {
            Canvas { context, size in
                guard records.count > 1 else { return }
                for index in 0..<(records.count - 1) {
                    let start = CGPoint(x: size.width * fraction(at: index), y: rowHeight * (CGFloat(index) + 0.5))
                    let end = CGPoint(x: size.width * fraction(at: index + 1), y: start.y + rowHeight)
                    var path = Path()
                    path.move(to: start)
                    path.addCurve(to: end,
                                  control1: CGPoint(x: start.x, y: start.y + rowHeight * 0.55),
                                  control2: CGPoint(x: end.x, y: end.y - rowHeight * 0.55))
                    context.stroke(path, with: .color(theme.accent.opacity(0.13)), style: StrokeStyle(lineWidth: 26, lineCap: .round))
                    context.stroke(path, with: .color(AppTheme.creamHighlight.opacity(0.88)), style: StrokeStyle(lineWidth: 19, lineCap: .round))
                    context.stroke(path, with: .color(records[index].isComplete ? AppTheme.festivalGoldDark : theme.accent.opacity(0.3)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 10]))
                }

                for index in stride(from: 1, to: records.count, by: 3) {
                    let leftSide = fraction(at: index) > 0.4
                    let point = CGPoint(x: size.width * (leftSide ? 0.1 : 0.88), y: rowHeight * (CGFloat(index) + 0.55))
                    let image = context.resolve(Text(theme.motif).font(.system(size: 36)))
                    context.draw(image, at: point)
                    let rock = CGRect(x: point.x - 25, y: point.y + 25, width: 50, height: 12)
                    context.fill(Path(ellipseIn: rock), with: .color(theme.accent.opacity(0.08)))
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
    }
}
