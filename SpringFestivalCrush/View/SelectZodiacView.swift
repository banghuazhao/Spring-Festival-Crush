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

    /// The landmarks in journey order, paired into the two-column rows the artwork paints,
    /// top row first — the path climbs bottom-to-top, so the first pair (rat, ox) is drawn
    /// last.
    private var rows: [[ZodiacRecord]] {
        let ordered = gameModel.zodiacRecords.sorted { $0.zodiacType.rawValue < $1.zodiacType.rawValue }
        let pairs = stride(from: 0, to: ordered.count, by: 2).map {
            Array(ordered[$0 ..< min($0 + 2, ordered.count)])
        }
        return pairs.reversed()
    }

    /// The scroll anchor for the row holding the current landmark. Rows are the scroll
    /// targets rather than individual landmarks because scrollTo moves both axes at once:
    /// centring a landmark would also centre its column, pushing the other column off screen.
    /// A row spans the map's full width, so centring one leaves the map centred horizontally.
    private var focusedRowAnchor: ChineseZodiac? {
        rows.first { row in row.contains { $0.zodiacType == focusedZodiac } }?
            .first?.zodiacType
    }

    /// Where the painted path puts the landmarks, as fractions of the map: two columns at
    /// 0.30 and 0.70 across. The expanded artwork leaves sky above the last chapter
    /// and a substantially deeper foreground below the Rat/Ox starting row.
    private static let columnInset: CGFloat = 0.10
    private static let firstRowY: CGFloat = 0.24
    private static let lastRowY: CGFloat = 0.69

    /// Preserve the expanded artwork's proportions (836x1881).
    private static let mapAspect: CGFloat = 1881.0 / 836.0

    /// How far past a screen-filling scale the map is drawn. Anything above 1 leaves the map
    /// bigger than the screen on both axes, which is what there is to pan around; higher
    /// values show less of it at once. This is the dial to turn if the balance feels wrong.
    private static let mapZoom: CGFloat = 1.35

    /// Use the actual expanded image aspect, not the old short map. On tall phones
    /// the old aspect enlarged both columns until their buttons touched the edges.
    static func mapSize(for screen: CGSize) -> CGSize {
        let width = max(screen.width * mapZoom, screen.height / mapAspect)
        return CGSize(width: width, height: width * mapAspect)
    }

    var body: some View {
        GeometryReader { geometry in
            // The reader itself stays safe-area aware so it can report the insets; adding
            // them back gives the true screen size the map has to cover before it ignores
            // the safe area and runs full-bleed. Landmarks are placed on the artwork, so a
            // row can pass under the status bar as the map pans — the haze below keeps the
            // clock legible when it does.
            let insets = geometry.safeAreaInsets
            let screen = CGSize(
                width: geometry.size.width + insets.leading + insets.trailing,
                height: geometry.size.height + insets.top + insets.bottom
            )
            // Cover the screen at minimum, then zoom past it, so the map overflows on both
            // axes and can be panned either way. Deriving the height from the width keeps the
            // artwork undistorted.
            let mapSize = Self.mapSize(for: screen)
            let mapWidth = mapSize.width
            let mapHeight = mapSize.height
            let nodeSize = min(max(screen.width * 0.19, 48), 84)
            let rowHeight = nodeSize + 26 // circle plus its name plate

            ZStack {
                // Keep artwork behind the scroll view as well, including while navigation
                // and safe-area changes are being laid out.
                Image("ZodiacFestivalMapExpanded")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
                    .accessibilityHidden(true)

                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Image("ZodiacFestivalMapExpanded")
                                .resizable()
                                .scaledToFill()
                                .frame(width: mapWidth, height: mapHeight)
                                .clipped()
                                .accessibilityHidden(true)

                            // Laid out against the map's own size, so each landmark lands on
                            // the spot the artwork paints for it — beside its own carving.
                            // Insets rather than .position: .position expands its result to
                            // fill the map, which would leave scrollTo treating the whole map
                            // as the target and never reaching an individual landmark.
                            VStack(spacing: 0) {
                                ForEach(rows.indices, id: \.self) { index in
                                    HStack(spacing: 0) {
                                        ForEach(rows[index]) { record in
                                            landmark(for: record, size: nodeSize)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .frame(height: rowHeight)
                                    .id(rows[index].first?.zodiacType)

                                    if index < rows.count - 1 {
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .padding(.top, mapHeight * Self.firstRowY - rowHeight / 2)
                            .padding(.bottom, mapHeight * (1 - Self.lastRowY) - rowHeight / 2)
                            .padding(.horizontal, mapWidth * Self.columnInset)
                            .frame(width: mapWidth, height: mapHeight)
                        }
                        .frame(width: mapWidth, height: mapHeight)
                        .background(MapScrollBoundary())
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        // One runloop later, so the scroll view has its content laid out.
                        DispatchQueue.main.async {
                            proxy.scrollTo(focusedRowAnchor, anchor: .center)
                        }
                    }
                    .onChange(of: focusedZodiac) { _, _ in
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                            proxy.scrollTo(focusedRowAnchor, anchor: .center)
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                // Landmarks pass under the status bar as the map scrolls, and a dark label
                // sliding behind the clock makes the time unreadable. A short haze over just
                // the status bar keeps it legible without putting a bar back on the map.
                LinearGradient(
                    colors: [Color.white.opacity(0.7), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: insets.top)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

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

                Text(zodiac.localizedName.localizedUppercase)
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
        .accessibilityLabel(Text("\(zodiac.localizedName) zodiac landmark"))
        .accessibilityValue(!isUnlocked ? Text("Locked") : (isAvailable ? Text("Unlocked") : Text("Coming soon")))
        .onAppear { updateBreathing() }
        // The current landmark moves as zodiacs are unlocked, and a node already on screen
        // never gets a second onAppear — without this the pulse stays on the old landmark.
        .onChange(of: isCurrent) { _, _ in updateBreathing() }
    }
}
