package com.shukaihu.rainyclock.model

import java.time.Instant

data class RouteWeatherSnapshot(
    val checkedAt: Instant,
    val forecastAt: Instant,
    val segments: List<RouteWeatherSegment>
) {
    fun exceedsRainThreshold(threshold: Double): Boolean =
        segments.any { it.precipitationProbability >= threshold }

    val maximumPrecipitationProbability: Double
        get() = segments.maxOfOrNull { it.precipitationProbability } ?: 0.0
}

data class RouteWeatherSegment(
    val name: String,
    val condition: WeatherCondition,
    val precipitationProbability: Double
)

enum class WeatherCondition {
    CLEAR,
    CLOUDY,
    RAIN
}

data class WeatherSample(
    val condition: WeatherCondition,
    val precipitationProbability: Double
)

/** Same buckets the iOS `WeatherSampleMapper` uses. */
object WeatherSampleMapper {
    fun condition(precipitationProbability: Double): WeatherCondition = when {
        precipitationProbability >= 0.5 -> WeatherCondition.RAIN
        precipitationProbability >= 0.2 -> WeatherCondition.CLOUDY
        else -> WeatherCondition.CLEAR
    }
}
