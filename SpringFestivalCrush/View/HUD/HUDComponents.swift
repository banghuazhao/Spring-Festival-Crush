//
// Reusable game-HUD building blocks: a single-banner hint system (so two hints can never
// stack on top of each other) and a data-driven booster tray (so adding a new booster is
// a list entry, not a new one-off view). Positioning is derived from measured frame sizes
// via HeightPreferenceKey instead of hardcoded padding constants.
//

import SwiftUI

// MARK: - Height measurement

/// Reports a view's measured height up the view tree so a sibling can position itself
/// relative to it without a hardcoded offset.
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Measures this view's height and reports it via HeightPreferenceKey.
    func measureHeight() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
    }
}

// MARK: - Banner

/// A single in-flight HUD hint. Callers pick exactly one to show at a time (see GameView) —
/// this type doesn't queue multiple banners, it just standardizes how one is drawn.
struct HUDBanner: Identifiable, Equatable {
    let id: String
    let text: String
    let icon: String?
    let tint: Color

    static func == (lhs: HUDBanner, rhs: HUDBanner) -> Bool { lhs.id == rhs.id }
}

struct HUDBannerView: View {
    let banner: HUDBanner
    /// Vertical offset from the top of the screen, typically the measured HUD height + a gap.
    let topOffset: CGFloat

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                if let icon = banner.icon {
                    Image(systemName: icon)
                }
                Text(banner.text)
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(banner.tint.opacity(0.85)))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            .padding(.top, topOffset)
            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .allowsHitTesting(false)
    }
}

// MARK: - Booster tray

/// One purchasable/usable booster shown in the in-game tray (hammer today, more later —
/// adding a booster means appending to the array GameView builds, not writing a new view).
struct BoosterItem: Identifiable {
    let id: String
    let icon: String
    let count: Int
    let isActive: Bool
    let activeGradient: LinearGradient
    let idleGradient: LinearGradient
    let action: () -> Void
}

struct BoosterTrayView: View {
    let boosters: [BoosterItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(boosters) { booster in
                Button {
                    HapticManager.buttonTap()
                    booster.action()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: booster.icon)
                        Text("\(booster.count)")
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.gamePrimary(
                    gradient: booster.isActive ? booster.activeGradient : booster.idleGradient,
                    shape: Capsule()
                ))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
