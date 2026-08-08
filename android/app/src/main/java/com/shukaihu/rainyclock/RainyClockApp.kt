package com.shukaihu.rainyclock

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import com.google.android.gms.ads.MobileAds
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class RainyClockApp : Application() {

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        AppGraph.initialize(this)
        createAlarmChannel()
        // Ad SDK init is not needed before the first frame; keep it off main.
        applicationScope.launch {
            MobileAds.initialize(this@RainyClockApp) {}
        }
    }

    private fun createAlarmChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        // The channel carries no sound of its own: AlarmRingService plays the
        // chosen tone through USAGE_ALARM audio, which respects the alarm
        // volume and rings through silent mode. Ten selectable tones on one
        // immutable-channel-sound API would otherwise mean ten channels.
        val channel = NotificationChannel(
            ALARM_CHANNEL_ID,
            getString(R.string.channel_alarm_name),
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = getString(R.string.channel_alarm_description)
            setSound(null, null)
            enableVibration(false)
            setBypassDnd(true)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ALARM_CHANNEL_ID = "alarm"
    }
}
