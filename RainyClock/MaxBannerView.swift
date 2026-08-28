import AppLovinSDK
import SwiftUI
import UIKit

struct MaxBannerView: View {
    let adUnitID: String
    @State private var isLoaded = false
    /// The height the loaded creative actually reported. Starts at the standard
    /// banner height so the reserved space is right before the first load.
    @State private var loadedHeight: CGFloat = 50

    var body: some View {
        GeometryReader { proxy in
            // Anchored adaptive, the same slot shape the AdMob banner used: this
            // banner is pinned above the tab bar, and the width decides the height
            // MAX may fill.
            let width = max(proxy.size.width, 320)
            let height = MAAdFormat.banner.adaptiveSize(forWidth: width).height

            HStack {
                Spacer(minLength: 0)
                MaxBannerContainer(
                    adUnitID: adUnitID,
                    width: width,
                    height: height,
                    isLoaded: $isLoaded,
                    loadedHeight: $loadedHeight
                )
                    .frame(width: width, height: height)
                    .opacity(isLoaded ? 1 : 0)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: height)
        }
        .frame(height: isLoaded ? loadedHeight : 0)
        .clipped()
    }
}

private struct MaxBannerContainer: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat
    let height: CGFloat
    @Binding var isLoaded: Bool
    @Binding var loadedHeight: CGFloat

    func makeUIView(context: Context) -> MAAdView {
        let configuration = MAAdViewConfiguration { builder in
            builder.adaptiveType = .anchored
        }

        let banner = MAAdView(adUnitIdentifier: adUnitID, configuration: configuration)
        banner.delegate = context.coordinator
        // MAX reads the slot size from the view's frame, so it is set before the
        // first load instead of being left to SwiftUI's layout pass.
        banner.frame = CGRect(x: 0, y: 0, width: width, height: height)
        banner.loadAd()
        // Auto-refresh is on by default; stated explicitly so a stray
        // stopAutoRefresh() can never silently freeze the slot on one creative.
        banner.startAutoRefresh()
        return banner
    }

    func updateUIView(_ banner: MAAdView, context: Context) {
        banner.frame = CGRect(x: 0, y: 0, width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoaded: $isLoaded, loadedHeight: $loadedHeight)
    }

    // `@preconcurrency`: AppLovin documents that every SDK callback arrives on
    // the main thread, but its delegate protocols predate Swift concurrency and
    // carry no isolation annotation for the compiler to check against.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency MAAdViewAdDelegate {
        @Binding private var isLoaded: Bool
        @Binding private var loadedHeight: CGFloat

        init(isLoaded: Binding<Bool>, loadedHeight: Binding<CGFloat>) {
            _isLoaded = isLoaded
            _loadedHeight = loadedHeight
        }

        func didLoad(_ ad: MAAd) {
            // Reserve exactly what the creative asked for: an adaptive size varies
            // with width and orientation, so a hardcoded height would clip it.
            loadedHeight = ad.size.height
            isLoaded = true
        }

        func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
            isLoaded = false
            // A failed load collapses to zero height and is indistinguishable from
            // "no ad requested" on screen, which is the diagnosis blind spot behind
            // every "is the integration broken?" round-trip in STATUS-IOS.md.
            #if DEBUG
            print("[MAX] banner failed to load: \(error.message)")
            #endif
        }

        func didDisplay(_ ad: MAAd) {}

        func didHide(_ ad: MAAd) {}

        func didClick(_ ad: MAAd) {}

        func didFail(toDisplay ad: MAAd, withError error: MAError) {}

        func didExpand(_ ad: MAAd) {}

        func didCollapse(_ ad: MAAd) {}
    }
}
