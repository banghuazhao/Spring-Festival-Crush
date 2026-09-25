import SwiftUI

// MARK: - Tile glyph

/// A board tile drawn from the scene's own artwork and overlays (gold armor frame,
/// ice, blast seal), so a pictogram looks exactly like what the player meets on the board.
struct PictoTile: View {
    enum Overlay: Equatable {
        case none
        case armor(Int)
        case ice
        case enhanced
    }

    let asset: String
    var overlay: Overlay = .none
    var size: CGFloat = 28

    private static let slot = Color(UIColor(hex: 0x2E4A50))
    private static let armorGold = Color(UIColor(red: 1, green: 0.79, blue: 0.28, alpha: 1))
    @MainActor private static var enhancedCache: [String: UIImage] = [:]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Self.slot.opacity(0.9))
            artwork
                .resizable()
                .scaledToFit()
                .padding(size * 0.08)
            switch overlay {
            case let .armor(layers):
                frame(color: Self.armorGold, badge: "\(layers)")
            case .ice:
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color.cyan.opacity(0.28))
                frame(color: .cyan, badge: "❄")
            case .none, .enhanced:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var artwork: Image {
        guard overlay == .enhanced, let base = UIImage(named: asset) else { return Image(asset) }
        if let cached = Self.enhancedCache[asset] { return Image(uiImage: cached) }
        let image = EnhancedTileAppearance.image(over: base)
        Self.enhancedCache[asset] = image
        return Image(uiImage: image)
    }

    private func frame(color: Color, badge: String) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .stroke(color, lineWidth: max(1.5, size * 0.08))
            .overlay(alignment: .bottomTrailing) {
                Text(badge)
                    .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .background(Circle().fill(Color(UIColor(red: 0.38, green: 0.16, blue: 0.03, alpha: 1))))
                    .overlay(Circle().stroke(color, lineWidth: 1))
                    .offset(x: size * 0.1, y: size * 0.1)
            }
    }
}

// MARK: - Pictogram grammar

/// The "becomes" arrow between the two halves of a pictogram.
struct PictoArrow: View {
    var systemName = "arrow.right"
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(AppTheme.festivalGoldDark)
            .accessibilityHidden(true)
    }
}

/// A short numeric tag such as ×2, −4 or +5. Numbers read in every language.
struct PictoTag: View {
    let text: String
    var tint: Color = AppTheme.festivalRed
    var size: CGFloat = 12

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, size * 0.45)
            .padding(.vertical, size * 0.12)
            .background(tint, in: Capsule())
            .accessibilityHidden(true)
    }
}

/// Burst stars for "this clears".
struct PictoClear: View {
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.7, weight: .bold))
            .foregroundStyle(AppTheme.festivalGold, AppTheme.festivalRed)
            .shadow(color: AppTheme.festivalGoldDark.opacity(0.6), radius: 1, y: 1)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// "Every N moves": a countdown ring split into N ticks around the number.
struct PictoCountdown: View {
    let moves: Int
    var size: CGFloat = 28
    var tint: Color = AppTheme.festivalRed

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1)
                .stroke(tint,
                        style: StrokeStyle(lineWidth: size * 0.1, lineCap: .butt,
                                           dash: [(.pi * size * 0.9) / CGFloat(max(1, moves)) - 2, 2]))
                .rotationEffect(.degrees(-90))
                .padding(size * 0.05)
            Text(verbatim: "\(moves)")
                .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A rounded card that holds one pictogram.
private struct PictoCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.festivalGold.opacity(0.7), lineWidth: 1.5))
    }
}

// MARK: - Level mechanic tips

/// One board mechanic a level introduces, shown as a picture instead of a sentence.
enum MechanicTip: Hashable {
    case swapToMatch
    case specials
    case lock
    case armor
    case ice
    case cascade

    /// Level JSON keeps the authored sentence (localized for VoiceOver); the briefing
    /// draws the mechanics it names. Order follows the sentence.
    static func tips(in hint: String) -> [MechanicTip] {
        let keys: [(String, MechanicTip)] = [
            ("Swap neighbors", .swapToMatch),
            ("Match 3 to collect", .swapToMatch),
            ("Gold frame", .armor),
            ("Ice:", .ice),
            ("beside a lock", .lock),
            ("Chain reactions", .cascade),
            ("Match 4", .specials),
            ("special tiles", .specials)
        ]
        let found = keys.compactMap { key, tip in hint.range(of: key).map { ($0.lowerBound, tip) } }
            .sorted { $0.0 < $1.0 }
        var tips: [MechanicTip] = []
        for (_, tip) in found where !tips.contains(tip) { tips.append(tip) }
        return tips
    }
}

/// The level's mechanics as a grid of pictograms, with the full sentence for VoiceOver.
struct MechanicTipsView: View {
    let hint: String

    var body: some View {
        let tips = MechanicTip.tips(in: hint)
        if tips.isEmpty {
            Text(LocalizedStringKey(hint))
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    PictoCard { MechanicTipArt(tip: tip) }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey(hint)))
        }
    }
}

private struct MechanicTipArt: View {
    let tip: MechanicTip
    private let tile: CGFloat = 26

    var body: some View {
        switch tip {
        case .swapToMatch:
            SwapToMatchPicto(tile: tile)
        case .specials:
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    TileRun(asset: "redPocket", count: 4, size: tile * 0.72)
                    PictoArrow(size: 11)
                    PictoTile(asset: "redPocket", overlay: .enhanced, size: tile)
                }
                HStack(spacing: 5) {
                    TileRun(asset: "dumpling", count: 5, size: tile * 0.72)
                    PictoArrow(size: 11)
                    PictoTile(asset: "FiveTile", size: tile)
                }
            }
        case .lock:
            NeighborMatchPicto(tile: tile, target: PictoTile(asset: "LockTile", size: tile)) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: tile * 0.62, weight: .bold))
                    .foregroundStyle(AppTheme.festivalGoldDark)
                    .frame(width: tile, height: tile)
            }
        case .ice:
            NeighborMatchPicto(tile: tile, target: PictoTile(asset: "lantern", overlay: .ice, size: tile)) {
                PictoTile(asset: "lantern", size: tile)
            }
        case .armor:
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    PictoTile(asset: "bowl", overlay: .armor(2), size: tile)
                    PictoArrow(size: 11)
                    PictoTile(asset: "bowl", overlay: .armor(1), size: tile)
                    PictoArrow(size: 11)
                    PictoClear(size: tile)
                }
                HStack(spacing: 4) {
                    Image("HammerBoosterIcon").resizable().scaledToFit().frame(width: tile * 0.8, height: tile * 0.8)
                    PictoTile(asset: "firecracker", overlay: .enhanced, size: tile * 0.8)
                    PictoArrow(size: 10)
                    PictoTag(text: "−1", tint: AppTheme.festivalGoldDark, size: 11)
                }
            }
        case .cascade:
            HStack(spacing: 5) {
                VStack(spacing: 1) {
                    PictoTile(asset: "firecracker", size: tile * 0.8)
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppTheme.festivalGoldDark)
                    PictoTile(asset: "dumpling", size: tile * 0.8)
                }
                PictoArrow(size: 11)
                VStack(spacing: 3) {
                    PictoClear(size: tile)
                    PictoTag(text: "×3", size: 11)
                }
            }
        }
    }
}

/// A short run of identical tiles, overlapped so four or five fit in a small card.
private struct TileRun: View {
    let asset: String
    let count: Int
    var size: CGFloat

    var body: some View {
        HStack(spacing: -size * 0.18) {
            ForEach(0 ..< count, id: \.self) { _ in PictoTile(asset: asset, size: size) }
        }
    }
}

/// Three matching tiles sitting right above a blocker, then what the blocker becomes.
private struct NeighborMatchPicto<Result: View>: View {
    let tile: CGFloat
    let target: PictoTile
    @ViewBuilder let result: Result

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0 ..< 3, id: \.self) { _ in PictoTile(asset: "redPocket", size: tile * 0.8) }
                }
                .overlay(Capsule().stroke(AppTheme.festivalGold, lineWidth: 2).padding(-2))
                target
            }
            PictoArrow(size: 11)
            result
        }
    }
}

/// The first lesson, animated: slide a tile into the gap, three in a row, clear.
private struct SwapToMatchPicto: View {
    let tile: CGFloat
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    private enum Phase: CaseIterable { case ready, swapped, cleared }

    var body: some View {
        if reduceMotion {
            board(.ready).overlay(swapBadge)
        } else {
            PhaseAnimator(Phase.allCases) { phase in
                board(phase).overlay(swapBadge.opacity(phase == .ready ? 1 : 0))
            } animation: { phase in
                switch phase {
                case .ready: .easeOut(duration: 0.25).delay(0.5)
                case .swapped: .spring(response: 0.35, dampingFraction: 0.65).delay(0.9)
                case .cleared: .easeInOut(duration: 0.3).delay(0.2)
                }
            }
        }
    }

    private var step: CGFloat { tile + 3 }

    private func board(_ phase: Phase) -> some View {
        let swapped = phase != .ready
        return ZStack(alignment: .topLeading) {
            PictoTile(asset: "redPocket", size: tile).offset(x: 0)
            PictoTile(asset: "redPocket", size: tile).offset(x: step * 2)
            PictoTile(asset: "dumpling", size: tile).offset(x: step, y: swapped ? step : 0)
            PictoTile(asset: "redPocket", size: tile).offset(x: step, y: swapped ? 0 : step)
            if phase == .cleared {
                HStack(spacing: 3) {
                    ForEach(0 ..< 3, id: \.self) { _ in PictoClear(size: tile) }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: step * 2 + tile, height: step + tile, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            Capsule()
                .stroke(AppTheme.festivalGold, lineWidth: 2)
                .frame(width: step * 2 + tile + 4, height: tile + 4)
                .offset(x: -2, y: -2)
                .opacity(swapped ? 1 : 0)
        }
    }

    private var swapBadge: some View {
        Image(systemName: "arrow.up.arrow.down.circle.fill")
            .font(.system(size: tile * 0.5, weight: .bold))
            .foregroundStyle(.white, AppTheme.festivalRed)
            .offset(x: tile * 0.62, y: tile * 0.55)
            .accessibilityHidden(true)
    }
}

// MARK: - Guardian rules

/// How to hurt this guardian and what it does back, drawn as three picture rules.
struct BossRulesView: View {
    let kind: BossConfiguration.Kind
    private let tile: CGFloat = 26

    var body: some View {
        VStack(spacing: 6) {
            switch kind {
            case .rat:
                rule {
                    PictoTile(asset: "redPocket", size: tile)
                    PictoArrow(systemName: "arrow.triangle.2.circlepath", size: 12)
                    PictoTile(asset: "dumpling", size: tile)
                } result: { hit("−1") }
                raid(every: 3) { PictoTile(asset: "redPocket", overlay: .armor(2), size: tile); PictoTag(text: "×2", size: 11) }
            case .ox:
                rule { PictoTile(asset: "bowl", overlay: .armor(1), size: tile) } result: { hit("−2") }
                rule {
                    PictoTile(asset: "bowl", overlay: .enhanced, size: tile)
                    PictoTile(asset: "LightningTile", size: tile)
                    PictoTile(asset: "FiveTile", size: tile)
                } result: { hit("−4") }
                raid(every: 4) { PictoTile(asset: "bowl", overlay: .armor(2), size: tile); PictoTag(text: "×3", size: 11) }
            case .tiger:
                rule { PictoTile(asset: "firecracker", size: tile) } result: { hit("−1") }
                rule {
                    PictoTile(asset: "lantern", size: tile * 0.8)
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppTheme.festivalGoldDark)
                    PictoTag(text: "2+", tint: AppTheme.festivalGoldDark, size: 11)
                } result: { hit("−1") }
                raid(every: 3) { PictoTile(asset: "lantern", overlay: .ice, size: tile); PictoTag(text: "×2", size: 11) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.instructions))
    }

    private func rule<Cause: View, Effect: View>(@ViewBuilder _ cause: () -> Cause,
                                                 @ViewBuilder result: () -> Effect) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) { cause() }
            PictoArrow(size: 12)
            result()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.creamHighlight, in: .rect(cornerRadius: 12))
    }

    private func raid<Effect: View>(every moves: Int, @ViewBuilder _ effect: () -> Effect) -> some View {
        HStack(spacing: 6) {
            PictoCountdown(moves: moves, size: tile)
            Text(verbatim: kind.avatar).font(.system(size: tile * 0.8))
            Text(verbatim: "💢").font(.system(size: tile * 0.5))
            PictoArrow(size: 12)
            HStack(spacing: 3) { effect() }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.festivalRed.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.festivalRed.opacity(0.35), lineWidth: 1))
    }

    private func hit(_ damage: String) -> some View {
        HStack(spacing: 2) {
            Text(verbatim: kind.avatar).font(.system(size: tile * 0.8))
            PictoTag(text: damage, size: 12)
        }
    }
}

// MARK: - Small shared pictures

/// Five lanterns, lit up to the level's challenge rating.
struct DifficultyLanterns: View {
    let difficulty: Int
    var tint: Color = AppTheme.festivalRed

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1 ... 5, id: \.self) { index in
                Image(systemName: index <= difficulty ? "flame.fill" : "flame")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(index <= difficulty ? tint : AppTheme.ink.opacity(0.25))
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

/// A bobbing pointer that says "tap here" without words.
struct TapHintHand: View {
    var size: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    var body: some View {
        Group {
            if reduceMotion {
                hand(pressed: false)
            } else {
                PhaseAnimator([false, true]) { pressed in
                    hand(pressed: pressed)
                } animation: { pressed in
                    pressed ? .easeIn(duration: 0.18) : .easeOut(duration: 0.45).delay(0.35)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hand(pressed: Bool) -> some View {
        Text(verbatim: "👆")
            .font(.system(size: size))
            .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            .scaleEffect(pressed ? 0.88 : 1)
            .offset(y: pressed ? -size * 0.15 : size * 0.1)
    }
}

/// A coin with an amount, for balances and prices.
struct CoinAmountChip: View {
    let amount: String
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.inset.filled")
                .foregroundStyle(AppTheme.festivalGoldDark)
            Text(verbatim: amount)
                .monospacedDigit()
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppTheme.creamHighlight, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.festivalGold, lineWidth: 1.5))
    }
}
