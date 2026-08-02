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

    /// A registration that throws must leave nothing behind that says an alarm is set.
    /// The summary is persisted while the failure message is not, so publishing it
    /// before registration succeeded made the next launch show a green "alarm
    /// scheduled" state for an alarm the system had never accepted.
    func testFailedRegistrationLeavesNoScheduledAlarmEvenAfterRelaunch() async throws {
        let spy = SchedulerSpy()
        spy.scheduleFailure = TestError.registrationRejected
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()

        XCTAssertFalse(viewModel.hasScheduledAlarm)
        XCTAssertNil(viewModel.scheduledAlarmSummary)

        let relaunched = AlarmViewModel(
            routeWeatherService: MockRouteWeatherService(),
            notificationScheduler: spy,
            settingsStorage: storage,
            autoRefreshDebounce: .milliseconds(80)
        )
        XCTAssertFalse(relaunched.hasScheduledAlarm)
    }

    /// The registered alarm repeats weekly with whatever the rain check said when it
    /// ran, so opening the app has to re-decide it once the answer is old enough.
    func testOpeningTheAppRedecidesAnArmedAlarmOnlyOnceItsRainCheckHasAgedOut() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()
        XCTAssertEqual(spy.scheduleCalls.count, 1)

        // Fresh decision: opening the app must not refetch or re-register anything.
        await viewModel.refreshScheduledAlarmIfWeatherIsStale()
        XCTAssertEqual(spy.scheduleCalls.count, 1)

        // Age the stored decision past its lifetime, the way an overnight gap would.
        storage.set(Date().addingTimeInterval(-5 * 60 * 60), forKey: "lastWeatherEvaluationAt")
        let relaunched = AlarmViewModel(
            routeWeatherService: MockRouteWeatherService(),
            notificationScheduler: spy,
            settingsStorage: storage,
            autoRefreshDebounce: .milliseconds(80)
        )
        XCTAssertTrue(relaunched.hasScheduledAlarm)

        await relaunched.refreshScheduledAlarmIfWeatherIsStale()
        XCTAssertEqual(spy.scheduleCalls.count, 2)
    }

    /// The refresh runs unprompted, so a failure must not replace the status line of an
    /// alarm that is still correctly armed from the previous run.
    func testAStaleRefreshThatFailsKeepsTheAlarmAndItsStatusMessage() async throws {
        let spy = SchedulerSpy()
        let viewModel = makeViewModel(spy: spy)

        await viewModel.evaluateRouteAndScheduleAlarm()
        let armedStatus = viewModel.statusMessage

        storage.set(Date().addingTimeInterval(-5 * 60 * 60), forKey: "lastWeatherEvaluationAt")
        let relaunched = AlarmViewModel(
            routeWeatherService: MockRouteWeatherService(),
            notificationScheduler: spy,
            settingsStorage: storage,
            autoRefreshDebounce: .milliseconds(80)
        )
        let restoredStatus = relaunched.statusMessage
        spy.scheduleFailure = TestError.registrationRejected

        await relaunched.refreshScheduledAlarmIfWeatherIsStale()

        XCTAssertTrue(relaunched.hasScheduledAlarm)
        XCTAssertEqual(relaunched.statusMessage, restoredStatus)
        XCTAssertFalse(armedStatus.isEmpty)
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

private enum TestError: Error {
    case registrationRejected
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
    private var storedScheduleFailure: Error?

    /// Set to make the next registration throw, standing in for AlarmKit or
    /// `UNUserNotificationCenter` refusing the alarm.
    var scheduleFailure: Error? {
        get { lock.withLock { storedScheduleFailure } }
        set { lock.withLock { storedScheduleFailure = newValue } }
    }

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
        if let failure = scheduleFailure {
            throw failure
        }

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
