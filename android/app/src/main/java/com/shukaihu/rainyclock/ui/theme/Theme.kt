package com.shukaihu.rainyclock.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// The iOS app pins itself to dark mode (`preferredColorScheme(.dark)`) and paints
// a black canvas with near-black cards and the system blue accent. These values
// are the same ones `ContentView.swift` defines, converted from its 0–1 channels,
// so the two platforms read as one product. There is deliberately no light
// scheme: matching iOS means dark regardless of the system setting.
val AppBackground = Color(0xFF000000)
val AppCard = Color(0xFF1F1F21)
val AppField = Color(0xFF2E2E33)

/** iOS system blue, dark-mode variant. */
val AppAccent = Color(0xFF0A84FF)

/** iOS secondary label over black. */
val AppSecondaryLabel = Color(0xFF98989E)

// The three weather-condition tints, and the card gradient behind them, are
// iOS's .yellow / .cyan / .blue in their dark-mode form.
val WeatherClear = Color(0xFFFFD60A)
val WeatherCloudy = Color(0xFF64D2FF)
val WeatherRain = Color(0xFF0A84FF)
val WeatherCardTop = Color(0xFF051F26)
val WeatherCardBottom = Color(0xFF05476B)

val StatusPositive = Color(0xFF30D158)
val StatusWarning = Color(0xFFFF9F0A)

private val RainyClockColorScheme = darkColorScheme(
    primary = AppAccent,
    onPrimary = Color.White,
    primaryContainer = AppAccent,
    onPrimaryContainer = Color.White,
    secondary = AppAccent,
    onSecondary = Color.White,
    // Stays dark: a slider's inactive track reads from the secondary container,
    // so tinting it accent would paint the whole track blue. Components that do
    // want an accent fill (the mode chips) ask for it explicitly.
    secondaryContainer = AppField,
    onSecondaryContainer = Color.White,
    tertiary = AppAccent,
    onTertiary = Color.White,
    background = AppBackground,
    onBackground = Color.White,
    surface = AppBackground,
    onSurface = Color.White,
    surfaceVariant = AppField,
    onSurfaceVariant = AppSecondaryLabel,
    // Cards resolve to surfaceContainerHighest; the navigation bar to
    // surfaceContainer, which stays black so the tab strip sits on the canvas
    // the way the iOS tab bar does.
    surfaceContainerLowest = AppBackground,
    surfaceContainerLow = AppCard,
    surfaceContainer = AppBackground,
    surfaceContainerHigh = AppCard,
    surfaceContainerHighest = AppCard,
    outline = Color(0xFF48484A),
    outlineVariant = Color(0xFF3A3A3C),
    error = Color(0xFFFF453A),
    onError = Color.White,
    scrim = Color.Black
)

@Composable
fun RainyClockTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = RainyClockColorScheme, content = content)
}
