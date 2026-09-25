import SwiftUI

/// Shown between running out and the defeat screen: buy a few more moves (or seconds)
/// with coins or a rewarded video, or give up and spend a life.
struct ContinueOfferView: View {
    let offer: ContinueOffer
    @EnvironmentObject private var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var appeared = false
    @State private var showInsufficientCoins = false

    private var canAfford: Bool { gameModel.coins >= offer.coinCost }

    private var title: String {
        offer.reason == .outOfTime ? String(localized: "NEED MORE TIME?") : String(localized: "KEEP GOING?")
    }

    private var grantText: String {
        switch (offer.grantsMoves, offer.grantsSeconds) {
        case (true, true):
            String(localized: "+\(ContinueOffer.extraMoves) moves & +\(ContinueOffer.extraSeconds)s")
        case (false, true):
            String(localized: "+\(ContinueOffer.extraSeconds) seconds")
        default:
            String(localized: "+\(ContinueOffer.extraMoves) moves")
        }
    }

    private var nearMissText: String {
        if gameModel.bossStatus != nil {
            return String(localized: "The guardian is almost beaten!")
        }
        switch offer.piecesRemaining {
        case 0: return String(localized: "You're so close!")
        case 1: return String(localized: "Only 1 more piece to go!")
        default: return String(localized: "Only \(offer.piecesRemaining) more pieces to go!")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                GamePopupPanel(title: title, tone: .red) {
                    VStack(spacing: 14) {
                        progressRing

                        Text(nearMissText)
                            .font(.headline)
                            .foregroundStyle(AppTheme.festivalRed)
                            .multilineTextAlignment(.center)

                        remainingGoals

                        Button(action: payWithCoins) {
                            HStack(spacing: 8) {
                                Image(systemName: offer.grantsMoves ? "plus.circle.fill" : "clock.fill")
                                Text(grantText)
                                Spacer(minLength: 4)
                                HStack(spacing: 3) {
                                    Image(systemName: "circle.inset.filled")
                                    Text("\(offer.coinCost)")
                                        .monospacedDigit()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.22), in: Capsule())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                        .opacity(canAfford ? 1 : 0.55)
                        .accessibilityIdentifier("continue-coins")
                        .accessibilityLabel(Text("\(grantText) for \(offer.coinCost) coins"))

                        CoinAmountChip(amount: "\(gameModel.coins)", size: 13)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("Balance: \(gameModel.coins)"))

                        if offer.allowsRewardedAd {
                            RewardedAdButton(title: "Watch Ad · Free Continue", systemImage: "play.rectangle.fill") {
                                gameModel.acceptContinueFromRewardedAd()
                            }
                        }

                        Button {
                            HapticManager.buttonTap()
                            gameModel.declineContinue()
                        } label: {
                            Text("Give Up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.ink.opacity(0.7))
                                .frame(minWidth: 120, minHeight: 44)
                        }
                        .buttonStyle(.gameIcon)
                        .accessibilityIdentifier("continue-decline")
                        .accessibilityHint(Text("Ends this attempt and uses one life"))
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(20)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
                .scaleEffect(reduceMotion || appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .gameNotice(isPresented: $showInsufficientCoins, message: String(localized: "Not enough coins. Try the free ad continue!"),
                    icon: "circle.fill", tint: AppTheme.festivalRed)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.festivalGold.opacity(0.25), lineWidth: 10)
            Circle()
                .trim(from: 0, to: appeared ? CGFloat(offer.progress) : 0)
                .stroke(AppTheme.accentGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.15), value: appeared)
            VStack(spacing: 0) {
                Text("\(Int((offer.progress * 100).rounded()))%")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("THERE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundStyle(AppTheme.festivalRed)
        }
        .frame(width: 92, height: 92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Int((offer.progress * 100).rounded())) percent of the goals done"))
    }

    @ViewBuilder
    private var remainingGoals: some View {
        let open = gameModel.createLevelTargetDatas().filter { $0.targetNum > 0 }
        if !open.isEmpty {
            HStack(spacing: 10) {
                ForEach(open) { target in
                    HStack(spacing: 4) {
                        target.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                        Text("\(target.targetNum)")
                            .font(.subheadline.weight(.black))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.creamHighlight, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.festivalGold, lineWidth: 1.5))
                }
            }
            .accessibilityElement(children: .combine)
        }
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
