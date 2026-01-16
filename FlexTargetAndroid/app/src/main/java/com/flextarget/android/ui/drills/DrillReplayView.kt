package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.ShotData
import kotlin.math.min

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillReplayView(
    drillSetup: DrillSetupEntity,
    shots: List<ShotData>,
    onBack: () -> Unit
) {
    var currentShotIndex by remember { mutableStateOf(0) }
    var isPlaying by remember { mutableStateOf(false) }

    // Auto-advance shots when playing
    LaunchedEffect(isPlaying) {
        while (isPlaying && currentShotIndex < shots.size) {
            kotlinx.coroutines.delay(1000) // 1 second per shot
            currentShotIndex = min(currentShotIndex + 1, shots.size)
        }
        if (currentShotIndex >= shots.size) {
            isPlaying = false
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Drill Replay", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.Red
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
        ) {
            // Progress control
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "${currentShotIndex} / ${shots.size} shots",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge
                )

                Slider(
                    value = currentShotIndex.toFloat(),
                    onValueChange = { currentShotIndex = it.toInt() },
                    valueRange = 0f..shots.size.toFloat(),
                    modifier = Modifier.weight(1f),
                    steps = if (shots.size > 1) shots.size - 1 else 0
                )

                Button(
                    onClick = { isPlaying = !isPlaying },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isPlaying) Color.Red else Color.Green
                    )
                ) {
                    Text(if (isPlaying) "Pause" else "Play")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Shot display
            if (shots.isNotEmpty()) {
                val visibleShots = shots.take(currentShotIndex + 1)

                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(visibleShots.size) { index ->
                        val shot = visibleShots[index]
                        val isCurrent = index == currentShotIndex

                        ShotReplayItem(
                            shot = shot,
                            shotNumber = index + 1,
                            isCurrent = isCurrent
                        )
                    }
                }
            } else {
                Text(
                    text = "No shots to replay",
                    color = Color.Gray,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                )
            }
        }
    }
}

@Composable
private fun ShotReplayItem(
    shot: ShotData,
    shotNumber: Int,
    isCurrent: Boolean
) {
    val backgroundColor = when {
        isCurrent -> Color.Red.copy(alpha = 0.8f)
        else -> Color.DarkGray.copy(alpha = 0.6f)
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = backgroundColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "#$shotNumber",
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.width(50.dp)
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Target: ${shot.device ?: "Unknown"}",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(
                    text = "Type: ${shot.content.actualTargetType}",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    text = "Hit: ${shot.content.actualHitArea}",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            Text(
                text = "${shot.content.actualTimeDiff}s",
                color = if (shot.content.actualTimeDiff > 0) Color.Green else Color.Red,
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.width(60.dp)
            )
        }
    }
}