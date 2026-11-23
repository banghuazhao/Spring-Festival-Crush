import SwiftUI

/// Every board rule in one book. A rule lights up once the player reaches the level that
/// teaches it; until then it waits in grey, showing which level unlocks it.
struct RuleHandbookView: View {
    private let onClose: (() -> Void)?
    @EnvironmentObject private var gameModel: GameModel
    @EnvironmentObject private var settingModel: SettingModel
    @Environment(\.dismiss) private var dismiss
    /// Unlocked but never opened here before; captured on open so the NEW tags last this visit.
    @State private var newRules: Set<GameRule> = []
    private let curriculum = RuleCurriculum.shared

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private func isUnlocked(_ rule: GameRule) -> Bool {
        curriculum.isUnlocked(rule) { settingModel.unlockAllLevels || gameModel.hasReached($0) }
    }

    var body: some View {
        let rules = curriculum.rules
        let unlocked = rules.filter(isUnlocked)
        ZStack {
            AppTheme.festivalBackground.ignoresSafeArea()
            ScrollView {
                GamePopupPanel(title: String(localized: "RULE HANDBOOK"), tone: .gold) {
                    VStack(spacing: 10) {
                        progress(unlocked.count, of: rules.count)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 136), spacing: AppTheme.Space.sm)], spacing: AppTheme.Space.sm) {
                            ForEach(rules.filter { $0.guardian == nil }) { page($0) }
                        }
                        if isUnlocked(.combos) {
                            PowerUpRecipeGuide()
                        }
                        let guardians = rules.filter { $0.guardian != nil }
                        if !guardians.isEmpty {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(AppTheme.festivalGoldDark)
                                .accessibilityLabel(Text("ZODIAC BOSS"))
                            ForEach(guardians) { page($0) }
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(.horizontal, AppTheme.Space.md)
                .padding(.top, AppTheme.Space.xl)
                .padding(.bottom, AppTheme.Space.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark", action: close)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(AppTheme.festivalRed)
                .frame(width: 34, height: 34)
                .background(AppTheme.paper, in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.hairline, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(.gameIcon)
                .padding(.trailing, AppTheme.Space.sm)
                .padding(.top, AppTheme.Space.sm)
                .accessibilityIdentifier("rule-handbook-close")
                #if targetEnvironment(macCatalyst)
                .keyboardShortcut(.cancelAction)
                #endif
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            newRules = Set(unlocked).subtracting(RuleHandbookStore.seen())
            RuleHandbookStore.markSeen(unlocked)
        }
    }

    private func close() {
        if let onClose { onClose() }
        else { dismiss() }
    }

    private func progress(_ unlocked: Int, of total: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.festivalRed)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.1))
                    Capsule().fill(AppTheme.accentGradient)
                        .frame(width: max(6, geometry.size.width * CGFloat(unlocked) / CGFloat(max(1, total))))
                }
            }
            .frame(height: 6)
            Text(verbatim: "\(unlocked)/\(total)")
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(unlocked) of \(total) rules unlocked"))
    }

    private func page(_ rule: GameRule) -> some View {
        RuleHandbookPage(rule: rule, unlocksAt: curriculum.introductions[rule]!,
                         isUnlocked: isUnlocked(rule), isNew: newRules.contains(rule))
    }
}

/// One rule: its picture and a "?" when unlocked; greyed out with its unlock level when not.
private struct RuleHandbookPage: View {
    let rule: GameRule
    let unlocksAt: LevelRef
    let isUnlocked: Bool
    let isNew: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @State private var nudge = false

    var body: some View {
        VStack(spacing: AppTheme.Space.xs) {
            RuleArt(rule: rule)
                .frame(maxWidth: .infinity, minHeight: 60)
                .grayscale(isUnlocked ? 0 : 1)
                .opacity(isUnlocked ? 1 : 0.28)
                .overlay {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.ink.opacity(0.55), in: Circle())
                    }
                }
            HStack(spacing: 6) {
                Text(rule.title)
                    .font(.caption.weight(.heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                if isUnlocked {
                    HelpTipButton(Text(rule.detail), size: 18)
                } else {
                    HStack(spacing: 3) {
                        Text(verbatim: unlocksAt.zodiac.emoji)
                        Text(verbatim: "\(unlocksAt.number)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.ink.opacity(0.1), in: Capsule())
                }
            }
            .foregroundStyle(isUnlocked ? AppTheme.ink : AppTheme.ink.opacity(0.45))
        }
        .padding(AppTheme.Space.sm)
        .background(isUnlocked ? AppTheme.paper : Color.black.opacity(0.05),
                    in: .rect(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .strokeBorder(isUnlocked ? AppTheme.hairline : AppTheme.ink.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if isNew { NewRuleTag().offset(x: -4, y: -6) }
        }
        .offset(x: nudge ? 6 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isUnlocked else { return }
            HapticManager.locked()
            guard !systemReduceMotion, !reducedEffects else { return }
            withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) { nudge = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { nudge = false }
        }
        .accessibilityElement(children: isUnlocked ? .contain : .ignore)
        .accessibilityLabel(isUnlocked ? Text(rule.title)
                            : Text(rule.title) + Text(verbatim: ". ") + Text("Locked"))
        .accessibilityValue(isUnlocked ? Text(rule.detail)
                            : Text("Reach \(unlocksAt.zodiac.localizedName) level \(unlocksAt.number) to unlock."))
        .accessibilityIdentifier("rule-page-\(rule.rawValue)")
    }
}
