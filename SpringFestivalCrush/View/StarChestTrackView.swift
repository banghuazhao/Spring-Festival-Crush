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
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @State private var bounce = false

    private var fraction: CGFloat {
        guard track.maxStars > 0 else { return 0 }
        return min(1, CGFloat(stars) / CGFloat(track.maxStars))
    }

    private var hasReadyChest: Bool { !track.readyChests(stars: stars, claimed: claimed).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("STAR CHESTS", systemImage: "star.fill")
                    .font(.caption.weight(.black))
                Spacer()
                Text("\(stars)/\(track.maxStars)")
                    .font(.caption.weight(.black).monospacedDigit())
            }
            .foregroundStyle(theme.accent)

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.12)).frame(height: 10)
                    Capsule().fill(AppTheme.accentGradient)
                        .frame(width: max(10, fraction * width), height: 10)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: stars)
                    ForEach(track.chests) { chest in
                        let state = track.state(of: chest, stars: stars, claimed: claimed)
                        Button {
                            guard state == .ready else {
                                HapticManager.locked()
                                return
                            }
                            HapticManager.buttonTap()
                            open(chest)
                        } label: {
                            VStack(spacing: 1) {
                                FestivalChestArt(state: state, width: 34)
                                    .scaleEffect(state == .ready && bounce && !reduceMotion ? 1.12 : 1)
                                    .rotationEffect(.degrees(state == .ready && bounce && !reduceMotion ? -5 : 0))
                                HStack(spacing: 1) {
                                    Image(systemName: "star.fill").font(.system(size: 8, weight: .black))
                                    Text("\(chest.threshold)").font(.system(size: 10, weight: .black, design: .rounded))
                                }
                                .foregroundStyle(state == .locked ? AppTheme.ink.opacity(0.5) : theme.accent)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.gameNode)
                        .position(x: min(width - 20, max(20, CGFloat(chest.threshold) / CGFloat(max(1, track.maxStars)) * width)),
                                  y: 30)
                        .accessibilityLabel(Text("Star chest at \(chest.threshold) stars"))
                        .accessibilityValue(Self.accessibilityValue(state))
                        .accessibilityIdentifier("star-chest-\(chest.index)")
                    }
                }
                .frame(height: 60)
            }
            .frame(height: 60)

            if hasReadyChest {
                Text("A chest is ready — tap it to open!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.festivalRed)
            }
        }
        .padding(14)
        .background(AppTheme.creamHighlight.opacity(0.78), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.7), lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .onAppear(perform: updateBounce)
        .onChange(of: hasReadyChest) { _, _ in updateBounce() }
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
                VStack(spacing: 16) {
                    FestivalChestArt(state: opened ? .opened : .ready, width: 110)
                        .scaleEffect(opened || reduceMotion ? 1 : 0.8)
                    RewardItemsView(reward: chest.reward, revealed: opened)
                    Button {
                        HapticManager.buttonTap()
                        onClose()
                    } label: {
                        Text("Collect").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient))
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
