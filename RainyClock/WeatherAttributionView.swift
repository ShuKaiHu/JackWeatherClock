import SwiftUI
import WeatherKit

/// Displays Apple's required WeatherKit attribution: the official Apple Weather
/// combined mark ( Weather) linked to the legal attribution page. The app is
/// locked to dark mode, so the dark combined mark is always used.
struct WeatherAttributionView: View {
    @State private var attribution: WeatherAttribution?

    private let fallbackLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        // The mark itself links to the legal attribution page, satisfying the
        // WeatherKit requirement of showing the Apple Weather trademark together
        // with a link to its data-source attribution.
        Link(destination: attribution?.legalPageURL ?? fallbackLegalURL) {
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
