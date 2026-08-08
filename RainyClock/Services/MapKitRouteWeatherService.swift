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
        homeLocation selectedHomeLocation: ResolvedMapLocation? = nil,
        to workAddress: String,
        workLocation selectedWorkLocation: ResolvedMapLocation? = nil,
        mode: CommuteAlarmSettings.CommuteMode,
        around commuteTime: Date
    ) async throws -> RouteWeatherSnapshot {
        let homeLocation: ResolvedMapLocation
        if let selectedHomeLocation {
            homeLocation = selectedHomeLocation
        } else {
            homeLocation = try await mapItemResolver.resolve(homeAddress)
        }

        let workLocation: ResolvedMapLocation
        if let selectedWorkLocation {
            workLocation = selectedWorkLocation
        } else {
            workLocation = try await mapItemResolver.resolve(workAddress)
        }
        let segments = try await makeSegments(
            homeLocation: homeLocation,
            workLocation: workLocation,
            mode: mode,
            around: commuteTime
        )

        return RouteWeatherSnapshot(checkedAt: Date(), forecastAt: commuteTime, segments: segments)
    }

    private func makeSegments(
        homeLocation: ResolvedMapLocation,
        workLocation: ResolvedMapLocation,
        mode: CommuteAlarmSettings.CommuteMode,
        around commuteTime: Date
    ) async throws -> [RouteWeatherSegment] {
        let interiorCoordinates = await interiorSampleCoordinates(
            homeLocation: homeLocation,
            workLocation: workLocation,
            mode: mode
        )

        var endpoints: [(name: String, coordinate: CLLocationCoordinate2D)] = [
            (
                String(localized: "segment_home_area"),
                homeLocation.coordinate
            )
        ]
        for (index, coordinate) in interiorCoordinates.enumerated() {
            endpoints.append((
                Self.interiorSegmentName(index: index, total: interiorCoordinates.count),
                coordinate
            ))
        }
        endpoints.append((
            String(localized: "segment_office_area"),
            workLocation.coordinate
        ))

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

    /// Points along the commute route that also get a rain check — the
    /// decision covers home, the route, and the office, and any of them over
    /// the threshold pulls the alarm earlier.
    ///
    /// Best-effort by design: MKDirections has no transit geometry, and any
    /// route failure degrades to the endpoint-only check rather than blocking
    /// the alarm decision.
    private func interiorSampleCoordinates(
        homeLocation: ResolvedMapLocation,
        workLocation: ResolvedMapLocation,
        mode: CommuteAlarmSettings.CommuteMode
    ) async -> [CLLocationCoordinate2D] {
        guard mode != .publicTransit else {
            return []
        }

        let request = MKDirections.Request()
        request.source = homeLocation.mapItem
        request.destination = workLocation.mapItem
        request.transportType = mode == .walking ? .walking : .automobile

        guard let response = try? await MKDirections(request: request).calculate(),
              let route = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            return []
        }

        return RoutePolylineSampler.interiorSamplePoints(along: route.polyline.coordinateArray)
    }

    static func interiorSegmentName(index: Int, total: Int) -> String {
        let base = String(localized: "segment_route_placeholder")
        guard total > 1 else {
            return base
        }
        return String.localizedStringWithFormat(String(localized: "segment_route_sample_format"), base, index + 1)
    }
}

/// Picks interior weather-sample points along a route polyline. Distance-based
/// because weather-model cells are a few km wide — on a short commute the
/// endpoints already cover the route:
///   < 4 km  → no interior samples
///   4–20 km → the midpoint
///   ≥ 20 km → quarter, mid, and three-quarter points
///
/// Replaces the earlier `RoutePolylineSampler` deleted in the 1.6.5 cleanup,
/// which trapped on `Int(Double.nan)` when asked for a single sample; the
/// degenerate cases (empty, single-point, zero-length routes) are unit-tested
/// this time. Matches the Android `RouteSampler` exactly.
enum RoutePolylineSampler {
    static func interiorSamplePoints(along coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else {
            return []
        }

        var cumulative: [CLLocationDistance] = [0]
        cumulative.reserveCapacity(coordinates.count)
        for index in 1..<coordinates.count {
            cumulative.append(cumulative[index - 1] + distance(coordinates[index - 1], coordinates[index]))
        }

        guard let total = cumulative.last, total > 0 else {
            return []
        }

        let fractions: [Double]
        switch total {
        case ..<4_000:
            return []
        case ..<20_000:
            fractions = [0.5]
        default:
            fractions = [0.25, 0.5, 0.75]
        }

        return fractions.map { fraction in
            point(atDistance: total * fraction, along: coordinates, cumulative: cumulative)
        }
    }

    private static func point(
        atDistance target: CLLocationDistance,
        along coordinates: [CLLocationCoordinate2D],
        cumulative: [CLLocationDistance]
    ) -> CLLocationCoordinate2D {
        for index in 1..<coordinates.count where cumulative[index] >= target {
            let segmentLength = cumulative[index] - cumulative[index - 1]
            guard segmentLength > 0 else {
                return coordinates[index]
            }
            let t = (target - cumulative[index - 1]) / segmentLength
            let start = coordinates[index - 1]
            let end = coordinates[index]
            return CLLocationCoordinate2D(
                latitude: start.latitude + (end.latitude - start.latitude) * t,
                longitude: start.longitude + (end.longitude - start.longitude) * t
            )
        }
        return coordinates[coordinates.count - 1]
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

private extension MKPolyline {
    var coordinateArray: [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
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
