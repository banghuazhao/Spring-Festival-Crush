import SwiftUI

struct ZodiacLevelNode: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @ScaledMetric(relativeTo: .title) private var numberSize = 23
    @ScaledMetric(relativeTo: .caption2) private var badgeSize = 9

    let number: Int
    let isUnlocked: Bool
    let isComplete: Bool
    let isCurrent: Bool
    let isBoss: Bool
    let stars: Int
    let theme: ZodiacChapterTheme
    var celebrationProgress: CGFloat? = nil
    var isNewUnlock = false
    let action: () -> Void

    private var face: Color { isUnlocked ? (isCurrent ? theme.accent : AppTheme.creamHighlight) : Color(white: 0.65) }
    private var ink: Color { isUnlocked ? (isCurrent ? .white : theme.accent) : Color(white: 0.28) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(isNewUnlock ? "UNLOCKED!" : (isBoss ? "BOSS" : (isCurrent ? "PLAY NEXT" : " ")) as LocalizedStringKey)
                    .font(.system(size: min(badgeSize, 14), weight: .black, design: .rounded))
                    .lineLimit(1)
                    .tracking(0.8)
                    .foregroundStyle(isCurrent ? .white : theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(isCurrent ? theme.accent : .clear, in: Capsule())

                ZStack {
                    if let progress = celebrationProgress, !reduceMotion {
                        Circle()
                            .stroke(AppTheme.festivalGold, lineWidth: 5)
                            .frame(width: 80, height: 80)
                            .scaleEffect(0.8 + 0.7 * progress)
                            .opacity(1 - progress)
                            .accessibilityHidden(true)
                    }
                    if isCurrent {
                        Circle().stroke(theme.accent.opacity(0.24), lineWidth: 2.5)
                            .frame(width: 80, height: 80)
                            .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
                                content.scaleEffect(reduceMotion ? 1 : (phase ? 1.09 : 1))
                                    .opacity(reduceMotion ? 1 : (phase ? 0.35 : 1))
                            } animation: { _ in .easeInOut(duration: 1.3) }
                    }
                    Circle().fill(isUnlocked ? theme.accent.opacity(0.7) : Color(white: 0.46))
                        .frame(width: 66, height: 66).offset(y: 4)
                    Circle().fill(face.gradient)
                        .frame(width: 66, height: 66)
                        .overlay(Circle().strokeBorder(isUnlocked ? AppTheme.festivalGold : .white.opacity(0.55), lineWidth: 2.5))
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.75).padding(5))
                    VStack(spacing: 0) {
                        if isBoss {
                            Image(systemName: "crown.fill")
                                .font(.system(size: min(badgeSize + 2, 16), weight: .black))
                        }
                        Text(number, format: .number)
                            .font(.system(size: min(numberSize, 32), weight: .black, design: .rounded))
                    }
                    .foregroundStyle(ink)

                    if !isUnlocked || isComplete {
                        Image(systemName: isComplete ? "checkmark" : "lock.fill")
                            .font(.system(size: min(badgeSize + 1, 13), weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 21, height: 21)
                            .background(isComplete ? theme.accent : Color(white: 0.42), in: Circle())
                            .overlay(Circle().stroke(AppTheme.creamHighlight, lineWidth: 1.5))
                            .offset(x: 26, y: 23)
                    }
                }
                .frame(width: 88, height: 80)

                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .foregroundStyle(index < stars ? AppTheme.festivalGoldDark : theme.accent.opacity(0.48))
                            .offset(y: index == 1 ? -1.5 : 0)
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AppTheme.paper.opacity(0.92), in: Capsule())
            }
            .frame(width: 104)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gameNode)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isBoss ? Text("Level \(number), zodiac boss") : Text("Level \(number)"))
        .accessibilityValue(isUnlocked
            ? Text("\(isCurrent ? String(localized: "Next level. ") : "")\(isComplete ? String(localized: "Complete. ") : "")\(String(localized: "\(stars) of 3 stars"))")
            : Text("Locked"))
        .accessibilityHint(isUnlocked ? Text("Opens goals and optional boosters") : Text("Complete the previous level to unlock"))
        .accessibilityIdentifier("chapter-level-\(number)")
    }
}
