package com.shukaihu.rainyclock.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.shukaihu.rainyclock.R
import com.shukaihu.rainyclock.ui.theme.AppAccent
import com.shukaihu.rainyclock.ui.theme.AppBackground
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.delay

/**
 * The full-screen ring surface raised over the lock screen. Audio belongs to
 * [AlarmRingService]; this activity only offers Stop and Snooze.
 */
class AlarmRingActivity : ComponentActivity() {

    private val ringStoppedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AlarmRingService.ACTION_RING_STOPPED) finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        ContextCompat.registerReceiver(
            this,
            ringStoppedReceiver,
            IntentFilter(AlarmRingService.ACTION_RING_STOPPED),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )

        val isAdjusted = intent.getBooleanExtra(AlarmRingService.EXTRA_IS_ADJUSTED, false)
        val snoozeMinutes = intent.getIntExtra(AlarmRingService.EXTRA_SNOOZE_MINUTES, 0)

        setContent {
            MaterialTheme {
                RingScreen(
                    isAdjusted = isAdjusted,
                    snoozeMinutes = snoozeMinutes,
                    onStop = { sendServiceAction(AlarmRingService.ACTION_STOP) },
                    onSnooze = { sendServiceAction(AlarmRingService.ACTION_SNOOZE, snoozeMinutes) }
                )
            }
        }
    }

    private fun sendServiceAction(action: String, snoozeMinutes: Int = 0) {
        startService(
            Intent(this, AlarmRingService::class.java).apply {
                this.action = action
                putExtra(AlarmRingService.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
            }
        )
        finish()
    }

    override fun onDestroy() {
        unregisterReceiver(ringStoppedReceiver)
        super.onDestroy()
    }
}

@Composable
private fun RingScreen(
    isAdjusted: Boolean,
    snoozeMinutes: Int,
    onStop: () -> Unit,
    onSnooze: () -> Unit
) {
    var now by remember { mutableStateOf(LocalTime.now()) }
    LaunchedEffect(Unit) {
        while (true) {
            now = LocalTime.now()
            delay(1_000)
        }
    }

    val timeFormatter = remember { DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppBackground)
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = now.format(timeFormatter),
            color = Color.White,
            fontSize = 64.sp
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(
                if (isAdjusted) R.string.alarm_alert_title_adjusted else R.string.alarm_alert_title_normal
            ),
            color = AppAccent,
            style = MaterialTheme.typography.titleLarge
        )
        Spacer(modifier = Modifier.height(64.dp))
        Button(
            onClick = onStop,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = AppAccent)
        ) {
            Text(text = stringResource(R.string.stop_alarm), fontSize = 20.sp)
        }
        if (snoozeMinutes > 0) {
            Spacer(modifier = Modifier.height(16.dp))
            OutlinedButton(onClick = onSnooze, modifier = Modifier.fillMaxWidth()) {
                Text(text = stringResource(R.string.alarm_snooze_button), fontSize = 20.sp, color = Color.White)
            }
        }
    }
}
