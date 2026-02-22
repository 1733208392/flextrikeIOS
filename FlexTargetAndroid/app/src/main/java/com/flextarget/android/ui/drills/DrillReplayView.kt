package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.ShotData

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillReplayView(
    drillSetup: DrillSetupEntity,
    shots: List<ShotData> = emptyList(),
    onBack: () -> Unit = {}
) {
    // State management
    var currentProgress by remember { mutableStateOf(0.0) }
    var isPlaying by remember { mutableStateOf(false) }

    // Calculate timing information
    val totalDuration = remember(shots) { TimingCalculator.calculateTotalDuration(shots) }
    val currentShotIndex = remember(currentProgress, shots) {
        TimingCalculator.findShotAtTime(shots, currentProgress)
    }

    // Timer for playback - 50ms updates for smooth animation
    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            while (isPlaying && currentProgress < totalDuration) {
                kotlinx.coroutines.delay(50) // 50ms per frame
                currentProgress += 0.05
            }
            if (currentProgress >= totalDuration) {
                isPlaying = false
                currentProgress = totalDuration
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.replay).uppercase(), color = md_theme_dark_onPrimary) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color(0xffde3823)
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
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            // Content
            if (shots.isEmpty()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(16.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "No shots to replay",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Top: Target preview area (~50% of height)
                TargetPreviewView(
                    shots = shots,
                    currentShotIndex = currentShotIndex,
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(0.70f),
                )

                // Bottom: Timeline and controls (~50%)
                Column(
                    modifier = Modifier
                        .weight(0.30f)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Time display (current / total)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = String.format("%.2f", minOf(currentProgress, totalDuration)),
                            color = Color.White,
                            style = MaterialTheme.typography.bodyMedium,
                            fontFamily = FontFamily.Monospace
                        )

                        Text(
                            text = String.format("%.2f", totalDuration),
                            color = Color.White.copy(alpha = 0.6f),
                            style = MaterialTheme.typography.bodyMedium,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    ShotTimelineView(
                        shots = shots,
                        currentProgress = currentProgress,
                        totalDuration = totalDuration,
                        onProgressChanged = { newProgress ->
                            currentProgress = newProgress
                            // Stop playback when user manually scrubs
                            isPlaying = false
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(20.dp)
                    )

                    // Playback controls
                    PlaybackControlsView(
                        isPlaying = isPlaying,
                        onPlayPauseClick = { isPlaying = !isPlaying },
                        onNextClick = {
                            // Jump to next shot
                            if (currentShotIndex < shots.size - 1) {
                                currentProgress = TimingCalculator.getTimeAtShotIndex(shots, currentShotIndex + 1)
                            } else {
                                currentProgress = totalDuration
                            }
                            isPlaying = false
                        },
                        onPrevClick = {
                            // Jump to previous shot
                            if (currentShotIndex > 0) {
                                currentProgress = TimingCalculator.getTimeAtShotIndex(shots, currentShotIndex - 1)
                            } else {
                                currentProgress = 0.0
                            }
                            isPlaying = false
                        },
                        canGoNext = currentShotIndex < shots.size - 1,
                        canGoPrev = currentShotIndex > 0
                    )
                }
            }
        }
        }
    }
}