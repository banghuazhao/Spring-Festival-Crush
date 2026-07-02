//
//  Ads.swift
//  Height Tracker
//
//  Created by Banghua Zhao on 2021/1/31.
//  Copyright © 2021 Banghua Zhao. All rights reserved.
//

#if !targetEnvironment(macCatalyst)
    import AdSupport
    import AppTrackingTransparency
    import GoogleMobileAds
    import SwiftUI

    class AdManager {
        static let isTestingAds = true
        static var isAuthorized = false

        struct GoogleAdsID {
            static let bannerAdUnitID = Bundle.main.object(forInfoDictionaryKey: "BannerAdUnitID") as? String ?? ""
            static let interstitialAdID = Bundle.main.object(forInfoDictionaryKey: "InterstitialAdID") as? String ?? ""
            static let appOpenAdID = Bundle.main.object(forInfoDictionaryKey: "AppOpenAdID") as? String ?? ""
        }

        static func requestATTPermission(with time: TimeInterval = 0) {
            guard !isAuthorized else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        // Tracking authorization dialog was shown
                        // and we are authorized
                        print("Authorized")
                        isAuthorized = true
                        // Now that we are authorized we can get the IDFA
                        print(ASIdentifierManager.shared().advertisingIdentifier)
                    case .denied:
                        // Tracking authorization dialog was
                        // shown and permission is denied
                        print("Denied")
                    case .notDetermined:
                        // Tracking authorization dialog has not been shown
                        print("Not Determined")
                    case .restricted:
                        print("Restricted")
                    @unknown default:
                        print("Unknown")
                    }
                }
            }
        }
    }

    final class OpenAd: NSObject, GADFullScreenContentDelegate {
        var appOpenAd: GADAppOpenAd?
        var loadTime = Date()
        var appHasEnterBackgroundBefore = false
        var bypassAdThisTime = false

        func requestAppOpenAd() {
            print("bannerAdUnitID: \(AdManager.GoogleAdsID.bannerAdUnitID)")
            print("InterstitialAdID: \(AdManager.GoogleAdsID.interstitialAdID)")
            print("appOpenAdID: \(AdManager.GoogleAdsID.appOpenAdID)")
            let request = GADRequest()
            request.scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            GADAppOpenAd.load(
                withAdUnitID: AdManager.GoogleAdsID.appOpenAdID,
                request: request,
                completionHandler: { appOpenAdIn, _ in
                    self.appOpenAd = appOpenAdIn
                    self.appOpenAd?.fullScreenContentDelegate = self
                    self.loadTime = Date()
                    print("[OPEN AD] Ad is ready")
                }
            )
        }

        func tryToPresentAd() {
            if let gOpenAd = appOpenAd, wasLoadTimeLessThanNHoursAgo(thresholdN: 4) {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                let window = windowScene?.windows.first
                if bypassAdThisTime {
                    bypassAdThisTime = false
                    return
                }
                if appHasEnterBackgroundBefore {
                    gOpenAd.present(fromRootViewController: (window?.rootViewController)!)
                }
            } else {
                requestAppOpenAd()
            }
        }

        func wasLoadTimeLessThanNHoursAgo(thresholdN: Int) -> Bool {
            let now = Date()
            let timeIntervalBetweenNowAndLoadTime = now.timeIntervalSince(loadTime)
            let secondsPerHour = 3600.0
            let intervalInHours = timeIntervalBetweenNowAndLoadTime / secondsPerHour
            return intervalInHours < Double(thresholdN)
        }

        func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
            print("[OPEN AD] Failed: \(error)")
            requestAppOpenAd()
        }

        func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
            requestAppOpenAd()
            print("[OPEN AD] Ad dismissed")
        }
    }

    struct BannerView: UIViewControllerRepresentable {
        @State var viewWidth: CGFloat = .zero
        private let bannerView = GADBannerView()
        private let adUnitID = AdManager.GoogleAdsID.bannerAdUnitID

        func makeUIViewController(context: Context) -> some UIViewController {
            let bannerViewController = BannerViewController()
            bannerView.adUnitID = adUnitID
            bannerView.rootViewController = bannerViewController
            bannerView.delegate = context.coordinator
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerViewController.view.addSubview(bannerView)
            // Constrain GADBannerView to the bottom of the view.
            NSLayoutConstraint.activate([
                bannerView.bottomAnchor.constraint(
                    equalTo: bannerViewController.view.safeAreaLayoutGuide.bottomAnchor),
                bannerView.centerXAnchor.constraint(equalTo: bannerViewController.view.centerXAnchor),
            ])
            bannerViewController.delegate = context.coordinator

            return bannerViewController
        }

        func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
            guard viewWidth != .zero else { return }

            bannerView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
            let request = GADRequest()
            request.scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            bannerView.load(request)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, BannerViewControllerWidthDelegate, GADBannerViewDelegate {
            let parent: BannerView

            init(_ parent: BannerView) {
                self.parent = parent
            }

            // MARK: - BannerViewControllerWidthDelegate methods

            func bannerViewController(
                _ bannerViewController: BannerViewController, didUpdate width: CGFloat
            ) {
                parent.viewWidth = width
            }

            // MARK: - GADBannerViewDelegate methods

            func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
                print("DID RECEIVE Banner AD")
            }

            func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
                print("DID NOT RECEIVE Banner AD: \(error.localizedDescription)")
            }
        }
    }

    protocol BannerViewControllerWidthDelegate: AnyObject {
        func bannerViewController(_ bannerViewController: BannerViewController, didUpdate width: CGFloat)
    }

    class BannerViewController: UIViewController {
        weak var delegate: BannerViewControllerWidthDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            delegate?.bannerViewController(
                self, didUpdate: view.frame.inset(by: view.safeAreaInsets).size.width)
        }

        override func viewWillTransition(
            to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
        ) {
            coordinator.animate { _ in
                // do nothing
            } completion: { _ in
                self.delegate?.bannerViewController(
                    self, didUpdate: self.view.frame.inset(by: self.view.safeAreaInsets).size.width)
            }
        }
    }

    /// Loads and presents an interstitial ad for the "watch an ad for +1 life / +coins" flows.
    /// InterstitialAdID is configured in AdMob as an Interstitial-format ad unit, so it must be
    /// loaded with GADInterstitialAd, not GADRewardedAd — loading a Rewarded-format request
    /// against an Interstitial ad unit doesn't match server-side and never fills, which is why
    /// ads weren't showing at all. The "reward" is a product decision layered on top: since this
    /// isn't a true rewarded-video creative, the reward is granted on dismissal regardless of
    /// how much the user watched.
    @MainActor
    final class RewardedAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
        static let shared = RewardedAdManager()

        @Published private(set) var isAdReady = false
        private var interstitialAd: GADInterstitialAd?
        private var onReward: (() -> Void)?

        override private init() {
            super.init()
            loadAd()
        }

        func loadAd() {
            let request = GADRequest()
            GADInterstitialAd.load(withAdUnitID: AdManager.GoogleAdsID.interstitialAdID, request: request) { [weak self] ad, error in
                guard let self else { return }
                if let error {
                    print("[REWARDED AD] Failed to load: \(error.localizedDescription)")
                    isAdReady = false
                    return
                }
                interstitialAd = ad
                interstitialAd?.fullScreenContentDelegate = self
                isAdReady = true
            }
        }

        /// Presents the preloaded ad. The reward is granted on dismissal
        /// (adDidDismissFullScreenContent below) — closing early still counts.
        func show(onReward: @escaping () -> Void) {
            guard isAdReady, let interstitialAd, let presenter = Self.topViewController() else { return }
            // Flip this immediately (not just in the dismiss/fail callbacks below) so a rapid
            // second tap — before the system presentation transition even completes — can't
            // call present() again on the same ad instance or silently overwrite onReward.
            isAdReady = false
            self.onReward = onReward
            BackgroundMusicManager.shared.stopBackgroundMusic()
            interstitialAd.present(fromRootViewController: presenter)
        }

        /// The reward buttons are used from inside SwiftUI .sheet presentations (e.g.
        /// PreLevelBoosterView), so the window's root view controller is often already busy
        /// presenting something else — GADInterstitialAd.present(fromRootViewController:)
        /// fails with "already presenting another view controller" if handed that root
        /// instead of the actual topmost presented controller.
        private static func topViewController() -> UIViewController? {
            guard var top = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first?.rootViewController
            else { return nil }
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }

        func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
            isAdReady = false
            interstitialAd = nil
            onReward?()
            onReward = nil
            loadAd()
            Task { await BackgroundMusicManager.shared.turnOnBackgroundMusic() }
        }

        func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
            print("[REWARDED AD] Failed to present: \(error.localizedDescription)")
            isAdReady = false
            interstitialAd = nil
            onReward = nil
            loadAd()
            Task { await BackgroundMusicManager.shared.turnOnBackgroundMusic() }
        }
    }
#endif
