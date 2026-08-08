package com.shukaihu.rainyclock

import com.shukaihu.rainyclock.logic.AlarmTimeCalculator
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmTimeCalculatorTest {

    private val zone: ZoneId = ZoneId.of("Asia/Taipei")

    /** Wednesday 2026-08-05 06:00 in Taipei. */
    private val now: Instant = ZonedDateTime.of(2026, 8, 5, 6, 0, 0, 0, zone).toInstant()

    @Test
    fun `weekday numbering is sunday based`() {
        val sunday = ZonedDateTime.of(2026, 8, 2, 12, 0, 0, 0, zone)
        assertEquals(1, AlarmTimeCalculator.sundayBasedWeekday(sunday))
        val saturday = ZonedDateTime.of(2026, 8, 8, 12, 0, 0, 0, zone)
        assertEquals(7, AlarmTimeCalculator.sundayBasedWeekday(saturday))
    }

    @Test
    fun `shifted weekday wraps in both directions`() {
        assertEquals(7, AlarmTimeCalculator.shiftedWeekday(1, -1))
        assertEquals(1, AlarmTimeCalculator.shiftedWeekday(7, 1))
        assertEquals(3, AlarmTimeCalculator.shiftedWeekday(3, 7))
        assertEquals(3, AlarmTimeCalculator.shiftedWeekday(3, -14))
    }

    @Test
    fun `next alarm falls on the same day when the check point is still ahead`() {
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 7,
            alarmMinute = 30,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = false,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.1,
            now = now,
            zone = zone
        )

        val expected = ZonedDateTime.of(2026, 8, 5, 7, 30, 0, 0, zone).toInstant()
        assertEquals(expected, summary.normalAlarmDate)
        assertEquals(expected, summary.scheduledAlarmDate)
        assertEquals(expected.minusSeconds(30 * 60), summary.weatherRefreshDate)
        assertEquals(0, summary.leadTimeMinutes)
    }

    @Test
    fun `alarm skips to the next day when the weather check point already passed`() {
        // 06:00 now, alarm 06:15 with a 30-minute lead: the 05:45 check point
        // is gone, so the alarm must move to tomorrow — never the past.
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 6,
            alarmMinute = 15,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = false,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.1,
            now = now,
            zone = zone
        )

        val expected = ZonedDateTime.of(2026, 8, 6, 6, 15, 0, 0, zone).toInstant()
        assertEquals(expected, summary.normalAlarmDate)
        assertTrue(summary.weatherRefreshDate.isAfter(now))
    }

    @Test
    fun `rain decision moves the ring to the weather check point`() {
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 7,
            alarmMinute = 30,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = true,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.8,
            now = now,
            zone = zone
        )

        assertEquals(summary.weatherRefreshDate, summary.scheduledAlarmDate)
        assertEquals(30, summary.leadTimeMinutes)
        assertTrue(summary.exceedsRainThreshold)
    }

    @Test
    fun `selected weekdays are honoured`() {
        // Only Saturdays (weekday 7). From Wednesday the next hit is 08-08.
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 7,
            alarmMinute = 30,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = false,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.1,
            selectedWeekdays = setOf(7),
            now = now,
            zone = zone
        )

        val expected = ZonedDateTime.of(2026, 8, 8, 7, 30, 0, 0, zone).toInstant()
        assertEquals(expected, summary.normalAlarmDate)
    }

    @Test
    fun `empty weekday selection means every day`() {
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 7,
            alarmMinute = 30,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = false,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.1,
            selectedWeekdays = emptySet(),
            now = now,
            zone = zone
        )

        val expected = ZonedDateTime.of(2026, 8, 5, 7, 30, 0, 0, zone).toInstant()
        assertEquals(expected, summary.normalAlarmDate)
    }

    @Test
    fun `lead time crossing midnight rings the previous day`() {
        // Alarm 00:10 with a 30-minute lead: the rainy ring lands at 23:40
        // the evening before.
        val summary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = 0,
            alarmMinute = 10,
            leadTimeMinutes = 30,
            shouldApplyLeadTime = true,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.9,
            now = now,
            zone = zone
        )

        val expectedNormal = ZonedDateTime.of(2026, 8, 6, 0, 10, 0, 0, zone).toInstant()
        val expectedRing = ZonedDateTime.of(2026, 8, 5, 23, 40, 0, 0, zone).toInstant()
        assertEquals(expectedNormal, summary.normalAlarmDate)
        assertEquals(expectedRing, summary.scheduledAlarmDate)
    }
}
