//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct LevelCompleteView: View {
    @EnvironmentObject var gameModel: GameModel

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
            VStack {
                HStack {
                    StarView(
                        fillColor: (gameModel.score >= gameModel.level.levelGoal.firstStarScore)
                            ? .yellow
                            : .gray
                    )
                    StarView(
                        fillColor: (gameModel.score >= gameModel.level.levelGoal.secondStarScore)
                            ? .yellow
                            : .gray
                    )
                    StarView(
                        fillColor: (gameModel.score >= gameModel.level.levelGoal.thirdStarScore)
                            ? .yellow
                            : .gray
                    )
                }
                .padding()
                Text("Level \(gameModel.currentLevel) completed!")
                    .padding()
                Text("Your score: \(gameModel.score)")
                    .padding()

                Button(action: gameModel.onTapNextLevel) {
                    Text("Next Level")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .clipShape(.rect(cornerRadius: 20))
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
