//
// Centralized design tokens (colors, gradients, shadows) shared across screens
// so buttons, panels, and modals read as one consistent visual system.
//

import SwiftUI

enum AppTheme {
    static let ink = Color(UIColor(hex: 0x4A2213))
    static let cream = Color(UIColor(hex: 0xFFF3D2))
    static let creamHighlight = Color(UIColor(hex: 0xFFFBE9))
    static let festivalRed = Color(UIColor(hex: 0xD83A31))
    static let festivalRedDark = Color(UIColor(hex: 0x8F201C))
    static let festivalGold = Color(UIColor(hex: 0xFFC947))
    static let festivalGoldDark = Color(UIColor(hex: 0xC67816))
    /// The raised card colour: brighter than `cream`, so nested surfaces read without shadows.
    static let paper = Color(UIColor(hex: 0xFFF9EA))
    static let lacquer = Color(UIColor(hex: 0x8C1D20))
    static let lacquerDeep = Color(UIColor(hex: 0x4A0E12))
    /// The one border weight for cards and chips, so edges stay quiet and consistent.
    static let hairline = Color(UIColor(hex: 0xD9A441)).opacity(0.5)

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }

    /// Moon blossoms (the board's jelly layer): pale for one clear left, deep for two or more.
    static func blossom(layers: Int) -> UIColor { UIColor(hex: layers > 1 ? 0xE0609A : 0xF4A6C6) }

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x6A3DE8)), Color(UIColor(hex: 0xD6398B))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xFFC95A)), Color(UIColor(hex: 0xE88A1E))],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Burnished gold for the single most important action on a screen. Pair with ink text.
    static let goldGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xFFE19A)), Color(UIColor(hex: 0xF5B942)), Color(UIColor(hex: 0xDE9024))],
        startPoint: .top,
        endPoint: .bottom
    )

    static let lacquerGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xA92C2C)), Color(UIColor(hex: 0x6B1518))],
        startPoint: .top,
        endPoint: .bottom
    )

    static let successGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x36A878)), Color(UIColor(hex: 0x1A7350))],
        startPoint: .top,
        endPoint: .bottom
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xE2524A)), Color(UIColor(hex: 0xA8242A))],
        startPoint: .top,
        endPoint: .bottom
    )

    static let neutralGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x8B6F5C)), Color(UIColor(hex: 0x5F4537))],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The shared festival backdrop used by every out-of-level screen (zodiac map, level
    /// grid), so the journey reads as one continuous place rather than separate screens.
    static let festivalBackground = LinearGradient(
        colors: [Color(UIColor(hex: 0xF8C96B)), Color(UIColor(hex: 0xB3262E))],
        startPoint: .top,
        endPoint: .bottom
    )

    static func shineOverlay(cornerShape: some Shape) -> some View {
        LinearGradient(
            colors: [Color.white.opacity(0.2), Color.white.opacity(0)],
            startPoint: .top,
            endPoint: .center
        )
        .clipShape(cornerShape)
    }

    // MARK: - Shadows

    static let cardShadowColor = Color.black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 4

    // MARK: - Corner Radius

    static let panelCornerRadius: CGFloat = 20
    static let buttonCornerRadius: CGFloat = 14
}

// A raised, glossy pill/rounded-rect button that scales down and dims on press —
// the same tactile feedback pattern industry match-3 games use for every CTA.
struct GamePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @ScaledMetric(relativeTo: .headline) private var fontSize = 17
    var gradient: LinearGradient = AppTheme.primaryGradient
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .shadow(color: foreground == .white ? .black.opacity(0.24) : .clear, radius: 0.5, x: 0, y: 1)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .frame(minHeight: 46)
            .background {
                ZStack {
                    shape.fill(gradient)
                    AppTheme.shineOverlay(cornerShape: shape)
                }
            }
            .overlay(shape.stroke(Color.white.opacity(0.32), lineWidth: 1))
            // A short lip under the face: the press travels into it instead of just dimming.
            .background(shape.fill(Color.black.opacity(0.28)).offset(y: pressed ? 1 : 3))
            .offset(y: pressed && !reduceMotion ? 2 : 0)
            .shadow(color: .black.opacity(pressed ? 0.1 : 0.18), radius: pressed ? 2 : 5, x: 0, y: pressed ? 1 : 3)
            .scaleEffect(pressed && !reduceMotion ? 0.985 : 1.0)
            .brightness(pressed ? -0.04 : 0)
            .padding(.bottom, 3)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.72), value: pressed)
    }
}

/// The quiet partner to a primary action, so each screen has one obvious next step.
struct GameSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    @ScaledMetric(relativeTo: .subheadline) private var fontSize = 15
    var tint: Color = AppTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.md - 1, style: .continuous)
        configuration.label
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(shape.fill(AppTheme.paper))
            .overlay(shape.strokeBorder(AppTheme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GameSecondaryButtonStyle {
    static var gameSecondary: GameSecondaryButtonStyle { GameSecondaryButtonStyle() }
    static func gameSecondary(tint: Color) -> GameSecondaryButtonStyle { GameSecondaryButtonStyle(tint: tint) }
}

// Type-erased shape wrapper so GamePrimaryButtonStyle can accept capsules, circles, or rounded rects.
struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init(_ shape: some Shape) {
        pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

extension ButtonStyle where Self == GamePrimaryButtonStyle {
    static var gamePrimary: GamePrimaryButtonStyle { GamePrimaryButtonStyle() }

    static func gamePrimary(gradient: LinearGradient, shape: some Shape = RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)) -> GamePrimaryButtonStyle {
        GamePrimaryButtonStyle(gradient: gradient, shape: AnyShape(shape))
    }

    /// The gold call to action. Use it at most once per screen.
    static var gameGold: GamePrimaryButtonStyle {
        GamePrimaryButtonStyle(gradient: AppTheme.goldGradient, foreground: AppTheme.ink)
    }
}

// A tap-to-shrink style for icon-only chrome (settings gear, back arrow) — lighter than the full CTA style.
struct GameIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }
    var pressedScale: CGFloat = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GameIconButtonStyle {
    static var gameIcon: GameIconButtonStyle { GameIconButtonStyle() }
    /// The same press, scaled for a wide tappable card.
    static var gameCard: GameIconButtonStyle { GameIconButtonStyle(pressedScale: 0.975) }
}

// The press feel for map/grid nodes (zodiac landmarks, level medallions) — a deeper squash
// than the chrome buttons get, shared so both journey screens react identically.
struct GameNodeButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.gameReducedEffects) private var reducedEffects
    private var reduceMotion: Bool { systemReduceMotion || reducedEffects }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.88 : 1)
            .rotationEffect(.degrees(configuration.isPressed && !reduceMotion ? -2 : 0))
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GameNodeButtonStyle {
    static var gameNode: GameNodeButtonStyle { GameNodeButtonStyle() }
}

// MARK: - Game panels and transient notices

enum GameRibbonTone {
    case gold, red, blue, green

    var gradient: LinearGradient {
        switch self {
        case .gold:
            AppTheme.goldGradient
        case .red:
            AppTheme.dangerGradient
        case .blue:
            LinearGradient(colors: [Color(UIColor(hex: 0x68B9F2)), Color(UIColor(hex: 0x2877C8))], startPoint: .top, endPoint: .bottom)
        case .green:
            AppTheme.successGradient
        }
    }

    var foreground: Color { self == .red || self == .blue ? .white : AppTheme.ink }
}

/// A framed, warm game surface with a floating ribbon. It keeps alerts and result screens
/// visually connected to the playfield instead of looking like stock system sheets.
struct GamePopupPanel<Content: View>: View {
    let title: String
    var tone: GameRibbonTone = .gold
    var titleFocus: AccessibilityFocusState<Bool>.Binding?
    @ViewBuilder let content: Content

    init(title: String, tone: GameRibbonTone = .gold,
         titleFocus: AccessibilityFocusState<Bool>.Binding? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
        self.titleFocus = titleFocus
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            focusableTitle
                .font(.headline.weight(.black))
                .fontDesign(.rounded)
                .tracking(0.4)
                .foregroundStyle(tone.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .frame(minWidth: 150)
                .background(tone.gradient, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.26), radius: 5, y: 3)
                .zIndex(1)

            content
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.top, 28)
                .padding(.bottom, AppTheme.Space.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                        .fill(LinearGradient(colors: [AppTheme.creamHighlight, AppTheme.cream],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                                .strokeBorder(AppTheme.goldGradient, lineWidth: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl - 4, style: .continuous)
                                .strokeBorder(AppTheme.hairline.opacity(0.7), lineWidth: 0.75)
                                .padding(4)
                        )
                )
                .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
                // Tuck the panel under its title pill without leaving dead space below it.
                .padding(.top, -17)
        }
        .frame(maxWidth: 380)
    }

    @ViewBuilder
    private var focusableTitle: some View {
        if let titleFocus {
            titleText.accessibilityFocused(titleFocus)
        } else {
            titleText
        }
    }

    private var titleText: some View {
        Text(LocalizedStringKey(title))
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Shared compact surfaces

extension View {
    /// A paper card nested inside a panel: one fill, one hairline, no stacked shadows.
    func gameInset(padding: CGFloat = 10, radius: CGFloat = AppTheme.Radius.md) -> some View {
        self
            .padding(padding)
            .background(AppTheme.paper, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
            )
    }
}

/// The small caps label above a group of content.
struct GameSectionLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption2.weight(.heavy))
            .fontDesign(.rounded)
            .tracking(0.6)
            .foregroundStyle(AppTheme.ink.opacity(0.62))
            .accessibilityAddTraits(.isHeader)
    }
}

/// An icon and a number in a capsule, for moves, time, coins and similar one-glance stats.
struct GameStatPill: View {
    let systemImage: String
    let value: String
    var tint: Color = AppTheme.festivalRed

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
            Text(verbatim: value)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .monospacedDigit()
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(AppTheme.paper, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .ignore)
    }
}

/// One remaining goal as tile art plus a count. The spoken label carries the goal's name.
struct GoalChip<Art: View>: View {
    let count: Int
    let label: Text
    @ViewBuilder let art: Art

    var body: some View {
        HStack(spacing: 5) {
            art
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            Text(count, format: .number)
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(AppTheme.paper, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(count, format: .number))
    }
}

struct GameNoticeBanner: View {
    let message: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
            Text(LocalizedStringKey(message))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(tint.gradient)
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.28), radius: 9, y: 4)
        .padding(.horizontal, 18)
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct GameNoticeModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let icon: String
    let tint: Color

    // Identifies the current showing so an older auto-dismiss can't cut a newer banner
    // short — tapping two locked levels in quick succession used to do exactly that.
    @State private var showID = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    GameNoticeBanner(message: message, icon: icon, tint: tint)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        .zIndex(100)
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isPresented)
            .onChange(of: isPresented) { _, shown in
                guard shown else { return }
                showID += 1
                let id = showID
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    guard id == showID else { return }
                    isPresented = false
                }
            }
    }
}

extension View {
    func gameNotice(
        isPresented: Binding<Bool>,
        message: String,
        icon: String,
        tint: Color
    ) -> some View {
        modifier(GameNoticeModifier(isPresented: isPresented, message: message, icon: icon, tint: tint))
    }
}
