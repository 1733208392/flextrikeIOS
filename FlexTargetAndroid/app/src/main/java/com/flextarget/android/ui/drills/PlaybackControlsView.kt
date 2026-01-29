package com.flextarget.android.ui.drills

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

/**
 * Playback controls for drill replay - matches iOS design
 * Includes backward, play/pause, and forward buttons
 */
@Composable
fun PlaybackControlsView(
    isPlaying: Boolean,
    onPlayPauseClick: () -> Unit,
    onNextClick: () -> Unit,
    onPrevClick: () -> Unit,
    canGoNext: Boolean = true,
    canGoPrev: Boolean = true,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 16.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Backward button
        IconButton(
            onClick = onPrevClick,
            enabled = canGoPrev,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = "Previous",
                tint = if (canGoPrev) Color.White else Color.Gray,
                modifier = Modifier
                    .size(24.dp)
                    .graphicsLayer(rotationZ = 180f)
            )
        }

        Spacer(modifier = Modifier.width(40.dp))

        // Play/Pause button (large centered)
        IconButton(
            onClick = onPlayPauseClick,
            modifier = Modifier.size(80.dp)
        ) {
            Icon(
                imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = if (isPlaying) "Pause" else "Play",
                tint = Color.White,
                modifier = Modifier.size(44.dp)
            )
        }

        Spacer(modifier = Modifier.width(40.dp))

        // Forward button
        IconButton(
            onClick = onNextClick,
            enabled = canGoNext,
            modifier = Modifier.size(48.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = "Next",
                tint = if (canGoNext) Color.White else Color.Gray,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
