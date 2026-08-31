import Foundation
import OSLog

/// Asks the proxy to speak a line, and comes back with audio or with a reason.
///
/// Never throws. Nothing here is worth abandoning an alarm over: the caller's
/// fallback is a tone the user already had, which is a worse alarm than the one
/// they asked for but still an alarm. The outcomes are separated only so the UI
/// can say something true — "those words were refused" and "the service is busy"
/// need different sentences, and both need a different one from "you are offline".
protocol AIVoiceGenerating: Sendable {
    func speak(_ text: String, as persona: VoicePersona) async -> AIVoiceOutcome
}

enum AIVoiceOutcome: Sendable {
    /// Raw little-endian 16-bit mono PCM at `GeneratedVoiceAssembler.speechSampleRate`.
    case speech(Data)
    /// The words were refused every time they were tried.
    case rejected
    /// Momentarily out of quota. Trying again later genuinely works.
    case busy
    /// Offline, misconfigured, or the service is down.
    case unavailable
}

struct AIVoiceClient: AIVoiceGenerating {
    private static let logger = Logger(subsystem: "com.shukaihu.RainyClock", category: "AIVoice")

    /// Empty in a build that has not been pointed at a proxy, exactly as
    /// `LevelPlayAppKey` is. The feature then reports itself unavailable rather
    /// than the app failing in some less obvious way.
    static var proxyURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "VoiceProxyURL") as? String,
              !raw.isEmpty else {
            return nil
        }
        return URL(string: raw)
    }

    static var isConfigured: Bool { proxyURL != nil }

    /// Long enough for a ten-second clip plus the model's own latency and a
    /// retry, short enough that a user waiting on a spinner gives up after the
    /// app does rather than before.
    private let timeout: TimeInterval = 45

    func speak(_ text: String, as persona: VoicePersona) async -> AIVoiceOutcome {
        guard let url = Self.proxyURL?.appendingPathComponent("v1/tts") else {
            Self.logger.error("No VoiceProxyURL configured; AI voice unavailable")
            return .unavailable
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Only the words and who says them. No tags: which feeling a sentence gets
        // is chosen server-side, because a bracketed adjective is read aloud as a
        // word and the mapping that avoids that has to be correctable without a
        // release.
        let body: [String: String] = [
            "persona": persona.rawValue,
            "language": Locale.current.language.languageCode?.identifier == "zh" ? "zh-Hant" : "en-US",
            "text": text
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .unavailable
            }

            switch http.statusCode {
            case 200:
                guard !data.isEmpty else {
                    Self.logger.error("Proxy returned an empty clip")
                    return .unavailable
                }
                return .speech(data)
            case 422:
                return .rejected
            case 429, 503:
                return .busy
            default:
                Self.logger.error("Proxy responded \(http.statusCode, privacy: .public)")
                return .unavailable
            }
        } catch {
            Self.logger.error("Voice request failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable
        }
    }
}

/// Used wherever generation must be impossible rather than merely unlikely — the
/// background refresh task and every unattended re-arm. Scheduling an alarm is
/// not allowed to reach the network, and a type that cannot is a stronger
/// guarantee than a flag someone has to remember to check.
struct NoVoiceGenerator: AIVoiceGenerating {
    func speak(_ text: String, as persona: VoicePersona) async -> AIVoiceOutcome { .unavailable }
}
