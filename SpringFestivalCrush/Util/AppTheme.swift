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

    // MARK: - Gradients

    static let primaryGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x6A3DE8)), Color(UIColor(hex: 0xD6398B))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xFFB238)), Color(UIColor(hex: 0xFF7A18))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x6BE07A)), Color(UIColor(hex: 0x2FAE4E))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0xFF7A7A)), Color(UIColor(hex: 0xE8394B))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let neutralGradient = LinearGradient(
        colors: [Color(UIColor(hex: 0x7C8CA8)), Color(UIColor(hex: 0x4A5670))],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
            colors: [Color.white.opacity(0.45), Color.white.opacity(0)],
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

    static let panelCornerRadius: CGFloat = 22
    static let buttonCornerRadius: CGFloat = 16
}

// A raised, glossy pill/rounded-rect button that scales down and dims on press —
// the same tactile feedback pattern industry match-3 games use for every CTA.
struct GamePrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = AppTheme.primaryGradient
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(shape.fill(Color.black.opacity(0.28)).offset(y: 6))
            .background(
                ZStack {
                    shape.fill(gradient)
                    AppTheme.shineOverlay(cornerShape: shape)
                        .padding(2)
                }
                .offset(y: configuration.isPressed ? 5 : 0)
            )
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 1))
            .clipShape(shape)
            .shadow(
                color: AppTheme.cardShadowColor,
                radius: configuration.isPressed ? 2 : AppTheme.cardShadowRadius,
                x: 0,
                y: configuration.isPressed ? 1 : AppTheme.cardShadowY
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .padding(.bottom, 6)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
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
}

// A tap-to-shrink style for icon-only chrome (settings gear, back arrow) — lighter than the full CTA style.
struct GameIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GameIconButtonStyle {
    static var gameIcon: GameIconButtonStyle { GameIconButtonStyle() }
}

// The press feel for map/grid nodes (zodiac landmarks, level medallions) — a deeper squash
// than the chrome buttons get, shared so both journey screens react identically.
struct GameNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -2 : 0))
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
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
            LinearGradient(colors: [AppTheme.festivalGold, AppTheme.festivalGoldDark], startPoint: .top, endPoint: .bottom)
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
    @ViewBuilder let content: Content

    init(title: String, tone: GameRibbonTone = .gold, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(tone.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
                .frame(minWidth: 180)
                .background(tone.gradient)
                .clipShape(.rect(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.65), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 7, y: 4)
                .zIndex(1)

            content
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppTheme.cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(AppTheme.festivalGold, lineWidth: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.white.opacity(0.75), lineWidth: 2)
                                .padding(7)
                        )
                )
                .shadow(color: .black.opacity(0.38), radius: 24, y: 13)
                .offset(y: -20)
        }
        .frame(maxWidth: 380)
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
            Text(message)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            Capsule()
                .fill(tint.gradient)
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1.5))
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
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
