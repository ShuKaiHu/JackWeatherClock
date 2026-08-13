package com.shukaihu.rainyclock.model

import com.shukaihu.rainyclock.logic.AlarmTimeCalculator
import java.time.Duration
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlinx.serialization.Serializable

/**
 * Port of the iOS `ScheduledAlarmSummary`. Instants are persisted as epoch
 * milliseconds so the JSON stays portable and additive.
 */
@Serializable
data class ScheduledAlarmSummary(
    val normalAlarmEpochMillis: Long,
    val scheduledAlarmEpochMillis: Long,
    val weatherRefreshEpochMillis: Long,
    val exceedsRainThreshold: Boolean,
    val leadTimeMinutes: Int,
    val rainProbabilityThreshold: Double,
    val maximumPrecipitationProbability: Double,
    /** When the rain decision behind this summary was made; 0 = unknown. */
    val checkedAtEpochMillis: Long = 0
) {
    val normalAlarmDate: Instant get() = Instant.ofEpochMilli(normalAlarmEpochMillis)
    val scheduledAlarmDate: Instant get() = Instant.ofEpochMilli(scheduledAlarmEpochMillis)
    val weatherRefreshDate: Instant get() = Instant.ofEpochMilli(weatherRefreshEpochMillis)

    /**
     * Returns the summary with past dates advanced to their next weekly
     * occurrence, so a summary reloaded after relaunch still describes the
     * upcoming ring.
     */
    fun rollingForward(
        selectedWeekdays: Set<Int>,
        now: Instant = Instant.now(),
        zone: ZoneId = ZoneId.systemDefault()
    ): ScheduledAlarmSummary {
        val weekdays = selectedWeekdays.ifEmpty { CommuteAlarmSettings.ALL_WEEKDAYS }
        return copy(
            scheduledAlarmEpochMillis = nextOccurrence(
                scheduledAlarmDate,
                shiftedWeekdays(weekdays, from = normalAlarmDate, to = scheduledAlarmDate, zone = zone),
                now,
                zone
            ).toEpochMilli(),
            weatherRefreshEpochMillis = nextOccurrence(
                weatherRefreshDate,
                shiftedWeekdays(weekdays, from = normalAlarmDate, to = weatherRefreshDate, zone = zone),
                now,
                zone
            ).toEpochMilli(),
            normalAlarmEpochMillis = nextOccurrence(normalAlarmDate, weekdays, now, zone).toEpochMilli()
        )
    }

    companion object {
        fun of(
            normalAlarmDate: Instant,
            scheduledAlarmDate: Instant,
            weatherRefreshDate: Instant,
            exceedsRainThreshold: Boolean,
            leadTimeMinutes: Int,
            rainProbabilityThreshold: Double,
            maximumPrecipitationProbability: Double
        ): ScheduledAlarmSummary = ScheduledAlarmSummary(
            normalAlarmEpochMillis = normalAlarmDate.toEpochMilli(),
            scheduledAlarmEpochMillis = scheduledAlarmDate.toEpochMilli(),
            weatherRefreshEpochMillis = weatherRefreshDate.toEpochMilli(),
            exceedsRainThreshold = exceedsRainThreshold,
            leadTimeMinutes = leadTimeMinutes,
            rainProbabilityThreshold = rainProbabilityThreshold,
            maximumPrecipitationProbability = maximumPrecipitationProbability
        )

        /**
         * A ring that sits on an earlier day than the normal alarm (rain lead
         * time crossing midnight) rings on every selected weekday shifted by
         * that delta.
         */
        private fun shiftedWeekdays(
            weekdays: Set<Int>,
            from: Instant,
            to: Instant,
            zone: ZoneId
        ): Set<Int> {
            val fromDay = from.atZone(zone).toLocalDate()
            val toDay = to.atZone(zone).toLocalDate()
            val dayShift = Duration.between(fromDay.atStartOfDay(zone), toDay.atStartOfDay(zone)).toDays().toInt()
            if (dayShift == 0) return weekdays
            return weekdays.map { AlarmTimeCalculator.shiftedWeekday(it, dayShift) }.toSet()
        }

        private fun nextOccurrence(
            date: Instant,
            weekdays: Set<Int>,
            now: Instant,
            zone: ZoneId
        ): Instant {
            if (!date.isBefore(now)) return date

            val time = date.atZone(zone).toLocalTime()
            val todayStart = now.atZone(zone).toLocalDate()
            for (dayOffset in 0..7) {
                val day = todayStart.plusDays(dayOffset.toLong())
                val candidate: ZonedDateTime = day.atTime(LocalTime.of(time.hour, time.minute, time.second)).atZone(zone)
                if (candidate.toInstant().isAfter(now) &&
                    weekdays.contains(AlarmTimeCalculator.sundayBasedWeekday(candidate))
                ) {
                    return candidate.toInstant()
                }
            }
            return date
        }
    }
}
