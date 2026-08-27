import Foundation

enum AppEnvironment {
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
