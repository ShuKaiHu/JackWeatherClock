package com.shukaihu.rainyclock.geo

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import com.shukaihu.rainyclock.model.ResolvedLocation
import java.util.Locale
import kotlin.coroutines.resume
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

class AddressNotFoundException(val address: String) : Exception("Could not resolve address: $address")

/**
 * The Android counterpart of the iOS `MapItemResolver`: forward-geocodes a
 * typed address through the platform `Geocoder` (no API key, no billing —
 * matching the Apple-geocoding-only posture of the iOS app).
 */
class AddressResolver(context: Context) {

    private val appContext = context.applicationContext

    suspend fun resolve(address: String): ResolvedLocation {
        val trimmed = address.trim()
        if (trimmed.isEmpty()) throw AddressNotFoundException(address)
        if (!Geocoder.isPresent()) throw AddressNotFoundException(address)

        val geocoder = Geocoder(appContext, Locale.getDefault())
        val results = lookup(geocoder, trimmed)
        val best = results.firstOrNull() ?: throw AddressNotFoundException(address)

        return ResolvedLocation(
            latitude = best.latitude,
            longitude = best.longitude,
            formattedAddress = formatted(best) ?: trimmed
        )
    }

    private suspend fun lookup(geocoder: Geocoder, address: String): List<Address> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return suspendCancellableCoroutine { continuation ->
                geocoder.getFromLocationName(
                    address,
                    MAX_RESULTS,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) {
                            continuation.resume(addresses)
                        }

                        override fun onError(errorMessage: String?) {
                            continuation.resume(emptyList())
                        }
                    }
                )
            }
        }

        return withContext(Dispatchers.IO) {
            try {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(address, MAX_RESULTS) ?: emptyList()
            } catch (_: Exception) {
                emptyList()
            }
        }
    }

    private fun formatted(address: Address): String? =
        address.getAddressLine(0)
            ?: listOfNotNull(address.thoroughfare, address.locality, address.adminArea, address.countryName)
                .takeIf { it.isNotEmpty() }
                ?.joinToString(", ")

    private companion object {
        const val MAX_RESULTS = 5
    }
}
