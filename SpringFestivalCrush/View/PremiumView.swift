import SwiftUI

/// The Premium offer: what it includes at a glance, one price, and Restore.
struct PremiumView: View {
    @ObservedObject private var store = PremiumStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isBusy: Bool { store.activity != .idle }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                hero
                VStack(spacing: 0) {
                    benefit(title: "No ads", badge: .check) {
                        Image(systemName: "play.slash.fill")
                    }
                    divider
                    benefit(title: "Unlimited lives", badge: .infinity) {
                        Image(systemName: "heart.fill")
                    }
                    divider
                    benefit(title: "Unlimited tools", badge: .infinity) {
                        Image("HammerBoosterIcon").resizable().scaledToFit()
                    }
                    divider
                    benefit(title: "Free +5 moves every level", badge: .free) {
                        Image(systemName: "plus.circle.fill")
                    }
                    divider
                    benefit(title: "Free continues", badge: .infinity) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                    }
                }
                .padding(.horizontal, AppTheme.Space.md)
                .background(AppTheme.paper, in: .rect(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .strokeBorder(AppTheme.goldGradient, lineWidth: 1.25))
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.top, 54)
            .padding(.bottom, AppTheme.Space.lg)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient(colors: [AppTheme.lacquer, AppTheme.lacquerDeep],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar }
        .overlay(alignment: .topTrailing) { closeButton }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.activity == .purchasing)
        .task { await store.loadProduct() }
    }

    private var hero: some View {
        VStack(spacing: AppTheme.Space.sm) {
            ZStack {
                Circle().fill(AppTheme.goldGradient)
                Circle().strokeBorder(.white.opacity(0.65), lineWidth: 2).padding(4)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(AppTheme.lacquerDeep)
            }
            .frame(width: 82, height: 82)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
            .accessibilityHidden(true)

            Text("PREMIUM")
                .font(.system(.title, design: .rounded, weight: .black))
                .tracking(2)
                .foregroundStyle(AppTheme.festivalGold)
                .accessibilityAddTraits(.isHeader)
            Text(store.isPremium ? "Premium is active. Enjoy!" : "Play without limits")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
    }

    private var divider: some View {
        Rectangle().fill(AppTheme.hairline).frame(height: 0.75)
    }

    private enum Badge {
        case infinity, free, check
    }

    private func benefit<Art: View>(title: LocalizedStringKey, badge: Badge,
                                    @ViewBuilder art: () -> Art) -> some View {
        HStack(spacing: AppTheme.Space.md) {
            art()
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(AppTheme.festivalRed)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            badgeView(badge)
        }
        .frame(minHeight: 50)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? AppTheme.Space.sm : 0)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func badgeView(_ badge: Badge) -> some View {
        Group {
            switch badge {
            case .infinity:
                Image(systemName: "infinity").font(.caption.weight(.black))
                    .accessibilityHidden(true)
            case .check:
                Image(systemName: "checkmark").font(.caption.weight(.black))
                    .accessibilityHidden(true)
            case .free:
                Text("FREE").font(.caption2.weight(.black))
            }
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.horizontal, 9)
        .frame(minWidth: 40, minHeight: 24)
        .background(AppTheme.goldGradient, in: Capsule())
    }

    private var closeButton: some View {
        Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(.white.opacity(0.16), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.gameIcon)
            .disabled(store.activity == .purchasing)
            .keyboardShortcut(.cancelAction)
            .padding(AppTheme.Space.sm)
            .accessibilityIdentifier("premium-close")
    }

    private var purchaseBar: some View {
        VStack(spacing: AppTheme.Space.xs) {
            if store.isPremium {
                Button { dismiss() } label: {
                    Label("Done", systemImage: "checkmark.seal.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameGold)
                .accessibilityIdentifier("premium-done")
            } else {
                Button {
                    HapticManager.buttonTap()
                    Task { await store.purchase() }
                } label: {
                    Group {
                        if store.activity == .purchasing || store.activity == .loading {
                            ProgressView().tint(AppTheme.ink)
                        } else if let product = store.product {
                            Text("Unlock Premium · \(product.displayPrice)")
                        } else {
                            Text("Try Again")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.gameGold)
                .disabled(isBusy)
                .accessibilityIdentifier("premium-buy")

                if store.isPending {
                    Text("Waiting for approval.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                } else if let message = store.message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.festivalRedDark)
                        .multilineTextAlignment(.center)
                } else {
                    Text("One-time purchase. No subscription.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.ink.opacity(0.72))
                }

                Button {
                    Task { await store.restore() }
                } label: {
                    Group {
                        if store.activity == .restoring {
                            ProgressView()
                        } else {
                            Text("Restore Purchase")
                        }
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(AppTheme.festivalRed)
                    .frame(minWidth: 160, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.gameIcon)
                .disabled(isBusy)
                .accessibilityIdentifier("premium-restore")
            }
        }
        .padding(.horizontal, AppTheme.Space.lg)
        .padding(.top, AppTheme.Space.md)
        .padding(.bottom, AppTheme.Space.xs)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background {
            AppTheme.creamHighlight
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(AppTheme.hairline).frame(height: 0.75) }
        }
    }
}

/// A quiet way into the Premium offer. Disappears for players who already own it.
struct PremiumUpsellButton: View {
    @ObservedObject private var store = PremiumStore.shared
    @State private var showPremium = false

    var body: some View {
        if !store.isPremium {
            Button {
                HapticManager.buttonTap()
                showPremium = true
            } label: {
                HStack(spacing: AppTheme.Space.sm) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(AppTheme.festivalGoldDark)
                        .accessibilityHidden(true)
                    Text("Go Premium")
                        .font(.subheadline.weight(.heavy))
                    Image(systemName: "infinity")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.festivalRed)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.cream, in: .rect(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.goldGradient, lineWidth: 1.25))
                .contentShape(Rectangle())
            }
            .buttonStyle(.gameCard)
            .accessibilityHint(Text("No ads, unlimited lives and tools"))
            .accessibilityIdentifier("premium-upsell")
            .sheet(isPresented: $showPremium) { PremiumView() }
        }
    }
}
