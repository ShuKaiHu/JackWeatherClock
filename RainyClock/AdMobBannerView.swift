import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: View {
    let adUnitID: String
    @State private var isLoaded = false

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 320)
            let adSize = inlineAdaptiveBanner(width: width, maxHeight: 36)
            let size = cgSize(for: adSize)

            HStack {
                Spacer(minLength: 0)
                AdMobBannerContainer(
                    adUnitID: adUnitID,
                    adSize: adSize,
                    isLoaded: $isLoaded
                )
                    .frame(width: size.width, height: size.height)
                    .opacity(isLoaded ? 1 : 0)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: 36)
        }
        .frame(height: isLoaded ? 36 : 0)
        .clipped()
    }
}

private struct AdMobBannerContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    @Binding var isLoaded: Bool

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.rainyClockRootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adSize = adSize
        banner.rootViewController = UIApplication.shared.rainyClockRootViewController
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded)
    }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding private var isLoaded: Bool

        init(isLoaded: Binding<Bool>) {
            _isLoaded = isLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            isLoaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            isLoaded = false
        }
    }
}

private extension UIApplication {
    var rainyClockRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
