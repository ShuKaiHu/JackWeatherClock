package com.shukaihu.rainyclock.ui

import android.text.format.DateFormat
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.RemoveCircleOutline
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.PlayCircle
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.graphics.Color
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.model.AlarmSound
import com.shukaihu.rainyclock.model.ScheduledAlarmSummary
import com.shukaihu.rainyclock.ui.theme.AppAccent
import com.shukaihu.rainyclock.ui.theme.AppCard
import com.shukaihu.rainyclock.ui.theme.SecondaryOnBlack
import com.shukaihu.rainyclock.ui.theme.SecondaryOnCard
import com.shukaihu.rainyclock.ui.theme.StatusPositive
import com.shukaihu.rainyclock.ui.theme.StatusWarning
import kotlin.math.roundToInt
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** The gap between the free-floating cards, and the page's side inset. */
private val PageSpacing = 22.dp
private val PageInset = 20.dp

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
            .padding(horizontal = PageInset)
            .padding(bottom = PageInset),
        verticalArrangement = Arrangement.spacedBy(PageSpacing)
    ) {
        // No "Alarm" heading and no "Repeat" label: iOS hides its navigation bar
        // on this tab and lets the two cards carry the structure instead.
        IosCard(cornerRadius = 30.dp, contentPadding = 22.dp, spacing = 20.dp) {
            WeekdaySelector(selected = state.settings.selectedWeekdays, onToggle = onWeekdayToggle)
            AlarmTimeReadout(
                hour = state.settings.alarmHour,
                minute = state.settings.alarmMinute,
                onClick = { showTimePicker = true }
            )
        }

        IosCard(cornerRadius = 24.dp, contentPadding = 18.dp, spacing = 18.dp) {
            IosSliderRow(
                label = stringResource(R.string.rain_lead_time),
                valueText = stringResource(
                    R.string.rain_lead_time_value,
                    state.settings.rainLeadTimeMinutes
                ),
                value = state.settings.rainLeadTimeMinutes.toFloat(),
                valueRange = 1f..60f,
                steps = 58,
                onValueChange = { onLeadTimeChange(it.roundToInt()) }
            )

            IosSliderRow(
                label = stringResource(R.string.rain_threshold),
                valueText = "${(state.settings.rainProbabilityThreshold * 100).toInt()}%",
                value = state.settings.rainProbabilityThreshold.toFloat(),
                valueRange = 0.1f..0.9f,
                steps = 15,
                onValueChange = { onThresholdChange(Math.round(it * 20.0) / 20.0) }
            )

            SoundRow(
                selected = state.settings.alarmSound,
                onSoundChange = onSoundChange,
                onPreviewSound = onPreviewSound
            )

            IosRow(label = stringResource(R.string.snooze)) {
                IosSwitch(
                    checked = state.settings.isSnoozeEnabled,
                    onCheckedChange = onSnoozeEnabledChange
                )
            }

            if (state.settings.isSnoozeEnabled) {
                IosSliderRow(
                    label = stringResource(R.string.snooze_duration),
                    valueText = stringResource(
                        R.string.snooze_duration_value,
                        state.settings.snoozeDurationMinutes
                    ),
                    value = state.settings.snoozeDurationMinutes.toFloat(),
                    valueRange = 1f..15f,
                    steps = 13,
                    onValueChange = { onSnoozeDurationChange(it.roundToInt()) }
                )
            }

            // Sits inside the settings card on iOS, not at the very bottom of
            // the page, and is plain accent text rather than a bordered button.
            if (privacyOptionsRequired) {
                IosRow(label = stringResource(R.string.ad_privacy_options)) {
                    Text(
                        text = stringResource(R.string.ad_privacy_options_manage),
                        color = AppAccent,
                        fontSize = IosBody,
                        lineHeight = IosBodyLine,
                        modifier = Modifier
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                role = Role.Button,
                                onClick = onShowPrivacyOptions
                            )
                            .padding(vertical = 12.dp)
                    )
                }
            }
        }

        IosProminentButton(
            text = if (state.isScheduling) {
                stringResource(R.string.checking_route)
            } else {
                stringResource(R.string.schedule_smart_alarm)
            },
            icon = Icons.Outlined.Alarm,
            onClick = onScheduleClick,
            enabled = !state.isScheduling
        )

        StatusLineText(status = state.status)

        state.summary?.let { summary ->
            ScheduledResultCard(summary = summary)
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

/**
 * The alarm time as iOS shows it: no label, no accent, just the time itself set
 * huge and centred across the card, with the whole strip tappable.
 *
 * iOS sets it in SF Pro Rounded. Android has no rounded system face and
 * bundling one for a single string would add a font file, a licence to track
 * and a different typographic character anyway, so this uses the platform
 * default. It is the one deliberate typographic difference between the two
 * apps.
 */
@Composable
private fun AlarmTimeReadout(hour: Int, minute: Int, onClick: () -> Unit) {
    val time = LocalTime.of(hour, minute)
        .format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT))
    // Sighted users read "the alarm time" from the size and position; a screen
    // reader would otherwise reach a bare time with nothing saying what it is
    // or that it opens a picker. iOS drops the visible label, not the meaning.
    val label = stringResource(R.string.normal_alarm)

    Text(
        text = time,
        color = Color.White,
        fontSize = 60.sp,
        lineHeight = 72.sp,
        fontWeight = FontWeight.Normal,
        maxLines = 1,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Button,
                onClick = onClick
            )
            .semantics { contentDescription = "$label, $time" }
    )
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
 * Seven day chips across the card. Selected days are accent discs with white
 * labels; **unselected days show no disc at all** — their circle is filled with
 * the card's own colour, so what remains is dim text floating on the card. That
 * is the iOS design, not an oversight: adding a ring or a lighter fill to
 * "correct" it is the most common way this row gets ported wrong.
 *
 * The circle grows with the system font scale rather than staying at 40dp. It
 * used to be fixed, so anyone who had enlarged their font saw seven ellipses
 * instead of seven day names: the label scaled, the box did not. Above a
 * scale of 1.3 the row also wraps to four per line, because seven circles wide
 * enough to hold scaled-up text do not fit across a phone at any size. This is
 * the same defect, and the same shape of fix, that iOS took on 2026-08-09.
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
    ).map { stringResource(it) }

    val fontScale = LocalDensity.current.fontScale
    // Capped so the largest accessibility scale cannot produce a chip taller
    // than the alarm time it sits under.
    val rowHeight = 44.dp * fontScale.coerceIn(1f, 1.9f)
    val columns = if (fontScale > 1.3f) 4 else 7
    val rows = labels.chunked(columns)
    val spacing = 12.dp

    BoxWithConstraints {
        val chipWidth = (maxWidth - spacing * (columns - 1)) / columns
        // iOS inscribes the disc in the chip frame, so it is the narrower of the
        // two dimensions that sets the diameter — usually the width, which is
        // why the disc is ~35dp rather than the row's 44dp.
        val diameter = if (chipWidth < rowHeight) chipWidth else rowHeight
        val labelSize = fittedLabelSize(labels, chipWidth - 8.dp, 16.sp)

        Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
            rows.forEachIndexed { rowIndex, rowLabels ->
                Row(horizontalArrangement = Arrangement.spacedBy(spacing)) {
                    rowLabels.forEachIndexed { indexInRow, label ->
                        val weekday = rowIndex * columns + indexInRow + 1
                        WeekdayChip(
                            label = label,
                            isSelected = selected.contains(weekday),
                            width = chipWidth,
                            height = rowHeight,
                            diameter = diameter,
                            labelSize = labelSize,
                            onClick = { onToggle(weekday) }
                        )
                    }
                    // Keep the short trailing row's chips the same width as the
                    // full row's instead of letting them stretch.
                    repeat(columns - rowLabels.size) {
                        Box(Modifier.size(width = chipWidth, height = rowHeight))
                    }
                }
            }
        }
    }
}

@Composable
private fun WeekdayChip(
    label: String,
    isSelected: Boolean,
    width: Dp,
    height: Dp,
    diameter: Dp,
    labelSize: TextUnit,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(width = width, height = height)
            // Selected days differ from unselected ones only by a fill that is
            // invisible when off, so the state has to be spoken rather than
            // shown. `toggleable` is what says it; a plain `clickable` would
            // announce seven identical buttons.
            .toggleable(
                value = isSelected,
                onValueChange = { onClick() },
                role = Role.Checkbox,
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(diameter)
                .background(if (isSelected) AppAccent else AppCard, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = label,
                color = if (isSelected) Color.White else Color.White.copy(alpha = 0.45f),
                fontSize = labelSize,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1
            )
        }
    }
}

/**
 * One type size shared by all seven chips, shrunk until the widest label fits.
 * Sizing each chip independently would leave the row with seven different type
 * sizes; picking a constant would clip "Wed" in English and every label at a
 * large font scale.
 */
@Composable
private fun fittedLabelSize(labels: List<String>, available: Dp, base: TextUnit): TextUnit {
    val measurer = rememberTextMeasurer()
    val availablePx = with(LocalDensity.current) { available.toPx() }
    if (availablePx <= 0f) return base
    val style = TextStyle(fontSize = base, fontWeight = FontWeight.SemiBold)
    val widest = labels.maxOf { measurer.measure(AnnotatedString(it), style).size.width }
    if (widest <= 0) return base
    return base * (availablePx / widest).coerceIn(0.5f, 1f)
}

/**
 * iOS renders the tone name as a bare `Menu` label — no box, no chevron — in a
 * dim desaturated blue, and pairs it with a filled play disc.
 *
 * Unlike iOS, the play button stays visible for the system default tone:
 * `AlarmViewModel` falls back to the platform's default alarm sound, so there
 * genuinely is something to preview. iOS hides it because there is no bundled
 * file behind that choice.
 */
@Composable
private fun SoundRow(
    selected: AlarmSound,
    onSoundChange: (AlarmSound) -> Unit,
    onPreviewSound: (AlarmSound) -> Unit
) {
    IosMenuRow(
        label = stringResource(R.string.alarm_sound),
        selected = selected,
        options = AlarmSound.entries,
        optionLabel = { stringResource(it.labelResId()) },
        onSelect = onSoundChange
    ) {
        Box(Modifier.size(width = 8.dp, height = 1.dp))
        // The disc stays iOS's 22dp while the tappable box overflows to the 44dp
        // the replaced `IconButton` guaranteed — `requiredSize` is what keeps the
        // bigger target from stretching the row.
        Box(
            modifier = Modifier.size(22.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .requiredSize(44.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        role = Role.Button
                    ) { onPreviewSound(selected) },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Rounded.PlayCircle,
                    contentDescription = stringResource(R.string.preview_alarm_sound),
                    tint = AppAccent,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}

@Composable
private fun StatusLineText(status: StatusLine) {
    val text = when (status.args.size) {
        0 -> stringResource(status.textResId)
        1 -> stringResource(status.textResId, status.args[0])
        else -> stringResource(status.textResId, status.args[0], status.args[1])
    }
    val colour = when (status.tone) {
        StatusTone.POSITIVE -> StatusPositive
        StatusTone.WARNING -> StatusWarning
        StatusTone.ERROR -> MaterialTheme.colorScheme.error
        StatusTone.NEUTRAL -> SecondaryOnBlack
    }
    // Colour answers "is an alarm actually armed right now?" at a glance, and
    // the icon says the same thing again for anyone who cannot separate the
    // greens from the oranges.
    val icon = when (status.tone) {
        StatusTone.POSITIVE -> Icons.Rounded.CheckCircle
        StatusTone.WARNING, StatusTone.ERROR -> Icons.Rounded.Warning
        StatusTone.NEUTRAL -> Icons.Outlined.RemoveCircleOutline
    }

    IosStatusLine(
        icon = icon,
        text = text,
        colour = colour,
        emphasised = status.tone != StatusTone.NEUTRAL
    )
}

@Composable
private fun ScheduledResultCard(summary: ScheduledAlarmSummary) {
    val timeFormatter = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)
    val dateTimeFormatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
    val zone = ZoneId.systemDefault()

    IosCard(cornerRadius = 24.dp, contentPadding = 18.dp, spacing = 12.dp) {
        Text(
            text = stringResource(R.string.scheduled_result),
            color = Color.White,
            fontSize = IosBody,
            lineHeight = IosBodyLine,
            fontWeight = FontWeight.SemiBold
        )
        // iOS repeats its stale warning inside this card, but its status line
        // carries a *different* sentence. Here `AlarmViewModel` already sets the
        // status line to `schedule_stale_notice` on every path that sets
        // `isStale`, so adding it again would print the same paragraph twice.
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

/** Grey title flush left, white value flush right — iOS's `MetricRow`. */
@Composable
private fun MetricRow(title: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            color = SecondaryOnCard,
            fontSize = IosBody,
            lineHeight = IosBodyLine,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = value,
            color = Color.White,
            fontSize = IosBody,
            lineHeight = IosBodyLine,
            textAlign = TextAlign.End
        )
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
