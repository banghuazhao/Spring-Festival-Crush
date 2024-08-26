//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SpriteKit
import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var themeModel: ThemeModel
    @EnvironmentObject var settingModel: SettingModel

    let screenSize: CGSize

    @State private var gameScene: GameScene?

    @State var showingSettings: Bool = false

    var body: some View {
        ZStack {
            if let gameScene {
                SpriteView(scene: gameScene)
                    .ignoresSafeArea(.all)
            }

            VStack {
                gameStatusView
                    .padding()
                Spacer() // This pushes the content to the top
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
                }
            }

            ZStack {
                if gameModel.gameState == .lose || gameModel.gameState == .win {
                    Color.black.opacity(0.2).ignoresSafeArea()
                }

                if gameModel.gameState == .lose {
                    LevelFailedView()
                } else if gameModel.gameState == .win {
                    LevelCompleteView()
                }
            }
        }
        .onAppear {
            gameScene = GameScene(
                size: screenSize,
                gameModel: gameModel,
                themeModel: themeModel,
                settingModel: settingModel
            )
        }
    }

    var gameStatusView: some View {
        HStack(spacing: 10) {
            // Level Info
            VStack(alignment: .leading) {
                HStack {
                    Text("Level:")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(gameModel.currentLevel)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.yellow)
                }

                VStack {
                    Text("Moves:")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Text("\(gameModel.movesLeft)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.yellow)
                }
            }
            .frame(minWidth: 80)

            Divider()
                .background(Color.white)

            // Score Info
            GeometryReader { geo in
                VStack {
                    Spacer()
                    StarProgressView(
                        currentScore: gameModel.score,
                        levelGoal: gameModel.level.levelGoal,
                        width: geo.size.width
                    )
                    LevelTargetView(levelTargetDatas: gameModel.createLevelTargetDatas())
                    Spacer()
                }
                .frame(minWidth: 160)
            }

            Divider()
                .background(Color.white)

            Button(action: {
                showingSettings.toggle() // Show settings when tapped
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
            .padding(.leading, 10) // Add some spacing from the progress bar
            .sheet(isPresented: $showingSettings) {
                SettingsView() // Display the settings view when tapped
            }
        }
        .padding(.vertical, 8) // Reduced vertical padding
        .padding(.horizontal, 10) // Adjust horizontal padding
        .frame(height: 100)
        .frame(maxWidth: 600)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(radius: 5)
        )
    }
}

struct StarProgressView: View {
    let currentScore: Int
    let levelGoal: LevelGoal

    let width: CGFloat
    let starPositions: [CGFloat] = [0.33, 0.66, 1.0] // Relative positions of stars on the bar

    var body: some View {
        ZStack(alignment: .leading) {
            // Background Bar
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.pink.opacity(0.5))
                .frame(height: 12)

            // Foreground Bar (Progress)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue)
                .frame(width: min(1.0, CGFloat(currentScore) / CGFloat(levelGoal.thirdStarScore)) * width, height: 12)

            // Star Indicators
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: width * starPositions[0])
                Image(systemName: "star.fill") // Default filled star
                    .foregroundColor(currentScore >= levelGoal.firstStarScore ? .yellow : .gray)
                Spacer()
                Image(systemName: "star.fill") // Default filled star
                    .foregroundColor(currentScore >= levelGoal.secondStarScore ? .yellow : .gray)
                Spacer()
                Image(systemName: "star.fill") // Default filled star
                    .foregroundColor(currentScore >= levelGoal.thirdStarScore ? .yellow : .gray)
            }
        }
        .frame(height: 20)
    }
}

struct LevelTargetView: View {
    let levelTargetDatas: [LevelTargetData]

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.purple.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 5, y: 5)

            // Content
            HStack {
                ForEach(levelTargetDatas) { levelTargetData in
                    HStack(spacing: 2) {
                        levelTargetData.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)

                        if levelTargetData.targetNum > 0 {
                            Text("\(levelTargetData.targetNum)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 2, y: 2)
                        } else {
                            Text("✅")
                                .font(.system(size: 18))
                        }
                    }
                }
            }
        }
        .frame(height: 40)
    }
}
