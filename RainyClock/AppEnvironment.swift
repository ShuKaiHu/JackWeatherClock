import Foundation

enum AppEnvironment {
    /// The LevelPlay banner unit — created in the Unity LevelPlay dashboard,
    /// and iOS-only: LevelPlay ad units are per-platform. There is no separate
    /// always-fill test unit id; development fill comes from the Test Suite
    /// (`-showLevelPlayTestSuite`) or a test device registered in the dashboard.
    static let levelPlayBannerAdUnitID = "kay9cneaxvesx4p4"

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
