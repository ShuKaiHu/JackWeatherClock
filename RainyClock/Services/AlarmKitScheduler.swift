import Foundation
import OSLog

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import SwiftUI

/// Schedules the commute alarm through AlarmKit (iOS 26+).
///
/// Unlike a `UNNotificationRequest`, an AlarmKit alarm overrides silent mode and
/// Focus, keeps alerting until the user acts, and offers a native snooze — so this
/// path needs none of the follow-up-notification bookkeeping that
/// `LocalNotificationScheduler` carries for older systems.
@available(iOS 26.0, *)
struct AlarmKitScheduler: NotificationScheduling {
    private static let logger = Logger(subsystem: "com.shukaihu.RainyClock", category: "AlarmKit")

    func requestAuthorization() async throws -> Bool {
        let manager = AlarmManager.shared
        if manager.authorizationState == .authorized {
            return true
        }

        return try await manager.requestAuthorization() == .authorized
    }

    func scheduleAlarm(
        at date: Date,
        normalAlarmDate: Date,
        weekdays: Set<Int>,
        sound: CommuteAlarmSettings.AlarmSound,
        snoozeMinutes: Int?,
        title: String,
        body: String
    ) async throws {
        let calendar = Calendar.current
        let selectedWeekdays = weekdays.isEmpty ? CommuteAlarmSettings.allWeekdays : weekdays

        // The ring may land on an earlier day than the normal alarm (rain lead time
        // crossing midnight), so every selected weekday shifts by the same day delta.
        let dayShift = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: normalAlarmDate),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        let ringWeekdays = selectedWeekdays.map { AlarmTimeCalculator.shiftedWeekday($0, byDays: dayShift) }

        let ringTime = calendar.dateComponents([.hour, .minute], from: date)
        let normalTime = calendar.dateComponents([.hour, .minute], from: normalAlarmDate)
        // A ring that differs from the configured alarm time is one rain moved earlier.
        // `title`/`body` from the protocol go unused: the alert renders in system UI
        // that takes a LocalizedStringResource, so the presentation below builds its
        // own copy from keys instead of pre-resolved strings.
        let adjustedForRain = abs(date.timeIntervalSince(normalAlarmDate)) >= 60

        let metadata = CommuteAlarmMetadata(
            adjustedForRain: adjustedForRain,
            normalAlarmHour: normalTime.hour ?? 0,
            normalAlarmMinute: normalTime.minute ?? 0
        )
        let attributes = AlarmAttributes(
            presentation: Self.presentation(adjustedForRain: adjustedForRain, snoozeMinutes: snoozeMinutes),
            metadata: metadata,
            tintColor: Color.accentColor
        )
        let schedule = Alarm.Schedule.relative(
            Alarm.Schedule.Relative(
                time: Alarm.Schedule.Relative.Time(
                    hour: ringTime.hour ?? 0,
                    minute: ringTime.minute ?? 0
                ),
                repeats: .weekly(ringWeekdays.sorted().compactMap(Self.localeWeekday))
            )
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: snoozeMinutes.map { Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval($0 * 60)) },
            schedule: schedule,
            attributes: attributes,
            sound: Self.alertSound(for: sound)
        )

        // Register the replacement before retiring what is already armed: if
        // scheduling throws, the user keeps the alarm they had instead of silently
        // ending up with none.
        let supersededIdentifiers = Self.scheduledAlarmIdentifiers()
        let identifier = UUID()
        _ = try await AlarmManager.shared.schedule(id: identifier, configuration: configuration)

        for supersededIdentifier in supersededIdentifiers where supersededIdentifier != identifier {
            try? AlarmManager.shared.cancel(id: supersededIdentifier)
        }
        // An upgraded install can still hold pending notification requests from the
        // pre-26 path; leaving them armed would ring twice.
        await LocalNotificationScheduler.cancelScheduledAlarms()
        Self.logger.info("Scheduled AlarmKit alarm \(identifier.uuidString, privacy: .public) on \(ringWeekdays.count, privacy: .public) weekdays, superseding \(supersededIdentifiers.count, privacy: .public)")
    }

    /// AlarmKit only exposes the calling app's alarms, so this can never see — or
    /// cancel — another app's or the system's.
    static func scheduledAlarmIdentifiers() -> [Alarm.ID] {
        ((try? AlarmManager.shared.alarms) ?? []).map(\.id)
    }

    func cancelScheduledAlarms() async {
        for identifier in Self.scheduledAlarmIdentifiers() {
            try? AlarmManager.shared.cancel(id: identifier)
        }
    }

    /// Pins the containing app's bundle by URL. These resources are decoded in the
    /// widget extension's process to render the snooze Live Activity, where `.main`
    /// would resolve to the appex — which ships no strings — and the UI would show
    /// the raw key.
    private static func localized(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.main.bundleURL))
    }

    /// The system alarm tone is only reachable through `.default`; every other
    /// choice names a file this app ships.
    private static func alertSound(for sound: CommuteAlarmSettings.AlarmSound) -> AlertConfiguration.AlertSound {
        sound.usesSystemAlarmTone ? .default : .named(sound.fileName)
    }

    private static func presentation(adjustedForRain: Bool, snoozeMinutes: Int?) -> AlarmPresentation {
        // Localized keys rather than resolved strings: AlarmKit renders the alert in
        // the system UI, so it resolves them in whatever locale is current when the
        // alarm fires instead of the one that was active when it was scheduled.
        let title = adjustedForRain
            ? localized("alarm_alert_title_adjusted")
            : localized("alarm_alert_title_normal")
        let snoozeButton = snoozeMinutes.map { _ in
            AlarmButton(
                text: localized("alarm_snooze_button"),
                textColor: .white,
                systemImageName: "zzz"
            )
        }
        // iOS 26.0 requires an explicit stop button; 26.1 supplies its own and
        // deprecated the parameter.
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: snoozeButton.map { _ in .countdown }
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(
                    text: localized("stop_alarm"),
                    textColor: .white,
                    systemImageName: "stop.circle"
                ),
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: snoozeButton.map { _ in .countdown }
            )
        }
        // AlarmKit expects a countdown presentation whenever an alarm can enter the
        // countdown state, which only the snooze button does.
        let countdown = snoozeMinutes.map { _ in
            AlarmPresentation.Countdown(title: localized("alarm_snoozing_title"))
        }
        return AlarmPresentation(alert: alert, countdown: countdown)
    }

    /// Maps `Calendar`'s 1-based weekday (1 = Sunday) onto `Locale.Weekday`.
    private static func localeWeekday(_ weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
    }
}
#endif
