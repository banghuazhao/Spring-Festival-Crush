//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SpriteKit
import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameModel: GameModel
    let screenSize: CGSize

    @State private var gameScene: GameScene?

    var body: some View {
        ZStack {
            if let gameScene {
                SpriteView(scene: gameScene)
                    .ignoresSafeArea(.all)
            }
            VStack {
                HStack {
                    Text(gameModel.levelLabel)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                    Text(gameModel.scoreLabel)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                    Text(gameModel.moveLabel)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Spacer()
                HStack {
                    Button(action: gameModel.onTapShuffle) {
                        Text("Shuffle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()

                    Button(action: gameModel.onTapBack) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }

            if gameModel.gameState == .lose {
                LevelFailedView(level: gameModel.currentLevel, onTapTryAgainLevel: gameModel.onTapTryAgainLevel)
            } else if gameModel.gameState == .win {
                LevelCompleteView(score: gameModel.score, level: gameModel.currentLevel, onTapNextLevel: gameModel.onTapNextLevel)
            }
        }
        .onAppear {
            gameScene = GameScene(size: screenSize, gameModel: gameModel)
        }
    }
}
