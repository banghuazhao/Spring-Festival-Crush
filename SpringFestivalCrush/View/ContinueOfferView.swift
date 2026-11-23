import SwiftUI

/// Shown between running out and the defeat screen: buy a few more moves (or seconds)
/// with coins or a rewarded video, or give up and spend a life.
struct ContinueOfferView: View {
    let offer: ContinueOffer
    var onRevealComplete: () -> Void = {}
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var appeared = false
    @State private var showInsufficientCoins = false
    @AccessibilityFocusState private var headingFocused: Bool

    private var canAfford: Bool { gameModel.coins >= offer.coinCost }

    private var guardianRecap: GuardianRecap? {
        guard let guardian = gameModel.bossStatus else { return nil }
        return GuardianRecap(health: guardian.health, maximumHealth: guardian.configuration.health)
    }

    private var title: String {
        offer.reason == .outOfTime ? String(localized: "NEED MORE TIME?") : String(localized: "KEEP GOING?")
    }

    private var grantText: Text {
        switch (offer.grantsMoves, offer.grantsSeconds) {
        case (true, true):
            Text("+\(ContinueOffer.extraMoves) moves & +\(ContinueOffer.extraSeconds)s")
        case (false, true):
            Text("+\(ContinueOffer.extraSeconds) seconds")
        default:
            Text("+\(ContinueOffer.extraMoves) moves")
        }
    }

    private var nearMissText: Text {
        if let guardian = guardianRecap {
            if guardian.isDefeated { return Text("Guardian defeated!") }
            return guardian.isAlmostBeaten
                ? Text("The guardian is almost beaten!")
                : Text("The guardian is still standing.")
        }
        switch offer.piecesRemaining {
        case 0: return Text("You're so close!")
        case 1: return Text("Only 1 more piece to go!")
        default: return Text("Only \(offer.piecesRemaining) more pieces to go!")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GamePopupPanel(title: title, tone: .red, titleFocus: $headingFocused) {
                    VStack(spacing: 10) {
                        HStack(spacing: AppTheme.Space.md) {
                            progressRing

                            VStack(alignment: .leading, spacing: 6) {
                                nearMissText
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .foregroundStyle(AppTheme.festivalRed)
                                    .fixedSize(horizontal: false, vertical: true)

                                CoinAmountChip(amount: "\(gameModel.coins)", size: 13)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel(Text("Balance: \(gameModel.coins)"))
                            }
                            Spacer(minLength: 0)
                        }

                        AttemptRecapView()

                        Button(action: payWithCoins) {
                            ContinuePurchaseLabel(grant: grantText, coinCost: offer.coinCost,
                                                  grantsMoves: offer.grantsMoves)
                        }
                        .buttonStyle(.gameGold)
                        .opacity(canAfford ? 1 : 0.55)
                        .accessibilityIdentifier("continue-coins")
                        .accessibilityLabel(Text("\(grantText) for \(offer.coinCost) coins"))

                        if offer.allowsRewardedAd {
                            RewardedAdButton(title: "Watch Ad · Free Continue", systemImage: "play.rectangle.fill",
                                             expandsForLargeText: true) {
                                gameModel.acceptContinueFromRewardedAd()
                            }
                        }

                        Button {
                            HapticManager.buttonTap()
                            gameModel.declineContinue()
                        } label: {
                            Text("Give Up")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.65))
                                .frame(minWidth: 120, minHeight: 44)
                        }
                        .buttonStyle(.gameIcon)
                        .accessibilityIdentifier("continue-decline")
                        .accessibilityHint(Text("Ends this attempt and uses one life"))
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(AppTheme.Space.lg)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .scaleEffect(reduceMotion || appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.7),
                          completionCriteria: .logicallyComplete) {
                appeared = true
            } completion: {
                onRevealComplete()
            }
            headingFocused = true
        }
        .onDisappear { headingFocused = false }
        .gameNotice(isPresented: $showInsufficientCoins, message: String(localized: "Not enough coins. Try the free ad continue!"),
                    icon: "circle.fill", tint: AppTheme.festivalRed)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.festivalGold.opacity(0.25), lineWidth: 7)
            Circle()
                .trim(from: 0, to: appeared ? CGFloat(offer.progress) : 0)
                .stroke(AppTheme.accentGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.15), value: appeared)
            VStack(spacing: 0) {
                Text("\(Int((offer.progress * 100).rounded()))%")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("THERE")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundStyle(AppTheme.festivalRed)
        }
        .frame(width: 68, height: 68)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Int((offer.progress * 100).rounded())) percent of the goals done"))
    }

    private func payWithCoins() {
        guard canAfford else {
            HapticManager.locked()
            showInsufficientCoins = true
            return
        }
        HapticManager.buttonTap()
        gameModel.acceptContinueWithCoins()
    }
}
