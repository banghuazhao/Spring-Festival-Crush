//
// Centralized design tokens (colors, gradients, shadows) shared across screens
// so buttons, panels, and modals read as one consistent visual system.
//

import SwiftUI

enum AppTheme {
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
            .background(
                ZStack {
                    shape.fill(gradient)
                    AppTheme.shineOverlay(cornerShape: shape)
                        .padding(2)
                }
            )
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 1))
            .clipShape(shape)
            .shadow(
                color: AppTheme.cardShadowColor,
                radius: configuration.isPressed ? 2 : AppTheme.cardShadowRadius,
                x: 0,
                y: configuration.isPressed ? 1 : AppTheme.cardShadowY
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Type-erased shape wrapper so GamePrimaryButtonStyle can accept capsules, circles, or rounded rects.
struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

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
