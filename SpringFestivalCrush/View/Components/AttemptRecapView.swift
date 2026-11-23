import SwiftUI

/// A read-only view of the current attempt, shared by pause and continue overlays.
struct AttemptRecapView: View {
    var showsResources = false
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesExpandedLayout: Bool { dynamicTypeSize >= .xxLarge }

    var body: some View {
        if let level = gameModel.level, let zodiac = gameModel.zodiac {
            let targets = level.levelGoal.levelTarget.getLevelTargetDatas(gameZodiac: zodiac)
                .filter { $0.targetNum > 0 }
            VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                if usesExpandedLayout {
                    GameSectionLabel(showsResources ? "ATTEMPT RECAP" : "GOALS REMAINING")
                    if showsResources {
                        Label("Moves remaining: \(max(0, gameModel.movesLeft))", systemImage: "arrow.left.arrow.right")
                        if let seconds = gameModel.secondsLeft {
                            Label("Time remaining: \(max(0, seconds)) seconds", systemImage: "timer")
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        GameSectionLabel("GOALS REMAINING")
                        Spacer(minLength: AppTheme.Space.xs)
                        if showsResources {
                            GameStatPill(systemImage: "arrow.left.arrow.right", value: "\(max(0, gameModel.movesLeft))")
                                .accessibilityLabel(Text("Moves remaining: \(max(0, gameModel.movesLeft))"))
                            if let seconds = gameModel.secondsLeft {
                                GameStatPill(systemImage: "timer", value: "\(max(0, seconds))s")
                                    .accessibilityLabel(Text("Time remaining: \(max(0, seconds)) seconds"))
                            }
                        }
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
                } else if usesExpandedLayout {
                    ForEach(targets) { target in
                        AttemptGoalRow(target: target, title: goalName(target.imageName, zodiac: zodiac))
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
                        ForEach(targets) { target in
                            AttemptGoalRow(target: target, title: goalName(target.imageName, zodiac: zodiac))
                        }
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gameInset()
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
        case "ingredient": Text("gifts to deliver")
        case "lightningCombos": Text("Lightning activations")
        case "fiveCombos": Text("Lucky Five activations")
        case "enhancedCombos": Text("Blast Tile activations")
        default: Text(verbatim: imageName)
        }
    }
}
