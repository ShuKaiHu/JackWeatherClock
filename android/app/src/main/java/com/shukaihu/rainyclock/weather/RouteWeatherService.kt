package com.shukaihu.rainyclock.weather

import android.content.Context
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.geo.AddressResolver
import com.shukaihu.rainyclock.model.ResolvedLocation
import com.shukaihu.rainyclock.model.RouteWeatherSegment
import com.shukaihu.rainyclock.model.RouteWeatherSnapshot
import java.time.Instant

interface RouteWeatherService {
    suspend fun fetchRouteWeather(
        homeAddress: String,
        homeLocation: ResolvedLocation?,
        workAddress: String,
        workLocation: ResolvedLocation?,
        around: Instant
    ): RouteWeatherSnapshot
}

/**
 * Samples the forecast at the home and office endpoints around the commute
 * time — the same segments the shipped iOS `MapKitRouteWeatherService`
 * produces (it never samples mid-route either; see PRODUCT_DECISIONS.md).
 */
class EndpointRouteWeatherService(
    context: Context,
    private val resolver: AddressResolver,
    private val sampler: WeatherSamplingService
) : RouteWeatherService {

    private val appContext = context.applicationContext

    override suspend fun fetchRouteWeather(
        homeAddress: String,
        homeLocation: ResolvedLocation?,
        workAddress: String,
        workLocation: ResolvedLocation?,
        around: Instant
    ): RouteWeatherSnapshot {
        val home = homeLocation ?: resolver.resolve(homeAddress)
        val work = workLocation ?: resolver.resolve(workAddress)

        val endpoints = listOf(
            appContext.getString(R.string.segment_home_area) to home,
            appContext.getString(R.string.segment_office_area) to work
        )

        val segments = endpoints.map { (name, location) ->
            val sample = sampler.sampleWeather(location.latitude, location.longitude, around)
            RouteWeatherSegment(
                name = name,
                condition = sample.condition,
                precipitationProbability = sample.precipitationProbability
            )
        }

        return RouteWeatherSnapshot(
            checkedAt = Instant.now(),
            forecastAt = around,
            segments = segments
        )
    }
}
