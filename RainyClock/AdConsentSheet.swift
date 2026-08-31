import SwiftUI

/// The GDPR consent sheet. This is the app's own UI on purpose: Google UMP went
/// away with the terminated AdMob account, and Unity LevelPlay bundles no
/// consent UI of its own. Both buttons allow ads — the choice only decides
/// personalisation — and the answer feeds `ConsentManager.recordConsent`,
/// which forwards it to LevelPlay.
///
/// The wording is not free copy. ironSource's Data Protection Addendum
/// requires the consent to name ironSource — and, for the personalised tier,
/// its advertising partners — as controllers, and to reach its privacy policy
/// from inside the app. Keep all three when editing.
struct AdConsentSheet: View {
    /// Unity's end-user-facing policy, the live successor of the ironSource
    /// mobile privacy policy the addendum names (that URL now redirects to
    /// Unity's legal index). Swap it if support supplies a more specific one.
    private static let adProviderPrivacyPolicyURL = URL(
        string: "https://unity.com/legal/game-player-and-app-user-privacy-policy"
    )!
    private static let appPrivacyPolicyURL = URL(
        string: "https://shukaihu.github.io/RainyClock/privacy-policy.html"
    )!

    @ObservedObject private var consentManager = ConsentManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ad_consent_title")
                .font(.title3.bold())

            // Only the prose scrolls. The two policy links sit outside it, so
            // they stay on screen at every text size and detent — the addendum
            // wants them part of the consent, and one behind a scroll is one
            // nobody sees.
            ScrollView {
                Text("ad_consent_body")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: Self.appPrivacyPolicyURL) {
                    Text("ad_consent_privacy_link")
                        .font(.callout)
                }

                Link(destination: Self.adProviderPrivacyPolicyURL) {
                    Text("ad_consent_provider_privacy_link")
                        .font(.callout)
                }
            }

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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
