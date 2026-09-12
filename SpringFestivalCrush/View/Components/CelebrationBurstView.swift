import SwiftUI

/// One finite burst. Completion-driven phases keep confetti off the result controls.
struct CelebrationBurstView: View {
    var onComplete: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @State private var phase = 0
    @State private var revealID = UUID()
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    private let points: [CGPoint] = [
        .init(x: 0.08, y: 0.18), .init(x: 0.24, y: 0.10), .init(x: 0.42, y: 0.13),
        .init(x: 0.65, y: 0.11), .init(x: 0.85, y: 0.17), .init(x: 0.94, y: 0.32),
        .init(x: 0.06, y: 0.42), .init(x: 0.12, y: 0.62), .init(x: 0.30, y: 0.76),
        .init(x: 0.65, y: 0.78), .init(x: 0.85, y: 0.67), .init(x: 0.94, y: 0.50)
    ]

    var body: some View {
        GeometryReader { geometry in
            if !reduceMotion && phase < 2 {
                ForEach(points.indices, id: \.self) { index in
                    Group {
                        if index.isMultiple(of: 3) {
                            Image("StarTile").resizable().scaledToFit().frame(width: 22, height: 22)
                        } else {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index.isMultiple(of: 2) ? AppTheme.festivalGold : AppTheme.festivalRed)
                                .frame(width: 6, height: 13)
                        }
                    }
                    .rotationEffect(.degrees(phase == 0 ? 0 : Double(index * 37)))
                    .scaleEffect(phase == 0 ? 0.3 : 1)
                    .opacity(phase == 0 ? 0 : 0.9)
                    .position(x: geometry.size.width * (phase == 0 ? 0.5 : points[index].x),
                              y: geometry.size.height * (phase == 0 ? 0.34 : points[index].y))
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: reveal)
        .onDisappear { revealID = UUID() }
        .onChange(of: reduceMotion) { _, value in
            if value { revealID = UUID(); phase = 2 }
        }
    }

    private func reveal() {
        let token = UUID()
        revealID = token
        guard !reduceMotion else { phase = 2; onComplete(); return }
        withAnimation(.easeOut(duration: 0.42), completionCriteria: .logicallyComplete) {
            phase = 1
        } completion: {
            guard revealID == token else { return }
            withAnimation(.easeIn(duration: 0.45), completionCriteria: .removed) {
                phase = 2
            } completion: {
                if revealID == token { onComplete() }
            }
        }
    }
}
