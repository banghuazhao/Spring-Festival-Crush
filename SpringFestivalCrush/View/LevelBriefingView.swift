import SwiftUI

struct LevelBriefingView: View {
    let level: Level
    let zodiac: Zodiac
    let theme: ZodiacChapterTheme

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    Label("\(level.maximumMoves) moves", systemImage: "arrow.left.arrow.right")
                    if let seconds = level.timeLimit {
                        Label("\(seconds)s", systemImage: "timer")
                    }
                }
                VStack(spacing: 6) {
                    Label("\(level.maximumMoves) moves", systemImage: "arrow.left.arrow.right")
                    if let seconds = level.timeLimit { Label("\(seconds) seconds", systemImage: "timer") }
                }
            }
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(theme.accent)

            Label("Score \(level.levelGoal.firstStarScore.formatted())", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.ink)

            let targets = level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac).filter { $0.targetNum > 0 }
            if !targets.isEmpty {
                Text("COMPLETE EVERY GOAL")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(targets) { target in
                        VStack(spacing: 3) {
                            target.image.resizable().scaledToFit().frame(width: 30, height: 30)
                            Text(target.targetNum, format: .number)
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                        }
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 12))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(target.targetNum) \(goalName(target.imageName))")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(theme.sky.opacity(0.7), in: .rect(cornerRadius: 18))
    }

    private func goalName(_ imageName: String) -> String {
        switch imageName {
        case "firecracker": "firecrackers"
        case "redPocket": "red envelopes"
        case "dumpling": "dumplings"
        case "bowl": "bowls"
        case "lantern": "lanterns"
        case "zodiac": "\(zodiac.zodiacType.name) tiles"
        case "lock": "locks"
        case "jelly": "jelly layers"
        case "ingredient": "gifts to bring to the bottom"
        case "lightningCombos": "lightning combos"
        case "fiveCombos": "five-tile combos"
        case "enhancedCombos": "enhanced combos"
        default: imageName
        }
    }
}
