import SwiftUI

/// Every board rule in one book. A rule lights up once the player reaches the level that
/// teaches it; until then it waits in grey, showing which level unlocks it.
struct RuleHandbookView: View {
    @EnvironmentObject private var gameModel: GameModel
    @EnvironmentObject private var settingModel: SettingModel
    @Environment(\.dismiss) private var dismiss
    /// Unlocked but never opened here before; captured on open so the NEW tags last this visit.
    @State private var newRules: Set<GameRule> = []
    private let curriculum = RuleCurriculum.shared

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
                    VStack(spacing: 14) {
                        progress(unlocked.count, of: rules.count)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                            ForEach(rules.filter { $0.guardian == nil }) { page($0) }
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
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.festivalRed)
                .frame(width: 44, height: 44)
                .background(AppTheme.creamHighlight, in: Circle())
                .buttonStyle(.gameIcon)
                .padding(.trailing, 16)
                .padding(.top, 8)
                .accessibilityIdentifier("rule-handbook-close")
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            newRules = Set(unlocked).subtracting(RuleHandbookStore.seen())
            RuleHandbookStore.markSeen(unlocked)
        }
    }

    private func progress(_ unlocked: Int, of total: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "book.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.festivalRed)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.12))
                    Capsule().fill(AppTheme.accentGradient)
                        .frame(width: max(10, geometry.size.width * CGFloat(unlocked) / CGFloat(max(1, total))))
                }
            }
            .frame(height: 10)
            Text(verbatim: "\(unlocked)/\(total)")
                .font(.system(.headline, design: .rounded, weight: .black))
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
        VStack(spacing: 8) {
            RuleArt(rule: rule)
                .frame(maxWidth: .infinity, minHeight: 72)
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
                    HelpTipButton(Text(rule.detail), size: 22)
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
        .padding(10)
        .background(isUnlocked ? AppTheme.creamHighlight : Color.black.opacity(0.05), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? AppTheme.festivalGold : AppTheme.ink.opacity(0.15), lineWidth: isUnlocked ? 2 : 1)
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
