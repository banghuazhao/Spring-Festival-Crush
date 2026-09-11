#if !targetEnvironment(macCatalyst)
import GoogleMobileAds
import SwiftUI

/// Tool refills use true rewarded ads, independently of the legacy coin/life ad flow.
@MainActor
final class ToolRewardAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPresenting = false
    @Published private(set) var message: String?
    private var ad: GADRewardedAd?
    private var reward: (() -> Void)?

    func load() async {
        guard !isLoading, !isReady, !isPresenting else { return }
        #if DEBUG
        let unitID = "ca-app-pub-3940256099942544/1712485313"
        #else
        let unitID = Bundle.main.object(forInfoDictionaryKey: "RewardedAdUnitID") as? String ?? ""
        guard unitID.hasPrefix("ca-app-pub-"), !unitID.contains("$(") else {
            message = "Ad refills are currently unavailable."
            return
        }
        #endif
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            ad = try await GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest())
            ad?.fullScreenContentDelegate = self
            isReady = true
        } catch {
            message = "No ad available right now. Please try again."
        }
    }

    func show(onReward: @escaping () -> Void) {
        guard isReady, !isPresenting, let ad,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var presenter = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = presenter.presentedViewController { presenter = presented }
        isReady = false
        isPresenting = true
        reward = onReward
        BackgroundMusicManager.shared.stopBackgroundMusic()
        ad.present(fromRootViewController: presenter) { [weak self] in
            // Consume the callback before granting: no duplicate or early-dismiss rewards.
            let grant = self?.reward
            self?.reward = nil
            grant?()
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in self?.finishPresentation() }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.message = "The ad could not be shown. Please try again."
            self?.finishPresentation()
        }
    }

    private func finishPresentation() {
        ad = nil
        reward = nil
        isPresenting = false
        Task { await BackgroundMusicManager.shared.turnOnBackgroundMusic() }
    }
}
#endif
