import CoreLocation
import Foundation

struct GooglePlaceResolver {
    private let apiKey: String
    private let urlSession: URLSession

    init(apiKey: String = AppEnvironment.googlePlacesAPIKey, urlSession: URLSession = .shared) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.urlSession = urlSession
    }

    func resolve(_ queries: [String]) async -> ResolvedMapLocation? {
        guard !apiKey.isEmpty else {
            return nil
        }

        for query in queries {
            guard let location = await geocode(query) else {
                continue
            }

            return location
        }

        return nil
    }

    private func geocode(_ query: String) async -> ResolvedMapLocation? {
        guard var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "address", value: query),
            URLQueryItem(name: "region", value: "tw"),
            URLQueryItem(name: "language", value: MapItemResolver.containsHanCharacters(query) ? "zh-TW" : "en"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components.url else {
            return nil
        }

        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let geocodeResponse = try JSONDecoder().decode(GoogleGeocodeResponse.self, from: data)
            guard geocodeResponse.status == "OK",
                  let coordinate = geocodeResponse.results.first?.geometry.location else {
                return nil
            }
            let displayAddress = geocodeResponse.results.first?.formattedAddress
            guard MapItemResolver.isAcceptableResolvedAddress(query: query, displayAddress: displayAddress) else {
                return nil
            }

            return ResolvedMapLocation(
                latitude: coordinate.lat,
                longitude: coordinate.lng,
                displayAddress: displayAddress,
                resolution: .suggested
            )
        } catch {
            return nil
        }
    }
}

private struct GoogleGeocodeResponse: Decodable {
    var status: String
    var results: [GoogleGeocodeResult]
}

private struct GoogleGeocodeResult: Decodable {
    var geometry: GoogleGeocodeGeometry
    var formattedAddress: String?

    private enum CodingKeys: String, CodingKey {
        case geometry
        case formattedAddress = "formatted_address"
    }
}

private struct GoogleGeocodeGeometry: Decodable {
    var location: GoogleGeocodeLocation
}

private struct GoogleGeocodeLocation: Decodable {
    var lat: Double
    var lng: Double
}
