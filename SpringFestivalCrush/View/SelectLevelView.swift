//
// Created by Banghua Zhao on 18/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct SelectLevelView: View {
    @EnvironmentObject var gameModel: GameModel
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
    // Set by the booster sheet's Start button and acted on in onDismiss: raising
    // shouldPresentGame while the sheet is still on screen makes UIKit try to present the
    // full-screen game from a controller that is mid-dismissal, and the game never appears.
    @State private var startAfterBoosterSheet = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// The lowest level the player hasn't cleared yet — highlighted so the grid always says
    /// "you are here", the same way the zodiac map marks the current landmark.
    private var currentLevelNumber: Int? {
        gameModel.currentLevelRecords
            .first { !$0.isComplete && ($0.isUnlocked || unlockAll) }?
            .number
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppTheme.festivalBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        LivesHeaderView()

                        LazyVGrid(columns: geometry.size.width < 600 ? columnsCompact : columnsRegular, spacing: 18) {
                            ForEach(gameModel.currentLevelRecords, id: \.self) { levelRecord in
                                LevelView(
                                    level: levelRecord.number,
                                    isUnlocked: levelRecord.isUnlocked || unlockAll,
                                    isCurrent: levelRecord.number == currentLevelNumber,
                                    stars: levelRecord.stars,
                                    presentLevelIsLocked: $presentLevelIsLocked
                                ) {
                                    guard gameModel.lives > 0 else {
                                        HapticManager.locked()
                                        presentOutOfLives = true
                                        return
                                    }
                                    pendingLevelNumber = levelRecord.number
                                    gameModel.resetBoostersForNewAttempt()
                                    showBoosterSheet = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $gameModel.shouldPresentGame) {
            GeometryReader { geo in
                GameView(screenSize: geo.size)
            }
        }
        .sheet(isPresented: $showBoosterSheet, onDismiss: {
            guard startAfterBoosterSheet else { return }
            startAfterBoosterSheet = false
            gameModel.selectLevel(pendingLevelNumber)
            gameModel.shouldPresentGame = true
        }) {
            PreLevelBoosterView(levelNumber: pendingLevelNumber) {
                startAfterBoosterSheet = true
            }
        }
        .navigationTitle(gameModel.zodiac?.zodiacType.title ?? "Select Level")
        .navigationBarTitleDisplayMode(.inline)
        .gameNotice(
            isPresented: $presentLevelIsLocked,
            message: "Complete the previous level to unlock this one.",
            icon: "lock.fill",
            tint: AppTheme.festivalRed
        )
        .gameNotice(
            isPresented: $presentOutOfLives,
            message: "Out of lives. A new heart is on the way!",
            icon: "heart.slash.fill",
            tint: AppTheme.festivalRed
        )
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
        VStack(spacing: 9) {
            HStack(spacing: 4) {
                ForEach(0 ..< GameModel.maxLives, id: \.self) { index in
                    Image(systemName: index < gameModel.lives ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(index < gameModel.lives ? Color.red : AppTheme.ink.opacity(0.28))
                }
                Spacer(minLength: 4)
                if gameModel.lives < GameModel.maxLives {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(countdownText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                } else {
                    Text("FULL")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(gameModel.lives) of \(GameModel.maxLives) lives")

            if gameModel.lives < GameModel.maxLives {
                HStack {
                    Spacer()
                    RewardedAdButton(title: "Watch Ad for +1 Life", systemImage: "play.rectangle.fill") {
                        gameModel.grantRewardedLife()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cream.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.festivalGold, lineWidth: 3)
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
    }
}

struct LevelView: View {
    let level: Int
    let isUnlocked: Bool
    var isCurrent: Bool = false
    let stars: Int
    @Binding var presentLevelIsLocked: Bool
    let action: () -> Void

    private let nodeSize: CGFloat = 74

    private var innerRingColor: Color {
        guard isUnlocked else { return .white.opacity(0.25) }
        return isCurrent ? AppTheme.festivalRed : AppTheme.festivalGoldDark
    }

    var body: some View {
        VStack(spacing: 6) {
            Button {
                if isUnlocked {
                    HapticManager.buttonTap()
                    action()
                } else {
                    HapticManager.locked()
                    presentLevelIsLocked = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            isUnlocked
                                ? LinearGradient(
                                    colors: [AppTheme.creamHighlight, AppTheme.festivalGold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.8), Color.black.opacity(0.62)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 3))
                        .overlay(
                            Circle()
                                .stroke(innerRingColor, lineWidth: isCurrent ? 3 : 2)
                                .padding(5)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 7, y: 5)

                    Text("\(level)")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundStyle(isUnlocked ? AppTheme.ink : .white.opacity(0.75))
                        .shadow(color: .black.opacity(isUnlocked ? 0.12 : 0.4), radius: 2, y: 1)

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Color.black.opacity(0.72)))
                            .offset(x: nodeSize * 0.33, y: nodeSize * 0.31)
                    }
                }
            }
            .buttonStyle(.gameNode)
            .accessibilityLabel("Level \(level)")
            .accessibilityValue(isUnlocked ? "\(stars) of 3 stars" : "Locked")

            HStack(spacing: 3) {
                ForEach(0 ..< 3) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(star < stars ? AppTheme.festivalGold : Color.black.opacity(0.22))
                        .shadow(color: star < stars ? AppTheme.festivalGold.opacity(0.7) : .clear, radius: 4)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
