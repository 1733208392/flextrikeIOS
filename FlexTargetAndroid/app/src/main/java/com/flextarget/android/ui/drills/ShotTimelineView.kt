package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.model.ShotData
import kotlinx.coroutines.delay
import kotlin.math.max
import kotlin.math.min

/**
 * Data class representing a cluster of shots fired within a time window
 */
private data class ShotCluster(
    val shots: List<Pair<Int, Double>>, // (index, cumulativeTime)
    val representativeTime: Double,
    val earliestTime: Double,
    val latestTime: Double
)

/**
 * Interactive timeline showing shot clusters with smart grouping and tooltips
 */
@Composable
fun ShotTimelineView(
    shots: List<ShotData>,
    currentProgress: Double,
    totalDuration: Double,
    onProgressChanged: (Double) -> Unit,
    modifier: Modifier = Modifier
) {
    // Calculate cumulative times for shots
    val shotTimings = remember(shots) {
        var cumulativeTime = 0.0
        shots.mapIndexed { index, shot ->
            cumulativeTime += shot.content.actualTimeDiff
            Pair(index, cumulativeTime)
        }
    }

    // Create clusters
    val clusters = remember(shots, totalDuration) {
        createShotClusters(shotTimings, totalDuration)
    }

    // Tooltip state
    var activeCluster by remember { mutableStateOf<ShotCluster?>(null) }
    var tooltipX by remember { mutableStateOf(0f) }
    var tooltipToken by remember { mutableStateOf(java.util.UUID.randomUUID()) }

    // Auto-hide tooltip after 1.2 seconds
    LaunchedEffect(activeCluster) {
        if (activeCluster != null) {
            val token = java.util.UUID.randomUUID()
            tooltipToken = token
            delay(1200)
            if (tooltipToken == token) {
                activeCluster = null
            }
        }
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(32.dp)
            .padding(horizontal = 16.dp)
    ) {
        // Background track (white 0.25 opacity) - 2.dp thin line
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(2.dp)
                .align(Alignment.Center)
                .background(Color.White.copy(alpha = 0.25f), shape = RoundedCornerShape(1.dp))
        )

        // Progress fill (white) - 2.dp thin line, grows left to right
        if (totalDuration > 0) {
            val progressFraction = (currentProgress / totalDuration).coerceIn(0.0, 1.0).toFloat()
            Box(
                modifier = Modifier
                    .height(2.dp)
                    .fillMaxWidth(fraction = progressFraction)
                    .align(Alignment.CenterStart)
                    .background(Color.White, shape = RoundedCornerShape(1.dp))
            )
        }

        // Shot cluster ticks and interactive area
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp)
                .pointerInput(Unit) {
                    detectTapGestures { offset ->
                        if (size.width > 0) {
                            val ratio = offset.x / size.width
                            val newProgress = ratio * totalDuration
                            onProgressChanged(newProgress.coerceIn(0.0, totalDuration))

                            // Find nearest cluster
                            val nearest = clusters.minByOrNull {
                                kotlin.math.abs(it.representativeTime - newProgress)
                            }
                            if (nearest != null) {
                                activeCluster = nearest
                                tooltipX = offset.x
                            }
                        }
                    }
                }
                .pointerInput(Unit) {
                    detectDragGestures { change, _ ->
                        if (size.width > 0) {
                            val ratio = change.position.x / size.width
                            val newProgress = (ratio * totalDuration).coerceIn(0.0, totalDuration)
                            onProgressChanged(newProgress)

                            // Update tooltip
                            val nearest = clusters.minByOrNull {
                                kotlin.math.abs(it.representativeTime - newProgress)
                            }
                            if (nearest != null) {
                                activeCluster = nearest
                                tooltipX = change.position.x
                            }
                        }
                    }
                }
        ) {
            // Draw cluster ticks
            clusters.forEach { cluster ->
                if (totalDuration > 0) {
                    val ratio = (cluster.representativeTime / totalDuration).coerceIn(0.0, 1.0).toFloat()
                    val isPastCluster = cluster.latestTime <= currentProgress + 0.0001
                    val tickWidth = if (cluster.shots.size > 1) 4.dp else 2.dp
                    val tickHeight = if (cluster.shots.size > 1) 18.dp else 12.dp
                    val baseColor = if (cluster.shots.size > 1) Color(0xFFFFA500) else Color.White.copy(alpha = 0.7f)
                    val fillColor = if (isPastCluster) {
                        if (cluster.shots.size > 1) Color(0xFFFFA500) else Color.Yellow
                    } else {
                        baseColor
                    }

                    Box(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .offset(x = (ratio * 100).dp - tickWidth / 2)
                            .width(tickWidth)
                            .height(tickHeight)
                            .background(fillColor)
                    )
                }
            }
        }

        // Tooltip
        if (activeCluster != null && clusters.isNotEmpty()) {
            val cluster = activeCluster!!
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = (-40).dp)
            ) {
                ClusterTooltip(cluster = cluster)
            }
        }
    }
}

/**
 * Create shot clusters by grouping shots within a merge window
 */
private fun createShotClusters(
    shotTimings: List<Pair<Int, Double>>,
    totalDuration: Double
): List<ShotCluster> {
    if (shotTimings.isEmpty()) return emptyList()

    val clusterMergeWindow = max(0.12, totalDuration * 0.02)
    val result = mutableListOf<ShotCluster>()
    var currentCluster = mutableListOf(shotTimings[0])

    for (i in 1 until shotTimings.size) {
        val shot = shotTimings[i]
        val lastTime = currentCluster.last().second
        
        if (shot.second - lastTime <= clusterMergeWindow) {
            currentCluster.add(shot)
        } else {
            result.add(
                ShotCluster(
                    shots = currentCluster.toList(),
                    representativeTime = currentCluster.map { it.second }.average(),
                    earliestTime = currentCluster.first().second,
                    latestTime = currentCluster.last().second
                )
            )
            currentCluster = mutableListOf(shot)
        }
    }

    result.add(
        ShotCluster(
            shots = currentCluster.toList(),
            representativeTime = currentCluster.map { it.second }.average(),
            earliestTime = currentCluster.first().second,
            latestTime = currentCluster.last().second
        )
    )

    return result
}

/**
 * Tooltip showing cluster information
 */
@Composable
private fun ClusterTooltip(cluster: ShotCluster) {
    Column(
        modifier = Modifier
            .background(Color.Black.copy(alpha = 0.85f), shape = RoundedCornerShape(6.dp))
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(6.dp))
            .padding(8.dp)
    ) {
        if (cluster.shots.size > 1) {
            Text(
                text = "${cluster.shots.size} shots",
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace
            )
        } else if (cluster.shots.isNotEmpty()) {
            Text(
                text = "Shot ${cluster.shots.first().first + 1}",
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace
            )
        }

        cluster.shots.forEach { (index, time) ->
            Text(
                text = String.format("%.2fs", time),
                color = Color.White.copy(alpha = 0.85f),
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace
            )
        }
    }
}
