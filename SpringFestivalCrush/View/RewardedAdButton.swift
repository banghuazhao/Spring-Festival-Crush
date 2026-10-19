//
// A small pill button that plays a rewarded video and grants the reward on completion.
// Self-contained: hides itself entirely on macCatalyst (no Google Mobile Ads there), and
// disables itself while no ad is preloaded, so callers never need their own platform checks.
//

import SwiftUI

struct RewardedAdButton: View {
    let title: String
    let systemImage: String
    var expandsForLargeText = false
    let onReward: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var buttonShape: AnyShape {
        if expandsForLargeText && dynamicTypeSize.isAccessibilitySize {
            return AnyShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius))
        }
        return AnyShape(Capsule())
    }

    #if !targetEnvironment(macCatalyst)
    @ObservedObject private var adManager = ToolRewardAdManager.shared
    #endif

    var body: some View {
        #if !targetEnvironment(macCatalyst)
        VStack(spacing: 6) {
            Button {
                HapticManager.buttonTap()
                adManager.show(onReward: onReward)
            } label: {
                Group {
                    if expandsForLargeText && dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 6) {
                            Image(systemName: systemImage).accessibilityHidden(true)
                            Text(LocalizedStringKey(title))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label(LocalizedStringKey(title), systemImage: systemImage)
                    }
                }
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient, shape: buttonShape))
            .disabled(!adManager.isReady || adManager.isPresenting)
            .opacity(adManager.isReady ? 1 : 0.5)
            if adManager.isLoading {
                ProgressView("Loading ad…").font(.caption)
            } else if !adManager.isReady && !adManager.isPresenting {
                if let message = adManager.message {
                    Text(message).font(.caption).multilineTextAlignment(.center)
                }
                Button("Retry Ad") { Task { await adManager.load() } }
                    .frame(minHeight: 44)
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
}
