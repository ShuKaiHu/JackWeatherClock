package com.shukaihu.rainyclock

import com.shukaihu.rainyclock.logic.PolylineCodec
import com.shukaihu.rainyclock.logic.RouteSampler
import com.shukaihu.rainyclock.model.LatLngPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteGeometryTest {

    @Test
    fun `decodes google's documented polyline example`() {
        val points = PolylineCodec.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        assertEquals(3, points.size)
        assertEquals(38.5, points[0].latitude, 1e-5)
        assertEquals(-120.2, points[0].longitude, 1e-5)
        assertEquals(40.7, points[1].latitude, 1e-5)
        assertEquals(-120.95, points[1].longitude, 1e-5)
        assertEquals(43.252, points[2].latitude, 1e-5)
        assertEquals(-126.453, points[2].longitude, 1e-5)
    }

    @Test
    fun `decoding an empty string yields no points`() {
        assertEquals(emptyList<LatLngPoint>(), PolylineCodec.decode(""))
    }

    @Test
    fun `degenerate routes produce no interior samples`() {
        // The deleted iOS RoutePolylineSampler trapped on these.
        assertEquals(emptyList<LatLngPoint>(), RouteSampler.interiorSamplePoints(emptyList()))
        assertEquals(
            emptyList<LatLngPoint>(),
            RouteSampler.interiorSamplePoints(listOf(LatLngPoint(25.0, 121.5)))
        )
        assertEquals(
            emptyList<LatLngPoint>(),
            RouteSampler.interiorSamplePoints(listOf(LatLngPoint(25.0, 121.5), LatLngPoint(25.0, 121.5)))
        )
    }

    @Test
    fun `short commutes rely on the endpoints alone`() {
        // ~2.2 km straight line: below the 4 km floor.
        val points = listOf(LatLngPoint(25.03, 121.50), LatLngPoint(25.05, 121.50))
        assertEquals(emptyList<LatLngPoint>(), RouteSampler.interiorSamplePoints(points))
    }

    @Test
    fun `medium commutes sample the midpoint`() {
        // ~11 km straight line north: one interior sample at the midpoint.
        val points = listOf(LatLngPoint(25.0, 121.5), LatLngPoint(25.1, 121.5))
        val samples = RouteSampler.interiorSamplePoints(points)
        assertEquals(1, samples.size)
        assertEquals(25.05, samples[0].latitude, 1e-6)
        assertEquals(121.5, samples[0].longitude, 1e-6)
    }

    @Test
    fun `long commutes sample quarter points`() {
        // ~33 km: quarter, mid, three-quarter.
        val points = listOf(LatLngPoint(25.0, 121.5), LatLngPoint(25.3, 121.5))
        val samples = RouteSampler.interiorSamplePoints(points)
        assertEquals(3, samples.size)
        assertEquals(25.075, samples[0].latitude, 1e-6)
        assertEquals(25.15, samples[1].latitude, 1e-6)
        assertEquals(25.225, samples[2].latitude, 1e-6)
    }

    @Test
    fun `midpoint interpolates within the containing segment`() {
        // Uneven vertices: 0 → 8 km → 10 km. Midpoint (5 km) sits inside the
        // first segment, not on a vertex.
        val points = listOf(
            LatLngPoint(25.0, 121.5),
            LatLngPoint(25.072, 121.5),
            LatLngPoint(25.09, 121.5)
        )
        val samples = RouteSampler.interiorSamplePoints(points)
        assertEquals(1, samples.size)
        assertEquals(25.045, samples[0].latitude, 1e-3)
    }

    @Test
    fun `haversine distance is plausible`() {
        // Taipei Main Station → Hsinchu Station is roughly 60–70 km.
        val meters = RouteSampler.haversineMeters(
            LatLngPoint(25.0478, 121.5170),
            LatLngPoint(24.8015, 120.9718)
        )
        assertTrue("was $meters", meters in 55_000.0..75_000.0)
    }
}
