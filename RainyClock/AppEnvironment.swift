import Foundation

enum AppEnvironment {
    /// Google requires test ads during development. Requesting production ads from
    /// simulators and debug builds counts as invalid traffic, and enough of it risks
    /// the AdMob account, so Debug builds use Google's always-filling test unit.
    static let adMobBannerAdUnitID: String = {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
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
