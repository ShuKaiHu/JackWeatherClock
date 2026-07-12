import Foundation
import OSLog
import UserNotifications

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleAlarm(
        at date: Date,
        weekdays: Set<Int>,
        sound: CommuteAlarmSettings.AlarmSound,
        title: String,
        body: String
    ) async throws
}

struct LocalNotificationScheduler: NotificationScheduling {
    static let categoryIdentifier = "RAINY_CLOCK_ALARM"
    static let stopActionIdentifier = "RAINY_CLOCK_STOP"
    private static let ringOffsetsInSeconds = [0, 30]

    static func registerNotificationCategories() {
        let stopAction = UNNotificationAction(
            identifier: stopActionIdentifier,
            title: String(localized: "stop_alarm"),
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [stopAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func scheduleAlarm(
        at date: Date,
        weekdays: Set<Int>,
        sound: CommuteAlarmSettings.AlarmSound,
        title: String,
        body: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = notificationSound(for: sound)
        content.categoryIdentifier = Self.categoryIdentifier

        let identifiers = ["commute-rain-alarm"] + alarmIdentifiers(for: CommuteAlarmSettings.allWeekdays)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)

        let selectedWeekdays = weekdays.isEmpty ? CommuteAlarmSettings.allWeekdays : weekdays
        let timeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: date)

        for weekday in selectedWeekdays.sorted() {
            for offset in Self.ringOffsetsInSeconds {
                let components = normalizedComponents(
                    weekday: weekday,
                    timeComponents: timeComponents,
                    offset: offset
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: alarmIdentifier(for: weekday, offset: offset),
                    content: content,
                    trigger: trigger
                )
                try await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    private func notificationSound(for sound: CommuteAlarmSettings.AlarmSound) -> UNNotificationSound {
        switch sound {
        case .systemDefault:
            .default
        default:
            UNNotificationSound(named: UNNotificationSoundName(sound.fileName))
        }
    }

    private func alarmIdentifiers(for weekdays: Set<Int>) -> [String] {
        weekdays.flatMap { weekday in
            Self.ringOffsetsInSeconds.map { offset in
                alarmIdentifier(for: weekday, offset: offset)
            }
        }
    }

    private func alarmIdentifier(for weekday: Int, offset: Int) -> String {
        "commute-rain-alarm-\(weekday)-\(offset)"
    }

    private func normalizedComponents(
        weekday: Int,
        timeComponents: DateComponents,
        offset: Int
    ) -> DateComponents {
        let hour = timeComponents.hour ?? 0
        let minute = timeComponents.minute ?? 0
        let second = timeComponents.second ?? 0
        let secondsPerDay = 24 * 60 * 60
        let totalSeconds = hour * 60 * 60 + minute * 60 + second + offset
        let dayOffset = totalSeconds / secondsPerDay
        let secondsInDay = totalSeconds % secondsPerDay
        let normalizedWeekday = ((weekday - 1 + dayOffset) % 7) + 1

        var components = DateComponents()
        components.weekday = normalizedWeekday
        components.hour = secondsInDay / 3_600
        components.minute = (secondsInDay % 3_600) / 60
        components.second = secondsInDay % 60
        return components
    }
}

final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated(unsafe) static let shared = NotificationPresentationDelegate()
    private let logger = Logger(subsystem: "com.shukaihu.RainyClock", category: "Notifications")

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        logger.info("Received notification response action=\(response.actionIdentifier, privacy: .public) request=\(response.notification.request.identifier, privacy: .public)")

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
            return

        case LocalNotificationScheduler.stopActionIdentifier:
            center.removePendingNotificationRequests(
                withIdentifiers: LocalNotificationScheduler()
                    .alarmIdentifiersForCancellation()
            )
            center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])

        default:
            return
        }
    }
}

private extension LocalNotificationScheduler {
    func alarmIdentifiersForCancellation() -> [String] {
        alarmIdentifiers(for: CommuteAlarmSettings.allWeekdays)
    }
}
