//
// A button that plays a rewarded video and grants the reward on completion.
// Self-contained: hides itself entirely on macCatalyst (no Google Mobile Ads there), and
// turns into its own retry while no ad is loaded, so callers never need platform checks.
//

import SwiftUI

struct RewardedAdButton: View {
    let title: String
    let systemImage: String
    var expandsForLargeText = false
    /// A short reward such as "+1". When set, the button is a small pill for toolbars and rows.
    var compactLabel: String? = nil
    let onReward: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var buttonShape: AnyShape {
        AnyShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
    }

    #if !targetEnvironment(macCatalyst)
    @ObservedObject private var adManager = ToolRewardAdManager.shared

    private var canRetry: Bool {
        !adManager.isLoading && !adManager.isReady && !adManager.isPresenting
    }

    private func activate() {
        HapticManager.buttonTap()
        if canRetry {
            Task { await adManager.load() }
        } else {
            adManager.show(onReward: onReward)
        }
    }
    #endif

    var body: some View {
        #if !targetEnvironment(macCatalyst)
        Group {
            if let compactLabel, !dynamicTypeSize.isAccessibilitySize {
                compactButton(compactLabel)
            } else {
                fullButton
            }
        }
        .task { await adManager.load() }
        .onChange(of: adManager.isPresenting) { _, presenting in
            if !presenting { Task { await adManager.load() } }
        }
        #else
        EmptyView()
        #endif
    }

    #if !targetEnvironment(macCatalyst)
    private var fullButton: some View {
        VStack(spacing: AppTheme.Space.xs) {
            // A ready ad is a real offer; while none is loaded it steps back to a quiet retry.
            if adManager.isReady {
                fullButtonControl.buttonStyle(.gamePrimary(gradient: AppTheme.lacquerGradient, shape: buttonShape))
            } else {
                fullButtonControl.buttonStyle(.gameSecondary)
            }

            if adManager.isLoading {
                ProgressView("Loading ad…")
                    .font(.caption2)
            } else if canRetry, let message = adManager.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fullButtonControl: some View {
        Button(action: activate) {
            Group {
                if expandsForLargeText && dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 6) {
                        Image(systemName: canRetry ? "arrow.clockwise" : systemImage)
                            .accessibilityHidden(true)
                        buttonTitle
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label { buttonTitle } icon: {
                        Image(systemName: canRetry ? "arrow.clockwise" : systemImage)
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .disabled(adManager.isLoading || adManager.isPresenting)
        .opacity(adManager.isLoading ? 0.62 : 1)
    }

    private var buttonTitle: Text {
        canRetry ? Text("Retry Ad") : Text(LocalizedStringKey(title))
    }

    private func compactButton(_ label: String) -> some View {
        Button(action: activate) {
            HStack(spacing: 3) {
                Image(systemName: canRetry ? "arrow.clockwise" : systemImage)
                    .font(.caption.weight(.black))
                Text(verbatim: label)
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .monospacedDigit()
            }
            .foregroundStyle(adManager.isReady ? Color.white : AppTheme.festivalRed)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(adManager.isReady ? AnyShapeStyle(AppTheme.lacquerGradient) : AnyShapeStyle(AppTheme.paper),
                        in: Capsule())
            .overlay(Capsule().strokeBorder(adManager.isReady ? AppTheme.festivalGold.opacity(0.7) : AppTheme.hairline,
                                            lineWidth: 1))
            // Small to look at, but still a full finger-sized target.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.gameIcon)
        .disabled(adManager.isLoading || adManager.isPresenting)
        .opacity(adManager.isLoading ? 0.55 : 1)
        .accessibilityLabel(buttonTitle)
        .accessibilityHint(canRetry ? (adManager.message.map { Text($0) } ?? Text(verbatim: "")) : Text(verbatim: ""))
    }
    #endif
}
