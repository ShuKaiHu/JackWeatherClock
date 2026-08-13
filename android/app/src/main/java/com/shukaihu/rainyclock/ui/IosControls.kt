package com.shukaihu.rainyclock.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shukaihu.rainyclock.ui.theme.AppAccent
import com.shukaihu.rainyclock.ui.theme.AppCard
import com.shukaihu.rainyclock.ui.theme.AppSliderTrackOff
import com.shukaihu.rainyclock.ui.theme.AppSwitchTrackOff
import com.shukaihu.rainyclock.ui.theme.AppTabBarFill
import com.shukaihu.rainyclock.ui.theme.AppTabBarRim
import com.shukaihu.rainyclock.ui.theme.AppTabBarSelected
import com.shukaihu.rainyclock.ui.theme.DisabledButtonFill
import com.shukaihu.rainyclock.ui.theme.DisabledButtonLabel
import com.shukaihu.rainyclock.ui.theme.MenuBackground
import com.shukaihu.rainyclock.ui.theme.SecondaryOnBlack
import com.shukaihu.rainyclock.ui.theme.SecondaryOnCard

/**
 * SwiftUI-shaped controls for the Compose port.
 *
 * Every number here was measured off the running iOS app rather than recalled
 * from a spec sheet, because the app is built against the iOS 26 SDK and gets
 * the Liquid Glass rendering of the stock controls — which is not what any
 * pre-iOS-26 reference describes. In particular the slider thumb and the switch
 * knob are **wide capsules, not circles** (36 x 23pt, radius 11.5), the slider
 * rail is a thin 6pt line whose unfilled half is nearly invisible, and stepped
 * sliders draw **no tick marks at all**. Material's defaults differ on every one
 * of those points, which is why these exist instead of the stock components.
 */

/** iOS body text: 17pt. The tabs and cards are laid out around this. */
val IosBody = 17.sp
private val IosSubheadline = 15.sp
private val IosCaption = 12.sp

/**
 * Line heights have to be stated alongside every size. Compose falls back to
 * `LocalTextStyle`, which here is Material's `bodyLarge` — a fixed 24sp line box
 * whatever `fontSize` says — so a 12sp tab caption was reserving two thirds more
 * height than its glyphs need and inflating the tab bar with it. These are iOS's
 * measured line heights: 20.33pt for body, and the same 4:3-ish ratio elsewhere.
 */
val IosBodyLine = 20.sp
private val IosSubheadlineLine = 18.sp
private val IosCaptionLine = 15.sp

// Slider — measured 36.33 x 23.33pt thumb on a 6pt rail.
private val SliderThumbWidth = 36.dp
private val SliderThumbHeight = 23.dp
private val SliderTrackHeight = 6.dp

/**
 * iOS lays the slider out in a 31pt slot. Android's guidance asks for 48dp of
 * touch height, so this splits the difference: the visual is iOS's, the drag
 * strip is a little taller than iOS ships. It stays comfortably grabbable
 * because the target is the full width of the card, not a small puck.
 */
private val SliderSlotHeight = 34.dp

// Switch — measured 63 x 28pt track carrying the same capsule knob.
private val SwitchTrackWidth = 63.dp
private val SwitchTrackHeight = 28.dp
private val SwitchKnobInset = 2.5.dp

/**
 * A card the way `RoundedRectangle(cornerRadius:style:.continuous)` draws one.
 *
 * Compose has no continuous-corner (squircle) shape, so this is a circular-arc
 * approximation; at these radii the difference shows only at the corner
 * shoulders.
 */
@Composable
fun IosCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 24.dp,
    contentPadding: Dp = 18.dp,
    spacing: Dp = 18.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(AppCard, RoundedCornerShape(cornerRadius))
            .padding(contentPadding),
        verticalArrangement = Arrangement.spacedBy(spacing),
        content = content
    )
}

/**
 * The stock SwiftUI slider as iOS 26 actually draws it: a 6pt rail, accent to
 * the left of the handle and a barely-there grey to the right, a white capsule
 * handle sitting over the join, and no ticks even though every slider here is
 * stepped.
 *
 * Material's gesture handling and accessibility semantics are kept — only the
 * drawing is replaced. That deliberately leaves one behavioural difference from
 * iOS: tapping the rail jumps the handle here, where UIKit only tracks touches
 * that start on the handle itself. Android users expect the tap, and it cannot
 * be seen in a screenshot.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IosSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    val span = (valueRange.endInclusive - valueRange.start).let { if (it > 0f) it else 1f }
    val fraction = ((value - valueRange.start) / span).coerceIn(0f, 1f)

    Slider(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .height(SliderSlotHeight),
        enabled = enabled,
        valueRange = valueRange,
        steps = steps,
        colors = SliderDefaults.colors(
            thumbColor = Color.White,
            activeTrackColor = AppAccent,
            inactiveTrackColor = AppSliderTrackOff,
            activeTickColor = Color.Transparent,
            inactiveTickColor = Color.Transparent
        ),
        thumb = { IosSliderThumb() },
        track = { IosSliderTrack(fraction) }
    )
}

@Composable
private fun IosSliderThumb() {
    Box(
        Modifier
            .size(width = SliderThumbWidth, height = SliderThumbHeight)
            .background(Color.White, RoundedCornerShape(percent = 50))
    )
}

/**
 * Drawn rather than composed for two reasons. The active fill has to run *under*
 * the handle — Material 3.1 opens a gap on either side of the thumb and iOS has
 * none, which is the single most obvious tell that a slider is Material. And the
 * rail has to reach the full width of the card: Material insets the track by half
 * a thumb so the handle can never overhang, where iOS runs the rail edge to edge
 * and lets the handle sit over the ends. Hence the deliberate overdraw of half a
 * thumb width beyond this slot on each side, which is exactly what Material took
 * away.
 */
@Composable
private fun IosSliderTrack(fraction: Float) {
    Canvas(
        Modifier
            .fillMaxWidth()
            .height(SliderSlotHeight)
    ) {
        val trackHeight = SliderTrackHeight.toPx()
        val radius = CornerRadius(trackHeight / 2f)
        val top = (size.height - trackHeight) / 2f
        val overhang = SliderThumbWidth.toPx() / 2f
        // Material mirrors the handle itself under a right-to-left layout, so
        // the fill has to be mirrored with it or the two would travel in
        // opposite directions. The app ships English and Traditional Chinese
        // today, but the manifest allows RTL.
        val mirrored = layoutDirection == LayoutDirection.Rtl
        val handleAt = if (mirrored) (1f - fraction) * size.width else fraction * size.width

        drawRoundRect(
            color = AppSliderTrackOff,
            topLeft = Offset(-overhang, top),
            size = Size(size.width + overhang * 2f, trackHeight),
            cornerRadius = radius
        )
        drawRoundRect(
            color = AppAccent,
            topLeft = Offset(if (mirrored) handleAt else -overhang, top),
            size = Size(
                if (mirrored) size.width - handleAt + overhang else handleAt + overhang,
                trackHeight
            ),
            cornerRadius = radius
        )
        // iOS's handle shadow reads on this near-black card only as a faint
        // darkening of the rail just left of the handle. A real elevation
        // shadow would be invisible against the card, so it is painted by hand
        // — and kept weak, because anything heavier reads as a dark blob rather
        // than a shadow.
        val glowRadius = SliderThumbWidth.toPx() * 0.5f
        val glowCentre = Offset(handleAt, size.height / 2f + 1.5.dp.toPx())
        drawCircle(
            brush = Brush.radialGradient(
                0.45f to Color.Black.copy(alpha = 0.12f),
                1f to Color.Transparent,
                center = glowCentre,
                radius = glowRadius
            ),
            radius = glowRadius,
            center = glowCentre
        )
    }
}

/** Label on the left, current value hard against the right, slider beneath. */
@Composable
fun IosSliderRow(
    label: String,
    valueText: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int,
    onValueChange: (Float) -> Unit
) {
    Column {
        IosRow(label = label) {
            Text(
                text = valueText,
                color = SecondaryOnCard,
                fontSize = IosBody,
                lineHeight = IosBodyLine
            )
        }
        IosSlider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
            steps = steps
        )
    }
}

/**
 * A settings row: white label on the left, whatever the caller supplies pinned
 * to the right. iOS builds every row in both cards this way.
 */
@Composable
fun IosRow(
    label: String,
    modifier: Modifier = Modifier,
    trailing: @Composable RowScope.() -> Unit
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = IosBody,
            lineHeight = IosBodyLine,
            modifier = Modifier.weight(1f)
        )
        trailing()
    }
}

/**
 * The stock iOS switch: a 63 x 28pt capsule with the same white capsule knob
 * the slider uses. Material's switch is a different shape entirely — a circular
 * thumb that grows when checked, an outline when off, and room for an icon.
 */
@Composable
fun IosSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val trackColour by animateColorAsState(
        targetValue = if (checked) AppAccent else AppSwitchTrackOff,
        animationSpec = tween(durationMillis = 200),
        label = "switchTrack"
    )
    val knobOffset by animateDpAsState(
        targetValue = if (checked) {
            SwitchTrackWidth - SliderThumbWidth - SwitchKnobInset
        } else {
            SwitchKnobInset
        },
        animationSpec = tween(durationMillis = 200),
        label = "switchKnob"
    )

    // The track is iOS's 28dp; the touch area is Android's 48dp. `requiredSize`
    // is what lets both be true — it makes the tappable box overflow its parent
    // rather than stretch it, so Material's guaranteed 48dp comes back without
    // the settings row growing 20dp taller than the iPhone's.
    Box(
        modifier = modifier.size(width = SwitchTrackWidth, height = SwitchTrackHeight),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .requiredSize(width = SwitchTrackWidth, height = 48.dp)
                .toggleable(
                    value = checked,
                    onValueChange = onCheckedChange,
                    role = Role.Switch,
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ),
            contentAlignment = Alignment.Center
        ) {
            Box(
                Modifier
                    .size(width = SwitchTrackWidth, height = SwitchTrackHeight)
                    .background(trackColour, RoundedCornerShape(percent = 50))
            ) {
                Box(
                    Modifier
                        .align(Alignment.CenterStart)
                        .offset(x = knobOffset)
                        .size(width = SliderThumbWidth, height = SliderThumbHeight)
                        .background(Color.White, RoundedCornerShape(percent = 50))
                )
            }
        }
    }
}

/**
 * iOS presents the alarm-tone choice as a `Menu`, which renders as bare text
 * with no box and no chevron. Its colour is the surprise: `.secondary` on a
 * Menu label resolves against the menu's *tint*, so the value reads as a dim,
 * desaturated blue — accent at half opacity — rather than grey.
 */
@Composable
fun <T> IosMenuRow(
    label: String,
    selected: T,
    options: List<T>,
    optionLabel: @Composable (T) -> String,
    onSelect: (T) -> Unit,
    trailing: @Composable RowScope.() -> Unit = {}
) {
    var expanded by remember { mutableStateOf(false) }

    IosRow(label = label) {
        Box {
            Text(
                text = optionLabel(selected),
                color = AppAccent.copy(alpha = 0.5f),
                fontSize = IosBody,
                lineHeight = IosBodyLine,
                modifier = Modifier.clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { expanded = true }
            )
            // The container colour has to be stated. Material resolves a menu's
            // background from `surfaceContainer`, which this theme pins to pure
            // black so the tab strip sits flat on the canvas — leaving the menu
            // an invisible black panel on a black page, with no edge at all.
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                shape = RoundedCornerShape(14.dp),
                containerColor = MenuBackground,
                tonalElevation = 0.dp,
                shadowElevation = 8.dp
            ) {
                options.forEach { option ->
                    val text = optionLabel(option)
                    DropdownMenuItem(
                        text = { Text(text) },
                        trailingIcon = {
                            if (option == selected) {
                                Icon(
                                    imageVector = Icons.Rounded.Check,
                                    contentDescription = null,
                                    tint = AppAccent,
                                    modifier = Modifier.size(18.dp)
                                )
                            }
                        },
                        onClick = {
                            onSelect(option)
                            expanded = false
                        }
                    )
                }
            }
        }
        trailing()
    }
}

/**
 * `.buttonStyle(.borderedProminent)` on iOS 26 is a full capsule, not the
 * rounded rectangle it drew through iOS 18.
 */
@Composable
fun IosProminentButton(
    text: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(46.dp)
            .background(
                color = if (enabled) AppAccent else DisabledButtonFill,
                shape = RoundedCornerShape(percent = 50)
            )
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Button,
                onClick = onClick
            ),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        val contentColour = if (enabled) Color.White else DisabledButtonLabel
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = contentColour,
            modifier = Modifier.size(19.dp)
        )
        Box(Modifier.width(6.dp))
        Text(text = text, color = contentColour, fontSize = IosBody, lineHeight = IosBodyLine)
    }
}

/**
 * The floating capsule that replaces the system tab bar. `.ultraThinMaterial`
 * has no Compose equivalent below API 31 and nothing to blur here anyway — the
 * bar sits on the app's black canvas — so the fill is the flat colour sampled
 * off the running app rather than a stack of translucent layers, which would
 * come out lighter than iOS.
 */
@Composable
fun <T> IosCapsuleTabBar(
    tabs: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    icon: (T) -> ImageVector,
    title: @Composable (T) -> String
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 34.dp)
            .padding(top = 12.dp, bottom = 22.dp)
            .background(AppTabBarFill, RoundedCornerShape(percent = 50))
            .border(1.dp, AppTabBarRim, RoundedCornerShape(percent = 50))
            .padding(6.dp)
    ) {
        tabs.forEach { tab ->
            val isSelected = tab == selected
            val tint by animateColorAsState(
                targetValue = if (isSelected) AppAccent else SecondaryOnBlack,
                animationSpec = tween(durationMillis = 350),
                label = "tabTint"
            )
            val pill by animateColorAsState(
                targetValue = if (isSelected) AppTabBarSelected else Color.Transparent,
                animationSpec = tween(durationMillis = 350),
                label = "tabPill"
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .background(pill, RoundedCornerShape(percent = 50))
                    // `selectable`, not `clickable`: the role alone announces
                    // "tab" but never which one is current, and the only other
                    // cue is colour.
                    .selectable(
                        selected = isSelected,
                        onClick = { onSelect(tab) },
                        role = Role.Tab,
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    )
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = icon(tab),
                    contentDescription = null,
                    tint = tint,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = title(tab),
                    color = tint,
                    fontSize = IosCaption,
                    lineHeight = IosCaptionLine,
                    // Only the icon thickens on selection — the label does not.
                    fontWeight = FontWeight.Normal
                )
            }
        }
    }
}

/** A status sentence with its state icon, sitting on the black page. */
@Composable
fun IosStatusLine(icon: ImageVector, text: String, colour: Color, emphasised: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = colour,
            modifier = Modifier.size(16.dp)
        )
        Text(
            text = text,
            color = colour,
            fontSize = IosSubheadline,
            lineHeight = IosSubheadlineLine,
            fontWeight = if (emphasised) FontWeight.SemiBold else FontWeight.Normal
        )
    }
}
