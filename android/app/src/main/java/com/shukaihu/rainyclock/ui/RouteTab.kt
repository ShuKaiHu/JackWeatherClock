package com.shukaihu.rainyclock.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.Polyline
import com.google.maps.android.compose.rememberCameraPositionState
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.model.CommuteMode
import com.shukaihu.rainyclock.model.RoutePreview
import com.shukaihu.rainyclock.model.RouteWeatherSegment
import com.shukaihu.rainyclock.model.WeatherCondition
import com.shukaihu.rainyclock.ui.theme.AppAccent
import com.shukaihu.rainyclock.ui.theme.AppField
import com.shukaihu.rainyclock.ui.theme.SecondaryOnBlack
import com.shukaihu.rainyclock.ui.theme.SecondaryOnCard
import com.shukaihu.rainyclock.ui.theme.StatusWarning
import com.shukaihu.rainyclock.ui.theme.WeatherCardBottom
import com.shukaihu.rainyclock.ui.theme.WeatherCardTop
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** Gap between weather cards, and the unit the W's nesting inset is built from. */
private val SEGMENT_SPACING = 10.dp

private val PageInset = 20.dp
private val PageSpacing = 22.dp

/**
 * Car, Transit, Walking — the order iOS lists them in, minus the scooter pill
 * it keeps and this port deliberately dropped. Declared here rather than by
 * reordering `CommuteMode`, whose declaration order is pinned by a test.
 */
private val ROUTE_MODES = listOf(CommuteMode.CAR, CommuteMode.PUBLIC_TRANSIT, CommuteMode.WALKING)

@Composable
fun RouteTab(
    state: AlarmUiState,
    modifier: Modifier = Modifier,
    isRoutePreviewConfigured: Boolean,
    usesAppleWeather: Boolean,
    onHomeAddressChange: (String) -> Unit,
    onWorkAddressChange: (String) -> Unit,
    onConfirmHomeSuggestion: () -> Unit,
    onConfirmWorkSuggestion: () -> Unit,
    onCommuteModeChange: (CommuteMode) -> Unit,
    onRefreshRouteWeather: () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = PageInset)
            .padding(bottom = PageInset),
        verticalArrangement = Arrangement.spacedBy(PageSpacing)
    ) {
        // No "Commute" heading: iOS opens straight onto the Home field with its
        // navigation bar hidden.
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            AddressField(
                label = stringResource(R.string.home_label),
                placeholder = stringResource(R.string.home_address),
                value = state.settings.homeAddress,
                invalid = state.homeInvalid,
                suggestion = state.homeSuggestion,
                onValueChange = onHomeAddressChange,
                onConfirmSuggestion = onConfirmHomeSuggestion
            )
            AddressField(
                label = stringResource(R.string.work_label),
                placeholder = stringResource(R.string.work_address),
                value = state.settings.workAddress,
                invalid = state.workInvalid,
                suggestion = state.workSuggestion,
                onValueChange = onWorkAddressChange,
                onConfirmSuggestion = onConfirmWorkSuggestion
            )

            ModeRow(
                selected = state.settings.commuteMode,
                onCommuteModeChange = onCommuteModeChange
            )
        }

        // iOS has no such control — it re-runs the preview from every committed
        // address or mode change. Android keeps the button on purpose: the route
        // is a billable Routes API call capped at 300/day, so the refresh stays
        // something the user asks for rather than something typing triggers.
        PreviewRouteButton(
            enabled = state.routeWeather != RouteWeatherState.Loading,
            onClick = onRefreshRouteWeather
        )

        if (isRoutePreviewConfigured) {
            state.routePreview?.let { preview -> RoutePreviewSection(preview) }
        } else {
            Text(
                text = stringResource(R.string.route_preview_requires_key),
                fontSize = 13.sp,
                color = SecondaryOnBlack
            )
        }

        RouteWeatherSection(
            state = state.routeWeather,
            usesAppleWeather = usesAppleWeather
        )
    }
}

/**
 * WeatherKit's terms require the Apple Weather mark shown together with a link
 * to its legal attribution page; Open-Meteo only asks for a credit line.
 *
 * The mark is spelled "Apple Weather" in words, not with the  glyph the iOS
 * app can use: U+F8FF lives in a private use area that only Apple's system
 * fonts fill in, so on Android it renders as nothing at all and the sentence
 * silently becomes "Weather data provided by Weather".
 */
@Composable
private fun WeatherAttribution(usesAppleWeather: Boolean) {
    if (!usesAppleWeather) {
        Text(
            text = stringResource(R.string.weather_data_attribution),
            fontSize = 13.sp,
            color = SecondaryOnBlack
        )
        return
    }

    val uriHandler = LocalUriHandler.current
    Text(
        text = stringResource(R.string.weather_attribution_apple),
        fontSize = 13.sp,
        color = SecondaryOnBlack,
        modifier = Modifier.clickable {
            uriHandler.openUri("https://weatherkit.apple.com/legal-attribution.html")
        }
    )
}

/**
 * iOS fills its address fields rather than outlining them, and puts the field's
 * name *inside* on the left instead of floating it up into a notch cut in a
 * border. An invalid address changes five things at once — fill, border, label,
 * cursor, and a caption underneath — because one of them alone is easy to miss.
 */
@Composable
private fun AddressField(
    label: String,
    placeholder: String,
    value: String,
    invalid: Boolean,
    suggestion: String?,
    onValueChange: (String) -> Unit,
    onConfirmSuggestion: () -> Unit
) {
    val errorColour = MaterialTheme.colorScheme.error
    val shape = RoundedCornerShape(16.dp)
    val focusManager = LocalFocusManager.current
    val focusRequester = remember { FocusRequester() }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    color = if (invalid) errorColour.copy(alpha = 0.20f) else AppField,
                    shape = shape
                )
                .then(
                    if (invalid) Modifier.border(2.5.dp, errorColour, shape) else Modifier
                )
                // `OutlinedTextField` focused itself when its box was tapped
                // anywhere; a bare `BasicTextField` only takes the one text line,
                // so tapping the label or the padding used to do nothing.
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) { focusRequester.requestFocus() }
                .padding(horizontal = 14.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = label,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (invalid) errorColour else SecondaryOnCard,
                maxLines = 1,
                modifier = Modifier.widthIn(min = 44.dp)
            )
            Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) {
                    Text(text = placeholder, fontSize = IosBody, color = SecondaryOnCard, maxLines = 1)
                }
                BasicTextField(
                    value = value,
                    onValueChange = onValueChange,
                    singleLine = true,
                    textStyle = TextStyle(color = Color.White, fontSize = IosBody),
                    cursorBrush = SolidColor(if (invalid) errorColour else AppAccent),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    // Compose's default action handler only knows Next, Previous
                    // and Done, so a Search key with no handler does nothing at
                    // all — not even dismiss the keyboard.
                    keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() }),
                    // The leading "Home"/"Work" text is a sibling, not a label
                    // the field owns, so without this a screen reader reaches an
                    // anonymous edit box. `OutlinedTextField` used to supply it.
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focusRequester)
                        .semantics { contentDescription = label }
                )
            }
            if (value.isNotEmpty()) {
                Box(modifier = Modifier.size(20.dp), contentAlignment = Alignment.Center) {
                    Box(
                        modifier = Modifier
                            .requiredSize(44.dp)
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                role = Role.Button
                            ) { onValueChange("") },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Cancel,
                            contentDescription = stringResource(R.string.clear_address),
                            tint = SecondaryOnCard,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }

        // The error caption and the suggestion footer are alternatives, never
        // both: a field that has a usable suggestion is not simply "not found".
        if (suggestion != null) {
            SuggestionFooter(suggestion = suggestion, onConfirm = onConfirmSuggestion)
        } else if (invalid) {
            Text(
                text = stringResource(R.string.address_not_found_inline),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = errorColour,
                modifier = Modifier.padding(horizontal = 14.dp)
            )
        }
    }
}

@Composable
private fun SuggestionFooter(suggestion: String, onConfirm: () -> Unit) {
    Column(
        modifier = Modifier.padding(horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            Icon(
                imageVector = Icons.Rounded.Warning,
                contentDescription = null,
                tint = StatusWarning,
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = stringResource(R.string.suggested_address_prefix, suggestion),
                fontSize = 12.sp,
                color = StatusWarning
            )
        }
        Text(
            text = stringResource(R.string.confirm_suggested_address),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = StatusWarning,
            modifier = Modifier
                .border(1.dp, StatusWarning.copy(alpha = 0.6f), CircleShape)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    role = Role.Button,
                    onClick = onConfirm
                )
                .padding(horizontal = 14.dp, vertical = 10.dp)
        )
    }
}

/** The label sits inline to the left of the pills, all inside one card. */
@Composable
private fun ModeRow(selected: CommuteMode, onCommuteModeChange: (CommuteMode) -> Unit) {
    IosCard(cornerRadius = 26.dp, contentPadding = 14.dp, spacing = 0.dp) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.mode),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = SecondaryOnCard,
                maxLines = 1,
                modifier = Modifier.widthIn(min = 44.dp)
            )
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                ROUTE_MODES.forEach { mode ->
                    val isSelected = selected == mode
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(38.dp)
                            .background(if (isSelected) AppAccent else AppField, CircleShape)
                            // `selectable` rather than `clickable`: the only
                            // difference between a chosen mode and the rest is
                            // the fill colour, which a screen reader cannot see.
                            // `FilterChip` published this state before.
                            .selectable(
                                selected = isSelected,
                                onClick = { onCommuteModeChange(mode) },
                                role = Role.RadioButton,
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        // Every pill is filled and every label is white — iOS
                        // does not grey out the unselected ones, it only drops
                        // the accent fill.
                        Text(
                            text = stringResource(mode.labelResId()),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White,
                            maxLines = 1,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PreviewRouteButton(enabled: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(46.dp)
            .border(1.dp, AppAccent.copy(alpha = if (enabled) 0.5f else 0.2f), CircleShape)
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Button,
                onClick = onClick
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = stringResource(R.string.preview_route),
            fontSize = IosBody,
            color = if (enabled) AppAccent else AppAccent.copy(alpha = 0.4f)
        )
    }
}

@Composable
private fun RoutePreviewSection(preview: RoutePreview) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            text = stringResource(R.string.route_preview),
            fontSize = IosBody,
            fontWeight = FontWeight.SemiBold,
            color = SecondaryOnBlack
        )
        RoutePreviewMap(preview)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MetricCard(
                title = stringResource(R.string.route_preview_travel_time),
                value = stringResource(R.string.route_preview_minutes_value, preview.durationMinutes),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                title = stringResource(R.string.route_preview_distance),
                value = stringResource(
                    R.string.route_preview_distance_value,
                    preview.distanceMeters / 1000.0f
                ),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun RoutePreviewMap(preview: RoutePreview) {
    val latLngs = remember(preview) { preview.points.map { LatLng(it.latitude, it.longitude) } }
    val cameraPositionState = rememberCameraPositionState()
    var mapLoaded by remember { mutableStateOf(false) }

    LaunchedEffect(mapLoaded, latLngs) {
        if (mapLoaded && latLngs.size >= 2) {
            val bounds = LatLngBounds.builder().apply { latLngs.forEach { include(it) } }.build()
            // move (not animate): the card may recompose while the map settles.
            cameraPositionState.move(CameraUpdateFactory.newLatLngBounds(bounds, 64))
        }
    }

    GoogleMap(
        modifier = Modifier
            .fillMaxWidth()
            .height(240.dp)
            .clip(RoundedCornerShape(18.dp)),
        cameraPositionState = cameraPositionState,
        // The zoom buttons and map toolbar are Material chrome iOS has no
        // equivalent of. The Google wordmark stays — the Maps terms require it.
        uiSettings = MapUiSettings(zoomControlsEnabled = false, mapToolbarEnabled = false),
        onMapLoaded = { mapLoaded = true }
    ) {
        Marker(
            state = MarkerState(position = latLngs.first()),
            title = stringResource(R.string.route_preview_home_pin)
        )
        Marker(
            state = MarkerState(position = latLngs.last()),
            title = stringResource(R.string.route_preview_work_pin)
        )
        Polyline(points = latLngs, color = AppAccent, width = 8f)
    }
}

/** Title above value in its own small card, the way iOS stacks the two. */
@Composable
private fun MetricCard(title: String, value: String, modifier: Modifier = Modifier) {
    IosCard(modifier = modifier, cornerRadius = 18.dp, contentPadding = 16.dp, spacing = 6.dp) {
        Text(text = title, fontSize = 12.sp, color = SecondaryOnCard, maxLines = 1)
        Text(text = value, fontSize = IosBody, fontWeight = FontWeight.SemiBold, color = Color.White)
    }
}

/**
 * The tiles are always on screen. Before a forecast arrives they hold the same
 * silhouette with a flat fill instead of the gradient — that difference, not a
 * replacement card, is what says "nothing loaded yet", so the section does not
 * jump around as the data lands.
 */
@Composable
private fun RouteWeatherSection(state: RouteWeatherState, usesAppleWeather: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(R.string.route_weather),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.weight(1f)
            )
            if (state == RouteWeatherState.Loading) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = SecondaryOnBlack
                )
            }
        }

        if (state is RouteWeatherState.Loaded) {
            SegmentLayout(state.snapshot.segments)
            val formatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT, FormatStyle.SHORT)
            Text(
                text = stringResource(
                    R.string.route_weather_updated,
                    formatter.format(state.snapshot.forecastAt.atZone(ZoneId.systemDefault())),
                    formatter.format(state.snapshot.checkedAt.atZone(ZoneId.systemDefault()))
                ),
                fontSize = 13.sp,
                color = SecondaryOnBlack
            )
            WeatherAttribution(usesAppleWeather = usesAppleWeather)
            return@Column
        }

        PlaceholderSegments()
        val message = when (state) {
            RouteWeatherState.Empty -> stringResource(R.string.route_weather_empty)
            RouteWeatherState.Loading -> stringResource(R.string.route_weather_refreshing)
            is RouteWeatherState.Failed ->
                stringResource(R.string.route_weather_failed, stringResource(state.messageResId))
            is RouteWeatherState.Loaded -> ""
        }
        Text(
            text = message,
            fontSize = 13.sp,
            color = if (state is RouteWeatherState.Failed) {
                MaterialTheme.colorScheme.error
            } else {
                SecondaryOnBlack
            }
        )
        WeatherAttribution(usesAppleWeather = usesAppleWeather)
    }
}

@Composable
private fun PlaceholderSegments() {
    Row(horizontalArrangement = Arrangement.spacedBy(SEGMENT_SPACING)) {
        listOf(R.string.segment_home_area, R.string.segment_office_area).forEach { titleRes ->
            SegmentTile(
                title = stringResource(titleRes),
                iconRes = R.drawable.ic_weather_cloudy,
                caption = stringResource(R.string.weather_waiting),
                background = null
            )
        }
    }
}

/**
 * Five cards will not fit across a phone, so they break onto two rows — as a
 * **W**: stops 1, 3 and 5 on top, stops 2 and 4 dropped into the gaps beneath
 * them. Every card still sits further right than the one before it, so the eye
 * reads home → office in order. A plain 3-then-2 grid loses that: its fourth
 * stop restarts at the far left, behind the second.
 *
 * Only an odd count staggers — an even one puts as many cards below as above and
 * leaves no gap to nest into. In practice the sampler yields two, three or five.
 */
@Composable
private fun SegmentLayout(segments: List<RouteWeatherSegment>) {
    if (segments.size < 5 || segments.size % 2 == 0) {
        Row(horizontalArrangement = Arrangement.spacedBy(SEGMENT_SPACING)) {
            segments.forEach { segment -> SegmentCard(segment) }
        }
        return
    }

    val top = segments.filterIndexed { index, _ -> index % 2 == 0 }
    val bottom = segments.filterIndexed { index, _ -> index % 2 == 1 }

    BoxWithConstraints {
        // Half a card plus half a gap lands the lower row exactly between the
        // two cards above it.
        val cardWidth = (maxWidth - SEGMENT_SPACING * (top.size - 1)) / top.size
        val inset = (cardWidth + SEGMENT_SPACING) / 2

        Column(verticalArrangement = Arrangement.spacedBy(SEGMENT_SPACING)) {
            Row(horizontalArrangement = Arrangement.spacedBy(SEGMENT_SPACING)) {
                top.forEach { segment -> SegmentCard(segment) }
            }
            Row(
                modifier = Modifier.padding(horizontal = inset),
                horizontalArrangement = Arrangement.spacedBy(SEGMENT_SPACING)
            ) {
                bottom.forEach { segment -> SegmentCard(segment) }
            }
        }
    }
}

@Composable
private fun RowScope.SegmentCard(segment: RouteWeatherSegment) {
    SegmentTile(
        title = segment.name,
        iconRes = segment.condition.iconRes(),
        caption = segment.conditionText(),
        background = Brush.verticalGradient(listOf(WeatherCardTop, WeatherCardBottom))
    )
}

/** `background = null` is the not-yet-loaded look: same tile, flat fill. */
@Composable
private fun RowScope.SegmentTile(
    title: String,
    @DrawableRes iconRes: Int,
    caption: String,
    background: Brush?
) {
    val shape = RoundedCornerShape(30.dp)
    Column(
        modifier = Modifier
            .weight(1f)
            .heightIn(min = 150.dp)
            .then(
                if (background != null) {
                    Modifier.background(brush = background, shape = shape)
                } else {
                    Modifier.background(
                        color = com.shukaihu.rainyclock.ui.theme.AppCard,
                        shape = shape
                    )
                }
            )
            .padding(vertical = 18.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)
    ) {
        Text(
            text = title,
            fontSize = IosBody,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
            textAlign = TextAlign.Center,
            maxLines = 2
        )
        // The marks carry their own colours, so no tint — see the drawables.
        //
        // 54dp, not the 42dp that matches iOS's `.font(.system(size: 42))`: an
        // SF Symbol draws well outside its nominal point size, so iOS renders a
        // mark about 42pt tall where this vector's art fills only ~78% of its
        // 24x24 box. This matches the drawn height. The widths still differ —
        // `cloud.sun.fill` is much wider than it is tall and the stand-in is
        // nearly square — and closing that needs the artwork redrawn, not
        // rescaled.
        Image(
            painter = painterResource(iconRes),
            contentDescription = null,
            modifier = Modifier.size(54.dp)
        )
        Text(
            text = caption,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = SecondaryOnCard,
            textAlign = TextAlign.Center,
            maxLines = 2
        )
    }
}

/** Rain reports its odds; the other two just name themselves, as on iOS. */
@Composable
private fun RouteWeatherSegment.conditionText(): String = when (condition) {
    WeatherCondition.CLEAR -> stringResource(R.string.weather_clear)
    WeatherCondition.CLOUDY -> stringResource(R.string.weather_cloudy)
    WeatherCondition.RAIN -> stringResource(
        R.string.precipitation_value,
        (precipitationProbability * 100).toInt()
    )
}

@DrawableRes
private fun WeatherCondition.iconRes(): Int = when (this) {
    WeatherCondition.CLEAR -> R.drawable.ic_weather_clear
    WeatherCondition.CLOUDY -> R.drawable.ic_weather_cloudy
    WeatherCondition.RAIN -> R.drawable.ic_weather_rain
}

fun CommuteMode.labelResId(): Int = when (this) {
    CommuteMode.CAR -> R.string.commute_mode_car
    CommuteMode.WALKING -> R.string.commute_mode_walking
    CommuteMode.PUBLIC_TRANSIT -> R.string.commute_mode_public_transit
}
