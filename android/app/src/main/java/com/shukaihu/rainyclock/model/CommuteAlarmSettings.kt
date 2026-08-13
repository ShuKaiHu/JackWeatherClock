package com.shukaihu.rainyclock.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Port of the iOS `CommuteAlarmSettings`. Weekdays keep the iOS `Calendar`
 * convention (1 = Sunday … 7 = Saturday) so the two platforms share one
 * mental model and the docs stay true for both.
 */
@Serializable
data class CommuteAlarmSettings(
    val homeAddress: String = "",
    val workAddress: String = "",
    val homeResolvedLocation: ResolvedLocation? = null,
    val workResolvedLocation: ResolvedLocation? = null,
    val confirmedHomeAddressInput: String? = null,
    val confirmedWorkAddressInput: String? = null,
    val commuteMode: CommuteMode = CommuteMode.CAR,
    val alarmHour: Int = 7,
    val alarmMinute: Int = 30,
    val rainLeadTimeMinutes: Int = 30,
    val rainProbabilityThreshold: Double = 0.5,
    val selectedWeekdays: Set<Int> = ALL_WEEKDAYS,
    val alarmSound: AlarmSound = AlarmSound.RAINY_CLOCK,
    val isSnoozeEnabled: Boolean = true,
    val snoozeDurationMinutes: Int = 5
) {
    /** Applies the same defaults-and-clamps the iOS decoder enforces. */
    fun sanitized(): CommuteAlarmSettings = copy(
        selectedWeekdays = if (selectedWeekdays.isEmpty()) ALL_WEEKDAYS else selectedWeekdays,
        snoozeDurationMinutes = snoozeDurationMinutes.coerceIn(SNOOZE_DURATION_RANGE),
        alarmHour = alarmHour.coerceIn(0, 23),
        alarmMinute = alarmMinute.coerceIn(0, 59)
    )

    /** The snooze interval to schedule with, or null when snooze is off. */
    val effectiveSnoozeMinutes: Int?
        get() = if (isSnoozeEnabled) snoozeDurationMinutes else null

    fun scheduleFingerprint(): AlarmScheduleFingerprint = AlarmScheduleFingerprint(
        homeAddress = homeAddress.trim(),
        workAddress = workAddress.trim(),
        commuteMode = commuteMode,
        alarmHour = alarmHour,
        alarmMinute = alarmMinute,
        selectedWeekdays = selectedWeekdays,
        rainLeadTimeMinutes = rainLeadTimeMinutes,
        rainProbabilityThreshold = rainProbabilityThreshold,
        alarmSoundRawValue = alarmSound.rawValue,
        isSnoozeEnabled = isSnoozeEnabled,
        snoozeDurationMinutes = snoozeDurationMinutes
    )

    companion object {
        val ALL_WEEKDAYS: Set<Int> = (1..7).toSet()
        val SNOOZE_DURATION_RANGE: IntRange = 1..15
    }
}

/**
 * No scooter mode on Android, unlike iOS. Routing a two-wheeler is an
 * Enterprise-tier Routes API feature, outside the free allowance, and scooters
 * are the most-chosen mode in this app's home market — so offering it would put
 * the most common request on the only billable path. A settings blob still
 * carrying the old `"scooter"` value decodes to [CAR] rather than failing, via
 * `coerceInputValues`; see `CommuteAlarmSettingsTest`.
 */
@Serializable
enum class CommuteMode {
    @SerialName("car") CAR,
    @SerialName("walking") WALKING,
    @SerialName("publicTransit") PUBLIC_TRANSIT
}

@Serializable
enum class AlarmSound(val rawValue: String, val resourceName: String?) {
    @SerialName("rainyClock") RAINY_CLOCK("rainyClock", "sound_rainy_clock"),
    @SerialName("morningBell") MORNING_BELL("morningBell", "sound_morning_bell"),
    @SerialName("softPiano") SOFT_PIANO("softPiano", "sound_soft_piano"),
    @SerialName("brightChime") BRIGHT_CHIME("brightChime", "sound_bright_chime"),
    @SerialName("gentleWaves") GENTLE_WAVES("gentleWaves", "sound_gentle_waves"),
    @SerialName("digitalBeep") DIGITAL_BEEP("digitalBeep", "sound_digital_beep"),
    @SerialName("forestBirds") FOREST_BIRDS("forestBirds", "sound_forest_birds"),
    @SerialName("energeticPulse") ENERGETIC_PULSE("energeticPulse", "sound_energetic_pulse"),
    @SerialName("deepResonance") DEEP_RESONANCE("deepResonance", "sound_deep_resonance"),
    @SerialName("minimalTap") MINIMAL_TAP("minimalTap", "sound_minimal_tap"),

    /** The device's default alarm ringtone, resolved through RingtoneManager. */
    @SerialName("systemDefault") SYSTEM_DEFAULT("systemDefault", null);

    val usesSystemAlarmTone: Boolean
        get() = this == SYSTEM_DEFAULT
}

@Serializable
data class ResolvedLocation(
    val latitude: Double,
    val longitude: Double,
    val formattedAddress: String
)

/**
 * Snapshot of every setting the scheduling flow reads. Comparing the stored
 * snapshot against the live settings tells whether the scheduled alarm still
 * matches what the user currently has configured.
 */
@Serializable
data class AlarmScheduleFingerprint(
    val homeAddress: String,
    val workAddress: String,
    val commuteMode: CommuteMode,
    val alarmHour: Int,
    val alarmMinute: Int,
    val selectedWeekdays: Set<Int>,
    val rainLeadTimeMinutes: Int,
    val rainProbabilityThreshold: Double,
    val alarmSoundRawValue: String,
    val isSnoozeEnabled: Boolean,
    val snoozeDurationMinutes: Int
)
