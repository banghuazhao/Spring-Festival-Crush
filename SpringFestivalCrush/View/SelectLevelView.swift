//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI
import EasyToast

struct SelectLevelView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var themeModel: ThemeModel

    @EnvironmentObject var settingModel: SettingModel

    var unlockAll: Bool {
        settingModel.unlockAllLevels
    }

    let columnsCompact = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let columnsRegular = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    @State private var presentLevelIsLocked = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeModel.pageBackgroundColor
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 20) {
                        ForEach(gameModel.currentLevelRecords, id: \.self) { levelRecord in
                            LevelView(
                                level: levelRecord.number,
                                isUnlocked: levelRecord.isUnlocked || unlockAll,
                                stars: levelRecord.stars,
                                presentLevelIsLocked: $presentLevelIsLocked
                            ) {
                                gameModel.selectLevel(levelRecord.number)
                                gameModel.shouldPresentGame = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(isPresented: $gameModel.shouldPresentGame) {
            GeometryReader { geo in
                GameView(screenSize: geo.size)
            }
        }
        .navigationTitle("Select Level")
        .navigationBarTitleDisplayMode(.inline)
        .easyToast(isPresented: $presentLevelIsLocked, message: "Complete previous levels to unlock")
    }
}

struct LevelView: View {
    let level: Int
    let isUnlocked: Bool
    let stars: Int
    @Binding var presentLevelIsLocked: Bool
    let action: () -> Void

    var body: some View {
        VStack {
            Button(action: action) {
                VStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [Color.pink.opacity(0.8), Color.purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.purple.opacity(0.6), radius: 10, x: 5, y: 5) // Purple shadow for depth
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.white.opacity(0.8), Color.clear]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .blur(radius: 1)
                                    .offset(x: -2, y: -2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                    .blur(radius: 1)
                                    .offset(x: 2, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .fill(
                                        RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.5), Color.clear]), center: .topLeading, startRadius: 0, endRadius: 40)
                                    )
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .blur(radius: 1)
                            )

                        Text("\(level)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 2, y: 2)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!isUnlocked)
            .overlay {
                if !isUnlocked {
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .onTapGesture {
                if !isUnlocked {
                    presentLevelIsLocked = true
                }
            }

            HStack(spacing: 4) {
                ForEach(0 ..< 3) { star in
                    Image(systemName: "star.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(star < stars ? Color.orange : Color.gray)
                }
            }
        }
    }
}
