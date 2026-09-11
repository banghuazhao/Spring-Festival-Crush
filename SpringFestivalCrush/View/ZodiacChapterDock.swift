import SwiftUI

struct ZodiacChapterDock: View {
    let theme: ZodiacChapterTheme
    let levelNumber: Int
    let isComplete: Bool
    let locate: () -> Void
    let play: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: locate) {
                Label("Find level", systemImage: "location.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 52, height: 52)
                    .background(theme.sky, in: .rect(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(theme.accent.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.gameIcon)
            .accessibilityHint("Scrolls to the recommended level")

            Button(action: play) {
                Label(isComplete ? "Replay Level \(levelNumber)" : "Play Level \(levelNumber)", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.gamePrimary(gradient: theme.gradient))
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("chapter-play")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background {
            AppTheme.creamHighlight.opacity(0.97).ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(theme.accent.opacity(0.15)).frame(height: 1) }
        }
    }
}
