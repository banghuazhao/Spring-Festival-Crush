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
        /// Strength pips of a multi-hit lock, as the board draws them.
        case lockStrength(Int)
        /// A moon blossom under the tile, deep pink while it needs more than one clear.
        case blossom(Int)
    }

    let asset: String
    var overlay: Overlay = .none
    var size: CGFloat = 28

    private static let slot = Color(UIColor(hex: 0x2E4A50))
    private static let armorGold = Color(UIColor(red: 1, green: 0.79, blue: 0.28, alpha: 1))
    @MainActor private static var decoratedCache: [String: UIImage] = [:]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(Self.slot.opacity(0.9))
            if case let .blossom(layers) = overlay {
                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(Color(AppTheme.blossom(layers: layers)))
                    .padding(size * 0.05)
            }
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
            case let .lockStrength(hits):
                frame(color: .clear, badge: "\(hits)")
            case let .blossom(layers):
                frame(color: Color(AppTheme.blossom(layers: layers)), badge: "\(layers)")
            case .none, .enhanced:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var artwork: Image {
        let key: String
        let decorate: (UIImage) -> UIImage
        switch overlay {
        case .enhanced:
            key = asset + ":enhanced"
            decorate = { EnhancedTileAppearance.image(over: $0) }
        case let .lockStrength(strength):
            key = asset + ":\(strength)"
            decorate = { LockTileAppearance.image(over: $0, strength: strength) }
        default:
            return Image(asset)
        }
        if let cached = Self.decoratedCache[key] { return Image(uiImage: cached) }
        guard let base = UIImage(named: asset) else { return Image(asset) }
        let image = decorate(base)
        Self.decoratedCache[key] = image
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
struct PictoCard<Content: View>: View {
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

// MARK: - Rule pictures

/// The rules a level teaches, as picture cards. A NEW tag marks a rule met for the first time;
/// each card's "?" holds the words.
struct RuleLessonsView: View {
    let rules: [GameRule]
    var isNew: (GameRule) -> Bool = { _ in false }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
            ForEach(rules) { rule in
                PictoCard { RuleArt(rule: rule) }
                    .overlay(alignment: .topLeading) {
                        if isNew(rule) { NewRuleTag().offset(x: -4, y: -6) }
                    }
                    .overlay(alignment: .topTrailing) {
                        HelpTipButton(Text(rule.detail), size: 16).padding(4)
                    }
            }
        }
    }
}

/// A small red "NEW" tag for a rule the player hasn't met before.
struct NewRuleTag: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.festivalRed, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1))
            .rotationEffect(.degrees(-8))
            .accessibilityLabel(Text("New rule"))
    }
}

/// The picture for one rule, shared by level briefings and the rule handbook.
struct RuleArt: View {
    let rule: GameRule
    private let tile: CGFloat = 26

    var body: some View {
        art
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(rule.title) + Text(verbatim: ". ") + Text(rule.detail))
    }

    @ViewBuilder
    private var art: some View {
        switch rule {
        case .goals:
            HStack(spacing: 6) {
                VStack(spacing: 2) {
                    PictoTile(asset: "redPocket", size: tile)
                    PictoTag(text: "12", tint: AppTheme.festivalGoldDark, size: 10)
                }
                VStack(spacing: 2) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(AppTheme.festivalRed)
                        .frame(height: tile)
                    PictoTag(text: "20", size: 10)
                }
                PictoArrow(size: 11)
                Image("StarTile").resizable().scaledToFit().frame(width: tile, height: tile)
            }
        case .swapMatch:
            SwapToMatchPicto(tile: tile)
        case .blastTile:
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    TileRun(asset: "redPocket", count: 4, size: tile * 0.72)
                    PictoArrow(size: 11)
                    PictoTile(asset: "redPocket", overlay: .enhanced, size: tile)
                }
                HStack(spacing: 5) {
                    PictoTile(asset: "redPocket", overlay: .enhanced, size: tile * 0.8)
                    PictoArrow(size: 11)
                    ClearGrid { row, column in abs(row - 2) <= 1 && abs(column - 2) <= 1 }
                }
            }
        case .luckyFive:
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    TileRun(asset: "dumpling", count: 5, size: tile * 0.72)
                    PictoArrow(size: 11)
                    PictoTile(asset: "FiveTile", size: tile)
                }
                HStack(spacing: 4) {
                    PictoTile(asset: "FiveTile", size: tile * 0.8)
                    PictoArrow(systemName: "arrow.left.arrow.right", size: 10)
                    PictoTile(asset: "lantern", size: tile * 0.8)
                    PictoArrow(size: 10)
                    TileRun(asset: "lantern", count: 3, size: tile * 0.62)
                        .overlay(PictoClear(size: tile * 0.8))
                }
            }
        case .lightning:
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    LShapeRun(asset: "firecracker", size: tile * 0.55)
                    PictoArrow(size: 11)
                    PictoTile(asset: "LightningTile", size: tile)
                }
                HStack(spacing: 5) {
                    PictoTile(asset: "LightningTile", size: tile * 0.8)
                    PictoArrow(size: 11)
                    ClearGrid { row, column in row == 2 || column == 2 }
                }
            }
        case .combos:
            HStack(spacing: 4) {
                PictoTile(asset: "FiveTile", size: tile)
                PictoArrow(systemName: "arrow.left.arrow.right", size: 11)
                PictoTile(asset: "LightningTile", size: tile)
                PictoArrow(size: 11)
                Image(systemName: "burst.fill")
                    .font(.system(size: tile * 1.1, weight: .bold))
                    .foregroundStyle(AppTheme.festivalGold)
                    .overlay(PictoClear(size: tile * 0.8))
            }
        case .lock:
            NeighborMatchPicto(tile: tile, target: PictoTile(asset: "LockTile", size: tile)) {
                OpenLockPicto(size: tile)
            }
        case .doubleLock:
            HStack(spacing: 4) {
                PictoTile(asset: "LockTile", overlay: .lockStrength(2), size: tile)
                PictoArrow(size: 11)
                PictoTile(asset: "LockTile", overlay: .lockStrength(1), size: tile)
                PictoArrow(size: 11)
                OpenLockPicto(size: tile)
            }
        case .vaultLock:
            HStack(spacing: 3) {
                PictoTile(asset: "LockTile", overlay: .lockStrength(3), size: tile * 0.9)
                PictoArrow(size: 10)
                PictoTile(asset: "LockTile", overlay: .lockStrength(2), size: tile * 0.9)
                PictoArrow(size: 10)
                PictoTile(asset: "LockTile", overlay: .lockStrength(1), size: tile * 0.9)
                PictoArrow(size: 10)
                OpenLockPicto(size: tile * 0.9)
            }
        case .blossom:
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    PictoTile(asset: "lantern", overlay: .blossom(1), size: tile)
                    PictoArrow(size: 11)
                    Text(verbatim: "🌸").font(.system(size: tile * 0.75))
                }
                HStack(spacing: 4) {
                    PictoTile(asset: "lantern", overlay: .blossom(2), size: tile)
                    PictoArrow(size: 11)
                    PictoTile(asset: "dumpling", overlay: .blossom(1), size: tile)
                    PictoArrow(size: 11)
                    Text(verbatim: "🌸").font(.system(size: tile * 0.75))
                }
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
        case .ratGuardian, .oxGuardian, .tigerGuardian, .rabbitGuardian:
            if let kind = rule.guardian { BossRulesView(kind: kind) }
        }
    }
}

/// A tiny board where the cells a power-up clears light up.
private struct ClearGrid: View {
    var cells = 5
    var cell: CGFloat = 6
    let lit: (Int, Int) -> Bool

    var body: some View {
        VStack(spacing: 1.5) {
            ForEach(0 ..< cells, id: \.self) { row in
                HStack(spacing: 1.5) {
                    ForEach(0 ..< cells, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(row == cells / 2 && column == cells / 2 ? AppTheme.festivalRed
                                  : lit(row, column) ? AppTheme.festivalGold : AppTheme.ink.opacity(0.15))
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Five tiles bent into an L: three down, then two across.
private struct LShapeRun: View {
    let asset: String
    let size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            PictoTile(asset: asset, size: size)
            PictoTile(asset: asset, size: size)
            HStack(spacing: 1) {
                ForEach(0 ..< 3, id: \.self) { _ in PictoTile(asset: asset, size: size) }
            }
        }
    }
}

private struct OpenLockPicto: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "lock.open.fill")
            .font(.system(size: size * 0.62, weight: .bold))
            .foregroundStyle(AppTheme.festivalGoldDark)
            .frame(width: size, height: size)
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
            case .rabbit:
                rule { PictoTile(asset: "lantern", size: tile) } result: { hit("−1") }
                rule { PictoTile(asset: "LockTile", size: tile) } result: { hit("−2") }
                raid(every: 3) {
                    Image(systemName: "arrow.down").font(.system(size: 12, weight: .black))
                        .foregroundStyle(AppTheme.festivalGoldDark)
                    PictoTile(asset: "LockTile", size: tile)
                    PictoTag(text: "×2", size: 11)
                }
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

// MARK: - Help on demand

/// A small "?" beside a pictogram. Pictures come first; the words stay one tap away
/// for players who want them, in a bubble that points back at what it explains.
struct HelpTipButton<Detail: View>: View {
    var size: CGFloat = 20
    var tint: Color = AppTheme.festivalGoldDark
    @ViewBuilder let detail: Detail
    @State private var isShowing = false

    var body: some View {
        Button {
            HapticManager.buttonTap()
            isShowing = true
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: size, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, tint)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                // Small to look at, but a full finger-sized target.
                .contentShape(Circle().inset(by: -max(0, (44 - size) / 2)))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing) {
            // A definite width, so the popover measures the wrapped height of every line.
            VStack(alignment: .leading, spacing: 10) { detail }
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(AppTheme.creamHighlight)
        }
        .accessibilityLabel(Text("How it works"))
    }
}

extension HelpTipButton where Detail == HelpTipRow<EmptyView> {
    /// A "?" whose bubble is a single sentence.
    init(_ text: Text, size: CGFloat = 20, tint: Color = AppTheme.festivalGoldDark) {
        self.init(size: size, tint: tint) { HelpTipRow(text) }
    }
}

/// One line in a help bubble: the picture the player saw, then the words for it.
struct HelpTipRow<Icon: View>: View {
    let text: Text
    let icon: Icon?

    init(_ text: Text, @ViewBuilder icon: () -> Icon) {
        self.text = text
        self.icon = icon()
    }

    init(_ text: Text, systemImage: String, tint: Color = AppTheme.festivalGoldDark) where Icon == AnyView {
        self.init(text) {
            AnyView(Image(systemName: systemImage)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint))
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let icon {
                icon.frame(width: 24).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            }
            text.fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension HelpTipRow where Icon == EmptyView {
    init(_ text: Text) {
        self.text = text
        self.icon = nil
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
