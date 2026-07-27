import XCTest
@testable import RainyClock

/// Covers the pieces 1.6.3 introduced that carry real branching: the weekday shift
/// both schedulers rely on, the snooze settings, and the migration paths for data
/// written by earlier builds.
final class AlarmSchedulingSettingsTests: XCTestCase {

    // MARK: - Weekday shift

    func testShiftedWeekdayIsIdentityWithoutAShift() {
        for weekday in 1...7 {
            XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(weekday, byDays: 0), weekday)
        }
    }

    func testShiftedWeekdayWrapsBackwardsAcrossTheWeekStart() {
        // Sunday minus a day is Saturday: a rain lead time that crosses midnight
        // moves the ring onto the previous weekday.
        XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(1, byDays: -1), 7)
        XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(2, byDays: -1), 1)
    }

    func testShiftedWeekdayWrapsForwardsPastSaturday() {
        XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(7, byDays: 1), 1)
        XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(6, byDays: 2), 1)
    }

    func testShiftedWeekdayHandlesShiftsLargerThanAWeek() {
        for weekday in 1...7 {
            XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(weekday, byDays: 7), weekday)
            XCTAssertEqual(AlarmTimeCalculator.shiftedWeekday(weekday, byDays: -14), weekday)
            XCTAssertEqual(
                AlarmTimeCalculator.shiftedWeekday(weekday, byDays: 9),
                AlarmTimeCalculator.shiftedWeekday(weekday, byDays: 2)
            )
        }
    }

    func testShiftedWeekdayIsABijectionSoSelectedDaysCannotCollapse() {
        // Every scheduler maps a Set of weekdays through this; a collision would
        // silently drop a day the user picked.
        for dayShift in -7...7 {
            let shifted = Set((1...7).map { AlarmTimeCalculator.shiftedWeekday($0, byDays: dayShift) })
            XCTAssertEqual(shifted, CommuteAlarmSettings.allWeekdays)
        }
    }

    // MARK: - Snooze settings

    func testSnoozeDefaultsMatchThePreviousFixedBehaviour() {
        let settings = CommuteAlarmSettings()

        XCTAssertTrue(settings.isSnoozeEnabled)
        XCTAssertEqual(settings.snoozeDurationMinutes, 5)
        XCTAssertEqual(settings.effectiveSnoozeMinutes, 5)
    }

    func testDisablingSnoozeRemovesTheInterval() {
        var settings = CommuteAlarmSettings()
        settings.isSnoozeEnabled = false

        XCTAssertNil(settings.effectiveSnoozeMinutes)
    }

    func testSettingsStoredBeforeSnoozeExistedKeepTheOldBehaviour() throws {
        // A 1.6.2 payload: no snooze keys at all.
        let stored = #"{"homeAddress":"A","workAddress":"B","rainLeadTimeMinutes":30}"#
        let settings = try JSONDecoder().decode(CommuteAlarmSettings.self, from: Data(stored.utf8))

        XCTAssertTrue(settings.isSnoozeEnabled)
        XCTAssertEqual(settings.snoozeDurationMinutes, 5)
    }

    func testDecodedSnoozeDurationIsClampedIntoRange() throws {
        let tooLong = #"{"snoozeDurationMinutes":999}"#
        let tooShort = #"{"snoozeDurationMinutes":-3}"#

        XCTAssertEqual(
            try JSONDecoder().decode(CommuteAlarmSettings.self, from: Data(tooLong.utf8)).snoozeDurationMinutes,
            CommuteAlarmSettings.snoozeDurationRange.upperBound
        )
        XCTAssertEqual(
            try JSONDecoder().decode(CommuteAlarmSettings.self, from: Data(tooShort.utf8)).snoozeDurationMinutes,
            CommuteAlarmSettings.snoozeDurationRange.lowerBound
        )
    }

    // MARK: - Alarm sound

    func testSystemAlarmToneIsOnlyOfferedWhereAlarmKitCanPlayIt() {
        let selectable = CommuteAlarmSettings.AlarmSound.selectableCases

        if #available(iOS 26.0, *) {
            XCTAssertTrue(selectable.contains(.systemDefault))
        } else {
            XCTAssertFalse(selectable.contains(.systemDefault))
        }
        XCTAssertTrue(selectable.contains(.rainyClock))
        XCTAssertEqual(Set(selectable).count, selectable.count)
    }

    func testOnlyTheSystemToneSkipsTheBundledFile() {
        for sound in CommuteAlarmSettings.AlarmSound.selectableCases where sound != .systemDefault {
            XCTAssertFalse(sound.usesSystemAlarmTone, "\(sound.rawValue) should name a bundled file")
        }
        XCTAssertTrue(CommuteAlarmSettings.AlarmSound.systemDefault.usesSystemAlarmTone)
    }

    func testStoredSoundTheSystemCannotOfferFallsBack() throws {
        let stored = #"{"alarmSound":"systemDefault"}"#
        let settings = try JSONDecoder().decode(CommuteAlarmSettings.self, from: Data(stored.utf8))

        if #available(iOS 26.0, *) {
            XCTAssertEqual(settings.alarmSound, .systemDefault)
        } else {
            XCTAssertEqual(settings.alarmSound, .rainyClock)
        }
    }

    // MARK: - Schedule fingerprint

    func testFingerprintStoredBeforeSnoozeExistedStillDecodes() throws {
        // Regression guard: if this throws, the "settings changed — reschedule"
        // notice silently stops working for every upgraded install.
        let stored = """
        {"homeAddress":"A","workAddress":"B","commuteMode":"car","alarmHour":7,\
        "alarmMinute":30,"selectedWeekdays":[2,3,4,5,6],"rainLeadTimeMinutes":30,\
        "rainProbabilityThreshold":0.5,"alarmSoundRawValue":"rainyClock"}
        """
        let fingerprint = try JSONDecoder().decode(AlarmScheduleFingerprint.self, from: Data(stored.utf8))

        XCTAssertTrue(fingerprint.isSnoozeEnabled)
        XCTAssertEqual(fingerprint.snoozeDurationMinutes, 5)
    }

    func testUntouchedSettingsStillMatchAFingerprintStoredBeforeSnoozeExisted() throws {
        var settings = CommuteAlarmSettings()
        settings.homeAddress = "A"
        settings.workAddress = "B"
        settings.selectedWeekdays = [2, 3, 4, 5, 6]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        settings.alarmTime = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 7, minute: 30))!

        let stored = """
        {"homeAddress":"A","workAddress":"B","commuteMode":"car","alarmHour":7,\
        "alarmMinute":30,"selectedWeekdays":[2,3,4,5,6],"rainLeadTimeMinutes":30,\
        "rainProbabilityThreshold":0.5,"alarmSoundRawValue":"rainyClock"}
        """
        let legacyFingerprint = try JSONDecoder().decode(AlarmScheduleFingerprint.self, from: Data(stored.utf8))

        XCTAssertEqual(settings.scheduleFingerprint(calendar: calendar), legacyFingerprint)
    }

    func testChangingSnoozeSettingsChangesTheFingerprint() {
        var settings = CommuteAlarmSettings()
        let before = settings.scheduleFingerprint()

        settings.snoozeDurationMinutes = 12
        XCTAssertNotEqual(settings.scheduleFingerprint(), before)

        settings.snoozeDurationMinutes = 5
        settings.isSnoozeEnabled = false
        XCTAssertNotEqual(settings.scheduleFingerprint(), before)
    }
}
