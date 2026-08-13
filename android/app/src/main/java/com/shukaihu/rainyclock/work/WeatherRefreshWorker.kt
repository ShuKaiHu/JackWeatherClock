package com.shukaihu.rainyclock.work

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.shukaihu.rainyclock.AppGraph

/**
 * The Android counterpart of the iOS `BackgroundWeatherRefresh`: re-decides
 * an armed alarm against the morning's forecast. Scheduled by
 * `AlarmScheduler` at 45 minutes before the lead-time point.
 *
 * A failed round keeps the previous decision — the alarm itself is already
 * registered and never disappears; only the earlier-or-not decision can go
 * stale. That is the same honest contract the iOS app documents.
 */
class WeatherRefreshWorker(
    context: Context,
    parameters: WorkerParameters
) : CoroutineWorker(context, parameters) {

    override suspend fun doWork(): Result {
        AppGraph.initialize(applicationContext)
        val repository = AppGraph.settingsRepository

        // Only refresh an alarm that is actually armed.
        repository.loadScheduledAlarmSummary() ?: return Result.success()
        val settings = repository.loadSettings()

        return try {
            AppGraph.alarmScheduler.decideAndArm(settings)
            Result.success()
        } catch (error: Exception) {
            if (runAttemptCount < MAX_RETRIES) Result.retry() else Result.success()
        }
    }

    companion object {
        const val UNIQUE_WORK_NAME = "weather-refresh"
        private const val MAX_RETRIES = 3
    }
}
