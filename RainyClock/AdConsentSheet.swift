import SwiftUI

/// The GDPR consent sheet. This is the app's own UI on purpose: Google UMP went
/// away with the terminated AdMob account, and AppLovin's built-in flow would
/// route straight back to UMP for its GDPR leg. Both buttons allow ads — the
/// choice only decides personalisation — and the answer feeds
/// `ConsentManager.recordConsent`, which forwards it to AppLovin.
struct AdConsentSheet: View {
    @ObservedObject private var consentManager = ConsentManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ad_consent_title")
                .font(.title3.bold())

            Text("ad_consent_body")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: URL(string: "https://shukaihu.github.io/RainyClock/privacy-policy.html")!) {
                Text("ad_consent_privacy_link")
                    .font(.callout)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    consentManager.recordConsent(personalized: true)
                } label: {
                    Text("ad_consent_accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    consentManager.recordConsent(personalized: false)
                } label: {
                    Text("ad_consent_decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
