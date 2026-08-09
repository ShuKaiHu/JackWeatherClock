package com.shukaihu.rainyclock.ui

import android.app.Application
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.util.Log
import androidx.annotation.StringRes
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.shukaihu.rainyclock.AppGraph
import com.shukaihu.rainyclock.BuildConfig
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.alarm.ExactAlarmPermissionException
import com.shukaihu.rainyclock.geo.AddressNotFoundException
import com.shukaihu.rainyclock.logic.AlarmTimeCalculator
import com.shukaihu.rainyclock.model.AlarmSound
import com.shukaihu.rainyclock.model.CommuteAlarmSettings
import com.shukaihu.rainyclock.model.CommuteMode
import com.shukaihu.rainyclock.model.RoutePreview
import com.shukaihu.rainyclock.model.RouteWeatherSnapshot
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import com.shukaihu.rainyclock.weather.WeatherUnavailableException
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class StatusTone { POSITIVE, WARNING, NEUTRAL, ERROR }

data class StatusLine(
    @StringRes val textResId: Int,
    val args: List<String> = emptyList(),
    val tone: StatusTone = StatusTone.NEUTRAL
)

sealed interface RouteWeatherState {
    data object Empty : RouteWeatherState
    data object Loading : RouteWeatherState
    data class Loaded(val snapshot: RouteWeatherSnapshot) : RouteWeatherState
    data class Failed(@StringRes val messageResId: Int) : RouteWeatherState
}

data class AlarmUiState(
    val settings: CommuteAlarmSettings = CommuteAlarmSettings(),
    val homeSuggestion: String? = null,
    val workSuggestion: String? = null,
    val homeInvalid: Boolean = false,
    val workInvalid: Boolean = false,
    val routeWeather: RouteWeatherState = RouteWeatherState.Empty,
    val routePreview: RoutePreview? = null,
    val summary: ScheduledAlarmSummary? = null,
    val isScheduling: Boolean = false,
    val isStale: Boolean = false,
    val status: StatusLine = StatusLine(R.string.status_enter_settings)
)

class AlarmViewModel(application: Application) : AndroidViewModel(application) {

    private val repository = AppGraph.settingsRepository
    private val scheduler = AppGraph.alarmScheduler
    private val routeWeatherService = AppGraph.routeWeatherService
    private val routePreviewService = AppGraph.routePreviewService

    /** False when no Maps key is configured; the map card hides itself. */
    val isRoutePreviewConfigured: Boolean = routePreviewService != null

    /**
     * Which provider actually answered decides which attribution is legal to
     * show: WeatherKit requires the Apple Weather mark linked to its legal page,
     * Open-Meteo requires a credit line. Showing the wrong one is a licence
     * breach either way, so this follows the graph rather than a constant.
     */
    val usesAppleWeather: Boolean = AppGraph.usesAppleWeather

    private val _uiState = MutableStateFlow(AlarmUiState())
    val uiState: StateFlow<AlarmUiState> = _uiState.asStateFlow()

    private var autoRescheduleJob: Job? = null
    private var previewPlayer: MediaPlayer? = null

    private val dateTimeFormatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT, FormatStyle.SHORT)

    init {
        val settings = repository.loadSettings()
        val summary = repository.loadScheduledAlarmSummary()
            ?.rollingForward(settings.selectedWeekdays)
        val fingerprint = repository.loadScheduleFingerprint()
        val isArmed = summary != null
        val isStale = isArmed && fingerprint != settings.scheduleFingerprint()

        _uiState.value = AlarmUiState(
            settings = settings,
            summary = summary,
            isStale = isStale,
            status = when {
                isArmed && isStale -> StatusLine(R.string.schedule_stale_notice, tone = StatusTone.WARNING)
                isArmed -> StatusLine(R.string.status_alarm_scheduled, tone = StatusTone.POSITIVE)
                else -> StatusLine(R.string.status_enter_settings)
            }
        )

        if (isStale) scheduleAutoReschedule()
    }

    // MARK: Address edits — remove the alarm outright (an alarm for a route
    // the user has not confirmed should never ring; see PRODUCT_DECISIONS.md).

    fun updateHomeAddress(text: String) {
        updateAddress { it.copy(homeAddress = text, homeResolvedLocation = null, confirmedHomeAddressInput = null) }
        _uiState.update { it.copy(homeSuggestion = null, homeInvalid = false) }
    }

    fun updateWorkAddress(text: String) {
        updateAddress { it.copy(workAddress = text, workResolvedLocation = null, confirmedWorkAddressInput = null) }
        _uiState.update { it.copy(workSuggestion = null, workInvalid = false) }
    }

    private fun updateAddress(transform: (CommuteAlarmSettings) -> CommuteAlarmSettings) {
        autoRescheduleJob?.cancel()
        val wasArmed = _uiState.value.summary != null
        val settings = transform(_uiState.value.settings)
        repository.saveSettings(settings)
        if (wasArmed) {
            scheduler.disarm()
            _uiState.update {
                it.copy(
                    settings = settings,
                    summary = null,
                    isStale = false,
                    status = StatusLine(R.string.status_alarm_removed_address_changed, tone = StatusTone.WARNING)
                )
            }
        } else {
            _uiState.update { it.copy(settings = settings) }
        }
    }

    fun confirmHomeSuggestion() {
        val suggestion = _uiState.value.homeSuggestion ?: return
        val settings = _uiState.value.settings.copy(
            homeAddress = suggestion,
            confirmedHomeAddressInput = suggestion
        )
        repository.saveSettings(settings)
        _uiState.update { it.copy(settings = settings, homeSuggestion = null) }
    }

    fun confirmWorkSuggestion() {
        val suggestion = _uiState.value.workSuggestion ?: return
        val settings = _uiState.value.settings.copy(
            workAddress = suggestion,
            confirmedWorkAddressInput = suggestion
        )
        repository.saveSettings(settings)
        _uiState.update { it.copy(settings = settings, workSuggestion = null) }
    }

    // MARK: Parameter edits — persist, and auto-refresh an armed alarm after
    // a short debounce (the scheduled alarm always matches visible settings).

    fun setCommuteMode(mode: CommuteMode) = updateParameters { it.copy(commuteMode = mode) }

    fun setAlarmTime(hour: Int, minute: Int) = updateParameters { it.copy(alarmHour = hour, alarmMinute = minute) }

    fun toggleWeekday(weekday: Int) = updateParameters {
        val selected = it.selectedWeekdays.toMutableSet()
        if (!selected.add(weekday)) selected.remove(weekday)
        it.copy(selectedWeekdays = selected)
    }

    fun setRainLeadTimeMinutes(minutes: Int) = updateParameters { it.copy(rainLeadTimeMinutes = minutes.coerceIn(1, 60)) }

    fun setRainProbabilityThreshold(threshold: Double) = updateParameters {
        it.copy(rainProbabilityThreshold = threshold.coerceIn(0.1, 0.9))
    }

    fun setAlarmSound(sound: AlarmSound) = updateParameters { it.copy(alarmSound = sound) }

    fun setSnoozeEnabled(enabled: Boolean) = updateParameters { it.copy(isSnoozeEnabled = enabled) }

    fun setSnoozeDurationMinutes(minutes: Int) = updateParameters {
        it.copy(snoozeDurationMinutes = minutes.coerceIn(CommuteAlarmSettings.SNOOZE_DURATION_RANGE))
    }

    private fun updateParameters(transform: (CommuteAlarmSettings) -> CommuteAlarmSettings) {
        val settings = transform(_uiState.value.settings)
        repository.saveSettings(settings)
        val armed = _uiState.value.summary != null
        val stale = armed && repository.loadScheduleFingerprint() != settings.scheduleFingerprint()
        _uiState.update {
            it.copy(
                settings = settings,
                isStale = stale,
                status = if (stale) StatusLine(R.string.schedule_stale_notice, tone = StatusTone.WARNING) else it.status
            )
        }
        if (stale) scheduleAutoReschedule()
    }

    private fun scheduleAutoReschedule() {
        autoRescheduleJob?.cancel()
        autoRescheduleJob = viewModelScope.launch {
            delay(1_500)
            scheduleAlarm(isAutoRefresh = true)
        }
    }

    // MARK: Scheduling

    fun scheduleAlarm(isAutoRefresh: Boolean = false) {
        autoRescheduleJob?.cancel()
        val settings = _uiState.value.settings
        if (settings.homeAddress.isBlank() || settings.workAddress.isBlank() || settings.rainLeadTimeMinutes <= 0) {
            _uiState.update { it.copy(status = StatusLine(R.string.status_required, tone = StatusTone.ERROR)) }
            return
        }

        viewModelScope.launch {
            _uiState.update {
                it.copy(isScheduling = true, status = StatusLine(R.string.checking_route, tone = StatusTone.NEUTRAL))
            }
            try {
                val outcome = scheduler.decideAndArm(settings)
                val summary = outcome.summary
                val forecastText = formatInstant(outcome.snapshot.forecastAt)
                val checkedText = formatInstant(outcome.snapshot.checkedAt)
                _uiState.update {
                    it.copy(
                        isScheduling = false,
                        summary = summary,
                        isStale = false,
                        routeWeather = RouteWeatherState.Loaded(outcome.snapshot),
                        status = StatusLine(
                            if (summary.exceedsRainThreshold) R.string.status_adjusted_checked else R.string.status_normal_checked,
                            args = listOf(forecastText, checkedText),
                            tone = StatusTone.POSITIVE
                        )
                    )
                }
            } catch (error: AddressNotFoundException) {
                val home = error.address.trim() == settings.homeAddress.trim()
                _uiState.update {
                    it.copy(
                        isScheduling = false,
                        homeInvalid = home || it.homeInvalid,
                        workInvalid = !home || it.workInvalid,
                        status = StatusLine(
                            R.string.error_address_not_found,
                            args = listOf(error.address),
                            tone = StatusTone.ERROR
                        )
                    )
                }
            } catch (error: ExactAlarmPermissionException) {
                _uiState.update {
                    it.copy(
                        isScheduling = false,
                        status = StatusLine(R.string.status_alarm_permission_denied, tone = StatusTone.ERROR)
                    )
                }
            } catch (error: Exception) {
                // On a failed auto-refresh keep the alarm armed on its previous
                // decision and keep the stale notice visible.
                val messageResId = if (error is WeatherUnavailableException) {
                    R.string.error_weather_unavailable
                } else {
                    R.string.status_schedule_failed
                }
                _uiState.update {
                    it.copy(
                        isScheduling = false,
                        status = if (isAutoRefresh && it.summary != null) {
                            StatusLine(R.string.schedule_stale_notice, tone = StatusTone.WARNING)
                        } else {
                            StatusLine(
                                messageResId,
                                args = if (messageResId == R.string.status_schedule_failed) {
                                    listOf(error.message ?: "")
                                } else {
                                    emptyList()
                                },
                                tone = StatusTone.ERROR
                            )
                        }
                    )
                }
            }
        }
    }

    /**
     * The foreground half of the three-path refresh contract: opening the app
     * re-decides an armed alarm whenever its rain check is older than four
     * hours, silently, keeping the previous status line if the refresh fails.
     */
    fun refreshScheduledAlarmIfWeatherIsStale() {
        val summary = _uiState.value.summary ?: return
        val checkedAt = summary.checkedAtEpochMillis
        val age = Duration.between(Instant.ofEpochMilli(checkedAt), Instant.now())
        if (checkedAt != 0L && age < Duration.ofHours(4)) return

        viewModelScope.launch {
            try {
                val outcome = scheduler.decideAndArm(_uiState.value.settings)
                _uiState.update { it.copy(summary = outcome.summary, isStale = false) }
            } catch (_: Exception) {
                // Keep the previous decision and status line.
            }
        }
    }

    // MARK: Route weather preview

    fun refreshRouteWeather() {
        val settings = _uiState.value.settings
        if (settings.homeAddress.isBlank() || settings.workAddress.isBlank()) {
            _uiState.update { it.copy(routeWeather = RouteWeatherState.Empty) }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(routeWeather = RouteWeatherState.Loading) }
            try {
                val checkTime = AlarmTimeCalculator.nextAlarmDateForWeatherCheck(
                    alarmHour = settings.alarmHour,
                    alarmMinute = settings.alarmMinute,
                    leadTimeMinutes = settings.rainLeadTimeMinutes,
                    shouldApplyLeadTime = false,
                    rainProbabilityThreshold = settings.rainProbabilityThreshold,
                    maximumPrecipitationProbability = 0.0,
                    selectedWeekdays = settings.selectedWeekdays
                ).weatherRefreshDate

                val snapshot = routeWeatherService.fetchRouteWeather(
                    homeAddress = settings.homeAddress,
                    homeLocation = settings.homeResolvedLocation,
                    workAddress = settings.workAddress,
                    workLocation = settings.workResolvedLocation,
                    mode = settings.commuteMode,
                    around = checkTime
                )

                maybeSurfaceResolvedAddresses(settings)
                _uiState.update { it.copy(routeWeather = RouteWeatherState.Loaded(snapshot)) }
                refreshRoutePreview()
            } catch (error: AddressNotFoundException) {
                val home = error.address.trim() == settings.homeAddress.trim()
                _uiState.update {
                    it.copy(
                        routeWeather = RouteWeatherState.Failed(R.string.error_address_not_found),
                        homeInvalid = home || it.homeInvalid,
                        workInvalid = !home || it.workInvalid
                    )
                }
            } catch (_: Exception) {
                _uiState.update { it.copy(routeWeather = RouteWeatherState.Failed(R.string.error_weather_unavailable)) }
            }
        }
    }

    /**
     * Fetches the route polyline for the map card. Best-effort: a failure
     * clears the map but never touches the weather result or the alarm.
     */
    private suspend fun refreshRoutePreview() {
        val service = routePreviewService ?: return
        val settings = _uiState.value.settings
        val home = settings.homeResolvedLocation ?: return
        val work = settings.workResolvedLocation ?: return
        val preview = try {
            service.fetchRoute(home, work, settings.commuteMode)
        } catch (error: Exception) {
            // A cleared map looks identical whether the key is missing, the API
            // is disabled, or the route genuinely has no result — keep the reason
            // visible in debug builds (same contract as the ad banner).
            if (BuildConfig.DEBUG) {
                Log.w("RoutePreview", "Route preview failed: $error")
            }
            null
        }
        _uiState.update { it.copy(routePreview = preview) }
    }

    /**
     * If the geocoder resolved typed text to a different formatted address,
     * make that visible and ask for confirmation ("actual address in use").
     */
    private suspend fun maybeSurfaceResolvedAddresses(settings: CommuteAlarmSettings) {
        val resolver = AppGraph.addressResolver
        if (settings.homeResolvedLocation == null && settings.homeAddress.isNotBlank() &&
            settings.confirmedHomeAddressInput != settings.homeAddress
        ) {
            runCatching { resolver.resolve(settings.homeAddress) }.onSuccess { resolved ->
                val current = _uiState.value.settings
                val updated = current.copy(homeResolvedLocation = resolved)
                repository.saveSettings(updated)
                _uiState.update {
                    it.copy(
                        settings = updated,
                        homeSuggestion = resolved.formattedAddress
                            .takeIf { formatted -> !formatted.equals(current.homeAddress.trim(), ignoreCase = true) }
                    )
                }
            }
        }
        if (settings.workResolvedLocation == null && settings.workAddress.isNotBlank() &&
            settings.confirmedWorkAddressInput != settings.workAddress
        ) {
            runCatching { resolver.resolve(settings.workAddress) }.onSuccess { resolved ->
                val current = _uiState.value.settings
                val updated = current.copy(workResolvedLocation = resolved)
                repository.saveSettings(updated)
                _uiState.update {
                    it.copy(
                        settings = updated,
                        workSuggestion = resolved.formattedAddress
                            .takeIf { formatted -> !formatted.equals(current.workAddress.trim(), ignoreCase = true) }
                    )
                }
            }
        }
    }

    // MARK: Sound preview — USAGE_ALARM so it is audible under silent mode,
    // like the alarm itself (the iOS build once previewed into .soloAmbient
    // and played nothing under the ring switch).

    fun previewSound(sound: AlarmSound) {
        stopPreview()
        val context = getApplication<Application>()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(attributes)
            val resourceId = sound.resourceName
                ?.let { context.resources.getIdentifier(it, "raw", context.packageName) } ?: 0
            if (resourceId != 0) {
                context.resources.openRawResourceFd(resourceId).use { fd ->
                    player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                }
            } else {
                player.setDataSource(context, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            }
            player.setOnCompletionListener { stopPreview() }
            player.prepare()
            player.start()
            previewPlayer = player
        } catch (_: Exception) {
            player.release()
        }
    }

    fun stopPreview() {
        previewPlayer?.release()
        previewPlayer = null
    }

    private fun formatInstant(instant: Instant): String =
        dateTimeFormatter.format(instant.atZone(ZoneId.systemDefault()))

    override fun onCleared() {
        stopPreview()
        super.onCleared()
    }
}
