import XCTest
@testable import RainyClock

final class AlarmTimeCalculatorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    func testNormalAlarmUsesTodayWhenTimeIsStillAhead() {
        let now = date(year: 2026, month: 5, day: 17, hour: 6, minute: 45)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDate(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.2,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 30))
        XCTAssertEqual(summary.scheduledAlarmDate, summary.normalAlarmDate)
        XCTAssertEqual(summary.weatherRefreshDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 0))
        XCTAssertEqual(summary.leadTimeMinutes, 0)
    }

    func testNormalAlarmRollsToTomorrowWhenTimeAlreadyPassed() {
        let now = date(year: 2026, month: 5, day: 17, hour: 8, minute: 0)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDate(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.2,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 18, hour: 7, minute: 30))
        XCTAssertEqual(summary.scheduledAlarmDate, summary.normalAlarmDate)
        XCTAssertEqual(summary.weatherRefreshDate, date(year: 2026, month: 5, day: 18, hour: 7, minute: 0))
    }

    func testNormalAlarmSkipsUnselectedWeekdays() {
        let now = date(year: 2026, month: 5, day: 17, hour: 6, minute: 45)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDate(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: false,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.2,
            selectedWeekdays: [2],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 18, hour: 7, minute: 30))
        XCTAssertEqual(summary.scheduledAlarmDate, summary.normalAlarmDate)
    }

    func testRainLeadTimeMovesScheduledAlarmEarlier() {
        let now = date(year: 2026, month: 5, day: 17, hour: 6, minute: 0)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDate(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: true,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.8,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.normalAlarmDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 30))
        XCTAssertEqual(summary.scheduledAlarmDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 0))
        XCTAssertEqual(summary.weatherRefreshDate, summary.scheduledAlarmDate)
        XCTAssertEqual(summary.leadTimeMinutes, 30)
    }

    func testRainLeadTimeDoesNotScheduleInThePast() {
        let now = date(year: 2026, month: 5, day: 17, hour: 7, minute: 15)
        let alarmTime = date(year: 2026, month: 5, day: 17, hour: 7, minute: 30)

        let summary = AlarmTimeCalculator.nextAlarmDate(
            alarmTime: alarmTime,
            leadTimeMinutes: 30,
            shouldApplyLeadTime: true,
            rainProbabilityThreshold: 0.5,
            maximumPrecipitationProbability: 0.8,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.weatherRefreshDate, date(year: 2026, month: 5, day: 17, hour: 7, minute: 0))
        XCTAssertEqual(summary.scheduledAlarmDate, now)
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
