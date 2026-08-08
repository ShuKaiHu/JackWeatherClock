package com.shukaihu.rainyclock.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import com.shukaihu.rainyclock.AppGraph

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ALARM_FIRED) return
        AppGraph.initialize(context)

        val isSnooze = intent.getBooleanExtra(EXTRA_IS_SNOOZE, false)
        val settings = AppGraph.settingsRepository.loadSettings()
        val summary = AppGraph.settingsRepository.loadScheduledAlarmSummary()

        val serviceIntent = Intent(context, AlarmRingService::class.java).apply {
            action = AlarmRingService.ACTION_RING
            putExtra(AlarmRingService.EXTRA_SOUND_RAW_VALUE, settings.alarmSound.rawValue)
            putExtra(AlarmRingService.EXTRA_IS_ADJUSTED, summary?.exceedsRainThreshold == true)
            putExtra(AlarmRingService.EXTRA_SNOOZE_MINUTES, settings.effectiveSnoozeMinutes ?: 0)
        }
        ContextCompat.startForegroundService(context, serviceIntent)

        // A snooze ring is a one-shot; only the weekly alarm advances the
        // schedule to next week (on the decision it already had — the refresh
        // worker re-decides ahead of the next morning).
        if (!isSnooze) {
            AppGraph.alarmScheduler.scheduleNextAfterFire()
        }
    }

    companion object {
        const val ACTION_ALARM_FIRED = "com.shukaihu.rainyclock.ALARM_FIRED"
        const val EXTRA_IS_SNOOZE = "is_snooze"
    }
}
