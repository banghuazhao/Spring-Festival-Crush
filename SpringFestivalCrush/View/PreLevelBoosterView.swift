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

    private var totalCost: Int {
        (buyExtraMoves ? GameModel.extraMovesBoosterCost : 0)
            + (buyHammer ? GameModel.hammerBoosterCost : 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Level \(levelNumber)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))

            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(.yellow)
                Text("\(gameModel.coins) Coins")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            RewardedAdButton(title: "Watch Ad for +\(GameModel.rewardedCoinsAmount) Coins", systemImage: "play.rectangle.fill") {
                gameModel.grantRewardedCoins()
            }

            VStack(spacing: 12) {
                boosterRow(
                    icon: "plus.circle.fill",
                    title: "+\(GameModel.extraMovesBoosterAmount) Moves",
                    cost: GameModel.extraMovesBoosterCost,
                    isSelected: $buyExtraMoves
                )
                boosterRow(
                    icon: "hammer.fill",
                    title: "Hammer (clear 1 tile)",
                    cost: GameModel.hammerBoosterCost,
                    isSelected: $buyHammer
                )
            }
            .padding(.horizontal)

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
            .disabled(totalCost > gameModel.coins)
            .opacity(totalCost > gameModel.coins ? 0.5 : 1.0)
            .padding(.horizontal)

            Button("Skip") {
                HapticManager.buttonTap()
                onStart()
                dismiss()
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
        }
        .padding()
        .presentationDetents([.height(420)])
    }

    private func boosterRow(icon: String, title: String, cost: Int, isSelected: Binding<Bool>) -> some View {
        let affordable = gameModel.coins >= cost
        return Button {
            guard affordable else { return }
            HapticManager.buttonTap()
            isSelected.wrappedValue.toggle()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(cost)")
                        .font(.system(size: 14, weight: .semibold))
                }
                Image(systemName: isSelected.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected.wrappedValue ? .green : .secondary.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected.wrappedValue ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected.wrappedValue ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
        .opacity(affordable ? 1.0 : 0.4)
    }
}
