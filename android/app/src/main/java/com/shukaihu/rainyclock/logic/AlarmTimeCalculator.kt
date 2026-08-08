package com.shukaihu.rainyclock.logic

import com.shukaihu.rainyclock.model.CommuteAlarmSettings
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Port of the iOS `AlarmTimeCalculator`. Weekdays use the iOS `Calendar`
 * numbering (1 = Sunday … 7 = Saturday); [sundayBasedWeekday] converts from
 * java.time's ISO numbering.
 */
object AlarmTimeCalculator {

    fun sundayBasedWeekday(dateTime: ZonedDateTime): Int =
        dateTime.dayOfWeek.value % 7 + 1

    /**
     * Moves a weekday (1 = Sunday … 7 = Saturday) by whole days, wrapping
     * around the week in either direction.
     */
    fun shiftedWeekday(weekday: Int, dayShift: Int): Int =
        ((weekday - 1 + dayShift) % 7 + 7) % 7 + 1

    /**
     * Picks the next alarm occurrence whose weather-refresh point is still in
     * the future, then applies the rain decision to it. Mirrors
     * `nextAlarmDateForWeatherCheck` on iOS.
     */
    fun nextAlarmDateForWeatherCheck(
        alarmHour: Int,
        alarmMinute: Int,
        leadTimeMinutes: Int,
        shouldApplyLeadTime: Boolean,
        rainProbabilityThreshold: Double,
        maximumPrecipitationProbability: Double,
        selectedWeekdays: Set<Int> = CommuteAlarmSettings.ALL_WEEKDAYS,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault()
    ): ScheduledAlarmSummary {
        val weekdays = selectedWeekdays.ifEmpty { CommuteAlarmSettings.ALL_WEEKDAYS }
        val normalAlarmDate = nextDate(alarmHour, alarmMinute, weekdays, now, zone) { candidate ->
            candidate.minusMinutes(leadTimeMinutes.toLong()).toInstant().isAfter(now)
        }

        val weatherRefreshDate = normalAlarmDate.minusSeconds(leadTimeMinutes * 60L)
        val scheduledAlarmDate = if (shouldApplyLeadTime) weatherRefreshDate else normalAlarmDate

        return ScheduledAlarmSummary.of(
            normalAlarmDate = normalAlarmDate,
            scheduledAlarmDate = scheduledAlarmDate,
            weatherRefreshDate = weatherRefreshDate,
            exceedsRainThreshold = shouldApplyLeadTime,
            leadTimeMinutes = if (shouldApplyLeadTime) leadTimeMinutes else 0,
            rainProbabilityThreshold = rainProbabilityThreshold,
            maximumPrecipitationProbability = maximumPrecipitationProbability
        )
    }

    private fun nextDate(
        hour: Int,
        minute: Int,
        selectedWeekdays: Set<Int>,
        now: Instant,
        zone: ZoneId,
        isValidCandidate: (ZonedDateTime) -> Boolean
    ): Instant {
        val todayStart = now.atZone(zone).toLocalDate()

        for (dayOffset in 0..7) {
            val day = todayStart.plusDays(dayOffset.toLong())
            val candidate = day.atTime(hour, minute).atZone(zone)
            if (!isValidCandidate(candidate)) continue
            if (selectedWeekdays.contains(sundayBasedWeekday(candidate))) {
                return candidate.toInstant()
            }
        }

        return now
    }
}
