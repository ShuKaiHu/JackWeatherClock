package com.shukaihu.rainyclock.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.maps.android.compose.GoogleMap
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
import com.shukaihu.rainyclock.ui.theme.WeatherCardBottom
import com.shukaihu.rainyclock.ui.theme.WeatherCardTop
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** Gap between weather cards, and the unit the W's nesting inset is built from. */
private val SEGMENT_SPACING = 10.dp

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
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(text = stringResource(R.string.commute), style = MaterialTheme.typography.titleMedium)

        AddressField(
            label = stringResource(R.string.home_address),
            value = state.settings.homeAddress,
            invalid = state.homeInvalid,
            suggestion = state.homeSuggestion,
            onValueChange = onHomeAddressChange,
            onConfirmSuggestion = onConfirmHomeSuggestion
        )

        AddressField(
            label = stringResource(R.string.work_address),
            value = state.settings.workAddress,
            invalid = state.workInvalid,
            suggestion = state.workSuggestion,
            onValueChange = onWorkAddressChange,
            onConfirmSuggestion = onConfirmWorkSuggestion
        )

        Text(text = stringResource(R.string.mode), style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CommuteMode.entries.forEach { mode ->
                FilterChip(
                    selected = state.settings.commuteMode == mode,
                    onClick = { onCommuteModeChange(mode) },
                    label = { Text(stringResource(mode.labelResId())) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = AppAccent,
                        selectedLabelColor = Color.White
                    )
                )
            }
        }

        OutlinedButton(
            onClick = onRefreshRouteWeather,
            modifier = Modifier.fillMaxWidth(),
            enabled = state.routeWeather != RouteWeatherState.Loading
        ) {
            Text(stringResource(R.string.preview_route))
        }

        if (isRoutePreviewConfigured) {
            state.routePreview?.let { preview -> RoutePreviewCard(preview) }
        } else {
            Text(
                text = stringResource(R.string.route_preview_requires_key),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        RouteWeatherCard(state = state.routeWeather)

        WeatherAttribution(usesAppleWeather = usesAppleWeather)
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
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        return
    }

    val uriHandler = LocalUriHandler.current
    Text(
        text = stringResource(R.string.weather_attribution_apple),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.clickable {
            uriHandler.openUri("https://weatherkit.apple.com/legal-attribution.html")
        }
    )
}

@Composable
private fun AddressField(
    label: String,
    value: String,
    invalid: Boolean,
    suggestion: String?,
    onValueChange: (String) -> Unit,
    onConfirmSuggestion: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            label = { Text(label) },
            isError = invalid,
            singleLine = true,
            // iOS fills its address fields rather than outlining them.
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = AppField,
                unfocusedContainerColor = AppField,
                errorContainerColor = AppField
            ),
            supportingText = if (invalid) {
                { Text(stringResource(R.string.address_not_found_inline)) }
            } else {
                null
            }
        )
        if (suggestion != null) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = stringResource(R.string.suggested_address_prefix, suggestion),
                        style = MaterialTheme.typography.bodySmall
                    )
                    TextButton(onClick = onConfirmSuggestion) {
                        Text(stringResource(R.string.confirm_suggested_address))
                    }
                }
            }
        }
    }
}

@Composable
private fun RoutePreviewCard(preview: RoutePreview) {
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

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(text = stringResource(R.string.route_preview), style = MaterialTheme.typography.titleSmall)
            GoogleMap(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                cameraPositionState = cameraPositionState,
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
            Row {
                Text(
                    text = stringResource(R.string.route_preview_travel_time),
                    modifier = Modifier.weight(1f),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(text = stringResource(R.string.route_preview_minutes_value, preview.durationMinutes))
            }
            Row {
                Text(
                    text = stringResource(R.string.route_preview_distance),
                    modifier = Modifier.weight(1f),
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = stringResource(R.string.route_preview_distance_value, preview.distanceMeters / 1000.0f)
                )
            }
        }
    }
}

@Composable
private fun RouteWeatherCard(state: RouteWeatherState) {
    if (state is RouteWeatherState.Loaded) {
        // Loaded segments are their own gradient tiles laid out side by side, the
        // way the iOS Route tab presents them — no surrounding card.
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SegmentLayout(state.snapshot.segments)
            val formatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.SHORT, FormatStyle.SHORT)
            Text(
                text = stringResource(
                    R.string.route_weather_updated,
                    formatter.format(state.snapshot.forecastAt.atZone(ZoneId.systemDefault())),
                    formatter.format(state.snapshot.checkedAt.atZone(ZoneId.systemDefault()))
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        return
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            when (state) {
                RouteWeatherState.Empty -> Text(
                    text = stringResource(R.string.route_weather_empty),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                RouteWeatherState.Loading -> Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    CircularProgressIndicator(modifier = Modifier.width(24.dp).height(24.dp))
                    Text(stringResource(R.string.route_weather_refreshing))
                }
                is RouteWeatherState.Failed -> Text(
                    text = stringResource(R.string.route_weather_failed, stringResource(state.messageResId)),
                    color = MaterialTheme.colorScheme.error
                )
                is RouteWeatherState.Loaded -> Unit
            }
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
    Column(
        modifier = Modifier
            .weight(1f)
            .heightIn(min = 150.dp)
            .background(
                brush = Brush.verticalGradient(listOf(WeatherCardTop, WeatherCardBottom)),
                shape = RoundedCornerShape(30.dp)
            )
            .padding(vertical = 18.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)
    ) {
        Text(
            text = segment.name,
            style = MaterialTheme.typography.titleSmall,
            textAlign = TextAlign.Center,
            maxLines = 2
        )
        // The marks carry their own colours, so no tint — see the drawables.
        Image(
            painter = painterResource(segment.condition.iconRes()),
            contentDescription = null,
            modifier = Modifier.size(42.dp)
        )
        Text(
            text = segment.conditionText(),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            maxLines = 1
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
