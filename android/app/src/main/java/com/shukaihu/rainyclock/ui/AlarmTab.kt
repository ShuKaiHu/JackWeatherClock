package com.shukaihu.rainyclock.ui

import android.text.format.DateFormat
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.model.AlarmSound
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@Composable
fun AlarmTab(
    state: AlarmUiState,
    modifier: Modifier = Modifier,
    privacyOptionsRequired: Boolean,
    onAlarmTimeChange: (hour: Int, minute: Int) -> Unit,
    onWeekdayToggle: (Int) -> Unit,
    onLeadTimeChange: (Int) -> Unit,
    onThresholdChange: (Double) -> Unit,
    onSoundChange: (AlarmSound) -> Unit,
    onPreviewSound: (AlarmSound) -> Unit,
    onSnoozeEnabledChange: (Boolean) -> Unit,
    onSnoozeDurationChange: (Int) -> Unit,
    onScheduleClick: () -> Unit,
    onShowPrivacyOptions: () -> Unit
) {
    var showTimePicker by rememberSaveable { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = stringResource(R.string.alarm), style = MaterialTheme.typography.titleMedium)

        // Normal alarm time — system-formatted, honoring 24-hour time
        // (the iOS build once forced a 12-hour clock here; don't repeat it).
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { showTimePicker = true },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(text = stringResource(R.string.normal_alarm), modifier = Modifier.weight(1f))
            Text(
                text = LocalTime.of(state.settings.alarmHour, state.settings.alarmMinute)
                    .format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }

        WeekdaySelector(selected = state.settings.selectedWeekdays, onToggle = onWeekdayToggle)

        LabeledSlider(
            label = stringResource(R.string.rain_lead_time),
            valueText = stringResource(R.string.rain_lead_time_value, state.settings.rainLeadTimeMinutes),
            value = state.settings.rainLeadTimeMinutes.toFloat(),
            valueRange = 1f..60f,
            steps = 58,
            onValueChange = { onLeadTimeChange(it.toInt()) }
        )

        LabeledSlider(
            label = stringResource(R.string.rain_threshold),
            valueText = "${(state.settings.rainProbabilityThreshold * 100).toInt()}%",
            value = state.settings.rainProbabilityThreshold.toFloat(),
            valueRange = 0.1f..0.9f,
            steps = 15,
            onValueChange = { onThresholdChange((Math.round(it * 20.0) / 20.0)) }
        )

        SoundPicker(
            selected = state.settings.alarmSound,
            onSoundChange = onSoundChange,
            onPreviewSound = onPreviewSound
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = stringResource(R.string.snooze), modifier = Modifier.weight(1f))
            Switch(
                checked = state.settings.isSnoozeEnabled,
                onCheckedChange = onSnoozeEnabledChange
            )
        }

        if (state.settings.isSnoozeEnabled) {
            LabeledSlider(
                label = stringResource(R.string.snooze_duration),
                valueText = stringResource(R.string.snooze_duration_value, state.settings.snoozeDurationMinutes),
                value = state.settings.snoozeDurationMinutes.toFloat(),
                valueRange = 1f..15f,
                steps = 13,
                onValueChange = { onSnoozeDurationChange(it.toInt()) }
            )
        }

        Button(
            onClick = onScheduleClick,
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isScheduling
        ) {
            Text(stringResource(R.string.schedule_smart_alarm))
        }

        StatusLineText(status = state.status)

        state.summary?.let { summary ->
            ScheduledResultCard(summary = summary)
        }

        if (privacyOptionsRequired) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = stringResource(R.string.ad_privacy_options), modifier = Modifier.weight(1f))
                TextButton(onClick = onShowPrivacyOptions) {
                    Text(stringResource(R.string.ad_privacy_options_manage))
                }
            }
        }
    }

    if (showTimePicker) {
        AlarmTimePickerDialog(
            initialHour = state.settings.alarmHour,
            initialMinute = state.settings.alarmMinute,
            onConfirm = { hour, minute ->
                onAlarmTimeChange(hour, minute)
                showTimePicker = false
            },
            onDismiss = { showTimePicker = false }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlarmTimePickerDialog(
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (hour: Int, minute: Int) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val timePickerState = rememberTimePickerState(
        initialHour = initialHour,
        initialMinute = initialMinute,
        is24Hour = DateFormat.is24HourFormat(context)
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.normal_alarm)) },
        text = { TimePicker(state = timePickerState) },
        confirmButton = {
            TextButton(onClick = { onConfirm(timePickerState.hour, timePickerState.minute) }) {
                Text(stringResource(R.string.done))
            }
        }
    )
}

/**
 * Selected days are filled circles with contrasting text, unselected days
 * plain dim text — the 1.6.4 redesign, ported. Weekday 1 = Sunday.
 */
@Composable
private fun WeekdaySelector(selected: Set<Int>, onToggle: (Int) -> Unit) {
    val labels = listOf(
        R.string.weekday_sunday_short,
        R.string.weekday_monday_short,
        R.string.weekday_tuesday_short,
        R.string.weekday_wednesday_short,
        R.string.weekday_thursday_short,
        R.string.weekday_friday_short,
        R.string.weekday_saturday_short
    )

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(text = stringResource(R.string.repeat_days), style = MaterialTheme.typography.titleSmall)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            labels.forEachIndexed { index, labelResId ->
                val weekday = index + 1
                val isSelected = selected.contains(weekday)
                Surface(
                    shape = CircleShape,
                    color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
                    modifier = Modifier
                        .size(40.dp)
                        .clickable { onToggle(weekday) }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            text = stringResource(labelResId),
                            color = if (isSelected) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun LabeledSlider(
    label: String,
    valueText: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    onValueChange: (Float) -> Unit
) {
    Column {
        Row {
            Text(text = label, modifier = Modifier.weight(1f))
            Text(text = valueText, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
            steps = steps
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SoundPicker(
    selected: AlarmSound,
    onSoundChange: (AlarmSound) -> Unit,
    onPreviewSound: (AlarmSound) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it },
            modifier = Modifier.weight(1f)
        ) {
            OutlinedTextField(
                value = stringResource(selected.labelResId()),
                onValueChange = {},
                readOnly = true,
                label = { Text(stringResource(R.string.alarm_sound)) },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    .fillMaxWidth()
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                AlarmSound.entries.forEach { sound ->
                    DropdownMenuItem(
                        text = { Text(stringResource(sound.labelResId())) },
                        onClick = {
                            onSoundChange(sound)
                            expanded = false
                        }
                    )
                }
            }
        }
        IconButton(onClick = { onPreviewSound(selected) }) {
            Icon(
                imageVector = Icons.Filled.PlayArrow,
                contentDescription = stringResource(R.string.preview_alarm_sound)
            )
        }
    }
}

@Composable
private fun StatusLineText(status: StatusLine) {
    val color = when (status.tone) {
        StatusTone.POSITIVE -> com.shukaihu.rainyclock.ui.theme.StatusPositive
        StatusTone.WARNING -> com.shukaihu.rainyclock.ui.theme.StatusWarning
        StatusTone.ERROR -> MaterialTheme.colorScheme.error
        StatusTone.NEUTRAL -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val text = when (status.args.size) {
        0 -> stringResource(status.textResId)
        1 -> stringResource(status.textResId, status.args[0])
        else -> stringResource(status.textResId, status.args[0], status.args[1])
    }
    Text(text = text, color = color, style = MaterialTheme.typography.bodyMedium)
}

@Composable
private fun ScheduledResultCard(summary: ScheduledAlarmSummary) {
    val timeFormatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
    val dateTimeFormatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
    val zone = ZoneId.systemDefault()

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(text = stringResource(R.string.scheduled_result), style = MaterialTheme.typography.titleSmall)
            MetricRow(
                title = stringResource(R.string.normal_alarm),
                value = timeFormatter.format(summary.normalAlarmDate.atZone(zone))
            )
            MetricRow(
                title = stringResource(R.string.scheduled_alarm),
                value = dateTimeFormatter.format(summary.scheduledAlarmDate.atZone(zone))
            )
            MetricRow(
                title = stringResource(R.string.weather_refresh),
                value = dateTimeFormatter.format(summary.weatherRefreshDate.atZone(zone))
            )
            MetricRow(
                title = stringResource(R.string.rain_threshold),
                value = "${(summary.rainProbabilityThreshold * 100).toInt()}%"
            )
            MetricRow(
                title = stringResource(R.string.route_max),
                value = "${(summary.maximumPrecipitationProbability * 100).toInt()}%"
            )
            MetricRow(
                title = stringResource(R.string.rain_adjustment),
                value = if (summary.exceedsRainThreshold) {
                    stringResource(R.string.minutes_earlier, summary.leadTimeMinutes)
                } else {
                    stringResource(R.string.not_applied)
                }
            )
        }
    }
}

@Composable
private fun MetricRow(title: String, value: String) {
    Row {
        Text(text = title, modifier = Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value)
    }
}

private fun AlarmSound.labelResId(): Int = when (this) {
    AlarmSound.RAINY_CLOCK -> R.string.alarm_sound_rainy_clock
    AlarmSound.MORNING_BELL -> R.string.alarm_sound_morning_bell
    AlarmSound.SOFT_PIANO -> R.string.alarm_sound_soft_piano
    AlarmSound.BRIGHT_CHIME -> R.string.alarm_sound_bright_chime
    AlarmSound.GENTLE_WAVES -> R.string.alarm_sound_gentle_waves
    AlarmSound.DIGITAL_BEEP -> R.string.alarm_sound_digital_beep
    AlarmSound.FOREST_BIRDS -> R.string.alarm_sound_forest_birds
    AlarmSound.ENERGETIC_PULSE -> R.string.alarm_sound_energetic_pulse
    AlarmSound.DEEP_RESONANCE -> R.string.alarm_sound_deep_resonance
    AlarmSound.MINIMAL_TAP -> R.string.alarm_sound_minimal_tap
    AlarmSound.SYSTEM_DEFAULT -> R.string.alarm_sound_system_default
}
