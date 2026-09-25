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
            Text(LocalizedStringKey(banner.text))
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
    let onRefill: () -> Void
}

struct BoosterTrayView: View {
    let boosters: [BoosterItem]

    var body: some View {
        // Three tools must fit a 320pt-wide iPhone SE, so each pill stays compact.
        HStack(spacing: 8) {
            ForEach(boosters) { booster in
                HStack(spacing: 0) {
                    Button {
                        HapticManager.buttonTap()
                        booster.action()
                    } label: {
                        HStack(spacing: 6) {
                            if let imageName = booster.imageName {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: booster.icon)
                            }
                            Text("\(booster.count)")
                                .font(.headline.weight(.heavy))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 2)
                        .frame(minWidth: 52, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.gameIcon)
                    .accessibilityLabel(Text(booster.title))
                    .accessibilityValue(Text("\(booster.count) remaining"))
                    .accessibilityAddTraits(booster.isActive ? .isSelected : [])
                    .accessibilityHint(booster.count == 0 ? Text("Open ad refill") : Text("Use one charge without spending a move"))

                    Button {
                        HapticManager.buttonTap()
                        booster.onRefill()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body.weight(.bold))
                            .frame(width: 32, height: 52)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.gameIcon)
                    .accessibilityLabel(Text("Add \(booster.title)"))
                    .accessibilityHint("Watch an optional ad for one charge")
                }
                .foregroundStyle(.white)
                .background(booster.isActive ? booster.activeGradient : booster.idleGradient,
                            in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                    booster.isActive ? AppTheme.festivalGold : .white.opacity(0.4), lineWidth: 2))
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
