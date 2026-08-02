import Foundation

enum AlarmTimeCalculator {
    /// Moves a `Calendar` weekday (1 = Sunday ... 7 = Saturday) by whole days,
    /// wrapping around the week in either direction.
    ///
    /// Both schedulers and the scheduled-alarm summary need this: a rain lead time
    /// that crosses midnight puts the ring on the previous day, so every selected
    /// weekday shifts with it.
    static func shiftedWeekday(_ weekday: Int, byDays dayShift: Int) -> Int {
        ((weekday - 1 + dayShift) % 7 + 7) % 7 + 1
    }

    static func nextAlarmDateForWeatherCheck(
        alarmTime: Date,
        leadTimeMinutes: Int,
        shouldApplyLeadTime: Bool,
        rainProbabilityThreshold: Double,
        maximumPrecipitationProbability: Double,
        selectedWeekdays: Set<Int> = CommuteAlarmSettings.allWeekdays,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ScheduledAlarmSummary {
        let timeComponents = calendar.dateComponents([.hour, .minute], from: alarmTime)
        let selectedWeekdays = selectedWeekdays.isEmpty ? CommuteAlarmSettings.allWeekdays : selectedWeekdays
        let normalAlarmDate = nextDate(
            hour: timeComponents.hour ?? 7,
            minute: timeComponents.minute ?? 30,
            selectedWeekdays: selectedWeekdays,
            after: now,
            calendar: calendar
        ) { candidate in
            let weatherRefreshDate = calendar.date(byAdding: .minute, value: -leadTimeMinutes, to: candidate) ?? candidate
            return weatherRefreshDate > now
        }

        let weatherRefreshDate = calendar.date(byAdding: .minute, value: -leadTimeMinutes, to: normalAlarmDate) ?? normalAlarmDate
        let scheduledAlarmDate = shouldApplyLeadTime
            ? weatherRefreshDate
            : normalAlarmDate

        return ScheduledAlarmSummary(
            normalAlarmDate: normalAlarmDate,
            scheduledAlarmDate: scheduledAlarmDate,
            weatherRefreshDate: weatherRefreshDate,
            exceedsRainThreshold: shouldApplyLeadTime,
            leadTimeMinutes: shouldApplyLeadTime ? leadTimeMinutes : 0,
            rainProbabilityThreshold: rainProbabilityThreshold,
            maximumPrecipitationProbability: maximumPrecipitationProbability
        )
    }

    private static func nextDate(
        hour: Int,
        minute: Int,
        selectedWeekdays: Set<Int>,
        after now: Date,
        calendar: Calendar
    ) -> Date {
        nextDate(
            hour: hour,
            minute: minute,
            selectedWeekdays: selectedWeekdays,
            after: now,
            calendar: calendar
        ) { candidate in
            candidate > now
        }
    }

    private static func nextDate(
        hour: Int,
        minute: Int,
        selectedWeekdays: Set<Int>,
        after now: Date,
        calendar: Calendar,
        isValidCandidate: (Date) -> Bool
    ) -> Date {
        let todayStart = calendar.startOfDay(for: now)

        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: todayStart),
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
                continue
            }

            guard isValidCandidate(candidate) else {
                continue
            }

            if selectedWeekdays.contains(calendar.component(.weekday, from: candidate)) {
                return candidate
            }
        }

        return now
    }
}
