package com.shukaihu.rainyclock.weather

import com.shukaihu.rainyclock.model.WeatherCondition
import com.shukaihu.rainyclock.model.WeatherSample
import com.shukaihu.rainyclock.model.WeatherSampleMapper
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Apple WeatherKit, reached through the signing proxy in `weather-proxy/`.
 *
 * The app cannot call WeatherKit directly: every request needs an ES256 token
 * signed with an Apple private key, and a key shipped inside an APK is a
 * published key. The proxy holds the key, mints the token and returns only the
 * three fields below, so this class stays a plain JSON client.
 *
 * Using the same source as iOS is the point — the whole product is one rain
 * decision, and two platforms disagreeing about whether it will rain is a
 * defect no amount of UI parity makes up for.
 */
class WeatherKitProxySamplingService(
    private val baseUrl: String,
    private val sharedSecret: String? = null
) : WeatherSamplingService {

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun sampleWeather(
        latitude: Double,
        longitude: Double,
        around: Instant
    ): WeatherSample = withContext(Dispatchers.IO) {
        // Ask for a window either side of the target rather than the whole
        // forecast: the response is smaller and the nearest-hour search below
        // has less to sift. Apple anchors hours to the top of the hour, so a
        // two-hour window always contains a candidate.
        val start = around.minusSeconds(SEARCH_WINDOW_SECONDS)
        val end = around.plusSeconds(SEARCH_WINDOW_SECONDS)

        val url = buildString {
            append(baseUrl.trimEnd('/'))
            append("/v1/weather")
            append(String.format(Locale.US, "?lat=%.4f&lon=%.4f", latitude, longitude))
            append("&tz=").append(encode(ZoneId.systemDefault().id))
            append("&lang=").append(encode(Locale.getDefault().toLanguageTag()))
            append("&start=").append(encode(INSTANT_FORMAT.format(start)))
            append("&end=").append(encode(INSTANT_FORMAT.format(end)))
        }

        val body = try {
            fetch(url)
        } catch (error: Exception) {
            throw WeatherUnavailableException("WeatherKit proxy request failed", error)
        }

        val response = try {
            json.decodeFromString<ProxyResponse>(body)
        } catch (error: Exception) {
            throw WeatherUnavailableException("WeatherKit proxy response could not be parsed", error)
        }

        val hour = response.hours
            .mapNotNull { entry -> entry.parsed() }
            .minByOrNull { (start, _) -> abs(start.epochSecond - around.epochSecond) }
            ?.second
            ?: throw WeatherUnavailableException("WeatherKit proxy returned no usable hour")

        val probability = hour.precipitationChance.coerceIn(0.0, 1.0)
        WeatherSample(
            condition = condition(hour.conditionCode, probability),
            precipitationProbability = probability
        )
    }

    private fun fetch(url: String): String {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            sharedSecret?.let { connection.setRequestProperty("X-RainyClock-Key", it) }

            val code = connection.responseCode
            if (code != HttpURLConnection.HTTP_OK) {
                val detail = connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                throw WeatherUnavailableException("Proxy returned HTTP $code: ${detail.take(200)}")
            }
            return connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    /**
     * WeatherKit's `conditionCode` is a far richer enumeration than the three
     * buckets this app shows, and Apple adds values to it. Rather than
     * enumerate it, trust the codes that unambiguously mean dry and let the
     * probability decide everything else — the same shape as the iOS mapper.
     */
    private fun condition(conditionCode: String, probability: Double): WeatherCondition = when {
        conditionCode in CLEAR_CODES -> WeatherCondition.CLEAR
        conditionCode in CLOUDY_CODES -> WeatherSampleMapper.condition(probability)
            .takeIf { it == WeatherCondition.RAIN } ?: WeatherCondition.CLOUDY
        else -> WeatherSampleMapper.condition(probability)
    }

    @Serializable
    private data class ProxyResponse(val hours: List<ProxyHour> = emptyList())

    @Serializable
    private data class ProxyHour(
        @SerialName("forecastStart") val forecastStart: String = "",
        @SerialName("precipitationChance") val precipitationChance: Double = 0.0,
        @SerialName("conditionCode") val conditionCode: String = ""
    ) {
        fun parsed(): Pair<Instant, ProxyHour>? = try {
            Instant.parse(forecastStart) to this
        } catch (_: Exception) {
            null
        }
    }

    private companion object {
        const val TIMEOUT_MS = 15_000
        const val SEARCH_WINDOW_SECONDS = 3_600L * 2
        val INSTANT_FORMAT: DateTimeFormatter = DateTimeFormatter.ISO_INSTANT

        val CLEAR_CODES = setOf("Clear", "MostlyClear", "Hot")
        val CLOUDY_CODES = setOf("Cloudy", "MostlyCloudy", "PartlyCloudy", "Haze", "Smoky", "Breezy", "Windy")

        fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
    }
}
