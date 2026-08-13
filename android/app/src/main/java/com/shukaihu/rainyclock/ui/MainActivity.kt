package com.shukaihu.rainyclock.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Alarm
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.ads.AdBanner
import com.shukaihu.rainyclock.ads.ConsentManager
import com.shukaihu.rainyclock.ui.theme.AppBackground
import com.shukaihu.rainyclock.ui.theme.RainyClockTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private val viewModel: AlarmViewModel by viewModels()
    private val consentManager = ConsentManager()

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { _ ->
            // The alarm schedules either way: audio comes from the ring
            // service, the notification only adds the full-screen surface.
            viewModel.scheduleAlarm()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consentManager.gatherConsent(this)

        setContent {
            RainyClockTheme {
                MainScreen(
                    viewModel = viewModel,
                    consentManager = consentManager,
                    onScheduleRequested = ::scheduleWithPermission,
                    onShowPrivacyOptions = { onFailure ->
                        consentManager.showPrivacyOptionsForm(this, onFailure)
                    }
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        viewModel.refreshScheduledAlarmIfWeatherIsStale()
    }

    private fun scheduleWithPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            viewModel.scheduleAlarm()
        }
    }
}

@Composable
private fun MainScreen(
    viewModel: AlarmViewModel,
    consentManager: ConsentManager,
    onScheduleRequested: () -> Unit,
    onShowPrivacyOptions: (onFailure: () -> Unit) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val canRequestAds by consentManager.canRequestAds.collectAsState()
    val privacyOptionsRequired by consentManager.privacyOptionsRequired.collectAsState()
    val adRevision by consentManager.adConfigurationRevision.collectAsState()

    var showPrivacyOptionsError by rememberSaveable { mutableStateOf(false) }

    // iOS presents the two tabs as a paged TabView, so the strip is not the only
    // way between them — the pages swipe. The pager owns the selection; the tab
    // strip is a second control over the same state, not a parallel one.
    val pagerState = rememberPagerState(pageCount = { 2 })
    val scope = rememberCoroutineScope()

    Scaffold(
        bottomBar = {
            // The banner sits below the tab strip, at the very bottom of the
            // window, so the tabs stay within thumb reach. The gesture-bar inset
            // moves to the Column, or it would pad above the ad and leave the ad
            // itself underneath the system handle.
            Column(
                modifier = Modifier
                    .background(AppBackground)
                    .navigationBarsPadding()
            ) {
                IosCapsuleTabBar(
                    tabs = listOf(0, 1),
                    selected = pagerState.currentPage,
                    onSelect = { page -> scope.launch { pagerState.animateScrollToPage(page) } },
                    icon = { page -> if (page == 0) Icons.Outlined.Map else Icons.Outlined.Alarm },
                    title = { page ->
                        stringResource(if (page == 0) R.string.tab_route else R.string.tab_alarm)
                    }
                )
                AdBanner(canRequestAds = canRequestAds, revision = adRevision)
            }
        }
    ) { innerPadding ->
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) { page ->
            when (page) {
                0 -> RouteTab(
                    state = uiState,
                    isRoutePreviewConfigured = viewModel.isRoutePreviewConfigured,
                    usesAppleWeather = viewModel.usesAppleWeather,
                    onHomeAddressChange = viewModel::updateHomeAddress,
                    onWorkAddressChange = viewModel::updateWorkAddress,
                    onConfirmHomeSuggestion = viewModel::confirmHomeSuggestion,
                    onConfirmWorkSuggestion = viewModel::confirmWorkSuggestion,
                    onCommuteModeChange = viewModel::setCommuteMode,
                    onRefreshRouteWeather = viewModel::refreshRouteWeather
                )
                else -> AlarmTab(
                    state = uiState,
                    privacyOptionsRequired = privacyOptionsRequired,
                    onAlarmTimeChange = viewModel::setAlarmTime,
                    onWeekdayToggle = viewModel::toggleWeekday,
                    onLeadTimeChange = viewModel::setRainLeadTimeMinutes,
                    onThresholdChange = viewModel::setRainProbabilityThreshold,
                    onSoundChange = viewModel::setAlarmSound,
                    onPreviewSound = viewModel::previewSound,
                    onSnoozeEnabledChange = viewModel::setSnoozeEnabled,
                    onSnoozeDurationChange = viewModel::setSnoozeDurationMinutes,
                    onScheduleClick = onScheduleRequested,
                    onShowPrivacyOptions = { onShowPrivacyOptions { showPrivacyOptionsError = true } }
                )
            }
        }
    }

    if (showPrivacyOptionsError) {
        AlertDialog(
            onDismissRequest = { showPrivacyOptionsError = false },
            title = { Text(stringResource(R.string.ad_privacy_options_failed_title)) },
            text = { Text(stringResource(R.string.ad_privacy_options_failed_body)) },
            confirmButton = {
                TextButton(onClick = { showPrivacyOptionsError = false }) {
                    Text(stringResource(R.string.ok_button))
                }
            }
        )
    }
}
