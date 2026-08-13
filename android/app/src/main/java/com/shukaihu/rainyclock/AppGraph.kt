package com.shukaihu.rainyclock

import android.content.Context
import com.shukaihu.rainyclock.alarm.AlarmScheduler
import com.shukaihu.rainyclock.data.SettingsRepository
import com.shukaihu.rainyclock.geo.AddressResolver
import com.shukaihu.rainyclock.geo.GoogleRoutesPreviewService
import com.shukaihu.rainyclock.geo.RoutePreviewService
import com.shukaihu.rainyclock.weather.EndpointRouteWeatherService
import com.shukaihu.rainyclock.weather.OpenMeteoWeatherService
import com.shukaihu.rainyclock.weather.RouteWeatherService
import com.shukaihu.rainyclock.weather.WeatherKitProxySamplingService
import com.shukaihu.rainyclock.weather.WeatherSamplingService

/**
 * Hand-rolled service locator — the app is small enough that a DI framework
 * would outweigh the object graph it wires.
 */
object AppGraph {

    @Volatile
    private var initialized = false

    lateinit var settingsRepository: SettingsRepository
        private set
    lateinit var addressResolver: AddressResolver
        private set
    lateinit var routeWeatherService: RouteWeatherService
        private set
    lateinit var alarmScheduler: AlarmScheduler
        private set

    /** Null when no Maps API key is configured — the preview UI hides itself. */
    var routePreviewService: RoutePreviewService? = null
        private set

    /** Drives which weather attribution the Route tab is required to display. */
    val usesAppleWeather: Boolean
        get() = BuildConfig.WEATHER_PROXY_URL.isNotBlank()

    @Synchronized
    fun initialize(context: Context) {
        if (initialized) return
        val appContext = context.applicationContext
        settingsRepository = SettingsRepository(appContext)
        addressResolver = AddressResolver(appContext)
        routePreviewService = BuildConfig.MAPS_API_KEY
            .takeIf { it.isNotBlank() }
            ?.let { GoogleRoutesPreviewService(appContext, it) }
        routeWeatherService = EndpointRouteWeatherService(
            context = appContext,
            resolver = addressResolver,
            sampler = weatherSampler(),
            routePreviewService = routePreviewService
        )
        alarmScheduler = AlarmScheduler(appContext, settingsRepository, routeWeatherService)
        initialized = true
    }

    /**
     * WeatherKit through the proxy when one is configured, Open-Meteo otherwise.
     * The fallback exists so a developer build without proxy credentials still
     * runs — it must not survive into a shipped, ad-carrying release, because
     * Open-Meteo's free tier is licensed for non-commercial use only.
     */
    private fun weatherSampler(): WeatherSamplingService =
        BuildConfig.WEATHER_PROXY_URL
            .takeIf { it.isNotBlank() }
            ?.let { url ->
                WeatherKitProxySamplingService(
                    baseUrl = url,
                    sharedSecret = BuildConfig.WEATHER_PROXY_SECRET.takeIf { it.isNotBlank() }
                )
            }
            ?: OpenMeteoWeatherService()
}
