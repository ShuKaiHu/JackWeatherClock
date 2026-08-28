import Foundation

enum AppEnvironment {
    /// The MAX banner unit. Unlike AdMob there is no separate always-fill test
    /// unit id: development fill comes from MAX test mode — the Mediation Debugger
    /// toggle, or a test device registered in the AppLovin dashboard. Simulators
    /// are still covered on the Google side, whose SDK treats them as test devices
    /// automatically, so debug builds don't produce billable AdMob traffic there.
    static let maxBannerAdUnitID = "kay9cneaxvesx4p4"

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
