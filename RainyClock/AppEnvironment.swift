import Foundation

enum AppEnvironment {
    /// The LevelPlay banner unit — created in the Unity LevelPlay dashboard,
    /// and iOS-only: LevelPlay ad units are per-platform. There is no separate
    /// always-fill test unit id; development fill comes from the Test Suite
    /// (`-showLevelPlayTestSuite`) or a test device registered in the dashboard.
    static let levelPlayBannerAdUnitID = "kay9cneaxvesx4p4"

    /// The rewarded unit, exchanged one video for one voice generation. Its
    /// dashboard reward is deliberately `Generation ×1`, matching what the app
    /// grants — the reward promised in the ad has to be the reward delivered.
    ///
    /// Blanking this string turns the exchange off without removing the code,
    /// the same way a blank app key keeps the SDK from starting: the sheet then
    /// says the free allowance is spent rather than offering a trade it cannot
    /// honour.
    static let levelPlayRewardedAdUnitID = "nhprp5kcjqwwuoar"

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
