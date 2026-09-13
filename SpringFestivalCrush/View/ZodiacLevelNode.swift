import SwiftUI

struct ZodiacLevelNode: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @ScaledMetric(relativeTo: .title) private var numberSize = 28
    @ScaledMetric(relativeTo: .caption2) private var badgeSize = 10

    let number: Int
    let isUnlocked: Bool
    let isComplete: Bool
    let isCurrent: Bool
    let isFinal: Bool
    let stars: Int
    let theme: ZodiacChapterTheme
    var celebrationProgress: CGFloat? = nil
    var isNewUnlock = false
    let action: () -> Void

    private var face: Color { isUnlocked ? (isCurrent ? theme.accent : AppTheme.creamHighlight) : Color(white: 0.65) }
    private var ink: Color { isUnlocked ? (isCurrent ? .white : theme.accent) : Color(white: 0.28) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(isNewUnlock ? "UNLOCKED!" : (isFinal ? "BOSS" : (isCurrent ? "PLAY NEXT" : " ")))
                    .font(.system(size: min(badgeSize, 14), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .tracking(1)
                    .foregroundStyle(isCurrent ? .white : theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(isCurrent ? theme.accent : .clear, in: Capsule())

                ZStack {
                    if let progress = celebrationProgress, !reduceMotion {
                        Circle()
                            .stroke(AppTheme.festivalGold, lineWidth: 5)
                            .frame(width: 98, height: 98)
                            .scaleEffect(0.8 + 0.7 * progress)
                            .opacity(1 - progress)
                            .accessibilityHidden(true)
                    }
                    if isCurrent {
                        Circle().stroke(theme.accent.opacity(0.2), lineWidth: 3)
                            .frame(width: 102, height: 102)
                            .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
                                content.scaleEffect(reduceMotion ? 1 : (phase ? 1.09 : 1))
                                    .opacity(reduceMotion ? 1 : (phase ? 0.35 : 1))
                            } animation: { _ in .easeInOut(duration: 1.3) }
                    }
                    Circle().fill(isUnlocked ? theme.accent.opacity(0.7) : Color(white: 0.46))
                        .frame(width: 82, height: 82).offset(y: 6)
                    Circle().fill(face.gradient)
                        .frame(width: 82, height: 82)
                        .overlay(Circle().stroke(isUnlocked ? AppTheme.festivalGold : .white.opacity(0.55), lineWidth: 3))
                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1).padding(7))
                    VStack(spacing: 0) {
                        if isFinal {
                            Image(systemName: "crown.fill")
                                .font(.system(size: min(badgeSize + 2, 16), weight: .black))
                        }
                        Text(number, format: .number)
                            .font(.system(size: min(numberSize, 40), weight: .black, design: .rounded))
                    }
                    .foregroundStyle(ink)

                    if !isUnlocked || isComplete {
                        Image(systemName: isComplete ? "checkmark" : "lock.fill")
                            .font(.system(size: min(badgeSize + 2, 16), weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 25, height: 25)
                            .background(isComplete ? theme.accent : Color(white: 0.42), in: Circle())
                            .overlay(Circle().stroke(AppTheme.creamHighlight, lineWidth: 2))
                            .offset(x: 33, y: 28)
                    }
                }
                .frame(width: 110, height: 102)

                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .foregroundStyle(index < stars ? AppTheme.festivalGoldDark : theme.accent.opacity(0.48))
                            .offset(y: index == 1 ? -3 : 0)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.creamHighlight.opacity(0.85), in: Capsule())
            }
            .frame(width: 130)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gameNode)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Level \(number)\(isFinal ? ", zodiac boss" : "")")
        .accessibilityValue(isUnlocked ? "\(isCurrent ? "Next level. " : "")\(isComplete ? "Complete. " : "")\(stars) of 3 stars" : "Locked")
        .accessibilityHint(isUnlocked ? "Opens goals and optional boosters" : "Complete the previous level to unlock")
        .accessibilityIdentifier("chapter-level-\(number)")
    }
}
