package com.shukaihu.rainyclock.alarm

import android.annotation.SuppressLint
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.shukaihu.rainyclock.AppGraph
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.RainyClockApp
import com.shukaihu.rainyclock.model.AlarmSound

/**
 * Plays the alarm as a foreground service: USAGE_ALARM audio rings through
 * silent mode at the alarm volume, and the notification's full-screen intent
 * raises [AlarmRingActivity] over the lock screen — the closest Android
 * equivalent of AlarmKit's system alert.
 */
class AlarmRingService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable { stopRinging() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> {
                val soundRawValue = intent.getStringExtra(EXTRA_SOUND_RAW_VALUE)
                val isAdjusted = intent.getBooleanExtra(EXTRA_IS_ADJUSTED, false)
                val snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 0)
                startRinging(soundRawValue, isAdjusted, snoozeMinutes)
            }
            ACTION_STOP -> stopRinging()
            ACTION_SNOOZE -> {
                val snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 0)
                if (snoozeMinutes > 0) {
                    AppGraph.initialize(this)
                    AppGraph.alarmScheduler.scheduleSnooze(snoozeMinutes)
                }
                stopRinging()
            }
        }
        return START_NOT_STICKY
    }

    private fun startRinging(soundRawValue: String?, isAdjusted: Boolean, snoozeMinutes: Int) {
        val notification = buildNotification(isAdjusted, snoozeMinutes)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startPlayer(soundRawValue)
        // Ring for at most ten minutes, matching the platform alarm apps'
        // give-up point, then release the audio and the notification.
        timeoutHandler.removeCallbacks(timeoutRunnable)
        timeoutHandler.postDelayed(timeoutRunnable, RING_TIMEOUT_MILLIS)
    }

    @SuppressLint("DiscouragedApi")
    private fun startPlayer(soundRawValue: String?) {
        stopPlayer()

        val sound = AlarmSound.entries.firstOrNull { it.rawValue == soundRawValue }
            ?: AlarmSound.RAINY_CLOCK
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val player = MediaPlayer()
        try {
            player.setAudioAttributes(attributes)
            val resourceName = sound.resourceName
            val resourceId = resourceName?.let { resources.getIdentifier(it, "raw", packageName) } ?: 0
            if (resourceId != 0) {
                resources.openRawResourceFd(resourceId).use { fd ->
                    player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                }
            } else {
                val fallback = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                player.setDataSource(this, fallback)
            }
            player.isLooping = true
            player.prepare()
            player.start()
            mediaPlayer = player
        } catch (_: Exception) {
            player.release()
        }
    }

    private fun buildNotification(isAdjusted: Boolean, snoozeMinutes: Int): Notification {
        val title = getString(
            if (isAdjusted) R.string.alarm_alert_title_adjusted else R.string.alarm_alert_title_normal
        )

        val fullScreenIntent = Intent(this, AlarmRingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(EXTRA_IS_ADJUSTED, isAdjusted)
            putExtra(EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, RainyClockApp.ALARM_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(title)
            .setContentText(getString(R.string.alarm_ring_notification_body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(0, getString(R.string.stop_alarm), servicePendingIntent(ACTION_STOP, 1))

        if (snoozeMinutes > 0) {
            builder.addAction(
                0,
                getString(R.string.alarm_snooze_button),
                servicePendingIntent(ACTION_SNOOZE, 2, snoozeMinutes)
            )
        }

        return builder.build()
    }

    private fun servicePendingIntent(action: String, requestCode: Int, snoozeMinutes: Int = 0): PendingIntent {
        val intent = Intent(this, AlarmRingService::class.java).apply {
            this.action = action
            putExtra(EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun stopRinging() {
        timeoutHandler.removeCallbacks(timeoutRunnable)
        stopPlayer()
        sendBroadcast(
            Intent(ACTION_RING_STOPPED).setPackage(packageName)
        )
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopPlayer() {
        mediaPlayer?.let { player ->
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
            }
            player.release()
        }
        mediaPlayer = null
    }

    override fun onDestroy() {
        timeoutHandler.removeCallbacks(timeoutRunnable)
        stopPlayer()
        super.onDestroy()
    }

    companion object {
        const val ACTION_RING = "com.shukaihu.rainyclock.RING"
        const val ACTION_STOP = "com.shukaihu.rainyclock.STOP_RING"
        const val ACTION_SNOOZE = "com.shukaihu.rainyclock.SNOOZE_RING"
        const val ACTION_RING_STOPPED = "com.shukaihu.rainyclock.RING_STOPPED"
        const val EXTRA_SOUND_RAW_VALUE = "sound_raw_value"
        const val EXTRA_IS_ADJUSTED = "is_adjusted"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"
        const val NOTIFICATION_ID = 42
        const val RING_TIMEOUT_MILLIS = 10L * 60L * 1000L
    }
}
