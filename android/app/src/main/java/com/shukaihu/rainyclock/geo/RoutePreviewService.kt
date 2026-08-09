package com.shukaihu.rainyclock.geo

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.shukaihu.rainyclock.logic.PolylineCodec
import com.shukaihu.rainyclock.model.CommuteMode
import com.shukaihu.rainyclock.model.LatLngPoint
import com.shukaihu.rainyclock.model.ResolvedLocation
import com.shukaihu.rainyclock.model.RoutePreview
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class RouteUnavailableException(message: String, cause: Throwable? = null) : Exception(message, cause)

interface RoutePreviewService {
    suspend fun fetchRoute(
        home: ResolvedLocation,
        work: ResolvedLocation,
        mode: CommuteMode
    ): RoutePreview
}

/**
 * Google Routes API (`computeRoutes`) client. The API key ships in the app,
 * which is Google's supported model for mobile: the key is restricted in the
 * Cloud console to this package + signing certificate, and the
 * X-Android-Package / X-Android-Cert headers carry the app identity the
 * restriction checks against.
 */
class GoogleRoutesPreviewService(
    context: Context,
    private val apiKey: String,
    private val endpoint: String = "https://routes.googleapis.com/directions/v2:computeRoutes"
) : RoutePreviewService {

    private val appContext = context.applicationContext
    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun fetchRoute(
        home: ResolvedLocation,
        work: ResolvedLocation,
        mode: CommuteMode
    ): RoutePreview = withContext(Dispatchers.IO) {
        // Every mode offered here maps to a free Essentials-tier travel mode, so
        // there is no billable path to fall back from.
        requestRoute(home, work, travelMode(mode))
    }

    private fun requestRoute(
        home: ResolvedLocation,
        work: ResolvedLocation,
        travelMode: String
    ): RoutePreview {
        val request = ComputeRoutesRequest(
            origin = Waypoint(Location(LatLng(home.latitude, home.longitude))),
            destination = Waypoint(Location(LatLng(work.latitude, work.longitude))),
            travelMode = travelMode
        )

        val body = post(json.encodeToString(request))
        val response = try {
            json.decodeFromString<ComputeRoutesResponse>(body)
        } catch (error: Exception) {
            throw RouteUnavailableException("Routes response could not be parsed", error)
        }

        val route = response.routes.firstOrNull()
            ?: throw RouteUnavailableException("Routes returned no route")
        val encoded = route.polyline?.encodedPolyline
            ?: throw RouteUnavailableException("Routes returned no polyline")
        val points = PolylineCodec.decode(encoded)
        if (points.size < 2) throw RouteUnavailableException("Routes polyline held fewer than two points")

        return RoutePreview(
            points = points,
            distanceMeters = route.distanceMeters,
            durationMinutes = parseDurationMinutes(route.duration)
        )
    }

    private fun post(payload: String): String {
        val connection = URL(endpoint).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-Goog-Api-Key", apiKey)
            connection.setRequestProperty(
                "X-Goog-FieldMask",
                "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"
            )
            connection.setRequestProperty("X-Android-Package", appContext.packageName)
            signingCertSha1()?.let { connection.setRequestProperty("X-Android-Cert", it) }

            connection.outputStream.use { it.write(payload.toByteArray()) }

            val code = connection.responseCode
            if (code != HttpURLConnection.HTTP_OK) {
                val detail = connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                throw RouteUnavailableException("Routes returned HTTP $code: ${detail.take(200)}")
            }
            return connection.inputStream.bufferedReader().use { it.readText() }
        } catch (error: RouteUnavailableException) {
            throw error
        } catch (error: Exception) {
            throw RouteUnavailableException("Routes request failed", error)
        } finally {
            connection.disconnect()
        }
    }

    /** Uppercase hex SHA-1 of the signing certificate, no separators. */
    private fun signingCertSha1(): String? = try {
        val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            appContext.packageManager
                .getPackageInfo(appContext.packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            @Suppress("DEPRECATION")
            appContext.packageManager
                .getPackageInfo(appContext.packageName, PackageManager.GET_SIGNATURES)
                .signatures?.firstOrNull()
        }
        signature?.let { sig ->
            MessageDigest.getInstance("SHA-1").digest(sig.toByteArray())
                .joinToString("") { "%02X".format(it) }
        }
    } catch (_: Exception) {
        null
    }

    private fun travelMode(mode: CommuteMode): String = when (mode) {
        CommuteMode.CAR -> "DRIVE"
        CommuteMode.WALKING -> "WALK"
        CommuteMode.PUBLIC_TRANSIT -> "TRANSIT"
    }

    /** Routes durations arrive as e.g. "1834s". */
    private fun parseDurationMinutes(duration: String?): Int {
        val seconds = duration?.removeSuffix("s")?.toLongOrNull() ?: 0L
        return ((seconds + 30) / 60).toInt()
    }
}

@Serializable
private data class ComputeRoutesRequest(
    val origin: Waypoint,
    val destination: Waypoint,
    val travelMode: String
)

@Serializable
private data class Waypoint(val location: Location)

@Serializable
private data class Location(val latLng: LatLng)

@Serializable
private data class LatLng(val latitude: Double, val longitude: Double)

@Serializable
private data class ComputeRoutesResponse(
    val routes: List<Route> = emptyList()
)

@Serializable
private data class Route(
    val distanceMeters: Int = 0,
    val duration: String? = null,
    val polyline: Polyline? = null
)

@Serializable
private data class Polyline(
    @SerialName("encodedPolyline")
    val encodedPolyline: String? = null
)
