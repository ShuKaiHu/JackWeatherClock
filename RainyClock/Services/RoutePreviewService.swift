import CoreLocation
import Foundation
import MapKit

@MainActor
protocol RoutePreviewService {
    func previewRoute(
        from homeAddress: String,
        to workAddress: String,
        mode: CommuteAlarmSettings.CommuteMode
    ) async throws -> RoutePreview
}

struct RoutePreview {
    var homeCoordinate: CLLocationCoordinate2D
    var workCoordinate: CLLocationCoordinate2D
    var homeLocation: ResolvedMapLocation
    var workLocation: ResolvedMapLocation
    var route: MKRoute?

    var routeName: String {
        guard let route else {
            return String(localized: "route_preview_locations_only")
        }

        return route.name.isEmpty ? String(localized: "route_preview_selected_route") : route.name
    }

    var expectedTravelTimeMinutes: Int? {
        guard let route else {
            return nil
        }

        return max(1, Int((route.expectedTravelTime / 60).rounded()))
    }

    var distanceKilometers: Double? {
        guard let route else {
            return nil
        }

        return route.distance / 1_000
    }
}

@MainActor
final class MapKitRoutePreviewService: RoutePreviewService {
    private let mapItemResolver: MapItemResolver

    init() {
        self.mapItemResolver = MapItemResolver()
    }

    func previewRoute(
        from homeAddress: String,
        to workAddress: String,
        mode: CommuteAlarmSettings.CommuteMode
    ) async throws -> RoutePreview {
        let homeLocation = try await mapItemResolver.resolve(homeAddress)
        let workLocation = try await mapItemResolver.resolve(workAddress)
        let route = try? await route(from: homeLocation.mapItem, to: workLocation.mapItem, mode: mode)

        return RoutePreview(
            homeCoordinate: homeLocation.coordinate,
            workCoordinate: workLocation.coordinate,
            homeLocation: homeLocation,
            workLocation: workLocation,
            route: route
        )
    }

    private func route(
        from homeItem: MKMapItem,
        to workItem: MKMapItem,
        mode: CommuteAlarmSettings.CommuteMode
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = homeItem
        request.destination = workItem
        request.transportType = mode.routePreviewTransportType
        request.highwayPreference = mode == .scooter ? .avoid : .any

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
                throw MapKitRouteWeatherServiceError.routeNotFound
            }

            return route
        } catch let error as MapKitRouteWeatherServiceError {
            throw error
        } catch {
            throw MapKitRouteWeatherServiceError.routeNotFound
        }
    }
}

private extension CommuteAlarmSettings.CommuteMode {
    var routePreviewTransportType: MKDirectionsTransportType {
        switch self {
        case .car, .scooter:
            .automobile
        case .walking:
            .walking
        case .publicTransit:
            .transit
        }
    }
}
