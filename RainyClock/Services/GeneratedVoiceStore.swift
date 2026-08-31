import Foundation
import OSLog

/// Owns the generated alarm clips in the app container's `Library/Sounds`.
///
/// Both alarm paths resolve a custom sound by bare file name and search that
/// directory, so a clip written here is playable without shipping in the bundle —
/// verified on a physical iPhone 16 Pro, iOS 26.5.2 (see the AlarmKit section of
/// `docs/app-store-submission-checklist.md`). Two things about the directory are
/// easy to get wrong and are handled here rather than at every call site:
///
/// - **It does not exist** in a fresh container. Writing into it without creating
///   it first fails, and the alarm then silently rings the system tone.
/// - **The default file protection makes it unreadable while the device is
///   locked**, which is exactly when an alarm fires. Every clip is written with
///   `.completeUntilFirstUserAuthentication`.
enum GeneratedVoiceStore {
    private static let logger = Logger(subsystem: "com.shukaihu.RainyClock", category: "GeneratedVoice")

    /// How long an assembled clip runs, speech plus tone bed.
    ///
    /// Not 30: on iOS 17–25 the alarm is a `UNNotificationSound`, whose documented
    /// limit is *less than* 30 seconds, and a file that hits the boundary exactly is
    /// discarded in favour of the default sound with no error anywhere. AlarmKit has
    /// no such limit — a 120 s file plays — but one length that is safe on both
    /// paths beats branching on OS version for two seconds of tone.
    static let assembledDuration: TimeInterval = 28

    /// How much of `assembledDuration` may be generated speech. The remainder is
    /// filled with the user's chosen tone, so the clip is a usable alarm whether or
    /// not the system repeats it — AlarmKit exposes no looping control, and the
    /// observed behaviour changed between iOS 26.0 and 26.1.
    static let maximumSpeechDuration: TimeInterval = 10

    static var directory: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Sounds", isDirectory: true)
    }

    /// The name back again when the file is really there, otherwise `nil` — the
    /// signature callers need to fall back on a shipped tone.
    static func existingFileName(named fileName: String) -> String? {
        guard let url = directory?.appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return fileName
    }

    /// Writes a clip and returns its file name, or `nil` on any failure.
    ///
    /// Deliberately non-throwing: no caller should ever abandon scheduling an alarm
    /// because a sound could not be saved.
    @discardableResult
    static func write(_ data: Data, fileName: String) -> String? {
        guard let directory else {
            logger.error("No library directory; generated voice not saved")
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(fileName)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return fileName
        } catch {
            logger.error("Generated voice write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Removes every clip except the ones named, so superseded generations do not
    /// accumulate. Failure is ignored: leftover files waste space, they do not break
    /// an alarm.
    static func removeAll(except keep: Set<String>) {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return
        }

        for name in names where !keep.contains(name) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
