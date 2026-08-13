package com.shukaihu.rainyclock

import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

class ScheduledAlarmSummaryTest {

    private val zone: ZoneId = ZoneId.of("Asia/Taipei")

    private fun at(year: Int, month: Int, day: Int, hour: Int, minute: Int): Instant =
        ZonedDateTime.of(year, month, day, hour, minute, 0, 0, zone).toInstant()

    @Test
    fun `future dates are untouched`() {
        val summary = ScheduledAlarmSummary.of(
            normalAlarmDate = at(2026, 8, 10, 7, 30),
            scheduledAlarmDate = at(2026, 8, 10, 7, 0),
            weatherRefreshDate = at(2026, 8, 10, 7, 0),
            exceedsRainThreshold = true,
            leadTimeMinutes = 30,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.7
        )

        val rolled = summary.rollingForward(setOf(2), now = at(2026, 8, 8, 12, 0), zone = zone)
        assertEquals(summary, rolled)
    }

    @Test
    fun `past dates advance to the next selected weekday`() {
        // Monday 08-03 07:30, reloaded on Saturday 08-08: next Monday is 08-10.
        val summary = ScheduledAlarmSummary.of(
            normalAlarmDate = at(2026, 8, 3, 7, 30),
            scheduledAlarmDate = at(2026, 8, 3, 7, 30),
            weatherRefreshDate = at(2026, 8, 3, 7, 0),
            exceedsRainThreshold = false,
            leadTimeMinutes = 0,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.1
        )

        val rolled = summary.rollingForward(setOf(2), now = at(2026, 8, 8, 12, 0), zone = zone)
        assertEquals(at(2026, 8, 10, 7, 30), rolled.normalAlarmDate)
        assertEquals(at(2026, 8, 10, 7, 30), rolled.scheduledAlarmDate)
        assertEquals(at(2026, 8, 10, 7, 0), rolled.weatherRefreshDate)
    }

    @Test
    fun `ring on the previous day keeps its day shift when rolling forward`() {
        // Normal alarm Monday 00:10; rainy ring Sunday 23:40. Rolled forward,
        // the ring must stay on Sunday nights, not drift onto Mondays.
        val summary = ScheduledAlarmSummary.of(
            normalAlarmDate = at(2026, 8, 3, 0, 10),
            scheduledAlarmDate = at(2026, 8, 2, 23, 40),
            weatherRefreshDate = at(2026, 8, 2, 23, 40),
            exceedsRainThreshold = true,
            leadTimeMinutes = 30,
            rainProbabilityThreshold = 0.5,
            maximumPrecipitationProbability = 0.8
        )

        val rolled = summary.rollingForward(setOf(2), now = at(2026, 8, 8, 12, 0), zone = zone)
        assertEquals(at(2026, 8, 10, 0, 10), rolled.normalAlarmDate)
        assertEquals(at(2026, 8, 9, 23, 40), rolled.scheduledAlarmDate)
    }
}
