import XCTest
@testable import RainyClock

/// Covers the 1.6.3 sync contract: parameter edits silently re-register the alarm,
/// address edits remove it until the user explicitly reschedules, and the alarm
/// that ends up registered always matches exactly one fingerprint.
@MainActor
final class AlarmViewModelSchedulingTests: XCTestCase {
    private var storage: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AlarmViewModelSchedulingTests-\(UUID().uuidString)"
        storage = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        storage.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeViewModel(spy: SchedulerSpy) -> AlarmViewModel {
        let viewModel = AlarmViewModel(
            routeWeatherService: MockRouteWeatherService(),
            notificationScheduler: spy,
            settingsStorage: storage,
            autoRefreshDebounce: .milliseconds(80)
        )
        viewModel.settings.homeAddress = "Home Street 1"
        viewModel.settings.workAddress = "Work Street 2"
        return viewModel
    }

    func testParameterChangeAutoRefreshesTheScheduledAlarm() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()
        XCTAssertEqual(spy.scheduleCalls.count, 1)
        XCTAssertTrue(viewModel.hasScheduledAlarm)

        viewModel.settings.snoozeDurationMinutes = 9

        try await waitUntil("auto refresh re-registered the alarm") {
            spy.scheduleCalls.count == 2
        }
        XCTAssertEqual(spy.scheduleCalls.last?.snoozeMinutes, 9)
        XCTAssertFalse(viewModel.isScheduleStale)
        XCTAssertEqual(spy.cancelCount, 0)
    }

    func testAddressChangeRemovesTheAlarmInsteadOfRefreshing() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()
        XCTAssertTrue(viewModel.hasScheduledAlarm)

        viewModel.settings.homeAddress = "Somewhere Completely Different 3"

        try await waitUntil("alarm removed after the address change") {
            spy.cancelCount >= 1 && !viewModel.hasScheduledAlarm
        }

        // No sneaky auto-reschedule afterwards: the button is the only way back.
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(spy.scheduleCalls.count, 1)
        XCTAssertFalse(viewModel.isScheduleStale)
    }

    func testRevertingAChangeBeforeTheDebounceFiresDoesNothing() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()
        XCTAssertEqual(spy.scheduleCalls.count, 1)

        let original = viewModel.settings.rainLeadTimeMinutes
        viewModel.settings.rainLeadTimeMinutes = original + 5
        viewModel.settings.rainLeadTimeMinutes = original

        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(spy.scheduleCalls.count, 1)
        XCTAssertFalse(viewModel.isScheduleStale)
    }

    func testParameterChangesDoNothingWhileNoAlarmIsScheduled() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        viewModel.settings.snoozeDurationMinutes = 3
        viewModel.settings.rainLeadTimeMinutes = 45

        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(spy.scheduleCalls.isEmpty)
        XCTAssertEqual(spy.cancelCount, 0)
    }

    private func waitUntil(
        _ what: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTFail("Timed out waiting until \(what)", file: file, line: line)
    }
}

private final class SchedulerSpy: NotificationScheduling, @unchecked Sendable {
    struct ScheduleCall {
        var date: Date
        var normalAlarmDate: Date
        var weekdays: Set<Int>
        var sound: CommuteAlarmSettings.AlarmSound
        var snoozeMinutes: Int?
    }

    private let lock = NSLock()
    private var storedScheduleCalls: [ScheduleCall] = []
    private var storedCancelCount = 0

    var scheduleCalls: [ScheduleCall] {
        lock.withLock { storedScheduleCalls }
    }

    var cancelCount: Int {
        lock.withLock { storedCancelCount }
    }

    func requestAuthorization() async throws -> Bool {
        true
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
        lock.withLock {
            storedScheduleCalls.append(
                ScheduleCall(
                    date: date,
                    normalAlarmDate: normalAlarmDate,
                    weekdays: weekdays,
                    sound: sound,
                    snoozeMinutes: snoozeMinutes
                )
            )
        }
    }

    func cancelScheduledAlarms() async {
        lock.withLock {
            storedCancelCount += 1
        }
    }
}
