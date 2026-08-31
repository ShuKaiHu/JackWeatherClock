import Foundation

/// The "report this ad" route required by App Review guideline 2.5.18, which
/// says an app carrying ads "must also include the ability for users to report
/// any inappropriate or age-inappropriate ads".
///
/// A mail draft rather than a form: the app has no backend that receives user
/// messages and no account to attach a report to, and adding either to satisfy
/// one guideline would mean collecting more about the user than the whole app
/// currently does.
///
/// Nothing here identifies the person. The prefilled body carries the app and
/// build version so a report can be tied to a release, and the ad network,
/// because an ad Rainy Clock cannot see is one only the mediator can trace —
/// everything else is left for the user to write, or not.
enum AdReport {
    static let address = "shukaihu@icloud.com"

    static var mailURL: URL {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

        let subject = String(localized: "report_ad_subject")
        let body = String.localizedStringWithFormat(
            String(localized: "report_ad_body"),
            "\(version) (\(build))"
        )

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        // `mailto` bodies are percent-encoded, and a newline left raw truncates
        // the draft at the first line in some mail clients.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url ?? URL(string: "mailto:\(address)")!
    }
}
