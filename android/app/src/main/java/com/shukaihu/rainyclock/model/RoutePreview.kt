package com.shukaihu.rainyclock.model

/** Platform-neutral coordinate so core logic stays free of Google Maps types. */
data class LatLngPoint(
    val latitude: Double,
    val longitude: Double
)

data class RoutePreview(
    val points: List<LatLngPoint>,
    val distanceMeters: Int,
    val durationMinutes: Int
)
