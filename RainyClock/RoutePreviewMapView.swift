import MapKit
import SwiftUI

struct RoutePreviewMapView: View {
    let preview: RoutePreview
    @State private var position: MapCameraPosition

    init(preview: RoutePreview) {
        self.preview = preview
        _position = State(initialValue: .rect(preview.displayMapRect.paddedForDisplay))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $position) {
                Marker(String(localized: "route_preview_home_pin"), coordinate: preview.homeCoordinate)
                    .tint(.blue)
                Marker(String(localized: "route_preview_work_pin"), coordinate: preview.workCoordinate)
                    .tint(.orange)
                if let route = preview.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            Button {
                centerRoute()
            } label: {
                Label(String(localized: "route_preview_center"), systemImage: "scope")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Color.black.opacity(0.18), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "route_preview_center"))
            .padding(12)
        }
        .frame(minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: preview.cameraResetID) { _, _ in
            centerRoute()
        }
    }

    private func centerRoute() {
        withAnimation(.easeInOut(duration: 0.25)) {
            position = .rect(preview.displayMapRect.paddedForDisplay)
        }
    }
}

private extension RoutePreview {
    var cameraResetID: String {
        let routeRect = route?.polyline.boundingMapRect ?? .null
        return [
            homeCoordinate.latitude,
            homeCoordinate.longitude,
            workCoordinate.latitude,
            workCoordinate.longitude,
            routeRect.origin.x,
            routeRect.origin.y,
            routeRect.size.width,
            routeRect.size.height
        ]
        .map { String(format: "%.6f", $0) }
        .joined(separator: "|")
    }

    var displayMapRect: MKMapRect {
        if let route {
            return route.polyline.boundingMapRect
        }

        let homePoint = MKMapPoint(homeCoordinate)
        let workPoint = MKMapPoint(workCoordinate)
        let minX = min(homePoint.x, workPoint.x)
        let minY = min(homePoint.y, workPoint.y)
        let maxX = max(homePoint.x, workPoint.x)
        let maxY = max(homePoint.y, workPoint.y)

        return MKMapRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

private extension MKMapRect {
    var paddedForDisplay: MKMapRect {
        let minimumSize: Double = 1_500
        let normalizedWidth = max(size.width, minimumSize)
        let normalizedHeight = max(size.height, minimumSize)
        let normalized = MKMapRect(
            x: midX - normalizedWidth / 2,
            y: midY - normalizedHeight / 2,
            width: normalizedWidth,
            height: normalizedHeight
        )

        return normalized.insetBy(
            dx: -normalized.size.width * 0.22,
            dy: -normalized.size.height * 0.22
        )
    }
}
