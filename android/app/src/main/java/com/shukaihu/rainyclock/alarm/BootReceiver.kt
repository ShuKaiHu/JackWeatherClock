package com.shukaihu.rainyclock.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.shukaihu.rainyclock.AppGraph

/**
 * AlarmManager registrations do not survive a reboot (and can drift across
 * time or timezone changes), so re-arm from the persisted summary. The rain
 * decision is whatever the last round produced — the refresh worker
 * re-decides ahead of the ring.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                AppGraph.initialize(context)
                val summary = AppGraph.settingsRepository.loadScheduledAlarmSummary() ?: return
                val settings = AppGraph.settingsRepository.loadSettings()
                try {
                    AppGraph.alarmScheduler.armFromSummary(summary, settings)
                } catch (_: ExactAlarmPermissionException) {
                    // Nothing to do from a receiver; the app surfaces the
                    // missing permission on next open.
                }
            }
        }
    }
}
