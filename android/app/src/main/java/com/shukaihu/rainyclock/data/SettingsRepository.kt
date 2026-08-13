package com.shukaihu.rainyclock.data

import android.content.Context
import android.content.SharedPreferences
import com.shukaihu.rainyclock.model.AlarmScheduleFingerprint
import com.shukaihu.rainyclock.model.CommuteAlarmSettings
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import kotlinx.serialization.json.Json

/**
 * Persistence for settings, the armed-alarm summary, and the schedule
 * fingerprint. SharedPreferences (not DataStore) because the alarm receiver
 * and boot receiver need synchronous reads on wake-up paths.
 */
class SettingsRepository(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
    }

    fun loadSettings(): CommuteAlarmSettings =
        decode<CommuteAlarmSettings>(KEY_SETTINGS)?.sanitized() ?: CommuteAlarmSettings()

    fun saveSettings(settings: CommuteAlarmSettings) {
        prefs.edit().putString(KEY_SETTINGS, json.encodeToString(CommuteAlarmSettings.serializer(), settings)).apply()
    }

    fun loadScheduledAlarmSummary(): ScheduledAlarmSummary? =
        decode<ScheduledAlarmSummary>(KEY_SUMMARY)

    fun saveScheduledAlarmSummary(summary: ScheduledAlarmSummary?) {
        if (summary == null) {
            prefs.edit().remove(KEY_SUMMARY).apply()
        } else {
            prefs.edit().putString(KEY_SUMMARY, json.encodeToString(ScheduledAlarmSummary.serializer(), summary)).apply()
        }
    }

    fun loadScheduleFingerprint(): AlarmScheduleFingerprint? =
        decode<AlarmScheduleFingerprint>(KEY_FINGERPRINT)

    fun saveScheduleFingerprint(fingerprint: AlarmScheduleFingerprint?) {
        if (fingerprint == null) {
            prefs.edit().remove(KEY_FINGERPRINT).apply()
        } else {
            prefs.edit()
                .putString(KEY_FINGERPRINT, json.encodeToString(AlarmScheduleFingerprint.serializer(), fingerprint))
                .apply()
        }
    }

    private inline fun <reified T> decode(key: String): T? {
        val raw = prefs.getString(key, null) ?: return null
        return try {
            json.decodeFromString<T>(raw)
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val PREFS_NAME = "rainy_clock_settings"
        private const val KEY_SETTINGS = "commute_alarm_settings"
        private const val KEY_SUMMARY = "scheduled_alarm_summary"
        private const val KEY_FINGERPRINT = "alarm_schedule_fingerprint"
    }
}
