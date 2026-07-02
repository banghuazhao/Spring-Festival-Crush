//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelFailedView: View {
    @EnvironmentObject var gameModel: GameModel

    @State private var shake = false

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.5, green: 0.5, blue: 0.55),
                    Color(red: 0.25, green: 0.25, blue: 0.3),
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .edgesIgnoringSafeArea(.all)
            VStack(spacing: 12) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.9))
                    .rotationEffect(.degrees(shake ? -8 : 8))
                    .animation(.easeInOut(duration: 0.12).repeatCount(4, autoreverses: true), value: shake)
                    .onAppear { shake = true }

                Text("OUT OF MOVES")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("Level \(gameModel.currentLevel) · Score \(gameModel.score)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))

                if gameModel.lives > 0 {
                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapTryAgainLevel()
                    } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.dangerGradient))
                    .padding(.top, 8)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "heart.slash.fill")
                            .foregroundColor(.red)
                        Text("Out of lives")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 8)

                    RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                        gameModel.grantRewardedLife()
                        gameModel.onTapTryAgainLevel()
                    }

                    Button {
                        HapticManager.buttonTap()
                        gameModel.onTapTryAgainLevel()
                    } label: {
                        Text("Back to Levels")
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.neutralGradient))
                }
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .clipShape(.rect(cornerRadius: AppTheme.panelCornerRadius))
        .shadow(color: AppTheme.cardShadowColor, radius: 16, x: 0, y: 8)
    }
}
