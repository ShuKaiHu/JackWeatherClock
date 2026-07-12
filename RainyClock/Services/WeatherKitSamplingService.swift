import CoreLocation
import Foundation
import OSLog
import WeatherKit

struct WeatherKitSamplingService: WeatherSamplingService {
    private let service: WeatherService
    private let calendar: Calendar
    private let logger = Logger(subsystem: "com.shukaihu.RainyClock", category: "WeatherKit")

    init(
        service: WeatherService = .shared,
        calendar: Calendar = .current
    ) {
        self.service = service
        self.calendar = calendar
    }

    func sampleWeather(
        at coordinate: CLLocationCoordinate2D,
        around date: Date
    ) async throws -> WeatherSample {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let startDate = calendar.date(byAdding: .hour, value: -1, to: date) ?? date
        let endDate = calendar.date(byAdding: .hour, value: 3, to: date) ?? date
        let hourlyForecast = try await service.weather(
            for: location,
            including: .hourly(startDate: startDate, endDate: endDate)
        )

        guard let hour = hourlyForecast.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else {
            throw WeatherKitSamplingServiceError.missingForecast
        }

        logger.info("WeatherKit sample target=\(date.formatted(date: .abbreviated, time: .standard), privacy: .public) matched=\(hour.date.formatted(date: .abbreviated, time: .standard), privacy: .public) condition=\(hour.condition.rawValue, privacy: .public) precipitation=\(hour.precipitationChance, privacy: .public)")

        return WeatherSample(
            condition: condition(for: hour.condition, precipitationProbability: hour.precipitationChance),
            precipitationProbability: hour.precipitationChance
        )
    }

    private func condition(
        for condition: WeatherCondition,
        precipitationProbability: Double
    ) -> RouteWeatherSegment.Condition {
        switch condition {
        case .drizzle, .freezingDrizzle, .freezingRain, .hail, .heavyRain, .rain, .sleet, .strongStorms, .sunShowers, .thunderstorms, .tropicalStorm, .hurricane:
            .rain
        case .blizzard, .blowingDust, .blowingSnow, .breezy, .cloudy, .flurries, .foggy, .frigid, .haze, .heavySnow, .isolatedThunderstorms, .mostlyCloudy, .partlyCloudy, .scatteredThunderstorms, .smoky, .snow, .sunFlurries, .windy, .wintryMix:
            .cloudy
        case .clear, .hot, .mostlyClear:
            WeatherSampleMapper.condition(for: precipitationProbability)
        @unknown default:
            WeatherSampleMapper.condition(for: precipitationProbability)
        }
    }
}

private enum WeatherKitSamplingServiceError: Error {
    case missingForecast
}
