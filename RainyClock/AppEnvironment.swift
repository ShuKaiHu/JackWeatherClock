import Foundation

enum AppEnvironment {
    /// Google requires test ads during development. Requesting production ads from
    /// developer devices counts as invalid traffic, and the account was disabled for
    /// invalid traffic on 2026-08-22 — see `docs/admob-invalid-traffic-appeal.md`.
    /// Only an App Store install may return the production unit; every other channel
    /// gets Google's always-filling test unit.
    static let adMobBannerAdUnitID: String = {
        // `targetEnvironment(simulator)` as well as `DEBUG`: a Release build run on a
        // simulator — which is how the archive gets smoke-tested — would otherwise
        // request the production unit, which is exactly the traffic Google filters.
        #if DEBUG || targetEnvironment(simulator)
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        // A Release build on a device is still not necessarily an App Store install:
        // Xcode and ad-hoc installs carry an embedded provisioning profile, which App
        // Store installs never do, so its presence marks developer traffic. TestFlight
        // builds carry none either — if TestFlight is ever adopted, register the test
        // devices in AdMob first (設定 → 測試裝置) before handing a build out.
        if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
            return "ca-app-pub-3940256099942544/2934735716"
        }
        return "ca-app-pub-2920259088304022/7372515130"
        #endif
    }()

    static var googlePlacesAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String ?? ""
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var routeWeatherService: any RouteWeatherService {
        MapKitRouteWeatherService()
    }

    static var showsWeatherAttribution: Bool {
        true
    }
}
