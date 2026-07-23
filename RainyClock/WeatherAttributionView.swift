import SwiftUI

struct WeatherAttributionView: View {
    private let attributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        Link(destination: attributionURL) {
            Text(String(localized: "weather_data_attribution"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
