package com.shukaihu.rainyclock.ads

import android.app.Activity
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Port of the iOS `ConsentManager`, minus ATT (which has no Android
 * counterpart — personalization is governed by the UMP/TCF consent alone,
 * which the Google Mobile Ads SDK reads on its own).
 */
class ConsentManager {

    private val _canRequestAds = MutableStateFlow(false)
    val canRequestAds: StateFlow<Boolean> = _canRequestAds.asStateFlow()

    private val _privacyOptionsRequired = MutableStateFlow(false)
    val privacyOptionsRequired: StateFlow<Boolean> = _privacyOptionsRequired.asStateFlow()

    /**
     * Bumped whenever an answer that shapes the ad request changes, so the
     * banner rebuilds instead of keeping a stale configuration (iOS audit
     * finding #4).
     */
    private val _adConfigurationRevision = MutableStateFlow(0)
    val adConfigurationRevision: StateFlow<Int> = _adConfigurationRevision.asStateFlow()

    /**
     * Runs the UMP flow: refresh consent info, then show the form when it is
     * required. Safe to call on every foreground — a failed round does not
     * latch; the next call retries (iOS audit cleanup: a networkless cold
     * start must not cost ads for the whole launch).
     */
    fun gatherConsent(activity: Activity) {
        val consentInformation = UserMessagingPlatform.getConsentInformation(activity)
        val parameters = ConsentRequestParameters.Builder().build()

        consentInformation.requestConsentInfoUpdate(
            activity,
            parameters,
            {
                UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { _ ->
                    refreshState(consentInformation)
                }
            },
            { _ ->
                // Keep whatever state we had; retry happens on next call.
                refreshState(consentInformation)
            }
        )
    }

    fun showPrivacyOptionsForm(activity: Activity, onFailure: () -> Unit) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { formError ->
            if (formError != null) {
                onFailure()
            }
            refreshState(UserMessagingPlatform.getConsentInformation(activity))
        }
    }

    private fun refreshState(consentInformation: ConsentInformation) {
        val couldRequestBefore = _canRequestAds.value
        // Two-way, not a latch: withdrawing consent must take ads down too.
        _canRequestAds.value = consentInformation.canRequestAds()
        _privacyOptionsRequired.value =
            consentInformation.privacyOptionsRequirementStatus ==
                ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
        if (couldRequestBefore != _canRequestAds.value) {
            _adConfigurationRevision.update { it + 1 }
        }
    }
}
