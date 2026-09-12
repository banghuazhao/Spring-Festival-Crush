//
// Pre-level booster purchase sheet, shown before a level starts.
//

import SwiftUI

struct PreLevelBoosterView: View {
    @EnvironmentObject var gameModel: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let levelNumber: Int
    let onStart: () -> Void

    @State private var buyExtraMoves = false
    @State private var buyHammer = false
    @State private var previewLevel: Level?
    @State private var showInsufficientCoins = false
    @State private var isStarting = false

    private var theme: ZodiacChapterTheme {
        ZodiacChapterTheme(zodiac: gameModel.zodiac?.zodiacType ?? .rat)
    }

    /// Coins already committed by the current selection. Affordability has to be judged
    /// against this, not against the raw balance: with 30 coins both boosters look
    /// individually affordable, so selecting both used to charge for the first and then
    /// silently drop the second at Start — the player paid and got nothing.
    private var selectedCost: Int {
        (buyExtraMoves ? GameModel.extraMovesBoosterCost : 0)
            + (buyHammer ? GameModel.hammerBoosterCost : 0)
    }

    private var coinsRemaining: Int {
        gameModel.coins - selectedCost
    }

    var body: some View {
        ZStack {
            ZodiacChapterScenery(theme: theme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                GamePopupPanel(title: "LEVEL \(levelNumber)", tone: .gold) {
                    VStack(spacing: 14) {
                        if let previewLevel, let zodiac = gameModel.zodiac {
                            LevelBriefingView(level: previewLevel, zodiac: zodiac, theme: theme)
                        } else {
                            Text("This level is unavailable. Please return to the trail.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ink)
                        }

                        Text("CHOOSE YOUR BOOSTERS")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.ink.opacity(0.65))

                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(AppTheme.festivalGold)
                            Text("\(coinsRemaining)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: coinsRemaining)
                            Text("COINS")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.ink.opacity(0.62))
                        }
                        .foregroundStyle(AppTheme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(AppTheme.creamHighlight))
                        .overlay(Capsule().stroke(AppTheme.festivalGold, lineWidth: 2))

                        RewardedAdButton(title: "Watch Ad · +\(GameModel.rewardedCoinsAmount)", systemImage: "play.rectangle.fill") {
                            gameModel.grantRewardedCoins()
                        }

                        VStack(spacing: 10) {
                            boosterRow(
                                icon: "plus.circle.fill",
                                title: "+\(GameModel.extraMovesBoosterAmount) Moves",
                                detail: "More room to make a comeback",
                                cost: GameModel.extraMovesBoosterCost,
                                isSelected: $buyExtraMoves
                            )
                            boosterRow(
                                icon: "hammer.fill",
                                imageName: "HammerBoosterIcon",
                                title: "Festival Hammer",
                                detail: "Clear any one tile",
                                cost: GameModel.hammerBoosterCost,
                                isSelected: $buyHammer
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Text(theme.zodiac.emoji).font(.system(size: 32)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Level \(levelNumber)").font(.headline)
                    } else {
                        Text(theme.name).font(.headline)
                        Text("Get ready to play").font(.subheadline)
                    }
                }
                .foregroundStyle(AppTheme.ink)
                Spacer(minLength: 0)
                Button("Close", systemImage: "xmark", action: { dismiss() })
                    .labelStyle(.iconOnly)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.creamHighlight, in: Circle())
                    .buttonStyle(.gameIcon)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("level-briefing-close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)
            .background(theme.sky)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if !dynamicTypeSize.isAccessibilitySize || selectedCost > 0 {
                    Text(selectedCost > 0 ? "Total: \(selectedCost) coins" : "Boosters are optional. Play your way!")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                Button(action: startLevel) {
                    Label("Let's Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gamePrimary(gradient: theme.gradient))
                .disabled(previewLevel == nil || isStarting)
                .opacity(previewLevel == nil ? 0.5 : 1)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("level-briefing-start")
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .background(AppTheme.creamHighlight.ignoresSafeArea(edges: .bottom))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .task(id: levelNumber) {
            guard let zodiac = gameModel.zodiac else { return }
            previewLevel = Level(filename: "\(zodiac.zodiacType.name)_Level_\(levelNumber)")
        }
        .gameNotice(isPresented: $showInsufficientCoins, message: "Not enough coins for this selection.", icon: "circle.fill", tint: theme.accent)
    }

    private func startLevel() {
        guard previewLevel != nil, !isStarting else { return }
        guard gameModel.coins >= selectedCost else {
            HapticManager.locked()
            showInsufficientCoins = true
            return
        }
        isStarting = true
        HapticManager.buttonTap()
        if buyExtraMoves { gameModel.applyExtraMovesBooster() }
        if buyHammer { gameModel.applyHammerBooster() }
        onStart()
        dismiss()
    }

    private func boosterRow(
        icon: String,
        imageName: String? = nil,
        title: String,
        detail: String,
        cost: Int,
        isSelected: Binding<Bool>
    ) -> some View {
        // Already-selected rows stay tappable so a selection can always be undone.
        let affordable = isSelected.wrappedValue || coinsRemaining >= cost
        return Button {
            guard affordable else {
                HapticManager.locked()
                showInsufficientCoins = true
                return
            }
            HapticManager.buttonTap()
            isSelected.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(affordable ? theme.gradient : AppTheme.neutralGradient))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.heavy))
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.ink.opacity(0.58))
                }
                Spacer()

                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.festivalGold)
                        Text("\(cost)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    Image(systemName: isSelected.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected.wrappedValue ? theme.accent : Color.gray.opacity(0.4))
                        .scaleEffect(isSelected.wrappedValue && !reduceMotion ? 1.12 : 1)
                }
            }
            .foregroundStyle(AppTheme.ink)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected.wrappedValue ? theme.sky : AppTheme.creamHighlight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected.wrappedValue ? theme.accent : AppTheme.festivalGold.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected.wrappedValue ? 0.2 : 0.08), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .opacity(affordable ? 1.0 : 0.48)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.65), value: isSelected.wrappedValue)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), \(cost) coins. \(detail)")
        .accessibilityValue(isSelected.wrappedValue ? "Selected" : (affordable ? "Not selected" : "Not enough coins"))
        .accessibilityAddTraits(isSelected.wrappedValue ? .isSelected : [])
    }
}
