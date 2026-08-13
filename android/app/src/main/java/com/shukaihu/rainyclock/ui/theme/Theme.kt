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

/**
 * iOS's system blue in dark mode, **measured** from the running iPhone app
 * rather than taken from a reference chart: `#0A84FF` is the value every
 * pre-iOS-26 table gives, and it is no longer what iOS renders. Sampled from a
 * screenshot with no system alert dimming the window, five interior points of
 * the accent-filled capsule and the selected tab label all read this exactly.
 */
val AppAccent = Color(0xFF0091FF)

/** iOS secondary label over black. */
val AppSecondaryLabel = Color(0xFF98989E)

/**
 * iOS's `.secondary` is `#EBEBF5` at 60%, so what it composites to depends on
 * what is behind it. Both surfaces it lands on here are pinned rather than
 * derived, because Compose has no equivalent of resolving a semantic colour
 * against its backdrop.
 */
val SecondaryOnCard = Color(0xFF9999A0)
val SecondaryOnBlack = Color(0xFF8D8D93)

// The stock-control colours, measured off the running iOS 26 app. Every one of
// these differs from both the Material default and the pre-iOS-26 reference
// value, which is why they are pinned here rather than derived from the scheme.
/** Slider rail to the right of the handle — barely visible against the card. */
val AppSliderTrackOff = Color(0xFF353537)
/** Switch track when off. The widely-quoted #39393D is the pre-iOS-26 value. */
val AppSwitchTrackOff = Color(0xFF5C5C60)
val DisabledButtonFill = Color(0xFF262629)
val DisabledButtonLabel = Color(0xFF525257)

/**
 * The floating tab bar. iOS fills it with `.ultraThinMaterial`, which Compose
 * cannot reproduce — there is no backdrop blur below API 31 and `minSdk` is 26.
 * It costs nothing here: the bar sits on the app's own black canvas, so the
 * material has nothing to blur and collapses to a flat tint. These two values
 * are sampled from a screenshot of the running iPhone app rather than estimated,
 * and they already include iOS's white-4% under-layer — do not stack a second
 * translucent layer on top or the bar comes out lighter than iOS.
 */
val AppTabBarFill = Color(0xFF242424)
val AppTabBarSelected = Color(0xFF3F3F3F)
val AppTabBarRim = Color(0x29FFFFFF)

/**
 * Pop-over menus. They cannot take their background from the scheme: Material
 * resolves it from `surfaceContainer`, which is pinned to black below so the tab
 * strip sits flat on the canvas, and a black menu on a black page has no edge.
 */
val MenuBackground = Color(0xFF2C2C2E)

// The weather marks. iOS renders these as multicolour SF Symbols, so what
// shows is the symbol's own palette rather than the condition tint: a white
// cloud with a yellow sun or blue rain. Clear and rain are measured from the
// iPhone app; the cloudy tint is the one value here still taken from a
// reference table rather than a screenshot, because no overcast icon has been
// on screen to sample.
val WeatherClear = Color(0xFFFFD600)
val WeatherCloudy = Color(0xFF64D2FF)
val WeatherRain = AppAccent
val WeatherCardTop = Color(0xFF051F26)
val WeatherCardBottom = Color(0xFF05476B)

val StatusPositive = Color(0xFF30D158)

/** Measured on iOS 26; `#FF9F0A` is the orange every older reference gives. */
val StatusWarning = Color(0xFFFF9230)

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
