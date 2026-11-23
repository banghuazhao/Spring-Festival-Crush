import SwiftUI

/// The chapter's star milestones: a progress rail with three chests that open at
/// one, two and three stars per level.
struct StarChestTrackView: View {
    let theme: ZodiacChapterTheme
    let track: StarChestTrack
    let stars: Int
    let claimed: Set<Int>
    let open: (StarChestTrack.Chest) -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var bounce = false
    @State private var previewChest: StarChestTrack.Chest?

    private var fraction: CGFloat {
        guard track.maxStars > 0 else { return 0 }
        return min(1, CGFloat(stars) / CGFloat(track.maxStars))
    }

    private var hasReadyChest: Bool { !track.readyChests(stars: stars, claimed: claimed).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
            HStack(spacing: 6) {
                GameSectionLabel("STAR CHESTS")
                HelpTipButton(Text("Earn stars on this chapter's levels. A chest opens when your stars reach its number."),
                              size: 14, tint: theme.accent)
                Spacer()
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.1)).frame(height: 6)
                    Capsule().fill(AppTheme.accentGradient)
                        .frame(width: max(6, fraction * width), height: 6)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stars)
                    ForEach(track.chests) { chest in
                        let state = track.state(of: chest, stars: stars, claimed: claimed)
                        Button {
                            switch state {
                            case .locked:
                                HapticManager.locked()
                                previewChest = chest
                            case .ready:
                                HapticManager.buttonTap()
                                open(chest)
                            case .opened:
                                HapticManager.buttonTap()
                                previewChest = chest
                            }
                        } label: {
                            VStack(spacing: 0) {
                                FestivalChestArt(state: state, width: 28)
                                    .scaleEffect(state == .ready && bounce && !reduceMotion ? 1.12 : 1)
                                    .rotationEffect(.degrees(state == .ready && bounce && !reduceMotion ? -5 : 0))
                                HStack(spacing: 1) {
                                    Image(systemName: "star.fill").font(.system(size: 7, weight: .black))
                                    Text("\(chest.threshold)").font(.system(size: 9, weight: .black, design: .rounded))
                                }
                                .foregroundStyle(state == .locked ? AppTheme.ink.opacity(0.5) : theme.accent)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .overlay(alignment: .bottomTrailing) {
                                if state == .ready {
                                    TapHintHand(size: 20).offset(x: 10, y: 10)
                                }
                            }
                        }
                        .buttonStyle(.gameNode)
                        .position(x: min(width - 20, max(20, CGFloat(chest.threshold) / CGFloat(max(1, track.maxStars)) * width)),
                                  y: 24)
                        .accessibilityLabel(Text("Star chest at \(chest.threshold) stars"))
                        .accessibilityValue(Self.accessibilityValue(state))
                        .accessibilityHint(state == .ready ? Text("Open chest") : Text("Preview rewards"))
                        .accessibilityIdentifier("star-chest-\(chest.index)")
                    }
                }
                .frame(height: 48)
            }
            .frame(height: 48)
        }
        .onAppear(perform: updateBounce)
        .onChange(of: hasReadyChest) { _, _ in updateBounce() }
        .sheet(item: $previewChest) { chest in
            preview(for: chest)
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Reads the chest's existing reward without going through the claim callback.
    private func preview(for chest: StarChestTrack.Chest) -> some View {
        let isOpened = claimed.contains(chest.index)
        return ZStack {
            AppTheme.festivalBackground.ignoresSafeArea()
            ScrollView {
                GamePopupPanel(title: String(localized: "Chest preview"), tone: .gold) {
                    VStack(spacing: AppTheme.Space.md) {
                        FestivalChestArt(state: isOpened ? .opened : .locked, width: 68)

                        if isOpened {
                            Label("Opened", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(theme.accent)
                        } else {
                            Label {
                                Text("Stars needed to unlock: \(max(0, chest.threshold - stars))")
                            } icon: {
                                Image(systemName: "star.fill")
                            }
                            .font(.headline)
                            .foregroundStyle(theme.accent)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                            ForEach(chest.reward.items) { item in
                                VStack(spacing: 4) {
                                    RewardIcon(kind: item.kind, size: 32)
                                    Text("+\(item.amount)")
                                        .font(.headline.weight(.black).monospacedDigit())
                                    Text(item.kind.name)
                                        .font(.caption.weight(.semibold))
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .gameInset(padding: 6, radius: AppTheme.Radius.sm)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text("\(item.amount) \(item.kind.name)"))
                            }
                        }

                        Button {
                            previewChest = nil
                        } label: {
                            Text("Close").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.gamePrimary(gradient: theme.gradient))
                        .accessibilityIdentifier("star-chest-preview-close")
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func updateBounce() {
        guard hasReadyChest, !reduceMotion else {
            bounce = false
            return
        }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { bounce = true }
    }

    private static func accessibilityValue(_ state: StarChestState) -> Text {
        switch state {
        case .locked: Text("Locked")
        case .ready: Text("Ready to open")
        case .opened: Text("Opened")
        }
    }
}

/// The chest-opening moment: lid pops, rewards spill out, all granted on open.
struct StarChestRewardView: View {
    let chest: StarChestTrack.Chest
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var opened = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { if opened { onClose() } }

            if opened && !reduceMotion {
                CelebrationBurstView().allowsHitTesting(false)
            }

            GamePopupPanel(title: String(localized: "STAR CHEST OPENED!"), tone: .gold) {
                VStack(spacing: AppTheme.Space.md) {
                    FestivalChestArt(state: opened ? .opened : .ready, width: 88)
                        .scaleEffect(opened || reduceMotion ? 1 : 0.8)
                    RewardItemsView(reward: chest.reward, revealed: opened)
                    Button {
                        HapticManager.buttonTap()
                        onClose()
                    } label: {
                        Text("Collect").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gameGold)
                    .accessibilityIdentifier("star-chest-collect")
                }
                .foregroundStyle(AppTheme.ink)
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .onAppear {
            UISoundPlayer.shared.play(.chime)
            UISoundPlayer.shared.play(.glissando, volume: 0.6)
            HapticManager.rewardOpen()
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.55).delay(0.12)) {
                opened = true
            }
        }
    }
}
