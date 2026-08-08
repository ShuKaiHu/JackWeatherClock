package com.shukaihu.rainyclock.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.shukaihu.rainyclock.data.SettingsRepository
import com.shukaihu.rainyclock.logic.AlarmTimeCalculator
import com.shukaihu.rainyclock.model.CommuteAlarmSettings
import com.shukaihu.rainyclock.model.RouteWeatherSnapshot
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import com.shukaihu.rainyclock.ui.MainActivity
import com.shukaihu.rainyclock.weather.RouteWeatherService
import com.shukaihu.rainyclock.work.WeatherRefreshWorker
import java.time.Duration
import java.time.Instant

class ExactAlarmPermissionException : Exception("Exact alarms are not permitted")

/** What a decide-and-arm round produced, for the status line. */
data class ArmOutcome(
    val summary: ScheduledAlarmSummary,
    val snapshot: RouteWeatherSnapshot
)

/**
 * The Android counterpart of the iOS `SystemAlarmScheduler` stack: exact
 * alarms via `AlarmManager.setAlarmClock`, which survives Doze, shows the
 * system alarm indicator, and is the documented path for alarm-clock apps.
 */
class AlarmScheduler(
    private val context: Context,
    private val repository: SettingsRepository,
    private val routeWeatherService: RouteWeatherService
) {

    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun canScheduleExactAlarms(): Boolean =
        if (Build.VERSION.SDK_INT in Build.VERSION_CODES.S..Build.VERSION_CODES.S_V2) {
            alarmManager.canScheduleExactAlarms()
        } else {
            // Below 31 no permission exists; from 33 USE_EXACT_ALARM is
            // granted at install for alarm-clock apps.
            true
        }

    /**
     * The full scheduling round the iOS view model runs: check the route
     * weather at the lead-time point, decide whether the alarm moves earlier,
     * and register the result. Throws when the weather fetch, the address
     * resolution, or the exact-alarm registration fails — the caller decides
     * how to surface it.
     */
    suspend fun decideAndArm(settings: CommuteAlarmSettings, now: Instant = Instant.now()): ArmOutcome {
        // First pass without the rain decision, to learn the check time.
        val preliminary = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = settings.alarmHour,
            alarmMinute = settings.alarmMinute,
            leadTimeMinutes = settings.rainLeadTimeMinutes,
            shouldApplyLeadTime = false,
            rainProbabilityThreshold = settings.rainProbabilityThreshold,
            maximumPrecipitationProbability = 0.0,
            selectedWeekdays = settings.selectedWeekdays,
            now = now
        )

        val snapshot = routeWeatherService.fetchRouteWeather(
            homeAddress = settings.homeAddress,
            homeLocation = settings.homeResolvedLocation,
            workAddress = settings.workAddress,
            workLocation = settings.workResolvedLocation,
            around = preliminary.weatherRefreshDate
        )

        val exceeds = snapshot.exceedsRainThreshold(settings.rainProbabilityThreshold)
        val decided = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
            alarmHour = settings.alarmHour,
            alarmMinute = settings.alarmMinute,
            leadTimeMinutes = settings.rainLeadTimeMinutes,
            shouldApplyLeadTime = exceeds,
            rainProbabilityThreshold = settings.rainProbabilityThreshold,
            maximumPrecipitationProbability = snapshot.maximumPrecipitationProbability,
            selectedWeekdays = settings.selectedWeekdays,
            now = now
        )
        val summary = decided.copy(checkedAtEpochMillis = snapshot.checkedAt.toEpochMilli())

        registerExact(summary.scheduledAlarmDate)
        // Only persist after registration succeeds — a failed registration
        // must never read back as a scheduled alarm (iOS audit finding #3).
        repository.saveScheduledAlarmSummary(summary)
        repository.saveScheduleFingerprint(settings.scheduleFingerprint())
        scheduleWeatherRefreshWork(summary, now)
        return ArmOutcome(summary, snapshot)
    }

    /**
     * Re-registers a stored summary without a fresh weather round — the boot
     * and after-fire paths, where ringing on the previous decision beats not
     * ringing at all.
     */
    fun armFromSummary(summary: ScheduledAlarmSummary, settings: CommuteAlarmSettings, now: Instant = Instant.now()) {
        val rolled = summary.rollingForward(settings.selectedWeekdays, now)
        registerExact(rolled.scheduledAlarmDate)
        repository.saveScheduledAlarmSummary(rolled)
        scheduleWeatherRefreshWork(rolled, now)
    }

    /** After-fire path: advance a week and re-arm on the stale decision. */
    fun scheduleNextAfterFire(now: Instant = Instant.now()) {
        val summary = repository.loadScheduledAlarmSummary() ?: return
        val settings = repository.loadSettings()
        // Nudge "now" past the ring that just fired so an alarm delivered a
        // moment early still rolls to next week instead of refiring.
        armFromSummary(summary, settings, now.plusSeconds(60))
    }

    fun disarm() {
        alarmManager.cancel(alarmPendingIntent())
        repository.saveScheduledAlarmSummary(null)
        repository.saveScheduleFingerprint(null)
        WorkManager.getInstance(context).cancelUniqueWork(WeatherRefreshWorker.UNIQUE_WORK_NAME)
    }

    fun scheduleSnooze(minutes: Int, now: Instant = Instant.now()) {
        val triggerAt = now.plusSeconds(minutes * 60L)
        val operation = alarmPendingIntent(isSnooze = true)
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAt.toEpochMilli(), showAlarmsPendingIntent()),
            operation
        )
    }

    private fun registerExact(triggerAt: Instant) {
        if (!canScheduleExactAlarms()) throw ExactAlarmPermissionException()
        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAt.toEpochMilli(), showAlarmsPendingIntent()),
            alarmPendingIntent()
        )
    }

    /**
     * Aims the rain re-check ahead of the ring, the same 45-minute margin the
     * iOS `BackgroundWeatherRefresh` uses — WorkManager just honours it far
     * more reliably than BGTaskScheduler.
     */
    private fun scheduleWeatherRefreshWork(summary: ScheduledAlarmSummary, now: Instant) {
        val target = summary.weatherRefreshDate.minus(Duration.ofMinutes(45))
        val delay = Duration.between(now, target).takeIf { !it.isNegative } ?: Duration.ZERO

        val request = OneTimeWorkRequestBuilder<WeatherRefreshWorker>()
            .setInitialDelay(delay)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()
            )
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            WeatherRefreshWorker.UNIQUE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }

    private fun alarmPendingIntent(isSnooze: Boolean = false): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_FIRED
            putExtra(AlarmReceiver.EXTRA_IS_SNOOZE, isSnooze)
        }
        return PendingIntent.getBroadcast(
            context,
            if (isSnooze) REQUEST_CODE_SNOOZE else REQUEST_CODE_ALARM,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun showAlarmsPendingIntent(): PendingIntent =
        PendingIntent.getActivity(
            context,
            REQUEST_CODE_SHOW,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    private companion object {
        const val REQUEST_CODE_ALARM = 1001
        const val REQUEST_CODE_SNOOZE = 1002
        const val REQUEST_CODE_SHOW = 1003
    }
}
