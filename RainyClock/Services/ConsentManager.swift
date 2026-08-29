import AppLovinSDK
import AppTrackingTransparency
import UIKit

/// Drives the app's ad consent and, behind it, Apple's App Tracking
/// Transparency prompt.
///
/// GDPR consent is collected by the app's own sheet (`AdConsentSheet`) and
/// handed to AppLovin through `ALPrivacySettings.setHasUserConsent`. Google's
/// UMP used to own this job, but its forms are configured in the AdMob console
/// and that account is terminated, so the whole Google layer is gone — and
/// AppLovin's built-in consent flow is no substitute, because its GDPR leg is
/// Google UMP again.
///
/// MAX initialises on first activation; AppLovin resolves the user's geography
/// during that handshake. GDPR users then keep ads gated until they answer the
/// sheet — either answer allows ads, the answer only decides personalisation.
/// Everyone else reaches `canRequestAds` as soon as the SDK is ready.
///
/// ATT comes after the consent decision, preserving the UMP-era ordering, and
/// applies everywhere rather than only in regulated regions.
@MainActor
final class ConsentManager: ObservableObject {
    static let shared = ConsentManager()

    /// Whether ads may be requested for this user: MAX finished initialising,
    /// and a GDPR user has an answer on file. The banner stays out of the view
    /// hierarchy until this turns true, so no ad request can precede consent or
    /// race SDK startup.
    @Published private(set) var canRequestAds = false

    /// Whether the user must be offered a way back into the consent sheet.
    /// Only GDPR regions require the entry point, so it stays hidden elsewhere.
    @Published private(set) var showsPrivacyOptions = false

    /// Whether the user allowed tracking through the ATT prompt.
    @Published private(set) var isTrackingAuthorized = false

    /// Bumped whenever an answer that shapes the ad request changes. The banner
    /// view is configured once when it is built, so it has to be rebuilt to pick
    /// up a new answer — a late ATT grant, or a consent choice the user revised.
    @Published private(set) var adConfigurationRevision = 0

    /// Drives the consent sheet. Dismissing without choosing is allowed: the
    /// user simply stays ad-free for the session and is asked again next launch.
    @Published var isConsentSheetPresented = false

    /// User-defaults key for the stored GDPR answer; missing means "never
    /// answered", which keeps ads off for GDPR users until the sheet is dealt
    /// with.
    private static let consentDefaultsKey = "gdprPersonalizedAdsConsent"

    private var hasStartedAdSdk = false
    private var isAdSdkReady = false
    private var isGDPRUser = false
    private var hasFinishedConsentFlow = false

    private init() {}

    /// Starts the ad SDK, and with it the consent flow. Safe to call on every
    /// activation — the SDK starts at most once per launch, and AppLovin retries
    /// a failed handshake internally, so no retry latch is needed here.
    func requestConsentThenStartAds() {
        guard !AppEnvironment.isRunningTests, !hasStartedAdSdk else {
            return
        }
        hasStartedAdSdk = true
        startMaxSdk()

        #if DEBUG
        // Launch with `-forceGDPRConsentGeography` to rehearse the regulated-
        // region flow from anywhere — the successor of UMP's old
        // `-forceEEAConsentGeography`. It skips the init handshake on purpose,
        // so the sheet can be exercised even while the SDK key is a placeholder.
        if ProcessInfo.processInfo.arguments.contains("-forceGDPRConsentGeography") {
            isGDPRUser = true
            showsPrivacyOptions = true
            if storedConsent == nil {
                isConsentSheetPresented = true
            }
        }
        #endif
    }

    /// Reopens the consent sheet so the user can change their choice — the
    /// entry point behind the Alarm tab's "Ad privacy options" row.
    func presentPrivacyOptions() {
        isConsentSheetPresented = true
    }

    /// Records the sheet's answer. Both answers allow ads; the value only
    /// decides whether AppLovin may personalise them.
    func recordConsent(personalized: Bool) {
        UserDefaults.standard.set(personalized, forKey: Self.consentDefaultsKey)
        ALPrivacySettings.setHasUserConsent(personalized)
        // The banner configures its `MAAdView` once, so a revised answer only
        // reaches the request stream by rebuilding it under a new identity.
        adConfigurationRevision &+= 1
        isConsentSheetPresented = false
    }

    /// Runs when the consent sheet closes, answered or dismissed. The first
    /// close finishes this launch's consent flow: ATT next, then the ad gate.
    func consentSheetDidClose() {
        Task {
            await finishConsentFlow()
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

    /// Starts AppLovin MAX. There is no Google demand behind it: the AdMob
    /// account is terminated (appeal denied), so the Google adapter, the Google
    /// SDK and `GADApplicationIdentifier` were removed on purpose — do not
    /// bring them back. AppLovin's own exchange is the demand.
    private func startMaxSdk() {
        // A stored answer reaches AppLovin before `initialize`, so even the
        // first request of the session carries the right consent bit.
        if let storedConsent {
            ALPrivacySettings.setHasUserConsent(storedConsent)
        }

        let sdkKey = Bundle.main.object(forInfoDictionaryKey: "AppLovinSdkKey") as? String ?? ""
        guard !sdkKey.isEmpty, sdkKey != "YOUR-APPLOVIN-SDK-KEY" else {
            // Skipping instead of crashing inside the SDK: with the placeholder
            // key the app just runs ad-free, and this line says why.
            print("[RainyClock] AppLovinSdkKey is still the placeholder, so MAX never initialises and no ads load.")
            return
        }

        let initConfig = ALSdkInitializationConfiguration(sdkKey: sdkKey) { builder in
            builder.mediationProvider = ALMediationProviderMAX
        }

        ALSdk.shared().initialize(with: initConfig) { [weak self] sdkConfig in
            // Only the geography value crosses into the main-actor task; the
            // config object itself is not Sendable.
            let geography = sdkConfig.consentFlowUserGeography
            Task { @MainActor in
                self?.adSdkDidInitialize(userGeography: geography)
            }
        }
    }

    private func adSdkDidInitialize(userGeography: ALConsentFlowUserGeography) {
        isAdSdkReady = true
        isGDPRUser = Self.isGDPRGeography(userGeography)
        showsPrivacyOptions = isGDPRUser
        presentMediationDebuggerIfRequested()

        if isGDPRUser, storedConsent == nil {
            // The gate stays closed until the sheet is dealt with; the rest of
            // the flow continues from `consentSheetDidClose()`.
            isConsentSheetPresented = true
            return
        }

        Task {
            await finishConsentFlow()
        }
    }

    private func finishConsentFlow() async {
        hasFinishedConsentFlow = true
        await requestTrackingAuthorizationIfNeeded()
        updateCanRequestAds()
    }

    /// Asks for tracking authorization, which Apple requires before any data may
    /// be used to track the user across apps — the ad SDK's device identifier
    /// included.
    ///
    /// The system denies a request made while the app is not active *without
    /// showing the prompt*, and the decision is then permanent, so a launch that
    /// has not reached the foreground defers to
    /// `requestTrackingAuthorizationIfDeferred()`.
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
        // A grant that arrives through the deferred path lands after the banner
        // was built; rebuilding it puts the new answer on the next request right
        // away instead of whenever the auto-refresh cycle next comes around.
        adConfigurationRevision &+= 1
    }

    private func updateCanRequestAds() {
        // A GDPR user needs an answer on file — either answer — before the
        // first request; everyone else only waits for the SDK itself.
        let allowsAdRequests = isAdSdkReady && (!isGDPRUser || storedConsent != nil)

        guard allowsAdRequests != canRequestAds else {
            return
        }

        canRequestAds = allowsAdRequests
    }

    private var storedConsent: Bool? {
        UserDefaults.standard.object(forKey: Self.consentDefaultsKey) as? Bool
    }

    private func presentMediationDebuggerIfRequested() {
        #if DEBUG
        // Launch with `-showMediationDebugger` to check the SDK wiring. It hangs
        // off the init completion because the debugger needs a live SDK.
        if ProcessInfo.processInfo.arguments.contains("-showMediationDebugger") {
            ALSdk.shared().showMediationDebugger()
        }
        #endif
    }

    /// AppLovin resolves geography server-side during init. `.unknown` — an
    /// offline first launch, a lookup hiccup — falls back to the device region,
    /// erring toward asking: a false positive costs one extra sheet, a false
    /// negative serves ads without a legal basis.
    private static func isGDPRGeography(_ geography: ALConsentFlowUserGeography) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-forceGDPRConsentGeography") {
            return true
        }
        #endif

        switch geography {
        case .GDPR:
            return true
        case .unknown:
            return Self.gdprFallbackRegions.contains(Locale.current.region?.identifier ?? "")
        default:
            return false
        }
    }

    /// EEA members plus the UK — consulted only when AppLovin's lookup fails.
    private static let gdprFallbackRegions: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DE", "DK", "EE", "ES", "FI", "FR",
        "GB", "GR", "HU", "IE", "IS", "IT", "LI", "LT", "LU", "LV", "MT", "NL",
        "NO", "PL", "PT", "RO", "SE", "SI", "SK",
    ]
}
