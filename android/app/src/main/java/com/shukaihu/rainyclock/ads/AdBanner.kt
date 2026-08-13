package com.shukaihu.rainyclock.ads

import android.util.Log
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.LoadAdError
import com.shukaihu.rainyclock.BuildConfig

/**
 * The single anchored adaptive banner, shown only once UMP says ads may be
 * requested. `revision` recreates the view whenever a consent answer that
 * shapes the request changes.
 */
@Composable
fun AdBanner(canRequestAds: Boolean, revision: Int, modifier: Modifier = Modifier) {
    if (!canRequestAds) return

    val screenWidthDp = LocalConfiguration.current.screenWidthDp

    key(revision) {
        AndroidView(
            modifier = modifier.fillMaxWidth(),
            factory = { context ->
                AdView(context).apply {
                    setAdSize(
                        AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(context, screenWidthDp)
                    )
                    adUnitId = AppEnvironment.adMobBannerAdUnitId
                    adListener = object : AdListener() {
                        override fun onAdFailedToLoad(error: LoadAdError) {
                            // A failed load renders at height 0 and looks
                            // identical to no ad; keep the reason visible in
                            // debug builds (iOS audit cleanup).
                            if (BuildConfig.DEBUG) {
                                Log.w("AdBanner", "Ad failed to load: $error")
                            }
                        }
                    }
                    loadAd(AdRequest.Builder().build())
                }
            },
            onRelease = { adView -> adView.destroy() }
        )
    }
}
