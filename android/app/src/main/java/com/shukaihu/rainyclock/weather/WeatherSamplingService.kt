package com.shukaihu.rainyclock.weather

import com.shukaihu.rainyclock.model.WeatherSample
import java.time.Instant

interface WeatherSamplingService {
    /**
     * Returns the forecast condition and precipitation probability (0.0–1.0)
     * for the hour nearest [around] at the given coordinate.
     */
    suspend fun sampleWeather(latitude: Double, longitude: Double, around: Instant): WeatherSample
}

class WeatherUnavailableException(message: String, cause: Throwable? = null) : Exception(message, cause)
