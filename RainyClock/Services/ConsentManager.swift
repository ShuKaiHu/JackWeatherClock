import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Drives Google's User Messaging Platform (UMP) consent flow.
///
/// Google requires consent to be collected from users in the EEA, the UK and
/// Switzerland *before* the Mobile Ads SDK is initialised, so ad loading waits
/// until `ConsentInformation` reports that ads may be requested. Users outside
/// those regions are never shown a form and reach `canRequestAds` immediately.
///
/// The published GDPR message also promises users an in-app way to change or
/// withdraw their choice; `presentPrivacyOptions()` is that entry point.
@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    /// Whether ads may be requested for this user. The banner stays out of the
    /// view hierarchy until this turns true, so no ad request can precede consent.
    @Published private(set) var canRequestAds = false

    /// Whether this user must be offered a way back into the consent form.
    /// Only regulated regions require the entry point, so it stays hidden elsewhere.
    @Published private(set) var showsPrivacyOptions = false

    private var hasRequestedConsent = false
    private var hasStartedMobileAds = false

    private init() {}

    /// Refreshes the consent state and presents a form if one is required. Safe to
    /// call on every activation — the work happens only once per launch.
    func requestConsentThenStartAds() {
        guard !AppEnvironment.isRunningTests, !hasRequestedConsent else {
            return
        }
        hasRequestedConsent = true

        ConsentInformation.shared.requestConsentInfoUpdate(with: Self.requestParameters()) { [weak self] error in
            Task { @MainActor in
                await self?.presentConsentFormIfRequired(updateError: error)
            }
        }
    }

    /// Reopens the consent form so the user can change or withdraw their choice.
    func presentPrivacyOptions() {
        guard let viewController = UIApplication.shared.rainyClockRootViewController else {
            return
        }

        Task {
            try? await ConsentForm.presentPrivacyOptionsForm(from: viewController)
            refreshConsentState()
        }
    }

    private func presentConsentFormIfRequired(updateError: Error?) async {
        // A failed refresh leaves the previous session's choice in place, so fall
        // through to `canRequestAds` either way rather than giving up on ads.
        if updateError == nil, let viewController = UIApplication.shared.rainyClockRootViewController {
            try? await ConsentForm.loadAndPresentIfRequired(from: viewController)
        }

        refreshConsentState()
    }

    private func refreshConsentState() {
        showsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        guard ConsentInformation.shared.canRequestAds else {
            return
        }

        if !hasStartedMobileAds {
            hasStartedMobileAds = true
            MobileAds.shared.start()
        }
        canRequestAds = true
    }

    private static func requestParameters() -> RequestParameters {
        let parameters = RequestParameters()
        #if DEBUG
        // Launch with `-forceEEAConsentGeography` to rehearse the regulated-region
        // flow from a simulator that is not actually in the EEA.
        if ProcessInfo.processInfo.arguments.contains("-forceEEAConsentGeography") {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            parameters.debugSettings = debugSettings
        }
        #endif
        return parameters
    }
}

extension UIApplication {
    var rainyClockRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
