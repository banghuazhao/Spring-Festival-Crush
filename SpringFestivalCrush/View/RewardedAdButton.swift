//
// A small pill button that plays a rewarded video and grants the reward on completion.
// Self-contained: hides itself entirely on macCatalyst (no Google Mobile Ads there), and
// disables itself while no ad is preloaded, so callers never need their own platform checks.
//

import SwiftUI

struct RewardedAdButton: View {
    let title: String
    let systemImage: String
    let onReward: () -> Void

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
                Label(LocalizedStringKey(title), systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient, shape: Capsule()))
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
