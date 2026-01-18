package com.flextarget.android.presentation.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.data.repository.DrillExecutionState
import com.flextarget.android.presentation.viewmodel.BLEViewModel
import com.flextarget.android.presentation.viewmodel.DrillViewModel
import kotlinx.coroutines.delay
import java.util.UUID

/**
 * Drill Execution Screen
 * 
 * Orchestrates the drill execution lifecycle:
 * 1. Initialize - Send READY signal, wait for device ACK (10s timeout)
 * 2. Execute - Collect shots from device
 * 3. Finalize - Send STOP signal, wait for final shots
 * 4. Complete - Save results and display summary
 * 
 * Shows real-time feedback:
 * - Current score
 * - Shots received
 * - Device connection status
 * - Execution time
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillExecutionScreen(
    drillViewModel: DrillViewModel,
    bleViewModel: BLEViewModel,
    drillId: UUID? = null,
    onExecutionComplete: (score: Int, shotCount: Int) -> Unit = { _, _ -> }
) {
    val executionContext by drillViewModel.executionContext.collectAsState()
    val bleUiState by bleViewModel.bleUiState.collectAsState()
    val shotEvents by bleViewModel.shotEvents.collectAsState()
    
    var executionTime by remember { mutableStateOf(0) }
    
    // Update execution time every second
    LaunchedEffect(executionContext?.state) {
        while (executionContext?.state == DrillExecutionState.EXECUTING) {
            delay(1000)
            executionTime++
        }
    }
    
    // Initialize drill on first load
    LaunchedEffect(drillId) {
        if (drillId != null && executionContext == null) {
            drillViewModel.initializeDrill(drillId)
        }
    }
    
    // Handle execution complete
    LaunchedEffect(executionContext?.state) {
        if (executionContext?.state == DrillExecutionState.COMPLETE) {
            onExecutionComplete(
                executionContext?.totalScore ?: 0,
                executionContext?.shotsReceived ?: 0
            )
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(executionContext?.drillSetup?.name ?: "Drill Execution") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                navigationIcon = {
                    if (executionContext?.state in listOf(
                        DrillExecutionState.IDLE,
                        DrillExecutionState.ERROR
                    )) {
                        IconButton(onClick = { /* Navigate back */ }) {
                            Icon(
                                imageVector = Icons.Filled.ArrowBack,
                                contentDescription = "Back"
                            )
                        }
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Current state indicator
            StateIndicator(
                state = executionContext?.state ?: DrillExecutionState.IDLE,
                modifier = Modifier.padding(top = 16.dp)
            )
            
            // Main score display
            ScoreDisplay(
                score = executionContext?.totalScore ?: 0,
                shotsReceived = executionContext?.shotsReceived ?: 0,
                executionTime = executionTime
            )
            
            // Device status
            DeviceStatusCard(
                isConnected = bleUiState.isConnected,
                deviceState = bleUiState.deviceState.toString()
            )
            
            // Real-time shot feedback
            if (shotEvents != null) {
                ShotFeedbackCard(
                    lastShot = shotEvents,
                    allShots = emptyList() // Would be populated from BLE events
                )
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            // Action buttons based on execution state
            ActionButtons(
                state = executionContext?.state ?: DrillExecutionState.IDLE,
                onStartClicked = { drillViewModel.startExecuting() },
                onFinalizeClicked = { drillViewModel.finalizeDrill() },
                onCompleteClicked = { drillViewModel.completeDrill() },
                onAbortClicked = { drillViewModel.abortDrill() }
            )
        }
    }
}

/**
 * State indicator with color-coded status
 */
@Composable
fun StateIndicator(
    state: DrillExecutionState,
    modifier: Modifier = Modifier
) {
    val (color, label, icon) = when (state) {
        DrillExecutionState.IDLE -> Triple(Color.Gray, "Ready", Icons.Filled.FavoriteBorder)
        DrillExecutionState.INITIALIZED -> Triple(Color.Yellow, "Initialized", Icons.Filled.Schedule)
        DrillExecutionState.WAITING_ACK -> Triple(Color.Cyan, "Waiting ACK", Icons.Filled.AccessTime)
        DrillExecutionState.EXECUTING -> Triple(Color.Green, "Executing", Icons.Filled.CheckCircle)
        DrillExecutionState.FINALIZING -> Triple(Color.Blue, "Finalizing", Icons.Filled.Info)
        DrillExecutionState.COMPLETE -> Triple(Color.Magenta, "Complete", Icons.Filled.Done)
        DrillExecutionState.ERROR -> Triple(Color.Red, "Error", Icons.Filled.Error)
    }
    
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(color.copy(alpha = 0.2f))
            .padding(16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = color,
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = label,
            color = color,
            style = MaterialTheme.typography.titleMedium
        )
    }
}

/**
 * Large score display in center of screen
 */
@Composable
fun ScoreDisplay(
    score: Int,
    shotsReceived: Int,
    executionTime: Int
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(24.dp)
    ) {
        Text(
            text = "Current Score",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        
        Text(
            text = score.toString(),
            style = MaterialTheme.typography.displayLarge,
            fontSize = 72.sp,
            color = MaterialTheme.colorScheme.primary
        )
        
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 16.dp),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Shots", style = MaterialTheme.typography.labelSmall)
                Text(shotsReceived.toString(), style = MaterialTheme.typography.headlineSmall)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Time", style = MaterialTheme.typography.labelSmall)
                Text("${executionTime}s", style = MaterialTheme.typography.headlineSmall)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Average", style = MaterialTheme.typography.labelSmall)
                val avg = if (shotsReceived > 0) score / shotsReceived else 0
                Text(avg.toString(), style = MaterialTheme.typography.headlineSmall)
            }
        }
    }
}

/**
 * Device connection status card
 */
@Composable
fun DeviceStatusCard(
    isConnected: Boolean,
    deviceState: String
) {
    val backgroundColor = animateColorAsState(
        targetValue = if (isConnected) Color.Green.copy(alpha = 0.1f) else Color.Red.copy(alpha = 0.1f)
    )
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = backgroundColor.value)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (isConnected) Icons.Filled.BluetoothConnected else Icons.Filled.BluetoothDisabled,
                contentDescription = "Device status",
                tint = if (isConnected) Color.Green else Color.Red
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column {
                Text(
                    text = if (isConnected) "Device Connected" else "Device Disconnected",
                    style = MaterialTheme.typography.labelLarge
                )
                Text(
                    text = deviceState,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * Last shot feedback card
 */
@Composable
fun ShotFeedbackCard(
    lastShot: com.flextarget.android.data.repository.ShotEvent?,
    allShots: List<com.flextarget.android.data.repository.ShotEvent>
) {
    if (lastShot == null) return
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.tertiaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text("Last Shot", style = MaterialTheme.typography.labelLarge)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(32.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("X: ${lastShot.x}", style = MaterialTheme.typography.bodyMedium)
                Text("Y: ${lastShot.y}", style = MaterialTheme.typography.bodyMedium)
                Text("Score: ${lastShot.score}", style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

/**
 * Action buttons for drill control
 */
@Composable
fun ActionButtons(
    state: DrillExecutionState,
    onStartClicked: () -> Unit,
    onFinalizeClicked: () -> Unit,
    onCompleteClicked: () -> Unit,
    onAbortClicked: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        when (state) {
            DrillExecutionState.WAITING_ACK -> {
                Button(
                    onClick = onStartClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Start Shooting")
                }
            }
            DrillExecutionState.EXECUTING -> {
                Button(
                    onClick = onFinalizeClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Stop & Finalize")
                }
            }
            DrillExecutionState.FINALIZING -> {
                Button(
                    onClick = onCompleteClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Complete Drill")
                }
            }
            else -> {}
        }
        
        // Abort button
        if (state in listOf(
            DrillExecutionState.WAITING_ACK,
            DrillExecutionState.EXECUTING,
            DrillExecutionState.FINALIZING
        )) {
            OutlinedButton(
                onClick = onAbortClicked,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                Text("Abort Drill")
            }
        }
    }
}

/**
 * Drill Execution Screen Preview
 */
// @androidx.compose.ui.tooling.preview.Preview(showBackground = true)
// @Composable
// fun DrillExecutionScreenPreview() {
//     MaterialTheme {
//         DrillExecutionScreen()
//     }
// }
