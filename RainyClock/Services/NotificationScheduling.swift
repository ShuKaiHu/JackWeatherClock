import Foundation
import OSLog
import UserNotifications

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleAlarm(
        at date: Date,
        normalAlarmDate: Date,
        weekdays: Set<Int>,
        sound: CommuteAlarmSettings.AlarmSound,
        title: String,
        body: String
    ) async throws
}

/// Serializes every pending-notification mutation: schedule/acknowledge/re-arm run to
/// completion one at a time, so concurrent entry points (the notification delegate and
/// the scenePhase activation handler) cannot interleave their remove/add sequences.
private actor AlarmRegistrationQueue {
    private var lastTask: Task<Void, Never>?

    func run<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let previous = lastTask
        let task = Task<T, Error> {
            await previous?.value
            return try await operation()
        }
        lastTask = Task { _ = try? await task.value }
        return try await task.value
    }
}

struct LocalNotificationScheduler: NotificationScheduling {
    static let categoryIdentifier = "RAINY_CLOCK_ALARM"
    static let stopActionIdentifier = "RAINY_CLOCK_STOP"
    private static let identifierPrefix = "commute-rain-alarm"
    private static let followUpIntervalSeconds = 5 * 60
    private static let maximumFollowUpCount = 10
    private static let pendingNotificationLimit = 64
    private static let storedPlanKey = "scheduledAlarmPlan"
    private static let rearmAfterKey = "scheduledAlarmRearmAfter"
    private static let registrationQueue = AlarmRegistrationQueue()

    static func registerNotificationCategories() {
        // Stop stays a background action (no .foreground): it must silence the alarm
        // even when the user cannot or will not unlock the device. Tapping the
        // notification body still opens the app and acknowledges the alarm.
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
        normalAlarmDate: Date,
        weekdays: Set<Int>,
        sound: CommuteAlarmSettings.AlarmSound,
        title: String,
        body: String
    ) async throws {
        let selectedWeekdays = weekdays.isEmpty ? CommuteAlarmSettings.allWeekdays : weekdays
        let plan = StoredAlarmPlan(
            scheduledAt: Date(),
            ringDate: date,
            normalAlarmDate: normalAlarmDate,
            weekdays: selectedWeekdays,
            soundRawValue: sound.rawValue,
            title: title,
            body: body
        )

        try await Self.registrationQueue.run {
            Self.storePlan(plan)
            try await Self.register(plan: plan, silencingWindowEndingAt: nil)
        }
    }

    /// Silences the remainder of the ring session the tapped notification belongs to,
    /// while keeping the weekly schedule armed. The silence window is anchored to the
    /// notification's delivery time, so tapping yesterday's stale banner cannot cancel
    /// an upcoming ring.
    func acknowledgeAlarm(notificationDeliveredAt deliveredAt: Date) async {
        try? await Self.registrationQueue.run {
            let center = UNUserNotificationCenter.current()
            let delivered = await center.deliveredNotifications()
            let deliveredAlarmIdentifiers = delivered
                .map(\.request.identifier)
                .filter { $0.hasPrefix(Self.identifierPrefix) }
            center.removeDeliveredNotifications(withIdentifiers: deliveredAlarmIdentifiers)

            guard let plan = Self.loadPlan() else {
                await Self.silenceLegacyRequests(center: center, deliveredAt: deliveredAt)
                return
            }

            // A notification delivered before the current plan existed belongs to an
            // older ring session; silencing based on it would suppress the ring the
            // user just scheduled.
            guard deliveredAt >= plan.scheduledAt else {
                return
            }

            let window = Self.followUpWindow(weekdayCount: plan.weekdays.count)
            let windowEnd = deliveredAt.addingTimeInterval(window)
            guard windowEnd > Date() else {
                return
            }

            try await Self.register(plan: plan, silencingWindowEndingAt: windowEnd)
        }
    }

    /// Converts any fallback triggers left behind by acknowledgeAlarm back into
    /// precise weekly calendar triggers, once their silence window has passed.
    /// Called on app activation.
    func rearmAlarmsIfNeeded() async {
        try? await Self.registrationQueue.run {
            guard let rearmAfter = Self.rearmAfterDate(),
                  Date() >= rearmAfter,
                  let plan = Self.loadPlan() else {
                return
            }

            try await Self.register(plan: plan, silencingWindowEndingAt: nil)
        }
    }

    private static func register(plan: StoredAlarmPlan, silencingWindowEndingAt windowEnd: Date?) async throws {
        let center = UNUserNotificationCenter.current()
        await removeAllPendingAlarmRequests(center: center)

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = notificationSound(for: CommuteAlarmSettings.AlarmSound(rawValue: plan.soundRawValue) ?? .rainyClock)
        content.categoryIdentifier = categoryIdentifier

        // The ring date may sit on an earlier day than the normal alarm (rain lead time
        // crossing midnight), so every selected weekday shifts by the same day delta.
        let calendar = Calendar.current
        let dayShift = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: plan.normalAlarmDate),
            to: calendar.startOfDay(for: plan.ringDate)
        ).day ?? 0
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: plan.ringDate)
        let offsets = ringOffsets(weekdayCount: plan.weekdays.count)
        var silencedTrigger = false

        for weekday in plan.weekdays.sorted() {
            for offset in offsets {
                let components = normalizedComponents(
                    weekday: weekday,
                    dayShift: dayShift,
                    timeComponents: timeComponents,
                    offset: offset
                )
                let repeatingTrigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                var trigger: UNNotificationTrigger = repeatingTrigger

                if let windowEnd,
                   let nextFireDate = repeatingTrigger.nextTriggerDate(),
                   nextFireDate < windowEnd {
                    // Re-registering this repeating trigger would ring again inside the
                    // acknowledged window. Fall back to a weekly time-interval trigger
                    // anchored at next week's occurrence — it keeps repeating (with
                    // minor drift) even if the app is never activated again, and
                    // rearmAlarmsIfNeeded restores the precise calendar version.
                    silencedTrigger = true
                    guard let nextWeekFireDate = calendar.date(byAdding: .day, value: 7, to: nextFireDate),
                          nextWeekFireDate.timeIntervalSinceNow > 60 else {
                        continue
                    }
                    trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: nextWeekFireDate.timeIntervalSinceNow,
                        repeats: true
                    )
                }

                let request = UNNotificationRequest(
                    identifier: alarmIdentifier(for: weekday, offset: offset),
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
            }
        }

        if silencedTrigger, let windowEnd {
            setRearmFlag(after: windowEnd)
        } else {
            clearRearmFlag()
        }
    }

    /// Legacy installs (upgraded with pending requests from the old two-ring design but
    /// no stored plan): silence only the requests firing inside the old ring window and
    /// leave the rest of the weekly schedule untouched.
    private static func silenceLegacyRequests(center: UNUserNotificationCenter, deliveredAt: Date) async {
        let windowEnd = deliveredAt.addingTimeInterval(120)
        guard windowEnd > Date() else {
            return
        }

        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
            .filter { request in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let nextFireDate = trigger.nextTriggerDate() else {
                    return false
                }
                return nextFireDate < windowEnd
            }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// The main ring plus follow-ups every 5 minutes until acknowledged. iOS keeps at
    /// most 64 pending notification requests per app, so the follow-up count shrinks
    /// when many weekdays are selected (all 7 days -> 8 follow-ups instead of 10).
    private static func ringOffsets(weekdayCount: Int) -> [Int] {
        let perWeekdayLimit = max(2, pendingNotificationLimit / max(1, weekdayCount))
        let followUpCount = min(maximumFollowUpCount, perWeekdayLimit - 1)
        return [0] + (1...followUpCount).map { $0 * followUpIntervalSeconds }
    }

    private static func followUpWindow(weekdayCount: Int) -> TimeInterval {
        TimeInterval((ringOffsets(weekdayCount: weekdayCount).last ?? 0) + 60)
    }

    private static func notificationSound(for sound: CommuteAlarmSettings.AlarmSound) -> UNNotificationSound {
        switch sound {
        case .systemDefault:
            .default
        default:
            UNNotificationSound(named: UNNotificationSoundName(sound.fileName))
        }
    }

    private static func alarmIdentifier(for weekday: Int, offset: Int) -> String {
        "\(identifierPrefix)-\(weekday)-\(offset)"
    }

    private static func removeAllPendingAlarmRequests(center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func normalizedComponents(
        weekday: Int,
        dayShift: Int,
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
        let normalizedWeekday = ((weekday - 1 + dayShift + dayOffset) % 7 + 7) % 7 + 1

        var components = DateComponents()
        components.weekday = normalizedWeekday
        components.hour = secondsInDay / 3_600
        components.minute = (secondsInDay % 3_600) / 60
        components.second = secondsInDay % 60
        return components
    }

    private struct StoredAlarmPlan: Codable, Sendable {
        var scheduledAt: Date
        var ringDate: Date
        var normalAlarmDate: Date
        var weekdays: Set<Int>
        var soundRawValue: String
        var title: String
        var body: String
    }

    private static func storePlan(_ plan: StoredAlarmPlan) {
        guard let data = try? JSONEncoder().encode(plan) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storedPlanKey)
    }

    private static func loadPlan() -> StoredAlarmPlan? {
        guard let data = UserDefaults.standard.data(forKey: storedPlanKey) else {
            return nil
        }

        return try? JSONDecoder().decode(StoredAlarmPlan.self, from: data)
    }

    private static func setRearmFlag(after date: Date) {
        UserDefaults.standard.set(date, forKey: rearmAfterKey)
    }

    private static func clearRearmFlag() {
        UserDefaults.standard.removeObject(forKey: rearmAfterKey)
    }

    private static func rearmAfterDate() -> Date? {
        UserDefaults.standard.object(forKey: rearmAfterKey) as? Date
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

        guard response.notification.request.content.categoryIdentifier == LocalNotificationScheduler.categoryIdentifier else {
            return
        }

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier, LocalNotificationScheduler.stopActionIdentifier:
            // Tapping the notification (opens the app) and the Stop action both
            // acknowledge the alarm: the rest of this ring session goes silent while
            // the weekly schedule stays armed.
            await LocalNotificationScheduler().acknowledgeAlarm(
                notificationDeliveredAt: response.notification.date
            )

        default:
            return
        }
    }
}
