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
            sampler = OpenMeteoWeatherService(),
            routePreviewService = routePreviewService
        )
        alarmScheduler = AlarmScheduler(appContext, settingsRepository, routeWeatherService)
        initialized = true
    }
}
