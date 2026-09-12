import SwiftUI

/// Quadratic arc, compatible with the app's iOS 17 deployment target.
struct GoalFlightPath: GeometryEffect {
    var progress: CGFloat
    let source: CGPoint
    let destination: CGPoint
    var lag: CGFloat = 0
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = min(1, max(0, progress - lag))
        let control = CGPoint(
            x: source.x + (destination.x - source.x) * 0.2,
            y: min(source.y, destination.y) - 24
        )
        let x = (1-t)*(1-t)*source.x + 2*(1-t)*t*control.x + t*t*destination.x
        let y = (1-t)*(1-t)*source.y + 2*(1-t)*t*control.y + t*t*destination.y
        return ProjectionTransform(CGAffineTransform(translationX: x - size.width / 2, y: y - size.height / 2))
    }
}
