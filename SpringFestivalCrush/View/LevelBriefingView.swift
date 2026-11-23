import SwiftUI

struct LevelBriefingView: View {
    @AppStorage(TimedLevelTimerMode.preferenceKey) private var timerModeRawValue = TimedLevelTimerMode.standard.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var goalChipMinimum: CGFloat = 68
    let level: Level
    let levelNumber: Int
    let zodiac: Zodiac
    let theme: ZodiacChapterTheme
    let savedBestStars: Int?
    private let scoutingLayout: BoardScoutingLayout?

    init(level: Level, levelNumber: Int, zodiac: Zodiac, theme: ZodiacChapterTheme, savedBestStars: Int?) {
        self.level = level
        self.levelNumber = levelNumber
        self.zodiac = zodiac
        self.theme = theme
        self.savedBestStars = savedBestStars
        scoutingLayout = LevelData.loadFrom(file: "\(zodiac.zodiacType.name)_Level_\(levelNumber)")
            .flatMap { BoardScoutingLayout(data: $0) }
    }

    private var ref: LevelRef { LevelRef(zodiac: zodiac.zodiacType, number: levelNumber) }
    private var bestScore: Int { BestScoreStore.best(for: zodiac.zodiacType, level: levelNumber) }
    private var timerMode: TimedLevelTimerMode { TimedLevelTimerMode(rawValue: timerModeRawValue) ?? .standard }
    private var usesStackedLayout: Bool { dynamicTypeSize >= .xxLarge }

    /// Only the rules this level teaches: each is shown on the first level or two where it
    /// appears, then left to the rule handbook. A guardian's rules have their own card.
    private var lessons: [GameRule] {
        RuleCurriculum.shared.lessons(for: ref).filter { $0.guardian == nil }
    }

    private var targets: [LevelTargetData] {
        level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac).filter { $0.targetNum > 0 }
    }

    var body: some View {
        VStack(spacing: 10) {
            summaryRow

            if usesStackedLayout {
                VStack(spacing: 10) {
                    if let scoutingLayout { BoardScoutingView(layout: scoutingLayout) }
                    objectives
                }
            } else {
                HStack(alignment: .top, spacing: AppTheme.Space.sm) {
                    if let scoutingLayout {
                        BoardScoutingView(layout: scoutingLayout, isCompact: true)
                            .frame(maxWidth: .infinity)
                    }
                    objectives
                        .frame(maxWidth: .infinity)
                }
            }

            if let boss = level.boss {
                BossRulesView(kind: boss.configuration.kind)
            }
            if !lessons.isEmpty {
                RuleLessonsView(rules: lessons) { RuleCurriculum.shared.introduces($0, at: ref) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryRow: some View {
        HStack(spacing: AppTheme.Space.sm) {
            if let boss = level.boss {
                HStack(spacing: 6) {
                    Text(verbatim: boss.configuration.kind.avatar)
                    Text(boss.configuration.kind.title.replacingOccurrences(of: boss.configuration.kind.avatar, with: "")
                        .trimmingCharacters(in: .whitespaces))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(theme.accent)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("ZODIAC BOSS") + Text(verbatim: ", ") + Text(boss.configuration.kind.title))
            } else {
                DifficultyLanterns(difficulty: level.difficulty, tint: theme.accent)
                    .accessibilityLabel(Text("CHALLENGE \(level.difficulty) / 5"))
            }
            Spacer(minLength: 0)
            if level.hasSnow {
                Label("瑞雪兆丰年", systemImage: "snowflake")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)
            }
            GameStatPill(systemImage: "arrow.left.arrow.right", value: "\(level.maximumMoves)", tint: theme.accent)
                .accessibilityLabel(Text("\(level.maximumMoves) moves"))
            if level.timeLimit != nil {
                if let seconds = timerMode.seconds(for: level.timeLimit) {
                    GameStatPill(systemImage: "timer", value: "\(seconds)s", tint: theme.accent)
                        .accessibilityLabel(Text("\(seconds) seconds"))
                } else {
                    GameStatPill(systemImage: "timer", value: timerMode.title, tint: theme.accent)
                        .accessibilityLabel(Text("Untimed"))
                }
            }
            HelpTipButton(size: 20, tint: theme.accent) { legend }
                .accessibilityIdentifier("level-briefing-help")
        }
    }

    /// Goals first because they decide the level, then what each star takes.
    private var objectives: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
            if !targets.isEmpty || level.boss != nil {
                VStack(alignment: .leading, spacing: 5) {
                    Label { GameSectionLabel("GOALS") } icon: {
                        Image(systemName: "target")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(theme.accent)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(level.boss == nil ? Text("COMPLETE EVERY GOAL") : Text("Defeat the guardian AND complete every goal."))
                    .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: goalChipMinimum), spacing: 5)], spacing: 5) {
                        if let boss = level.boss {
                            GoalChip(count: boss.configuration.health, label: Text("Boss health")) {
                                Text(verbatim: boss.configuration.kind.avatar).font(.system(size: 18))
                            }
                        }
                        ForEach(targets) { target in
                            GoalChip(count: target.targetNum, label: Text(goalName(target.imageName))) {
                                target.image.resizable().scaledToFit()
                            }
                        }
                    }
                }
            }

            starTargets

            if let savedBestStars {
                bestRow(savedBestStars)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gameInset(padding: AppTheme.Space.sm)
    }

    private var starTargets: some View {
        VStack(spacing: 3) {
            starRow(count: 1) {
                Image(systemName: "flag.checkered")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(theme.accent)
            }
            starRow(count: 2) { Text(verbatim: level.levelGoal.secondStarScore.formatted()) }
            starRow(count: 3) { Text(verbatim: level.levelGoal.thirdStarScore.formatted()) }
        }
        .font(.system(.caption, design: .rounded, weight: .heavy).monospacedDigit())
        .foregroundStyle(AppTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("Complete the level to earn 1 star.") + Text(verbatim: " ")
                + Text("2 stars: \(level.levelGoal.secondStarScore.formatted()) points") + Text(verbatim: " ")
                + Text("3 stars: \(level.levelGoal.thirdStarScore.formatted()) points")
        )
    }

    private func starRow<Value: View>(count: Int, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(AppTheme.festivalGoldDark)
            }
            Spacer(minLength: AppTheme.Space.xs)
            value()
        }
    }

    private func bestRow(_ stars: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < stars ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.accent)
            }
            if bestScore > 0 {
                Spacer(minLength: AppTheme.Space.xs)
                Image(systemName: "trophy.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.festivalGoldDark)
                Text(verbatim: bestScore.formatted())
                    .font(.system(.caption, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppTheme.ink.opacity(0.8))
            }
        }
        .padding(.top, 5)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Saved best: \(stars) of 3 stars"))
        .accessibilityValue(bestScore > 0 ? Text("Best score: \(bestScore)") : Text(verbatim: ""))
        .accessibilityIdentifier("level-briefing-best-stars")
    }

    /// The words behind every picture on this card, each next to the icon it explains.
    @ViewBuilder
    private var legend: some View {
        if let boss = level.boss {
            HelpTipRow(Text(boss.configuration.kind.instructions)) {
                Text(verbatim: boss.configuration.kind.avatar).font(.system(size: 20))
            }
        } else {
            HelpTipRow(Text("CHALLENGE \(level.difficulty) / 5"), systemImage: "flame.fill", tint: theme.accent)
        }
        ForEach(lessons) { rule in
            HelpTipRow(Text(rule.detail), systemImage: "lightbulb.fill", tint: theme.accent)
        }
        HelpTipRow(Text("\(level.maximumMoves) moves"), systemImage: "arrow.left.arrow.right", tint: theme.accent)
        if level.timeLimit != nil {
            if let seconds = timerMode.seconds(for: level.timeLimit) {
                HelpTipRow(Text("\(seconds) seconds"), systemImage: "timer", tint: theme.accent)
            } else {
                HelpTipRow(Text("Untimed"), systemImage: "timer", tint: theme.accent)
            }
            if timerMode == .extraTime {
                HelpTipRow(Text("Extra time: double the usual limit."), systemImage: "timer", tint: theme.accent)
            }
        }
        HelpTipRow(level.boss == nil ? Text("Complete every goal before you run out of moves.")
                                     : Text("Defeat the guardian AND complete every goal."),
                   systemImage: "target", tint: theme.accent)
        HelpTipRow(Text("Complete the level to earn 1 star."), systemImage: "star.fill", tint: theme.accent)
        if scoutingLayout != nil {
            HelpTipRow(Text("Layout only. Plain spaces receive random tiles when you play."),
                       systemImage: "map", tint: theme.accent)
        }
    }

    private func goalName(_ imageName: String) -> String {
        switch imageName {
        case "firecracker": String(localized: "firecrackers")
        case "redPocket": String(localized: "red envelopes")
        case "dumpling": String(localized: "dumplings")
        case "bowl": String(localized: "bowls")
        case "lantern": String(localized: "lanterns")
        case "zodiac": String(localized: "\(zodiac.zodiacType.localizedName) tiles")
        case "lock": String(localized: "locks")
        case "jelly": String(localized: "moon blossoms")
        case "ingredient": String(localized: "gifts to deliver")
        case "lightningCombos": String(localized: "Lightning activations")
        case "fiveCombos": String(localized: "Lucky Five activations")
        case "enhancedCombos": String(localized: "Blast Tile activations")
        default: imageName
        }
    }
}
