import Foundation

/// Who the alarm sounds like.
///
/// The ids here are a contract with `weather-proxy/personas.js`, which owns the
/// voice each one maps to and the direction it is spoken with. Deliberately
/// asymmetric: the app names a persona, the proxy decides what that sounds like,
/// so retuning a voice is a redeploy rather than a release through App Review.
///
/// Gender is a property of the choice rather than a question of its own — the
/// roster is three female and three male, and the API has no gender parameter to
/// pass anyway. A separate control would only filter a list the user is already
/// looking at.
enum VoicePersona: String, CaseIterable, Codable, Identifiable, Sendable {
    case steady
    case bright
    case gentle
    case buddy
    case mom
    case sergeant

    var id: String { rawValue }

    /// The default carries the app's own reason for existing — a rain briefing is
    /// delivered better by an informative voice than an excited one — and is the
    /// least likely of the six to wear out as a novelty.
    static let `default`: VoicePersona = .steady

    var displayName: String {
        switch self {
        case .steady: String(localized: "voice_persona_steady")
        case .bright: String(localized: "voice_persona_bright")
        case .gentle: String(localized: "voice_persona_gentle")
        case .buddy: String(localized: "voice_persona_buddy")
        case .mom: String(localized: "voice_persona_mom")
        case .sergeant: String(localized: "voice_persona_sergeant")
        }
    }

    var subtitle: String {
        switch self {
        case .steady: String(localized: "voice_persona_steady_hint")
        case .bright: String(localized: "voice_persona_bright_hint")
        case .gentle: String(localized: "voice_persona_gentle_hint")
        case .buddy: String(localized: "voice_persona_buddy_hint")
        case .mom: String(localized: "voice_persona_mom_hint")
        case .sergeant: String(localized: "voice_persona_sergeant_hint")
        }
    }

    /// A clip shipped in the bundle, so a user can hear every voice before
    /// spending a generation — or a network round trip — on any of them.
    var previewResourceName: String {
        let language = Locale.current.language.languageCode?.identifier == "zh" ? "zh" : "en"
        return "preview-\(rawValue)-\(language)"
    }
}
