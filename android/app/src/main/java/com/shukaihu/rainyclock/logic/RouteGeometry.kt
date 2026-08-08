package com.shukaihu.rainyclock.logic

import com.shukaihu.rainyclock.model.LatLngPoint
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Decoder for Google's encoded-polyline format (1e-5 precision). */
object PolylineCodec {

    fun decode(encoded: String): List<LatLngPoint> {
        val points = mutableListOf<LatLngPoint>()
        var index = 0
        var lat = 0
        var lng = 0

        while (index < encoded.length) {
            val latDelta = decodeChunk(encoded, index)
            index = latDelta.nextIndex
            lat += latDelta.value
            if (index >= encoded.length) break
            val lngDelta = decodeChunk(encoded, index)
            index = lngDelta.nextIndex
            lng += lngDelta.value
            points.add(LatLngPoint(lat * 1e-5, lng * 1e-5))
        }

        return points
    }

    private data class Chunk(val value: Int, val nextIndex: Int)

    private fun decodeChunk(encoded: String, startIndex: Int): Chunk {
        var index = startIndex
        var result = 0
        var shift = 0
        var byte: Int
        do {
            byte = encoded[index++].code - 63
            result = result or ((byte and 0x1f) shl shift)
            shift += 5
        } while (byte >= 0x20 && index < encoded.length)
        val value = if (result and 1 != 0) (result shr 1).inv() else result shr 1
        return Chunk(value, index)
    }
}

/**
 * Picks interior sample points along a route for weather checks. The product
 * intent: home, office, *and* points along the commute each get a rain check,
 * and any of them exceeding the threshold pulls the alarm earlier.
 *
 * Sampling is distance-based because weather-model cells are a few km wide —
 * on a short commute the endpoints already cover the route:
 *   < 4 km   → no interior samples
 *   4–20 km  → the midpoint
 *   ≥ 20 km  → quarter, mid, and three-quarter points
 *
 * (The deleted iOS `RoutePolylineSampler` trapped on `Int(Double.nan)` when
 * asked for a single sample; this implementation is covered by unit tests
 * including the degenerate zero-length and single-point routes.)
 */
object RouteSampler {

    fun interiorSamplePoints(points: List<LatLngPoint>): List<LatLngPoint> {
        if (points.size < 2) return emptyList()

        val cumulative = DoubleArray(points.size)
        for (i in 1 until points.size) {
            cumulative[i] = cumulative[i - 1] + haversineMeters(points[i - 1], points[i])
        }
        val totalMeters = cumulative.last()
        if (totalMeters <= 0.0) return emptyList()

        val fractions = when {
            totalMeters < 4_000 -> return emptyList()
            totalMeters < 20_000 -> listOf(0.5)
            else -> listOf(0.25, 0.5, 0.75)
        }

        return fractions.map { fraction -> pointAtDistance(points, cumulative, totalMeters * fraction) }
    }

    private fun pointAtDistance(
        points: List<LatLngPoint>,
        cumulative: DoubleArray,
        target: Double
    ): LatLngPoint {
        for (i in 1 until points.size) {
            if (cumulative[i] >= target) {
                val segmentLength = cumulative[i] - cumulative[i - 1]
                if (segmentLength <= 0.0) return points[i]
                val t = (target - cumulative[i - 1]) / segmentLength
                return LatLngPoint(
                    latitude = points[i - 1].latitude + (points[i].latitude - points[i - 1].latitude) * t,
                    longitude = points[i - 1].longitude + (points[i].longitude - points[i - 1].longitude) * t
                )
            }
        }
        return points.last()
    }

    fun haversineMeters(a: LatLngPoint, b: LatLngPoint): Double {
        val earthRadius = 6_371_000.0
        val dLat = Math.toRadians(b.latitude - a.latitude)
        val dLng = Math.toRadians(b.longitude - a.longitude)
        val sinLat = sin(dLat / 2)
        val sinLng = sin(dLng / 2)
        val h = sinLat * sinLat +
            cos(Math.toRadians(a.latitude)) * cos(Math.toRadians(b.latitude)) * sinLng * sinLng
        return 2 * earthRadius * asin(sqrt(h.coerceIn(0.0, 1.0)))
    }
}
