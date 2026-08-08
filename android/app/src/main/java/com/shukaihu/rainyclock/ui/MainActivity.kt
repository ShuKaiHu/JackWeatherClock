package com.shukaihu.rainyclock.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Alarm
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.ads.AdBanner
import com.shukaihu.rainyclock.ads.ConsentManager

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
            MaterialTheme {
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

    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    var showPrivacyOptionsError by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        bottomBar = {
            Column {
                AdBanner(canRequestAds = canRequestAds, revision = adRevision)
                NavigationBar {
                    NavigationBarItem(
                        selected = selectedTab == 0,
                        onClick = { selectedTab = 0 },
                        icon = { Icon(Icons.Filled.Map, contentDescription = null) },
                        label = { Text(stringResource(R.string.tab_route)) }
                    )
                    NavigationBarItem(
                        selected = selectedTab == 1,
                        onClick = { selectedTab = 1 },
                        icon = { Icon(Icons.Filled.Alarm, contentDescription = null) },
                        label = { Text(stringResource(R.string.tab_alarm)) }
                    )
                }
            }
        }
    ) { innerPadding ->
        val contentModifier = Modifier.padding(innerPadding)
        when (selectedTab) {
            0 -> RouteTab(
                state = uiState,
                modifier = contentModifier,
                isRoutePreviewConfigured = viewModel.isRoutePreviewConfigured,
                onHomeAddressChange = viewModel::updateHomeAddress,
                onWorkAddressChange = viewModel::updateWorkAddress,
                onConfirmHomeSuggestion = viewModel::confirmHomeSuggestion,
                onConfirmWorkSuggestion = viewModel::confirmWorkSuggestion,
                onCommuteModeChange = viewModel::setCommuteMode,
                onRefreshRouteWeather = viewModel::refreshRouteWeather
            )
            else -> AlarmTab(
                state = uiState,
                modifier = contentModifier,
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
