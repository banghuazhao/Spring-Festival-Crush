import SwiftUI

struct LevelBriefingView: View {
    let level: Level
    let zodiac: Zodiac
    let theme: ZodiacChapterTheme

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if let boss = level.boss {
                    HStack(spacing: 6) {
                        Text(verbatim: boss.configuration.kind.avatar)
                        Text(boss.configuration.kind.title.replacingOccurrences(of: boss.configuration.kind.avatar, with: "")
                            .trimmingCharacters(in: .whitespaces))
                    }
                    .font(.subheadline.weight(.heavy))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("ZODIAC BOSS") + Text(verbatim: ", ") + Text(boss.configuration.kind.title))
                } else {
                    DifficultyLanterns(difficulty: level.difficulty, tint: theme.accent)
                        .accessibilityLabel(Text("CHALLENGE \(level.difficulty) / 5"))
                }
                Spacer()
                if level.hasSnow { Label("瑞雪兆丰年", systemImage: "snowflake") }
            }
            .font(.caption.weight(.heavy))
            .foregroundStyle(theme.accent)

            if let boss = level.boss {
                BossRulesView(kind: boss.configuration.kind)
            }
            if let hint = level.mechanicHint {
                MechanicTipsView(hint: hint)
            }

            HStack(spacing: 8) {
                statChip(systemImage: "arrow.left.arrow.right", value: "\(level.maximumMoves)")
                    .accessibilityLabel(Text("\(level.maximumMoves) moves"))
                if let seconds = level.timeLimit {
                    statChip(systemImage: "timer", value: "\(seconds)s")
                        .accessibilityLabel(Text("\(seconds) seconds"))
                }
                statChip(systemImage: "star.fill", value: level.levelGoal.firstStarScore.formatted())
                    .accessibilityLabel(Text("Score \(level.levelGoal.firstStarScore.formatted())"))
            }

            let targets = level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac).filter { $0.targetNum > 0 }
            if !targets.isEmpty || level.boss != nil {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel(level.boss == nil ? Text("COMPLETE EVERY GOAL") : Text("Defeat the guardian AND complete every goal."))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                        if let boss = level.boss {
                            goalCell {
                                Text(verbatim: boss.configuration.kind.avatar).font(.system(size: 26))
                                    .frame(width: 30, height: 30)
                            } count: {
                                Label("\(boss.configuration.health)", systemImage: "heart.fill")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(AppTheme.festivalRed)
                            }
                            .accessibilityLabel(Text("Boss health") + Text(verbatim: " \(boss.configuration.health)"))
                        }
                        ForEach(targets) { target in
                            goalCell {
                                target.image.resizable().scaledToFit().frame(width: 30, height: 30)
                            } count: {
                                Text(target.targetNum, format: .number)
                            }
                            .accessibilityLabel("\(target.targetNum) \(goalName(target.imageName))")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(theme.sky.opacity(0.7), in: .rect(cornerRadius: 18))
    }

    private func statChip(systemImage: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(theme.accent)
            Text(verbatim: value)
                .font(.system(.headline, design: .rounded, weight: .black))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.creamHighlight, in: Capsule())
        .overlay(Capsule().stroke(theme.accent.opacity(0.35), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
    }

    private func goalCell<Art: View, Count: View>(@ViewBuilder art: () -> Art, @ViewBuilder count: () -> Count) -> some View {
        VStack(spacing: 3) {
            art()
            count()
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .monospacedDigit()
        }
        .foregroundStyle(AppTheme.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
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
        case "jelly": String(localized: "jelly layers")
        case "ingredient": String(localized: "gifts to bring to the bottom")
        case "lightningCombos": String(localized: "lightning combos")
        case "fiveCombos": String(localized: "five-tile combos")
        case "enhancedCombos": String(localized: "enhanced combos")
        default: imageName
        }
    }
}
