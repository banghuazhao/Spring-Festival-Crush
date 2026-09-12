import UIKit

@MainActor
enum LockTileAppearance {
    /// Permanent strength pips retain a common lock identity at every damage stage.
    static func image(over base: UIImage, strength: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256), format: format).image { _ in
            base.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
            let width = CGFloat(strength) * 22 + 12
            let backing = UIBezierPath(roundedRect: CGRect(x: 128 - width / 2, y: 209, width: width, height: 24), cornerRadius: 12)
            UIColor(hex: 0x123B38).setFill()
            backing.fill()
            UIColor(hex: 0xFFE0A0).setStroke()
            backing.lineWidth = 2
            backing.stroke()
            for index in 0..<strength {
                UIColor(hex: 0xFFE0A0).setFill()
                UIBezierPath(ovalIn: CGRect(x: 128 - CGFloat(strength - 1) * 11 + CGFloat(index) * 22 - 5,
                                           y: 216, width: 10, height: 10)).fill()
            }
        }
    }
}
