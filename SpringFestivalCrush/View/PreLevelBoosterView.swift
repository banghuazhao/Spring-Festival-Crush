//
// Pre-level booster purchase sheet, shown before a level starts.
//

import SwiftUI

struct PreLevelBoosterView: View {
    @EnvironmentObject var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let levelNumber: Int
    let onClose: () -> Void
    let onStart: () -> Void

    @State private var buyExtraMoves = false
    @State private var buyHammer = false
    @State private var buySwap = false
    @State private var previewLevel: Level?
    @State private var showInsufficientCoins = false
    @State private var isStarting = false

    private var theme: ZodiacChapterTheme {
        ZodiacChapterTheme(zodiac: gameModel.zodiac?.zodiacType ?? .rat)
    }

    /// Read only the selected chapter's saved result; uncompleted levels have no best yet.
    private var savedBestStars: Int? {
        guard let zodiac = gameModel.zodiac,
              let record = gameModel.currentLevelRecords.first(where: {
                  $0.number == levelNumber && $0.zodiacRecord.zodiacType == zodiac.zodiacType && $0.isComplete
              }) else { return nil }
        return min(3, max(0, record.stars))
    }

    /// Coins already committed by the current selection. Affordability has to be judged
    /// against this, not against the raw balance: with 30 coins both boosters look
    /// individually affordable, so selecting both used to charge for the first and then
    /// silently drop the second at Start — the player paid and got nothing.
    private var selectedCost: Int {
        (buyExtraMoves ? GameModel.extraMovesBoosterCost : 0)
            + (buyHammer ? GameModel.hammerBoosterCost : 0)
            + (buySwap ? GameModel.swapBoosterCost : 0)
    }

    private var coinsRemaining: Int {
        gameModel.coins - selectedCost
    }

    private var usesListLayout: Bool { dynamicTypeSize >= .xxLarge }

    var body: some View {
        ZStack {
            ZodiacChapterScenery(theme: theme).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if let previewLevel, let zodiac = gameModel.zodiac {
                        LevelBriefingView(level: previewLevel, levelNumber: levelNumber, zodiac: zodiac,
                                          theme: theme, savedBestStars: savedBestStars)
                    } else {
                        Text("This level is unavailable. Please return to the trail.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity)
                            .gameInset(padding: AppTheme.Space.lg)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        RewardedAdButton(title: String(localized: "Watch Ad · +\(GameModel.rewardedCoinsAmount) coins"),
                                         systemImage: "play.rectangle.fill") {
                            gameModel.grantRewardedCoins()
                        }
                    }

                    LazyVGrid(columns: usesListLayout
                              ? [GridItem(.flexible())]
                              : Array(repeating: GridItem(.flexible(), spacing: AppTheme.Space.sm), count: 3),
                              spacing: AppTheme.Space.sm) {
                        boosterRow(
                            icon: "plus.circle.fill",
                            title: String(localized: "+\(GameModel.extraMovesBoosterAmount) Moves"),
                            detail: "More room to make a comeback",
                            cost: GameModel.extraMovesBoosterCost,
                            isSelected: $buyExtraMoves
                        ) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(theme.accent)
                                PictoTag(text: "+\(GameModel.extraMovesBoosterAmount)", tint: Color(UIColor(hex: 0x1A7350)), size: 10)
                            }
                        }
                        boosterRow(
                            icon: "hammer.fill",
                            imageName: "HammerBoosterIcon",
                            title: "Festival Hammer",
                            detail: "Clear any one tile",
                            cost: GameModel.hammerBoosterCost,
                            isSelected: $buyHammer
                        ) {
                            HStack(spacing: 3) {
                                PictoTile(asset: "dumpling", size: 17)
                                PictoArrow(size: 8)
                                PictoClear(size: 17)
                            }
                        }
                        boosterRow(
                            icon: "arrow.left.arrow.right",
                            imageName: "SwapBoosterIcon",
                            title: "Ruyi Swap",
                            detail: "Swap any two tiles, no match needed",
                            cost: GameModel.swapBoosterCost,
                            isSelected: $buySwap
                        ) {
                            HStack(spacing: 2) {
                                PictoTile(asset: "redPocket", size: 17)
                                PictoArrow(systemName: "arrow.left.arrow.right", size: 8)
                                PictoTile(asset: "lantern", size: 17)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.top, AppTheme.Space.xs)
                .padding(.bottom, AppTheme.Space.md)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                if selectedCost > 0 {
                    CoinAmountChip(amount: "−\(selectedCost)", size: 13)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("Total: \(selectedCost) coins"))
                }
                Button(action: startLevel) {
                    Label("Let's Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameGold)
                .disabled(previewLevel == nil || isStarting)
                .opacity(previewLevel == nil ? 0.5 : 1)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("level-briefing-start")
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: selectedCost > 0)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, 10)
            .padding(.bottom, AppTheme.Space.xs)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(AppTheme.creamHighlight.opacity(0.72))
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task(id: levelNumber) {
            guard let zodiac = gameModel.zodiac else { return }
            previewLevel = Level(filename: "\(zodiac.zodiacType.name)_Level_\(levelNumber)")
        }
        .gameNotice(isPresented: $showInsufficientCoins, message: "Not enough coins for this selection.", icon: "circle.fill", tint: theme.accent)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(AppTheme.creamHighlight.gradient)
                Circle().strokeBorder(AppTheme.goldGradient, lineWidth: 2)
                Text(theme.zodiac.emoji).font(.system(size: 22))
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(theme.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(String(localized: "LEVEL \(levelNumber)"))
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            GameStatPill(systemImage: "circle.inset.filled", value: "\(coinsRemaining)", tint: AppTheme.festivalGoldDark)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: coinsRemaining)
                .accessibilityLabel(Text("\(coinsRemaining) coins"))

            if !dynamicTypeSize.isAccessibilitySize {
                RewardedAdButton(title: String(localized: "Watch Ad · +\(GameModel.rewardedCoinsAmount) coins"),
                                 systemImage: "play.rectangle.fill",
                                 compactLabel: "+\(GameModel.rewardedCoinsAmount)") {
                    gameModel.grantRewardedCoins()
                }
            }

            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.paper, in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.hairline, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(.gameIcon)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("level-briefing-close")
        }
        .padding(.leading, AppTheme.Space.lg)
        .padding(.trailing, AppTheme.Space.md)
        .padding(.top, AppTheme.Space.lg)
        .padding(.bottom, AppTheme.Space.xs)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(theme.sky)
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
        if buySwap { gameModel.applySwapBooster() }
        onStart()
        onClose()
    }

    private func boosterRow<Art: View>(
        icon: String,
        imageName: String? = nil,
        title: String,
        detail: String,
        cost: Int,
        isSelected: Binding<Bool>,
        @ViewBuilder art: () -> Art
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
            VStack(spacing: AppTheme.Space.xs) {
                Group {
                    if let imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Circle().fill(affordable ? theme.gradient : AppTheme.neutralGradient))
                    }
                }
                .frame(width: 36, height: 36)

                Text(LocalizedStringKey(title))
                    .font(.caption.weight(.heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(usesListLayout ? nil : 2)
                    .minimumScaleFactor(0.85)
                    .frame(minHeight: usesListLayout ? nil : 30)

                art()
                    .frame(height: 18)

                HStack(spacing: 3) {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.festivalGoldDark)
                    Text("\(cost)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .padding(.horizontal, AppTheme.Space.sm)
                .padding(.vertical, 2)
                .background(AppTheme.cream, in: Capsule())
            }
            .foregroundStyle(AppTheme.ink)
            .padding(.top, AppTheme.Space.sm)
            .padding(.bottom, 6)
            .padding(.horizontal, AppTheme.Space.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(isSelected.wrappedValue ? theme.sky : AppTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .strokeBorder(isSelected.wrappedValue ? theme.accent : AppTheme.hairline,
                                  lineWidth: isSelected.wrappedValue ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected.wrappedValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, theme.accent)
                        .padding(AppTheme.Space.xs)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) {
                // Its own button inside the tile, so asking doesn't select the booster.
                HelpTipButton(Text(LocalizedStringKey(detail)), size: 15, tint: theme.accent)
                    .padding(AppTheme.Space.xs)
            }
        }
        .buttonStyle(.plain)
        .opacity(affordable ? 1.0 : 0.48)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.65), value: isSelected.wrappedValue)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("\(String(localized: String.LocalizationValue(title))), \(cost) coins. \(String(localized: String.LocalizationValue(detail)))"))
        .accessibilityValue(isSelected.wrappedValue ? Text("Selected") : (affordable ? Text("Not selected") : Text("Not enough coins")))
        .accessibilityAddTraits(isSelected.wrappedValue ? .isSelected : [])
    }
}
