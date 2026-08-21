//
// Created by Banghua Zhao on 20/08/2024
// Copyright Apps Bay Limited. All rights reserved.
//

import SwiftUI

struct SelectChineseZodiacView: View {
    @EnvironmentObject var gameModel: GameModel
    @EnvironmentObject var settingModel: SettingModel

    @State private var shouldPresentLevel = false
    @State private var presentZodiacUnavailable = false
    @State private var presentZodiacIsLocked = false

    private var unlockAll: Bool { settingModel.unlockAllLevels }

    /// The last unlocked landmark is the player's current place in the journey.
    private var focusedZodiac: ChineseZodiac {
        gameModel.zodiacRecords
            .filter { $0.isUnlocked || unlockAll }
            .max { $0.zodiacType.rawValue < $1.zodiacType.rawValue }?
            .zodiacType ?? .rat
    }

    var body: some View {
        GeometryReader { geometry in
            let mapWidth = min(geometry.size.width - 20, 680)
            let mapHeight = mapWidth * 1.5

            ZStack {
                LinearGradient(
                    colors: [Color(UIColor(hex: 0xF8C96B)), Color(UIColor(hex: 0xB3262E))],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            mapHeader

                            ZStack {
                                Image("ZodiacFestivalMap")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: mapWidth, height: mapHeight)
                                    .clipped()

                                ForEach(gameModel.zodiacRecords) { record in
                                    let zodiac = Zodiac.all.first { $0.zodiacType == record.zodiacType }
                                    let unlocked = record.isUnlocked || unlockAll

                                    ZodiacMapNode(
                                        zodiac: record.zodiacType,
                                        isUnlocked: unlocked,
                                        isAvailable: zodiac?.isAvailable ?? false,
                                        isCurrent: record.zodiacType == focusedZodiac,
                                        size: min(max(mapWidth * 0.16, 62), 88)
                                    ) {
                                        if !unlocked {
                                            HapticManager.locked()
                                            presentZodiacIsLocked = true
                                        } else if let zodiac, zodiac.isAvailable {
                                            HapticManager.buttonTap()
                                            gameModel.selectZodiac(record)
                                            shouldPresentLevel = true
                                        } else {
                                            HapticManager.unavailable()
                                            presentZodiacUnavailable = true
                                        }
                                    }
                                    .position(
                                        x: mapWidth * record.zodiacType.mapPosition.x,
                                        y: mapHeight * record.zodiacType.mapPosition.y
                                    )
                                    .id(record.zodiacType)
                                }
                            }
                            .frame(width: mapWidth, height: mapHeight)
                            .clipShape(.rect(cornerRadius: 26))
                            .overlay(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.white.opacity(0.45), lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)

                            mapLegend
                                .padding(.bottom, 22)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(focusedZodiac, anchor: .center)
                        }
                    }
                    .onChange(of: focusedZodiac) { _, zodiac in
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                            proxy.scrollTo(zodiac, anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $shouldPresentLevel) {
            SelectLevelView()
        }
        .gameNotice(
            isPresented: $presentZodiacUnavailable,
            message: "This landmark is still being built. Coming soon!",
            icon: "hammer.fill",
            tint: .orange
        )
        .gameNotice(
            isPresented: $presentZodiacIsLocked,
            message: "Complete the previous zodiac to unlock this landmark.",
            icon: "lock.fill",
            tint: AppTheme.festivalRed
        )
    }

    private var mapHeader: some View {
        VStack(spacing: 5) {
            Text("THE ZODIAC JOURNEY")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Text("Climb the festival path · master all 12 guardians")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(AppTheme.cream.opacity(0.94))
                .overlay(Capsule().stroke(AppTheme.festivalGold, lineWidth: 3))
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }

    private var mapLegend: some View {
        HStack(spacing: 14) {
            Label("Current", systemImage: "sparkles")
            Label("Locked", systemImage: "lock.fill")
            Label("Coming soon", systemImage: "hammer.fill")
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(AppTheme.ink.opacity(0.8))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(AppTheme.cream.opacity(0.9)))
    }
}

private extension ChineseZodiac {
    var mapPosition: CGPoint {
        switch self {
        case .rat: CGPoint(x: 0.30, y: 0.91)
        case .ox: CGPoint(x: 0.72, y: 0.91)
        case .tiger: CGPoint(x: 0.31, y: 0.77)
        case .rabbit: CGPoint(x: 0.70, y: 0.77)
        case .dragon: CGPoint(x: 0.31, y: 0.625)
        case .snake: CGPoint(x: 0.70, y: 0.625)
        case .horse: CGPoint(x: 0.32, y: 0.48)
        case .goat: CGPoint(x: 0.68, y: 0.48)
        case .monkey: CGPoint(x: 0.31, y: 0.34)
        case .rooster: CGPoint(x: 0.70, y: 0.34)
        case .dog: CGPoint(x: 0.32, y: 0.215)
        case .pig: CGPoint(x: 0.70, y: 0.215)
        }
    }
}

private struct ZodiacMapNode: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let zodiac: ChineseZodiac
    let isUnlocked: Bool
    let isAvailable: Bool
    let isCurrent: Bool
    let size: CGFloat
    let action: () -> Void

    @State private var breathing = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: -3) {
                ZStack {
                    if isCurrent {
                        Circle()
                            .stroke(AppTheme.festivalGold, lineWidth: 5)
                            .frame(width: size + 12, height: size + 12)
                            .scaleEffect(breathing ? 1.16 : 0.96)
                            .opacity(breathing ? 0.05 : 0.9)
                    }

                    Circle()
                        .fill(
                            isUnlocked
                                ? LinearGradient(colors: [AppTheme.creamHighlight, AppTheme.festivalGold], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.gray.opacity(0.85), Color.black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: size, height: size)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 3))
                        .overlay(Circle().stroke(AppTheme.festivalGoldDark, lineWidth: 2).padding(5))
                        .shadow(color: .black.opacity(0.42), radius: 8, y: 6)

                    Text(zodiac.emoji)
                        .font(.system(size: size * 0.5))
                        .grayscale(isUnlocked ? 0 : 1)
                        .opacity(isUnlocked ? 1 : 0.55)

                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.25, weight: .black))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Color.black.opacity(0.72)))
                            .offset(x: size * 0.34, y: size * 0.32)
                    } else if !isAvailable {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: size * 0.2, weight: .black))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(Color.orange))
                            .offset(x: size * 0.34, y: size * 0.32)
                    }
                }

                Text(zodiac.name.uppercased())
                    .font(.system(size: max(10, size * 0.17), weight: .black, design: .rounded))
                    .foregroundStyle(isUnlocked ? AppTheme.ink : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isUnlocked ? AppTheme.cream.opacity(0.96) : Color.black.opacity(0.72))
                            .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
        }
        .buttonStyle(ZodiacNodeButtonStyle())
        .accessibilityLabel("\(zodiac.name) zodiac landmark")
        .accessibilityValue(!isUnlocked ? "Locked" : (isAvailable ? "Unlocked" : "Coming soon"))
        .onAppear {
            guard isCurrent, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: false)) {
                breathing = true
            }
        }
    }
}

private struct ZodiacNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -2 : 0))
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
    }
}
