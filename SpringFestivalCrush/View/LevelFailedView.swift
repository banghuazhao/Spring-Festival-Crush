//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelFailedView: View {
    @EnvironmentObject var gameModel: GameModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shake = false

    var body: some View {
        GamePopupPanel(title: gameModel.loseReason.title, tone: .red) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color(UIColor(hex: 0xC8D0DA))],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 48
                            )
                        )
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(Color.gray.opacity(0.55), lineWidth: 4))

                    Image(systemName: gameModel.loseReason.icon)
                        .font(.system(size: 35, weight: .black))
                        .foregroundStyle(AppTheme.festivalRed)
                }
                .offset(x: reduceMotion ? 0 : (shake ? -6 : 6))
                .rotationEffect(.degrees(reduceMotion ? 0 : (shake ? -4 : 4)))
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.1).repeatCount(5, autoreverses: true),
                    value: shake
                )

                Text("So close! Every attempt reveals a better path.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.75))
                    .multilineTextAlignment(.center)

                HStack(spacing: 18) {
                    // Levels below 1 aren't real levels (the DEBUG demos use -1).
                    resultStat(title: "LEVEL", value: gameModel.currentLevel >= 1 ? "\(gameModel.currentLevel)" : "DEMO")
                    Rectangle()
                        .fill(AppTheme.festivalGold.opacity(0.5))
                        .frame(width: 1, height: 42)
                    resultStat(title: "SCORE", value: "\(gameModel.score)")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.creamHighlight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.festivalGold.opacity(0.6), lineWidth: 2)
                        )
                )

                if gameModel.lives > 0 {
                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapTryAgainLevel()
                    } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                } else {
                    Label("Out of lives", systemImage: "heart.slash.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.festivalRed)

                    RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                        gameModel.grantRewardedLife()
                        gameModel.onTapTryAgainLevel()
                    }

                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapBack()
                    } label: {
                        Label("Back to Levels", systemImage: "map.fill")
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                }
            }
        }
        .padding(.horizontal, 24)
        .onAppear { shake = true }
    }

    private func resultStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.55))
            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.festivalRed)
        }
        .frame(maxWidth: .infinity)
    }
}
