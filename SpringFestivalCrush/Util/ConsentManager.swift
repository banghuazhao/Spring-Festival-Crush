#if !targetEnvironment(macCatalyst)
import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

/// The single answer to "may we request ads, and may they be personalized?".
/// Google UMP consent is gathered first, then App Tracking Transparency, and every ad
/// load waits for that answer before it builds a request.
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    @Published private(set) var isPrivacyOptionsRequired = false
    private var gathering: Task<Bool, Never>?
    private var hasStartedAds = false

    /// True once UMP allows ad requests: consent obtained, or not required in this region.
    var canRequestAds: Bool { UMPConsentInformation.sharedInstance.canRequestAds }

    /// Personalized ads need every prompt to allow them; a refusal in either one wins.
    var allowsPersonalizedAds: Bool {
        canRequestAds && ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// Runs the consent flow once per launch; later callers await the same answer.
    @MainActor
    @discardableResult
    func gatherConsent() async -> Bool {
        if let gathering { return await gathering.value }
        let task = Task { await runConsentFlow() }
        gathering = task
        return await task.value
    }

    func makeRequest() -> GADRequest {
        let request = GADRequest()
        if !allowsPersonalizedAds {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }

    /// Reopens the UMP privacy options so a choice can be withdrawn as easily as it was given.
    @MainActor
    func presentPrivacyOptions() async {
        guard let presenter = Self.topViewController() else { return }
        try? await UMPConsentForm.presentPrivacyOptionsForm(from: presenter)
        refreshPrivacyOptionsRequirement()
        startAdsIfAllowed()
    }

    @MainActor
    private func runConsentFlow() async -> Bool {
        await waitUntilActive()
        do {
            try await UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: UMPRequestParameters())
            if let presenter = Self.topViewController() {
                try await UMPConsentForm.loadAndPresentIfRequired(from: presenter)
            }
        } catch {
            // A failed update keeps the stored consent; canRequestAds still reflects it.
        }
        refreshPrivacyOptionsRequirement()
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined, !refusedDeviceAccessInConsentForm {
            // The system silently denies the request unless the app is foreground-active.
            await waitUntilActive()
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        startAdsIfAllowed()
        return canRequestAds
    }

    /// Where GDPR applies, a refusal of TCF purpose 1 (store or access information on the
    /// device) must not be followed by a second request to track.
    private var refusedDeviceAccessInConsentForm: Bool {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "IABTCF_gdprApplies") == 1 else { return false }
        return !(defaults.string(forKey: "IABTCF_PurposeConsents") ?? "").hasPrefix("1")
    }

    @MainActor
    private func refreshPrivacyOptionsRequirement() {
        isPrivacyOptionsRequired = UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    @MainActor
    private func startAdsIfAllowed() {
        guard canRequestAds, !hasStartedAds else { return }
        hasStartedAds = true
        GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = .general
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    @MainActor
    private func waitUntilActive() async {
        let activations = NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification)
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in activations { return }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
#endif
