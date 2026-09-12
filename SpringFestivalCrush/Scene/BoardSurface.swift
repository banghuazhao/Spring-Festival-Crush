import SpriteKit

/// Baked once per board, not a collection of per-frame shape/effect nodes.
/// The silhouette follows playable cells, including holes and disconnected islands.
enum BoardSurface {
    static let padding: CGFloat = 7

    static func image(columns: Int, rows: Int, tileSize: CGSize,
                      contains: (Int, Int) -> Bool) -> UIImage {
        let size = CGSize(width: CGFloat(columns) * tileSize.width + padding * 2,
                          height: CGFloat(rows) * tileSize.height + padding * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            let silhouette = UIBezierPath()
            var cells: [(Int, Int, CGRect)] = []
            for row in 0..<rows {
                for column in 0..<columns where contains(column, row) {
                    // UIKit is top-down; SpriteKit board rows are bottom-up.
                    let rect = CGRect(x: padding + CGFloat(column) * tileSize.width,
                                      y: padding + CGFloat(rows - row - 1) * tileSize.height,
                                      width: tileSize.width, height: tileSize.height)
                    cells.append((column, row, rect))
                    silhouette.append(UIBezierPath(roundedRect: rect, cornerRadius: 6))
                    if column + 1 < columns, contains(column + 1, row) {
                        silhouette.append(UIBezierPath(rect: CGRect(x: rect.midX, y: rect.minY,
                            width: tileSize.width, height: tileSize.height)))
                    }
                    if row + 1 < rows, contains(column, row + 1) {
                        silhouette.append(UIBezierPath(rect: CGRect(x: rect.minX, y: rect.minY - tileSize.height / 2,
                            width: tileSize.width, height: tileSize.height)))
                    }
                }
            }

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 4,
                              color: UIColor.black.withAlphaComponent(0.4).cgColor)
            UIColor(hex: 0x102B34).setFill()
            silhouette.fill()
            context.restoreGState()

            context.saveGState()
            silhouette.addClip()
            let colors = [UIColor(hex: 0x355661).cgColor, UIColor(hex: 0x182F39).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            // Quiet alternating wells separate silhouettes without a heavy checkerboard.
            for (column, row, rect) in cells {
                let well = UIBezierPath(roundedRect: rect.insetBy(dx: 1.2, dy: 1.2), cornerRadius: 5)
                UIColor.white.withAlphaComponent((column + row).isMultiple(of: 2) ? 0.055 : 0.025).setFill()
                well.fill()
                UIColor.black.withAlphaComponent(0.13).setStroke()
                well.lineWidth = 0.7
                well.stroke()
            }
            context.restoreGState()

            // Exposed edges only: no gold lines between adjacent playable cells.
            context.setLineCap(.round)
            context.setLineWidth(1.7)
            context.setStrokeColor(UIColor(hex: 0xC5AA70).cgColor)
            for (column, row, rect) in cells {
                let radius: CGFloat = 6
                let top = row == rows - 1 || !contains(column, row + 1)
                let bottom = row == 0 || !contains(column, row - 1)
                let left = column == 0 || !contains(column - 1, row)
                let right = column == columns - 1 || !contains(column + 1, row)
                func edge(_ a: CGPoint, _ b: CGPoint) {
                    context.move(to: a); context.addLine(to: b)
                }
                func corner(_ center: CGPoint, _ start: CGFloat) {
                    context.move(to: CGPoint(x: center.x + cos(start) * radius, y: center.y + sin(start) * radius))
                    context.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .pi / 2, clockwise: false)
                }
                if top {
                    edge(CGPoint(x: rect.minX + (left ? radius : 0), y: rect.minY), CGPoint(x: rect.maxX - (right ? radius : 0), y: rect.minY))
                }
                if bottom {
                    edge(CGPoint(x: rect.minX + (left ? radius : 0), y: rect.maxY), CGPoint(x: rect.maxX - (right ? radius : 0), y: rect.maxY))
                }
                if left {
                    edge(CGPoint(x: rect.minX, y: rect.minY + (top ? radius : 0)), CGPoint(x: rect.minX, y: rect.maxY - (bottom ? radius : 0)))
                }
                if right {
                    edge(CGPoint(x: rect.maxX, y: rect.minY + (top ? radius : 0)), CGPoint(x: rect.maxX, y: rect.maxY - (bottom ? radius : 0)))
                }
                if top && left { corner(CGPoint(x: rect.minX + radius, y: rect.minY + radius), .pi) }
                if top && right { corner(CGPoint(x: rect.maxX - radius, y: rect.minY + radius), -.pi / 2) }
                if bottom && right { corner(CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), 0) }
                if bottom && left { corner(CGPoint(x: rect.minX + radius, y: rect.maxY - radius), .pi / 2) }
            }
            context.strokePath()
        }
    }
}
