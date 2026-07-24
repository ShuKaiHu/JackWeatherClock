import SwiftUI
import WeatherKit

/// Displays Apple's required WeatherKit attribution: the official Apple Weather
/// combined mark ( Weather) linked to the legal attribution page. The app is
/// locked to dark mode, so the dark combined mark is always used.
struct WeatherAttributionView: View {
    @State private var attribution: WeatherAttribution?

    private let fallbackLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        Link(destination: attribution?.legalPageURL ?? fallbackLegalURL) {
            HStack(spacing: 6) {
                if let markURL = attribution?.combinedMarkDarkURL {
                    AsyncImage(url: markURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        fallbackLabel
                    }
                    .frame(height: 16)
                } else {
                    fallbackLabel
                }

                Text("weather_data_source_link")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
        .task {
            attribution = try? await WeatherService.shared.attribution
        }
    }

    private var fallbackLabel: some View {
        Text("weather_data_attribution")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}
