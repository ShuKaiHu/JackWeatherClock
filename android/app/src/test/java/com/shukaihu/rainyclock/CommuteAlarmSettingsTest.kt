package com.shukaihu.rainyclock

import com.shukaihu.rainyclock.model.AlarmSound
import com.shukaihu.rainyclock.model.CommuteAlarmSettings
import com.shukaihu.rainyclock.model.CommuteMode
import com.shukaihu.rainyclock.model.WeatherCondition
import com.shukaihu.rainyclock.model.WeatherSampleMapper
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CommuteAlarmSettingsTest {

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    @Test
    fun `missing fields decode to the same defaults the iOS decoder applies`() {
        val settings = json.decodeFromString<CommuteAlarmSettings>("""{"homeAddress":"台北"}""").sanitized()

        assertEquals("台北", settings.homeAddress)
        assertEquals(7, settings.alarmHour)
        assertEquals(30, settings.alarmMinute)
        assertEquals(30, settings.rainLeadTimeMinutes)
        assertEquals(0.5, settings.rainProbabilityThreshold, 1e-9)
        assertEquals(CommuteAlarmSettings.ALL_WEEKDAYS, settings.selectedWeekdays)
        assertEquals(AlarmSound.RAINY_CLOCK, settings.alarmSound)
        assertEquals(true, settings.isSnoozeEnabled)
        assertEquals(5, settings.snoozeDurationMinutes)
    }

    @Test
    fun `unknown alarm sound falls back instead of failing the decode`() {
        val settings = json.decodeFromString<CommuteAlarmSettings>(
            """{"alarmSound":"toneFromTheFuture"}"""
        ).sanitized()
        assertEquals(AlarmSound.RAINY_CLOCK, settings.alarmSound)
    }

    @Test
    fun `a settings blob left over from the scooter mode keeps every other field`() {
        // Android dropped the scooter mode; anything persisted before that must
        // degrade to the default rather than losing the whole settings object,
        // which is what the repository's decode does on a thrown exception.
        val settings = json.decodeFromString<CommuteAlarmSettings>(
            """{"commuteMode":"scooter","homeAddress":"台南","alarmHour":6,"snoozeDurationMinutes":9}"""
        ).sanitized()

        assertEquals(CommuteMode.CAR, settings.commuteMode)
        assertEquals("台南", settings.homeAddress)
        assertEquals(6, settings.alarmHour)
        assertEquals(9, settings.snoozeDurationMinutes)
    }

    @Test
    fun `snooze duration is clamped to the selectable range`() {
        val tooLong = json.decodeFromString<CommuteAlarmSettings>("""{"snoozeDurationMinutes":90}""").sanitized()
        assertEquals(15, tooLong.snoozeDurationMinutes)
        val tooShort = json.decodeFromString<CommuteAlarmSettings>("""{"snoozeDurationMinutes":0}""").sanitized()
        assertEquals(1, tooShort.snoozeDurationMinutes)
    }

    @Test
    fun `empty weekday selection is treated as every day`() {
        val settings = json.decodeFromString<CommuteAlarmSettings>("""{"selectedWeekdays":[]}""").sanitized()
        assertEquals(CommuteAlarmSettings.ALL_WEEKDAYS, settings.selectedWeekdays)
    }

    @Test
    fun `fingerprint changes when a scheduling parameter changes and ignores whitespace`() {
        val base = CommuteAlarmSettings(homeAddress = " 台北 ", workAddress = "新竹")
        assertEquals(base.scheduleFingerprint(), base.copy(homeAddress = "台北").scheduleFingerprint())
        val edited = base.copy(alarmMinute = 45)
        assertEquals(false, base.scheduleFingerprint() == edited.scheduleFingerprint())
    }

    @Test
    fun `effective snooze is null when snooze is off`() {
        assertNull(CommuteAlarmSettings(isSnoozeEnabled = false).effectiveSnoozeMinutes)
        assertEquals(5, CommuteAlarmSettings().effectiveSnoozeMinutes)
    }

    @Test
    fun `weather sample mapper buckets match the iOS thresholds`() {
        assertEquals(WeatherCondition.RAIN, WeatherSampleMapper.condition(0.5))
        assertEquals(WeatherCondition.CLOUDY, WeatherSampleMapper.condition(0.2))
        assertEquals(WeatherCondition.CLOUDY, WeatherSampleMapper.condition(0.49))
        assertEquals(WeatherCondition.CLEAR, WeatherSampleMapper.condition(0.19))
    }
}
