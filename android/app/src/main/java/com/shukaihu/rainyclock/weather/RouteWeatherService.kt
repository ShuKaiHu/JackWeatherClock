package com.shukaihu.rainyclock.weather

import android.content.Context
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.geo.AddressResolver
import com.shukaihu.rainyclock.geo.RoutePreviewService
import com.shukaihu.rainyclock.logic.RouteSampler
import com.shukaihu.rainyclock.model.CommuteMode
import com.shukaihu.rainyclock.model.LatLngPoint
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
        mode: CommuteMode,
        around: Instant
    ): RouteWeatherSnapshot
}

/**
 * Samples the forecast around the commute time at the home and office
 * endpoints, plus interior points along the route when one is available —
 * any sampled point exceeding the rain threshold pulls the alarm earlier.
 *
 * The route is best-effort: no Maps key, no billing, an unsupported travel
 * mode, or a network failure degrade silently to the endpoint-only check the
 * shipped iOS app performs. The alarm decision must never break because the
 * preview infrastructure did.
 */
class EndpointRouteWeatherService(
    context: Context,
    private val resolver: AddressResolver,
    private val sampler: WeatherSamplingService,
    private val routePreviewService: RoutePreviewService? = null
) : RouteWeatherService {

    private val appContext = context.applicationContext

    override suspend fun fetchRouteWeather(
        homeAddress: String,
        homeLocation: ResolvedLocation?,
        workAddress: String,
        workLocation: ResolvedLocation?,
        mode: CommuteMode,
        around: Instant
    ): RouteWeatherSnapshot {
        val home = homeLocation ?: resolver.resolve(homeAddress)
        val work = workLocation ?: resolver.resolve(workAddress)

        val interiorPoints = interiorSamplePoints(home, work, mode)

        val endpoints = buildList {
            add(appContext.getString(R.string.segment_home_area) to LatLngPoint(home.latitude, home.longitude))
            interiorPoints.forEachIndexed { index, point ->
                add(interiorSegmentName(index, interiorPoints.size) to point)
            }
            add(appContext.getString(R.string.segment_office_area) to LatLngPoint(work.latitude, work.longitude))
        }

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

    private suspend fun interiorSamplePoints(
        home: ResolvedLocation,
        work: ResolvedLocation,
        mode: CommuteMode
    ): List<LatLngPoint> {
        val service = routePreviewService ?: return emptyList()
        return try {
            RouteSampler.interiorSamplePoints(service.fetchRoute(home, work, mode).points)
        } catch (_: Exception) {
            emptyList()
        }
    }

    /**
     * Names an interior sample by where it sits along the route rather than by
     * its index — "Halfway" says something a rider can act on, "sample 2" does
     * not. The sampler only ever produces one or three interior points, so those
     * two get proper fraction names; the format string is the safety net if that
     * ever changes.
     */
    private fun interiorSegmentName(index: Int, total: Int): String = when {
        total == 1 -> appContext.getString(R.string.segment_route_half)
        total == 3 -> appContext.getString(
            when (index) {
                0 -> R.string.segment_route_quarter
                1 -> R.string.segment_route_half
                else -> R.string.segment_route_three_quarter
            }
        )
        else -> appContext.getString(R.string.segment_route_fraction_format, index + 1, total + 1)
    }
}
