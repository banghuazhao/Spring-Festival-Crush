//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelCompleteView: View {
    @EnvironmentObject var gameModel: GameModel

    @State private var starsVisible = false

    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.8, blue: 0.9), // light pink
                    Color(red: 1.0, green: 0.4, blue: 0.6), // darker pink
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .edgesIgnoringSafeArea(.all)
            VStack(spacing: 12) {
                Text("LEVEL COMPLETE!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 2)

                HStack(spacing: 8) {
                    StarView(fillColor: (gameModel.score >= gameModel.level.levelGoal.firstStarScore) ? .yellow : .white.opacity(0.4))
                        .scaleEffect(starsVisible ? 1.0 : 0.1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.05), value: starsVisible)
                    StarView(fillColor: (gameModel.score >= gameModel.level.levelGoal.secondStarScore) ? .yellow : .white.opacity(0.4))
                        .scaleEffect(starsVisible ? 1.0 : 0.1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2), value: starsVisible)
                    StarView(fillColor: (gameModel.score >= gameModel.level.levelGoal.thirdStarScore) ? .yellow : .white.opacity(0.4))
                        .scaleEffect(starsVisible ? 1.0 : 0.1)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.35), value: starsVisible)
                }
                .padding()
                .onAppear { starsVisible = true }

                Text("Your score: \(gameModel.score)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Button {
                    HapticManager.buttonTap()
                    gameModel.onTapNextLevel()
                } label: {
                    Label("Next Level", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .clipShape(.rect(cornerRadius: AppTheme.panelCornerRadius))
        .shadow(color: AppTheme.cardShadowColor, radius: 16, x: 0, y: 8)
    }
}

struct StarView: View {
    var fillColor: Color

    var body: some View {
        Image(systemName: "star.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 50, height: 50)
            .foregroundColor(fillColor)
            .shadow(color: fillColor.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}
