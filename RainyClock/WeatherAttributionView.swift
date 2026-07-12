import SwiftUI

struct WeatherAttributionView: View {
    private let attributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        Link(destination: attributionURL) {
            Text(verbatim: "Weather data by Apple Weather")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
