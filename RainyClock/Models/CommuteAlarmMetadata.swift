import Foundation

#if canImport(AlarmKit)
import AlarmKit

/// Travels with the AlarmKit alarm so the Live Activity can describe the ring
/// without reading app storage — widget extensions run in their own process and
/// have no access to the app's UserDefaults.
@available(iOS 26.0, *)
struct CommuteAlarmMetadata: AlarmMetadata {
    /// True when rain moved the ring earlier than the configured alarm time.
    var adjustedForRain: Bool
    /// The alarm time the user configured, before any rain lead time.
    var normalAlarmHour: Int
    var normalAlarmMinute: Int

    init(adjustedForRain: Bool = false, normalAlarmHour: Int = 0, normalAlarmMinute: Int = 0) {
        self.adjustedForRain = adjustedForRain
        self.normalAlarmHour = normalAlarmHour
        self.normalAlarmMinute = normalAlarmMinute
    }
}
#endif
