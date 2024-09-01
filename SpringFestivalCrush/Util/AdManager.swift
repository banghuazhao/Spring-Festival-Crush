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
#endif
