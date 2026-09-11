//
// Reusable game-HUD building blocks: a single-banner hint system (so two hints can never
// stack on top of each other) and a data-driven booster tray (so adding a new booster is
// a list entry, not a new one-off view).
//

import SwiftUI

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

/// Drawn as an ordinary element directly beneath the HUD card rather than positioned with a
/// measured offset — a measured offset silently collapsed to ~0 whenever the preference was
/// reduced against a non-contributing sibling, dropping the banner on top of the HUD.
struct HUDBannerView: View {
    let banner: HUDBanner

    var body: some View {
        HStack(spacing: 6) {
            if let icon = banner.icon {
                Image(systemName: icon)
            }
            Text(banner.text)
                .multilineTextAlignment(.center)
        }
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(banner.tint.opacity(0.85)))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .padding(.horizontal, 16)
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
    var imageName: String? = nil
    var title: String = "Booster"
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
                        if let imageName = booster.imageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: booster.icon)
                        }
                        Text("\(booster.count)")
                            .fontWeight(.bold)
                    }
                }
                .buttonStyle(.gamePrimary(
                    gradient: booster.isActive ? booster.activeGradient : booster.idleGradient,
                    shape: Capsule()
                ))
                .accessibilityLabel(booster.title)
                .accessibilityValue("\(booster.count) remaining")
                .accessibilityAddTraits(booster.isActive ? .isSelected : [])
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
