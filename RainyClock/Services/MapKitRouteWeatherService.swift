import CoreLocation
import Foundation
import MapKit

actor MapKitRouteWeatherService: RouteWeatherService {
    private let mapItemResolver: MapItemResolver
    private let weatherSamplingService: any WeatherSamplingService

    init(
        weatherSamplingService: any WeatherSamplingService = WeatherKitSamplingService()
    ) {
        self.mapItemResolver = MapItemResolver()
        self.weatherSamplingService = weatherSamplingService
    }

    func fetchRouteWeather(
        from homeAddress: String,
        to workAddress: String,
        mode: CommuteAlarmSettings.CommuteMode,
        around commuteTime: Date
    ) async throws -> RouteWeatherSnapshot {
        let homeLocation = try await mapItemResolver.resolve(homeAddress)
        let workLocation = try await mapItemResolver.resolve(workAddress)
        let segments = try await makeSegments(
            homeLocation: homeLocation,
            workLocation: workLocation,
            around: commuteTime
        )

        return RouteWeatherSnapshot(checkedAt: Date(), forecastAt: commuteTime, segments: segments)
    }

    private func makeSegments(
        homeLocation: ResolvedMapLocation,
        workLocation: ResolvedMapLocation,
        around commuteTime: Date
    ) async throws -> [RouteWeatherSegment] {
        let endpoints: [(name: String, coordinate: CLLocationCoordinate2D)] = [
            (
                String(localized: "segment_home_area"),
                homeLocation.coordinate
            ),
            (
                String(localized: "segment_office_area"),
                workLocation.coordinate
            )
        ]

        var segments: [RouteWeatherSegment] = []
        segments.reserveCapacity(endpoints.count)

        for endpoint in endpoints {
            let sample = try await weatherSamplingService.sampleWeather(at: endpoint.coordinate, around: commuteTime)
            segments.append(RouteWeatherSegment(
                name: endpoint.name,
                condition: sample.condition,
                precipitationProbability: sample.precipitationProbability
            ))
        }

        return segments
    }
}

enum MapKitRouteWeatherServiceError: LocalizedError, Equatable {
    case addressNotFound(String)
    case routeNotFound

    var errorDescription: String? {
        switch self {
        case .addressNotFound(let address):
            String.localizedStringWithFormat(String(localized: "error_address_not_found"), address)
        case .routeNotFound:
            String(localized: "error_route_not_found")
        }
    }
}
