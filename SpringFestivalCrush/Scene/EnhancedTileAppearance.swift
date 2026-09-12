import SpriteKit

/// Shared visual grammar for a same-type tile carrying an area-blast charge.
/// Composited once into TileArtwork's cache: no extra resting nodes or particles.
@MainActor
enum EnhancedTileAppearance {
    static func image(over base: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { renderer in
            let context = renderer.cgContext
            let frame = UIBezierPath()
            let points: [CGPoint] = [
                CGPoint(x: 68, y: 16), CGPoint(x: 188, y: 16),
                CGPoint(x: 240, y: 68), CGPoint(x: 240, y: 188),
                CGPoint(x: 188, y: 240), CGPoint(x: 68, y: 240),
                CGPoint(x: 16, y: 188), CGPoint(x: 16, y: 68)
            ]
            frame.move(to: points[0])
            points.dropFirst().forEach { frame.addLine(to: $0) }
            frame.close()
            frame.lineJoinStyle = .round
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 4,
                              color: UIColor.black.withAlphaComponent(0.5).cgColor)
            UIColor(hex: 0x104D4C).setFill()
            frame.fill()
            context.restoreGState()
            context.saveGState()
            frame.addClip()
            let colors = [UIColor(hex: 0x398B79).cgColor, UIColor(hex: 0x124A4F).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 32, y: 16),
                                           end: CGPoint(x: 224, y: 240), options: [])
            }
            context.restoreGState()
            UIColor(hex: 0x6D4822).setStroke()
            frame.lineWidth = 10
            frame.stroke()
            UIColor(hex: 0xF9D783).setStroke()
            frame.lineWidth = 5
            frame.stroke()

            // Retain the original silhouette, palette, proportions and center.
            base.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))

            // A fixed burst seal reads in grayscale and when Reduce Motion is on.
            let seal = UIBezierPath(ovalIn: CGRect(x: 171, y: 171, width: 68, height: 68))
            UIColor(hex: 0x68451F).setFill()
            seal.fill()
            UIColor(hex: 0xFFE29B).setStroke()
            seal.lineWidth = 5
            seal.stroke()
            let burst = UIBezierPath()
            for index in 0..<16 {
                let angle = CGFloat(index) * .pi / 8 - .pi / 2
                let radius: CGFloat = index.isMultiple(of: 2) ? 24 : 11
                let point = CGPoint(x: 205 + cos(angle) * radius, y: 205 + sin(angle) * radius)
                if index == 0 { burst.move(to: point) } else { burst.addLine(to: point) }
            }
            burst.close()
            UIColor(hex: 0xFFF3CA).setFill()
            burst.fill()
        }
    }
}
