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
    @ObservedObject private var adManager = RewardedAdManager.shared
    #endif

    var body: some View {
        #if !targetEnvironment(macCatalyst)
        Button {
            HapticManager.buttonTap()
            adManager.show(onReward: onReward)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.gamePrimary(gradient: AppTheme.successGradient, shape: Capsule()))
        .disabled(!adManager.isAdReady)
        .opacity(adManager.isAdReady ? 1.0 : 0.5)
        #else
        EmptyView()
        #endif
    }
}
