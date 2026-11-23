import SwiftUI

struct ZodiacChapterDock: View {
    let theme: ZodiacChapterTheme
    let levelNumber: Int
    let isComplete: Bool
    let locate: () -> Void
    let play: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: locate) {
                Label("Find level", systemImage: "location.fill")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.paper, in: .rect(cornerRadius: AppTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .strokeBorder(AppTheme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.gameIcon)
            .accessibilityHint("Scrolls to the recommended level")

            Button(action: play) {
                Label(isComplete ? String(localized: "Replay Level \(levelNumber)") : String(localized: "Play Level \(levelNumber)"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.gameGold)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("chapter-play")
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, 10)
        .padding(.bottom, AppTheme.Space.xs)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(AppTheme.creamHighlight.opacity(0.72))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
        }
    }
}
