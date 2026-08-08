package com.shukaihu.rainyclock.weather

import com.shukaihu.rainyclock.model.WeatherCondition
import com.shukaihu.rainyclock.model.WeatherSample
import com.shukaihu.rainyclock.model.WeatherSampleMapper
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.Locale
import kotlin.math.abs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The Android stand-in for WeatherKit: the Open-Meteo forecast API. No API
 * key; hourly precipitation probability plus a WMO weather code, which maps
 * onto the same three-bucket condition the iOS app uses.
 *
 * Note on licensing: Open-Meteo's keyless tier is for non-commercial use.
 * Before the ad-supported build ships, either subscribe to their API plan or
 * swap this class for another provider — everything behind
 * [WeatherSamplingService] stays unchanged. See docs/ANDROID.md.
 */
class OpenMeteoWeatherService(
    private val baseUrl: String = "https://api.open-meteo.com/v1/forecast"
) : WeatherSamplingService {

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun sampleWeather(
        latitude: Double,
        longitude: Double,
        around: Instant
    ): WeatherSample = withContext(Dispatchers.IO) {
        val url = String.format(
            Locale.US,
            "%s?latitude=%.4f&longitude=%.4f&hourly=precipitation_probability,weather_code&forecast_days=8&timezone=UTC",
            baseUrl,
            latitude,
            longitude
        )

        val body = try {
            fetch(url)
        } catch (error: Exception) {
            throw WeatherUnavailableException("Open-Meteo request failed", error)
        }

        val response = try {
            json.decodeFromString<OpenMeteoResponse>(body)
        } catch (error: Exception) {
            throw WeatherUnavailableException("Open-Meteo response could not be parsed", error)
        }

        val hourly = response.hourly
        if (hourly == null || hourly.time.isEmpty()) {
            throw WeatherUnavailableException("Open-Meteo response held no hourly forecast")
        }

        val index = hourly.time.indices.minByOrNull { index ->
            abs(parseUtcHour(hourly.time[index]).epochSecond - around.epochSecond)
        } ?: throw WeatherUnavailableException("Open-Meteo response held no hourly forecast")

        val probability = (hourly.precipitationProbability.getOrNull(index) ?: 0) / 100.0
        val weatherCode = hourly.weatherCode.getOrNull(index)

        WeatherSample(
            condition = condition(weatherCode, probability),
            precipitationProbability = probability.coerceIn(0.0, 1.0)
        )
    }

    private fun fetch(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.setRequestProperty("Accept", "application/json")
            val code = connection.responseCode
            if (code != HttpURLConnection.HTTP_OK) {
                throw WeatherUnavailableException("Open-Meteo returned HTTP $code")
            }
            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    private fun parseUtcHour(value: String): Instant =
        LocalDateTime.parse(value).toInstant(ZoneOffset.UTC)

    /**
     * WMO weather interpretation codes, folded into the same buckets the iOS
     * WeatherKit condition mapping produces.
     */
    private fun condition(weatherCode: Int?, precipitationProbability: Double): WeatherCondition =
        when (weatherCode) {
            null -> WeatherSampleMapper.condition(precipitationProbability)
            // Drizzle, rain, freezing rain, rain showers, thunderstorms.
            in 51..67, in 80..82, in 95..99 -> WeatherCondition.RAIN
            // Cloud cover, fog, snow, snow showers.
            in 1..3, 45, 48, in 71..77, 85, 86 -> WeatherCondition.CLOUDY
            // Clear sky falls through to the probability-based bucket.
            else -> WeatherSampleMapper.condition(precipitationProbability)
        }
}

@Serializable
private data class OpenMeteoResponse(
    val hourly: OpenMeteoHourly? = null
)

@Serializable
private data class OpenMeteoHourly(
    val time: List<String> = emptyList(),
    @SerialName("precipitation_probability")
    val precipitationProbability: List<Int?> = emptyList(),
    @SerialName("weather_code")
    val weatherCode: List<Int?> = emptyList()
)
