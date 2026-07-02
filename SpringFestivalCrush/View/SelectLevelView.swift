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
    @State private var showBoosterSheet = false
    @State private var pendingLevelNumber: Int = 0
    @State private var presentOutOfLives = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                themeModel.pageBackgroundColor
                    .edgesIgnoringSafeArea(.all)

                ScrollView {
                    LivesHeaderView()
                        .padding(.horizontal)
                        .padding(.top, 8)

                    LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 20) {
                        ForEach(gameModel.currentLevelRecords, id: \.self) { levelRecord in
                            LevelView(
                                level: levelRecord.number,
                                isUnlocked: levelRecord.isUnlocked || unlockAll,
                                stars: levelRecord.stars,
                                presentLevelIsLocked: $presentLevelIsLocked
                            ) {
                                guard gameModel.lives > 0 else {
                                    presentOutOfLives = true
                                    return
                                }
                                pendingLevelNumber = levelRecord.number
                                gameModel.resetBoostersForNewAttempt()
                                showBoosterSheet = true
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
        .sheet(isPresented: $showBoosterSheet) {
            PreLevelBoosterView(levelNumber: pendingLevelNumber) {
                gameModel.selectLevel(pendingLevelNumber)
                gameModel.shouldPresentGame = true
            }
        }
        .navigationTitle("Select Level")
        .navigationBarTitleDisplayMode(.inline)
        .easyToast(isPresented: $presentLevelIsLocked, message: "Complete previous levels to unlock")
        .easyToast(isPresented: $presentOutOfLives, message: "Out of lives! Wait for a life to regenerate.")
        .onAppear {
            gameModel.refreshLives()
        }
        .onReceive(ticker) { _ in
            gameModel.tickLivesCountdown()
        }
    }
}

struct LivesHeaderView: View {
    @EnvironmentObject var gameModel: GameModel

    private var countdownText: String {
        let seconds = Int(gameModel.timeUntilNextLife)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0 ..< GameModel.maxLives, id: \.self) { index in
                    Image(systemName: index < gameModel.lives ? "heart.fill" : "heart")
                        .foregroundColor(index < gameModel.lives ? .red : .secondary.opacity(0.4))
                }
                Spacer()
                if gameModel.lives < GameModel.maxLives {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(countdownText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                }
            }

            if gameModel.lives < GameModel.maxLives {
                HStack {
                    Spacer()
                    RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                        gameModel.grantRewardedLife()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
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
