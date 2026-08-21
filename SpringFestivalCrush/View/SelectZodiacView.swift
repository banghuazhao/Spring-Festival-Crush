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

    /// The landmarks in journey order, paired into the two-column rows the map is laid out
    /// in, top row first — the artwork reads bottom-to-top, so the first pair (rat, ox) is
    /// drawn last.
    private var rows: [[ZodiacRecord]] {
        let ordered = gameModel.zodiacRecords.sorted { $0.zodiacType.rawValue < $1.zodiacType.rawValue }
        let pairs = stride(from: 0, to: ordered.count, by: 2).map {
            Array(ordered[$0 ..< min($0 + 2, ordered.count)])
        }
        return pairs.reversed()
    }

    var body: some View {
        ZStack {
            AppTheme.festivalBackground
                .ignoresSafeArea()

            // The artwork is the screen: full-bleed behind the nav bar and home indicator,
            // cropped rather than letterboxed. It carries the "journey" idea on its own, so
            // there is no title card or legend competing with it.
            Color.clear
                .overlay {
                    Image("ZodiacFestivalMap")
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()

            GeometryReader { geometry in
                // Landmarks are laid out rather than pinned to fractions of the image: the
                // image is cropped by an amount that depends on the device's aspect ratio,
                // so anything positioned in image space drifts off screen on some devices.
                let rowHeight = geometry.size.height / CGFloat(max(rows.count, 1))
                let nodeSize = min(max(geometry.size.width * 0.19, 48), min(84, rowHeight - 28))

                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        HStack(spacing: 0) {
                            ForEach(rows[index]) { record in
                                landmark(for: record, size: nodeSize)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        if index < rows.count - 1 {
                            Spacer(minLength: 6)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .padding(.horizontal, 8)
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

    private func landmark(for record: ZodiacRecord, size: CGFloat) -> some View {
        let zodiac = Zodiac.all.first { $0.zodiacType == record.zodiacType }
        let unlocked = record.isUnlocked || unlockAll

        return ZodiacMapNode(
            zodiac: record.zodiacType,
            isUnlocked: unlocked,
            isAvailable: zodiac?.isAvailable ?? false,
            isCurrent: record.zodiacType == focusedZodiac,
            size: size
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

    private func updateBreathing() {
        guard isCurrent, !reduceMotion else {
            breathing = false
            return
        }
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: false)) {
            breathing = true
        }
    }

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
        .buttonStyle(.gameNode)
        .accessibilityLabel("\(zodiac.name) zodiac landmark")
        .accessibilityValue(!isUnlocked ? "Locked" : (isAvailable ? "Unlocked" : "Coming soon"))
        .onAppear { updateBreathing() }
        // The current landmark moves as zodiacs are unlocked, and a node already on screen
        // never gets a second onAppear — without this the pulse stays on the old landmark.
        .onChange(of: isCurrent) { _, _ in updateBreathing() }
    }
}
