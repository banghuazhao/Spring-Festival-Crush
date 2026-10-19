import SwiftUI

/// A read-only view of the current attempt, shared by pause and continue overlays.
struct AttemptRecapView: View {
    var showsResources = false
    @EnvironmentObject private var gameModel: GameModel

    var body: some View {
        if let level = gameModel.level, let zodiac = gameModel.zodiac {
            let targets = level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac)
                .filter { $0.targetNum > 0 }
            VStack(alignment: .leading, spacing: 8) {
                Text(showsResources ? "ATTEMPT RECAP" : "GOALS REMAINING" as LocalizedStringKey)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink.opacity(0.7))

                if showsResources {
                    Label("Moves remaining: \(max(0, gameModel.movesLeft))", systemImage: "arrow.left.arrow.right")
                    if let seconds = gameModel.secondsLeft {
                        Label("Time remaining: \(max(0, seconds)) seconds", systemImage: "timer")
                    }
                }

                if let boss = gameModel.bossStatus,
                   let guardian = GuardianRecap(health: boss.health, maximumHealth: boss.configuration.health) {
                    Label {
                        if guardian.isDefeated {
                            Text("Guardian defeated!")
                        } else {
                            Text("Guardian health: \(guardian.health) of \(guardian.maximumHealth)")
                        }
                    } icon: {
                        Image(systemName: guardian.isDefeated ? "checkmark.seal.fill" : "heart.fill")
                            .foregroundStyle(guardian.isDefeated ? AppTheme.festivalGoldDark : AppTheme.festivalRed)
                    }
                    .accessibilityIdentifier("attempt-guardian-health")
                }

                if targets.isEmpty {
                    Label("All collection goals complete!", systemImage: "checkmark.circle.fill")
                } else {
                    if showsResources {
                        Text("GOALS REMAINING")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.ink.opacity(0.7))
                            .padding(.top, 4)
                    }
                    ForEach(targets) { target in
                        AttemptGoalRow(target: target, title: goalName(target.imageName, zodiac: zodiac))
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 16))
            .accessibilityIdentifier(showsResources ? "pause-attempt-recap" : "continue-attempt-recap")
        }
    }

    private func goalName(_ imageName: String, zodiac: Zodiac) -> Text {
        switch imageName {
        case "firecracker": Text("firecrackers")
        case "redPocket": Text("red envelopes")
        case "dumpling": Text("dumplings")
        case "bowl": Text("bowls")
        case "lantern": Text("lanterns")
        case "zodiac": Text("\(Text(LocalizedStringKey(zodiac.zodiacType.name))) tiles")
        case "lock": Text("locks")
        case "jelly": Text("moon blossoms")
        case "ingredient": Text("gifts to bring to the bottom")
        case "lightningCombos": Text("lightning combos")
        case "fiveCombos": Text("five-tile combos")
        case "enhancedCombos": Text("enhanced combos")
        default: Text(verbatim: imageName)
        }
    }
}
