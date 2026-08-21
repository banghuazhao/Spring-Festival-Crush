//
// Pre-level booster purchase sheet, shown before a level starts.
//

import SwiftUI

struct PreLevelBoosterView: View {
    @EnvironmentObject var gameModel: GameModel
    @Environment(\.dismiss) private var dismiss

    let levelNumber: Int
    let onStart: () -> Void

    @State private var buyExtraMoves = false
    @State private var buyHammer = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(UIColor(hex: 0x5B183A)), Color(UIColor(hex: 0x24102E))],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                GamePopupPanel(title: "LEVEL \(levelNumber)", tone: .blue) {
                    VStack(spacing: 14) {
                        Text("CHOOSE YOUR BOOSTERS")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.65))

                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(AppTheme.festivalGold)
                            Text("\(gameModel.coins)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .contentTransition(.numericText())
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
                                title: "Festival Hammer",
                                detail: "Clear any one tile",
                                cost: GameModel.hammerBoosterCost,
                                isSelected: $buyHammer
                            )
                        }

                        Button {
                            HapticManager.buttonTap()
                            if buyExtraMoves { gameModel.applyExtraMovesBooster() }
                            if buyHammer { gameModel.applyHammerBooster() }
                            onStart()
                            dismiss()
                        } label: {
                            Label("Start Level", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
        }
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    private func boosterRow(
        icon: String,
        title: String,
        detail: String,
        cost: Int,
        isSelected: Binding<Bool>
    ) -> some View {
        let affordable = gameModel.coins >= cost
        return Button {
            guard affordable else {
                HapticManager.locked()
                return
            }
            HapticManager.buttonTap()
            isSelected.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(affordable ? AppTheme.accentGradient : AppTheme.neutralGradient))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text(detail)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                        .foregroundStyle(isSelected.wrappedValue ? Color.green : Color.gray.opacity(0.4))
                        .scaleEffect(isSelected.wrappedValue ? 1.12 : 1)
                }
            }
            .foregroundStyle(AppTheme.ink)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected.wrappedValue ? Color.green.opacity(0.14) : AppTheme.creamHighlight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected.wrappedValue ? Color.green : AppTheme.festivalGold.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: .black.opacity(isSelected.wrappedValue ? 0.2 : 0.08), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .opacity(affordable ? 1.0 : 0.48)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected.wrappedValue)
    }
}
