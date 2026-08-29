import GoogleMobileAds
import SwiftUI
import UIKit

struct AdMobBannerView: View {
    let adUnitID: String
    /// Mirrors the ATT decision. The banner is only built once `ConsentManager`
    /// has settled both prompts, so this is never read before it is known.
    let allowsPersonalizedAds: Bool
    @State private var isLoaded = false
    /// The height the loaded creative actually reported. Starts at the standard
    /// banner height so the reserved space is right before the first load.
    @State private var loadedHeight: CGFloat = 50

    var body: some View {
        GeometryReader { proxy in
            // Anchored, not inline: this banner is pinned above the tab bar, and
            // Google documents inline adaptive as the scroll-view variant. The old
            // `inlineAdaptiveBanner(maxHeight: 36)` also capped the slot below the
            // 50pt standard creative, which excluded most of the inventory.
            let width = max(proxy.size.width, 320)
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            let size = cgSize(for: adSize)

            HStack {
                Spacer(minLength: 0)
                AdMobBannerContainer(
                    adUnitID: adUnitID,
                    adSize: adSize,
                    allowsPersonalizedAds: allowsPersonalizedAds,
                    isLoaded: $isLoaded,
                    loadedHeight: $loadedHeight
                )
                    .frame(width: size.width, height: size.height)
                    .opacity(isLoaded ? 1 : 0)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: size.height)
        }
        .frame(height: isLoaded ? loadedHeight : 0)
        .clipped()
    }
}

private struct AdMobBannerContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    let allowsPersonalizedAds: Bool
    @Binding var isLoaded: Bool
    @Binding var loadedHeight: CGFloat

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.rainyClockRootViewController
        banner.load(Self.request(allowsPersonalizedAds: allowsPersonalizedAds))
        return banner
    }

    // Personalization is allowed only where the user granted ATT; everyone who
    // declined, or who was never asked, gets `npa=1`.
    private static func request(allowsPersonalizedAds: Bool) -> Request {
        let request = Request()
        guard !allowsPersonalizedAds else {
            return request
        }

        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        banner.adSize = adSize
        banner.rootViewController = UIApplication.shared.rainyClockRootViewController
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded, loadedHeight: $loadedHeight)
    }

    @MainActor
    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding private var isLoaded: Bool
        @Binding private var loadedHeight: CGFloat

        init(isLoaded: Binding<Bool>, loadedHeight: Binding<CGFloat>) {
            _isLoaded = isLoaded
            _loadedHeight = loadedHeight
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            // Reserve exactly what the creative asked for: an adaptive size varies
            // with width and orientation, so a hardcoded height would clip it.
            loadedHeight = bannerView.adSize.size.height
            isLoaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            isLoaded = false
            // A failed load collapses to zero height and is indistinguishable from
            // "no ad requested" on screen, which is the diagnosis blind spot behind
            // every "is the integration broken?" round-trip in STATUS-IOS.md.
            #if DEBUG
            print("[AdMob] banner failed to load: \(error.localizedDescription)")
            #endif
        }
    }
}
