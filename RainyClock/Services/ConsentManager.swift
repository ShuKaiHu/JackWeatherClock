import AppTrackingTransparency
import UIKit
import UserMessagingPlatform

/// Drives Google's User Messaging Platform (UMP) consent flow and, behind it,
/// Apple's App Tracking Transparency prompt.
///
/// Google requires consent to be collected from users in the EEA, the UK and
/// Switzerland before anything ad-related runs, so ad loading waits until
/// `ConsentInformation` reports that ads may be requested. Users outside
/// those regions are never shown a form and reach `canRequestAds` immediately.
///
/// ATT comes after the UMP form, per Google's documented ordering, and applies
/// everywhere rather than only in regulated regions.
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

    /// Whether the user allowed tracking through the ATT prompt.
    @Published private(set) var isTrackingAuthorized = false

    /// Bumped whenever an answer that shapes the ad request changes. The banner
    /// view is configured once when it is built, so it has to be rebuilt to pick up
    /// a new answer — a late ATT grant, or a consent choice the user just revised.
    @Published private(set) var adConfigurationRevision = 0

    /// Set when reopening the consent form failed, so the UI can say so instead of
    /// leaving a button that appears to do nothing.
    @Published var privacyOptionsFailed = false

    private var hasRequestedConsent = false
    private var hasFinishedConsentFlow = false

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
                // Release the latch on failure. A cold start with no network used to
                // burn the app's only attempt — no ads and no privacy-options entry
                // point for the rest of that launch — because the sole caller runs
                // once. Now the next foreground can try again.
                if error != nil {
                    self?.hasRequestedConsent = false
                }
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
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
                privacyOptionsFailed = false
            } catch {
                // The form is loaded lazily, so a tap that lands before it is ready
                // fails immediately while the SDK retries in the background. Saying
                // nothing made the button look dead; the caller shows an alert.
                privacyOptionsFailed = true
            }

            refreshConsentState()
            // The form can change purposes or vendors without moving `canRequestAds`,
            // and the published GDPR message promises the choice takes effect. Rebuild
            // the banner unconditionally so the next request carries the new answer.
            adConfigurationRevision &+= 1
        }
    }

    /// Retries a tracking prompt that was skipped because the app was not active
    /// when the consent flow finished. A no-op in every other case.
    func requestTrackingAuthorizationIfDeferred() async {
        guard hasFinishedConsentFlow else {
            return
        }

        await requestTrackingAuthorizationIfNeeded()
    }

    private func presentConsentFormIfRequired(updateError: Error?) async {
        // A failed refresh leaves the previous session's choice in place, so fall
        // through to `canRequestAds` either way rather than giving up on ads.
        if updateError == nil, let viewController = UIApplication.shared.rainyClockRootViewController {
            try? await ConsentForm.loadAndPresentIfRequired(from: viewController)
        }

        hasFinishedConsentFlow = true
        await requestTrackingAuthorizationIfNeeded()
        refreshConsentState()
    }

    /// Asks for tracking authorization, which Apple requires before any data may be
    /// used to track the user across apps — the ad SDK's device identifier included.
    ///
    /// The system denies a request made while the app is not active *without showing
    /// the prompt*, and the decision is then permanent, so a launch that has not
    /// reached the foreground defers to `requestTrackingAuthorizationIfDeferred()`.
    private func requestTrackingAuthorizationIfNeeded() async {
        guard !AppEnvironment.isRunningTests else {
            return
        }

        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            isTrackingAuthorized = ATTrackingManager.trackingAuthorizationStatus == .authorized
            return
        }

        guard UIApplication.shared.applicationState == .active else {
            return
        }

        let authorized = await ATTrackingManager.requestTrackingAuthorization() == .authorized
        guard authorized != isTrackingAuthorized else {
            return
        }

        isTrackingAuthorized = authorized
        // A grant that arrives through the deferred path lands after the banner was
        // built; without this the whole session would stay non-personalized.
        adConfigurationRevision &+= 1
    }

    private func refreshConsentState() {
        showsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required

        let allowsAdRequests = ConsentInformation.shared.canRequestAds

        // Two-way on purpose. This used to only ever latch true, so a user who
        // withdrew consent through the privacy options form kept seeing ads for the
        // rest of the session — the opposite of what that form promises them.
        guard allowsAdRequests != canRequestAds else {
            return
        }

        canRequestAds = allowsAdRequests
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
