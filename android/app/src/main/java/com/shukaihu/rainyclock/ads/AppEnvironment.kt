package com.shukaihu.rainyclock.ads

import com.shukaihu.rainyclock.BuildConfig

object AppEnvironment {

    /** Google's public test banner unit for Android. */
    private const val TEST_BANNER_AD_UNIT_ID = "ca-app-pub-3940256099942544/6300978111"

    /**
     * Debug builds always use the test unit — requesting production ads from
     * development builds is invalid traffic and risks the AdMob account (the
     * same rule the iOS `AppEnvironment` enforces). A release build without a
     * configured production unit also falls back to the test unit rather than
     * silently requesting nothing.
     */
    val adMobBannerAdUnitId: String
        get() = if (BuildConfig.DEBUG || BuildConfig.ADMOB_BANNER_AD_UNIT_ID.isBlank()) {
            TEST_BANNER_AD_UNIT_ID
        } else {
            BuildConfig.ADMOB_BANNER_AD_UNIT_ID
        }
}
