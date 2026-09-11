import SwiftUI

/// Lightweight native scenery stays sharp at phone and iPad sizes, without stretching art.
struct ZodiacChapterScenery: View {
    let theme: ZodiacChapterTheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [theme.sky, theme.sky, theme.ground], startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    let unit = min(size.width, 600)
                    for layer in 0..<3 {
                        let baseline = size.height * (0.42 + Double(layer) * 0.23)
                        var hill = Path()
                        hill.move(to: CGPoint(x: 0, y: baseline))
                        hill.addCurve(
                            to: CGPoint(x: size.width, y: baseline + unit * 0.12),
                            control1: CGPoint(x: size.width * 0.35, y: baseline - unit * 0.45),
                            control2: CGPoint(x: size.width * 0.65, y: baseline + unit * 0.35)
                        )
                        hill.addLine(to: CGPoint(x: size.width, y: size.height))
                        hill.addLine(to: CGPoint(x: 0, y: size.height))
                        hill.closeSubpath()
                        context.fill(hill, with: .color(theme.accent.opacity(0.035 + Double(layer) * 0.025)))
                    }
                    for index in 0..<7 {
                        let x = size.width * (index.isMultiple(of: 2) ? 0.04 : 0.9)
                        let y = CGFloat(index) * size.height / 6
                        let cloud = CGRect(x: x - 40, y: y, width: 110, height: 28)
                        context.fill(Path(ellipseIn: cloud), with: .color(.white.opacity(0.26)))
                        context.fill(Path(ellipseIn: cloud.offsetBy(dx: 30, dy: -12).insetBy(dx: 12, dy: 0)), with: .color(.white.opacity(0.26)))
                    }
                }
                Circle()
                    .fill(AppTheme.creamHighlight.opacity(0.65))
                    .frame(width: 150, height: 150)
                    .blur(radius: 2)
                    .position(x: geometry.size.width * 0.88, y: geometry.size.height * 0.16)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
