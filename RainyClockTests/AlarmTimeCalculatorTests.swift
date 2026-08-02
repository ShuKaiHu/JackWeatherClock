import XCTest
@testable import RainyClock

final class AlarmTimeCalculatorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    /// Kept from the five tests that used to guard the unshipped `nextAlarmDate`:
    /// the invariant is real, it just belongs to the entry point the app calls.
    func testTheShippedCalculatorNeverSchedulesAnAlarmInThePast() {
        let now = date(year: 2026, month: 5, day: 17, hour: 7, minute: 15)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        for shouldApplyLeadTime in [true, false] {
            let summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
                alarmTime: alarmTime,
                leadTimeMinutes: 30,
                shouldApplyLeadTime: shouldApplyLeadTime,
                rainProbabilityThreshold: 0.5,
                maximumPrecipitationProbability: 0.8,
                now: now,
                calendar: calendar
            )

            XCTAssertGreaterThan(summary.scheduledAlarmDate, now)
            XCTAssertGreaterThan(summary.weatherRefreshDate, now)
        }
    }

    func testWeatherCheckUsesTodayWhenLeadTimeIsStillAhead() {
        let now = date(year: 2026, month: 5, day: 17, hour: 6, minute: 45)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.2,
            selectedWeekdays: [1],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 30))
        XCTAssertEqual(summary.weatherRefreshDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 0))
    }

    func testWeatherCheckRollsToNextSelectedWeekdayWhenLeadTimeAlreadyPassed() {
        let now = date(year: 2026, month: 5, day: 17, hour: 7, minute: 15)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.2,
            selectedWeekdays: [1],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 24, hour: 7, minute: 30))
        XCTAssertEqual(summary.weatherRefreshDate, date(year: 2026, month: 5, day: 24, hour: 7, minute: 0))
    }

    func testRouteWeatherThresholdUsesGreaterThanOrEqual() {
        let snapshot = RouteWeatherSnapshot(
            checkedAt: date(year: 2026, month: 5, day: 17, hour: 6, minute: 0),
            forecastAt: date(year: 2026, month: 5, day: 17, hour: 7, minute: 30),
            segments: [
                RouteWeatherSegment(name: "Segment A", condition: .cloudy, precipitationProbability: 0.49),
                RouteWeatherSegment(name: "Segment B", condition: .rain, precipitationProbability: 0.5)
            ]
        )

        XCTAssertTrue(snapshot.exceedsRainThreshold(0.5))
        XCTAssertEqual(snapshot.maximumPrecipitationProbability, 0.5)
    }

    func testScheduledSummaryRollsForwardToNextSelectedWeekday() {
        // Monday 2026-07-20 07:30, weekdays Mon-Fri; reloaded Wednesday noon.
        let normal = date(year: 2026, month: 7, day: 20, hour: 7, minute: 30)
        let summary = ScheduledAlarmSummary(
            normalAlarmDate: normal,
            scheduledAlarmDate: normal,
            weatherRefreshDate: date(year: 2026, month: 7, day: 20, hour: 7, minute: 0),
            exceedsRainThreshold: false,
            leadTimeMinutes: 0,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.1
        )
        let now = date(year: 2026, month: 7, day: 22, hour: 12, minute: 0)

        let rolled = summary.rollingForward(selectedWeekdays: [2, 3, 4, 5, 6], now: now, calendar: calendar)

        XCTAssertEqual(rolled.normalAlarmDate, date(year: 2026, month: 7, day: 23, hour: 7, minute: 30))
        XCTAssertEqual(rolled.scheduledAlarmDate, date(year: 2026, month: 7, day: 23, hour: 7, minute: 30))
        XCTAssertEqual(rolled.weatherRefreshDate, date(year: 2026, month: 7, day: 23, hour: 7, minute: 0))
    }

    func testScheduledSummaryRollForwardKeepsMidnightCrossingDayShift() {
        // Monday-only alarm at 00:20 whose rain lead time moved the ring to Sunday 23:50.
        let summary = ScheduledAlarmSummary(
            normalAlarmDate: date(year: 2026, month: 7, day: 20, hour: 0, minute: 20),
            scheduledAlarmDate: date(year: 2026, month: 7, day: 19, hour: 23, minute: 50),
            weatherRefreshDate: date(year: 2026, month: 7, day: 19, hour: 23, minute: 50),
            exceedsRainThreshold: true,
            leadTimeMinutes: 30,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.8
        )
        let now = date(year: 2026, month: 7, day: 22, hour: 12, minute: 0)

        let rolled = summary.rollingForward(selectedWeekdays: [2], now: now, calendar: calendar)

        XCTAssertEqual(rolled.normalAlarmDate, date(year: 2026, month: 7, day: 27, hour: 0, minute: 20))
        XCTAssertEqual(rolled.scheduledAlarmDate, date(year: 2026, month: 7, day: 26, hour: 23, minute: 50))
        XCTAssertEqual(rolled.weatherRefreshDate, date(year: 2026, month: 7, day: 26, hour: 23, minute: 50))
    }

    func testScheduledSummaryWithFutureDatesStaysUnchanged() {
        let summary = ScheduledAlarmSummary(
            normalAlarmDate: date(year: 2026, month: 7, day: 24, hour: 7, minute: 30),
            scheduledAlarmDate: date(year: 2026, month: 7, day: 24, hour: 7, minute: 30),
            weatherRefreshDate: date(year: 2026, month: 7, day: 24, hour: 7, minute: 0),
            exceedsRainThreshold: false,
            leadTimeMinutes: 0,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.1
        )
        let now = date(year: 2026, month: 7, day: 22, hour: 12, minute: 0)

        let rolled = summary.rollingForward(selectedWeekdays: [2, 3, 4, 5, 6], now: now, calendar: calendar)

        XCTAssertEqual(rolled, summary)
    }

    func testScheduleFingerprintIgnoresAlarmDateComponent() {
        var settings = CommuteAlarmSettings()
        settings.homeAddress = "台北車站"
        settings.workAddress = "台北101"
        settings.alarmTime = date(year: 2026, month: 7, day: 20, hour: 7, minute: 30)

        var sameTimeOtherDay = settings
        sameTimeOtherDay.alarmTime = date(year: 2026, month: 8, day: 3, hour: 7, minute: 30)

        XCTAssertEqual(
            settings.scheduleFingerprint(calendar: calendar),
            sameTimeOtherDay.scheduleFingerprint(calendar: calendar)
        )
    }

    func testScheduleFingerprintChangesWithScheduleRelevantSettings() {
        var settings = CommuteAlarmSettings()
        settings.homeAddress = "台北車站"
        settings.workAddress = "台北101"
        settings.alarmTime = date(year: 2026, month: 7, day: 20, hour: 7, minute: 30)
        let baseline = settings.scheduleFingerprint(calendar: calendar)

        var changedLeadTime = settings
        changedLeadTime.rainLeadTimeMinutes += 5
        XCTAssertNotEqual(changedLeadTime.scheduleFingerprint(calendar: calendar), baseline)

        var changedAddress = settings
        changedAddress.homeAddress = "板橋車站"
        XCTAssertNotEqual(changedAddress.scheduleFingerprint(calendar: calendar), baseline)

        var changedTime = settings
        changedTime.alarmTime = date(year: 2026, month: 7, day: 20, hour: 8, minute: 0)
        XCTAssertNotEqual(changedTime.scheduleFingerprint(calendar: calendar), baseline)

        var changedWeekdays = settings
        changedWeekdays.selectedWeekdays = [2, 3, 4]
        XCTAssertNotEqual(changedWeekdays.scheduleFingerprint(calendar: calendar), baseline)

        var changedSound = settings
        changedSound.alarmSound = .morningBell
        XCTAssertNotEqual(changedSound.scheduleFingerprint(calendar: calendar), baseline)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
