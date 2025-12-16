package com.flextarget.android.ui.drills

import android.media.MediaPlayer
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.flextarget.android.R
import java.util.*
import java.util.Timer
import java.util.Date
import java.util.TimerTask
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.model.DrillExecutionManager
import com.flextarget.android.data.model.DrillRepeatSummary
import java.util.*
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

enum class TimerState {
    IDLE,
    STANDBY,
    RUNNING,
    PAUSED
}

@Composable
fun TimerSessionView(
    drillSetup: DrillSetupEntity,
    targets: List<DrillTargetsConfigEntity>,
    bleManager: AndroidBLEManager,
    navController: NavController,
    onDrillComplete: (List<DrillRepeatSummary>) -> Unit,
    onDrillFailed: () -> Unit
) {
    val context = LocalContext.current

    var timerState by remember { mutableStateOf(TimerState.IDLE) }
    var delayTarget by remember { mutableStateOf<Date?>(null) }
    var delayRemaining by remember { mutableStateOf(0.0) }
    var randomDelay by remember { mutableStateOf(0.0) }
    var timerStartDate by remember { mutableStateOf<Date?>(null) }
    var elapsedDuration by remember { mutableStateOf(0.0) }
    var updateTimer by remember { mutableStateOf<Timer?>(null) }
    var mediaPlayer by remember { mutableStateOf<MediaPlayer?>(null) }
    var showEndDrillAlert by remember { mutableStateOf(false) }
    var gracePeriodActive by remember { mutableStateOf(false) }
    var gracePeriodRemaining by remember { mutableStateOf(0.0) }
    val gracePeriodDuration = 3.0

    // Drill execution properties
    var executionManager by remember { mutableStateOf<DrillExecutionManager?>(null) }
    var readinessManager by remember { mutableStateOf<DrillExecutionManager?>(null) }
    var expectedDevices by remember { mutableStateOf<List<String>>(emptyList()) }

    // Target readiness properties
    var readyTargetsCount by remember { mutableStateOf(0) }
    var nonResponsiveTargets by remember { mutableStateOf<List<String>>(emptyList()) }
    var readinessTimeoutOccurred by remember { mutableStateOf(false) }

    // Consecutive repeats properties
    var currentRepeat by remember { mutableStateOf(1) }
    var totalRepeats by remember { mutableStateOf(1) }
    var accumulatedSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }
    var isPauseActive by remember { mutableStateOf(false) }
    var pauseRemaining by remember { mutableStateOf(0.0) }
    var drillEndedEarly by remember { mutableStateOf(false) }

    // Audio players
    val standbyPlayer = remember { MediaPlayer.create(context, R.raw.standby) }
    val highBeepPlayer = remember { MediaPlayer.create(context, R.raw.synthetic_shot_timer) }

    val elapsedTimeText by remember(elapsedDuration) {
        derivedStateOf {
            val centiseconds = (elapsedDuration * 100).toInt()
            val minutes = centiseconds / 100 / 60
            val seconds = centiseconds / 100 % 60
            val hundredths = centiseconds % 100
            String.format("%02d:%02d:%02d", minutes, seconds, hundredths)
        }
    }

    val buttonText by remember(timerState) {
        derivedStateOf {
            when (timerState) {
                TimerState.IDLE, TimerState.PAUSED -> "START"
                TimerState.STANDBY -> "STANDBY"
                TimerState.RUNNING -> "STOP"
            }
        }
    }

    val buttonColor by remember(timerState) {
        derivedStateOf {
            when (timerState) {
                TimerState.IDLE -> Color.Red
                TimerState.STANDBY -> Color.Red
                TimerState.RUNNING -> Color.Blue
                TimerState.PAUSED -> Color.Red
            }
        }
    }

    fun playStandbySound() {
        try {
            standbyPlayer?.start()
        } catch (e: Exception) {
            println("Failed to play standby audio: ${e.message}")
        }
    }

    fun playHighBeep() {
        try {
            highBeepPlayer?.start()
        } catch (e: Exception) {
            println("Failed to play audio: ${e.message}")
        }
    }

    fun stopUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = null
    }

    fun transitionToRunning(timestamp: Date) {
        timerState = TimerState.RUNNING
        timerStartDate = timestamp
        playHighBeep()
        executionManager?.setBeepTime(timestamp)
        executionManager?.startExecution()
    }

    fun resetTimer() {
        stopUpdateTimer()
        timerState = TimerState.IDLE
        delayTarget = null
        delayRemaining = 0.0
        timerStartDate = null
        elapsedDuration = 0.0
        gracePeriodActive = false
        gracePeriodRemaining = 0.0
        isPauseActive = false
        pauseRemaining = 0.0
    }

    fun resumeTimer() {
        val elapsedSoFar = elapsedDuration
        timerStartDate = Date(Date().time - (elapsedSoFar * 1000).toLong())
        timerState = TimerState.RUNNING
        startUpdateTimer()
    }

    fun startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    val now = Date()

                    if (timerState == TimerState.STANDBY && delayTarget != null) {
                        if (now >= delayTarget) {
                            delayTarget = null
                            delayRemaining = 0.0
                            transitionToRunning(now)
                        } else {
                            delayRemaining = (delayTarget!!.time - now.time) / 1000.0
                        }
                    }

                    if (timerState == TimerState.RUNNING && timerStartDate != null) {
                        elapsedDuration = (now.time - timerStartDate!!.time) / 1000.0
                    }

                    if (gracePeriodActive) {
                        gracePeriodRemaining = maxOf(0.0, gracePeriodRemaining - 0.05)
                        if (gracePeriodRemaining <= 0) {
                            gracePeriodActive = false

                            // Collect the summary from the just-completed repeat
                            // Use currentRepeat - 1 as the index since currentRepeat starts at 1
                            executionManager?.summaries?.getOrNull(currentRepeat - 1)?.let { completedSummary ->
                                accumulatedSummaries = accumulatedSummaries + completedSummary
                                println("Collected repeat ${completedSummary.repeatIndex} summary, total collected: ${accumulatedSummaries.size}")
                            }

                            // Check if drill was ended early or all repeats are complete
                            if (drillEndedEarly || currentRepeat >= totalRepeats) {
                                // Drill completed (either manually ended or all repeats done) - finalize drill
                                stopUpdateTimer()
                                executionManager?.completeDrill()
                            } else if (currentRepeat < totalRepeats) {
                                // More repeats to go - start pause and prepare next repeat
                                isPauseActive = true
                                pauseRemaining = drillSetup.pause.toDouble()

                                // Increment repeat for next drill
                                currentRepeat += 1

                                // Reset readiness state
                                readyTargetsCount = 0
                                nonResponsiveTargets = emptyList()
                                readinessTimeoutOccurred = false

                                // Start readiness check for next repeat
                                executionManager?.setCurrentRepeat(currentRepeat)
                                executionManager?.performReadinessCheck()
                            }
                        }
                    }

                    if (isPauseActive) {
                        pauseRemaining = maxOf(0.0, pauseRemaining - 0.05)
                        if (pauseRemaining <= 0) {
                            isPauseActive = false
                            resetTimer()
                            startSequence()
                        }
                    }
                }
            }, 0, 50)
        }
    }

    fun initializeReadinessCheck() {
        // Stop any existing execution manager
        executionManager?.stopExecution()

        // Extract expected devices from drill targets
        val expectedDevicesList = targets.mapNotNull { it.targetName }
        expectedDevices = expectedDevicesList

        // Initialize state
        currentRepeat = 1
        totalRepeats = drillSetup.repeats
        accumulatedSummaries = emptyList()

        // Create execution manager for the entire drill session
        val manager = DrillExecutionManager(
            bleManager = bleManager,
            drillSetup = drillSetup,
            targets = targets,
            expectedDevices = expectedDevices,
            onComplete = { summaries ->
                // This callback is ONLY called when completeDrill() is explicitly called by UI
                // It provides all summaries for all completed repeats
                onDrillComplete(summaries)
                // NOTE: Do NOT navigate here - let parent view handle navigation
            },
            onFailure = {
                onDrillFailed()
            },
            onReadinessUpdate = { readyCount, totalCount ->
                readyTargetsCount = readyCount
            },
            onReadinessTimeout = { nonResponsiveList ->
                nonResponsiveTargets = nonResponsiveList
                readinessTimeoutOccurred = true
            }
        )

        executionManager = manager
        // Set currentRepeat to 1 for first repeat
        manager.setCurrentRepeat(1)
        // Perform initial readiness check for first repeat
        manager.performReadinessCheck()
    }

    fun startSequence() {
        timerState = TimerState.STANDBY
        playStandbySound()
        val randomDelayValue = Random.nextInt(2, 6).toDouble()
        randomDelay = randomDelayValue
        delayTarget = Date(Date().time + (randomDelayValue * 1000).toLong())
        delayRemaining = randomDelayValue
        timerStartDate = null
        startUpdateTimer()

        // Set the current repeat and random delay in the manager
        executionManager?.setCurrentRepeat(currentRepeat)
        executionManager?.setRandomDelay(randomDelayValue)
    }

    fun startUpdateTimer() {
        stopUpdateTimer()
        updateTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    val now = Date()

                    if (timerState == TimerState.STANDBY && delayTarget != null) {
                        if (now >= delayTarget) {
                            delayTarget = null
                            delayRemaining = 0.0
                            transitionToRunning(now)
                        } else {
                            delayRemaining = (delayTarget!!.time - now.time) / 1000.0
                        }
                    }

                    if (timerState == TimerState.RUNNING && timerStartDate != null) {
                        elapsedDuration = (now.time - timerStartDate!!.time) / 1000.0
                    }

                    if (gracePeriodActive) {
                        gracePeriodRemaining = maxOf(0.0, gracePeriodRemaining - 0.05)
                        if (gracePeriodRemaining <= 0) {
                            gracePeriodActive = false

                            // Collect the summary from the just-completed repeat
                            // Use currentRepeat - 1 as the index since currentRepeat starts at 1
                            executionManager?.summaries?.getOrNull(currentRepeat - 1)?.let { completedSummary ->
                                accumulatedSummaries = accumulatedSummaries + completedSummary
                                println("Collected repeat ${completedSummary.repeatIndex} summary, total collected: ${accumulatedSummaries.size}")
                            }

                            // Check if drill was ended early or all repeats are complete
                            if (drillEndedEarly || currentRepeat >= totalRepeats) {
                                // Drill completed (either manually ended or all repeats done) - finalize drill
                                stopUpdateTimer()
                                executionManager?.completeDrill()
                            } else if (currentRepeat < totalRepeats) {
                                // More repeats to go - start pause and prepare next repeat
                                isPauseActive = true
                                pauseRemaining = drillSetup.pause.toDouble()

                                // Increment repeat for next drill
                                currentRepeat += 1

                                // Reset readiness state
                                readyTargetsCount = 0
                                nonResponsiveTargets = emptyList()
                                readinessTimeoutOccurred = false

                                // Set the next repeat in the manager and perform readiness check
                                executionManager?.setCurrentRepeat(currentRepeat)
                                executionManager?.performReadinessCheck()
                            }
                        }
                    }

                    if (isPauseActive) {
                        pauseRemaining = maxOf(0.0, pauseRemaining - 0.05)
                        if (pauseRemaining <= 0) {
                            isPauseActive = false
                            resetTimer()
                            startSequence()
                        }
                    }
                }
            }, 0, 50)
        }
    }

    fun buttonTapped() {
        if (isPauseActive) return
        when (timerState) {
            TimerState.IDLE -> startSequence()
            TimerState.STANDBY -> {} // Do nothing while delay is running
            TimerState.RUNNING -> {
                // End the drill by calling manualStopDrill and show grace period
                executionManager?.manualStopRepeat()
                timerState = TimerState.IDLE  // Stop the elapsed timer display
                gracePeriodActive = true
                gracePeriodRemaining = gracePeriodDuration
                stopUpdateTimer()
                startUpdateTimer()
            }
            TimerState.PAUSED -> resumeTimer()
        }
    }

    fun handleBackButtonTap() {
        if (timerState == TimerState.STANDBY || timerState == TimerState.RUNNING || gracePeriodActive || isPauseActive) {
            showEndDrillAlert = true
        } else {
            navController.popBackStack()
        }
    }

    fun endDrillEarly() {
        // Mark that drill was ended early by user
        drillEndedEarly = true

        // If already in grace period or pause, just proceed to complete the drill
        if (gracePeriodActive || isPauseActive) {
            stopUpdateTimer()
            executionManager?.completeDrill()
            return
        }

        // Otherwise, stop the current repeat and trigger grace period
        executionManager?.manualStopRepeat()
        timerState = TimerState.IDLE
        gracePeriodActive = true
        gracePeriodRemaining = gracePeriodDuration
        stopUpdateTimer()
        startUpdateTimer()

        // Grace period timer will check drillEndedEarly flag and complete drill instead of continuing
    }

    fun pauseTimer() {
        stopUpdateTimer()
        timerState = TimerState.PAUSED
    }

    LaunchedEffect(Unit) {
        initializeReadinessCheck()
    }

    DisposableEffect(Unit) {
        onDispose {
            stopUpdateTimer()
            readinessManager?.stopExecution()
            readinessManager = null
            mediaPlayer?.release()
            mediaPlayer = null
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = elapsedTimeText,
                    fontSize = 48.sp,
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 4.sp
                )

                if (timerState == TimerState.STANDBY) {
                    LinearProgressIndicator(
                        progress = (1f - (delayRemaining / randomDelay)).toFloat(),
                        modifier = Modifier
                            .width(200.dp)
                            .height(2.dp),
                        color = Color.Red,
                        trackColor = Color.White.copy(alpha = 0.2f)
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            if (gracePeriodActive) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(200.dp)
                ) {
                    CircularProgressIndicator(
                        progress = (gracePeriodRemaining / gracePeriodDuration).toFloat(),
                        modifier = Modifier.fillMaxSize(),
                        color = Color.Blue,
                        strokeWidth = 8.dp,
                        trackColor = Color.White.copy(alpha = 0.2f)
                    )
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = gracePeriodRemaining.toInt().toString(),
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "Processing shots",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            } else if (isPauseActive) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(200.dp)
                ) {
                    CircularProgressIndicator(
                        progress = (pauseRemaining / drillSetup.pause).toFloat(),
                        modifier = Modifier.fillMaxSize(),
                        color = Color.Green,
                        strokeWidth = 8.dp,
                        trackColor = Color.White.copy(alpha = 0.2f)
                    )
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = pauseRemaining.toInt().toString(),
                            fontSize = 32.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            text = "Pause between repeats",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            } else {
                Button(
                    onClick = { buttonTapped() },
                    modifier = Modifier.size(200.dp),
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = buttonColor,
                        disabledContainerColor = buttonColor.copy(alpha = 0.5f)
                    ),
                    enabled = !(timerState == TimerState.STANDBY || (timerState == TimerState.IDLE && readyTargetsCount < expectedDevices.size && expectedDevices.isNotEmpty()))
                ) {
                    Text(
                        text = buttonText,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
        }

        // Top bar with back button
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { handleBackButtonTap() }) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back",
                        tint = Color.Red
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
            }

            if (totalRepeats > 1) {
                Text(
                    text = "Repeat $currentRepeat of $totalRepeats",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Target readiness status at the bottom
            if (timerState == TimerState.IDLE || isPauseActive) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (readinessTimeoutOccurred) {
                        Text(
                            text = "Targets not ready",
                            fontSize = 14.sp,
                            color = Color.Red
                        )
                        Text(
                            text = "Targets not ready message",
                            fontSize = 12.sp,
                            color = Color(0xFFFFA500)
                        )
                        Text(
                            text = nonResponsiveTargets.joinToString(", "),
                            fontSize = 10.sp,
                            color = Color(0xFFFFA500)
                        )
                    } else {
                        Text(
                            text = "$readyTargetsCount/${expectedDevices.size} targets ready",
                            fontSize = 14.sp,
                            color = if (readyTargetsCount == expectedDevices.size && expectedDevices.isNotEmpty()) Color.Green else Color.White
                        )
                    }
                }
            }
        }

        if (showEndDrillAlert) {
            AlertDialog(
                onDismissRequest = { showEndDrillAlert = false },
                title = { Text("End drill") },
                text = { Text("Drill in progress") },
                confirmButton = {
                    TextButton(
                        onClick = {
                            showEndDrillAlert = false
                            endDrillEarly()
                        }
                    ) {
                        Text("Confirm", color = Color.Red)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showEndDrillAlert = false }) {
                        Text("Cancel")
                    }
                }
            )
        }
    }
}