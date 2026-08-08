package com.shukaihu.rainyclock.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@Composable
fun RouteTab(
    state: AlarmUiState,
    modifier: Modifier = Modifier,
    isRoutePreviewConfigured: Boolean,
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
                    label = { Text(stringResource(mode.labelResId())) }
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

        Text(
            text = stringResource(R.string.weather_data_attribution),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
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
                Polyline(points = latLngs, color = Color(0xFF2563EB), width = 8f)
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
                is RouteWeatherState.Loaded -> {
                    state.snapshot.segments.forEach { segment ->
                        SegmentRow(segment)
                    }
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
            }
        }
    }
}

@Composable
private fun SegmentRow(segment: RouteWeatherSegment) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = segment.condition.icon(),
            contentDescription = null,
            tint = segment.condition.tint()
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Text(text = segment.name, style = MaterialTheme.typography.bodyLarge)
            Text(
                text = stringResource(
                    R.string.precipitation_value,
                    (segment.precipitationProbability * 100).toInt()
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun WeatherCondition.icon(): ImageVector = when (this) {
    WeatherCondition.CLEAR -> Icons.Filled.WbSunny
    WeatherCondition.CLOUDY -> Icons.Filled.Cloud
    WeatherCondition.RAIN -> Icons.Filled.WaterDrop
}

private fun WeatherCondition.tint(): Color = when (this) {
    WeatherCondition.CLEAR -> Color(0xFFF59E0B)
    WeatherCondition.CLOUDY -> Color(0xFF64748B)
    WeatherCondition.RAIN -> Color(0xFF2563EB)
}

fun CommuteMode.labelResId(): Int = when (this) {
    CommuteMode.CAR -> R.string.commute_mode_car
    CommuteMode.SCOOTER -> R.string.commute_mode_scooter
    CommuteMode.WALKING -> R.string.commute_mode_walking
    CommuteMode.PUBLIC_TRANSIT -> R.string.commute_mode_public_transit
}
