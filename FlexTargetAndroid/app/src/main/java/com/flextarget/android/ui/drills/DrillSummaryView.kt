package com.flextarget.android.ui.drills

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillSummaryView(
    drillSetup: DrillSetupEntity,
    summaries: List<DrillRepeatSummary>,
    onBack: () -> Unit,
    onViewResult: (DrillRepeatSummary) -> Unit
) {
    println("[DrillSummaryView] Rendering with ${summaries.size} summaries")
    summaries.forEach { summary ->
        println("[DrillSummaryView] Summary ${summary.repeatIndex}: ${summary.numShots} shots, score: ${summary.score}")
    }
    val originalScores = remember { mutableStateMapOf<UUID, Int>() }

    // Initialize original scores on first composition
    LaunchedEffect(summaries) {
        summaries.forEach { summary ->
            if (!originalScores.containsKey(summary.id)) {
                originalScores[summary.id] = summary.score
            }
        }
    }

    val drillName = drillSetup.name ?: "Untitled Drill"

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Drill Results Summary",
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .background(Color.Black, CircleShape)
                                .shadow(8.dp, CircleShape, ambientColor = Color.Red.copy(alpha = 0.3f))
                        ) {
                            Icon(
                                Icons.Default.ArrowBack,
                                contentDescription = "Back",
                                tint = Color.Red,
                                modifier = Modifier.align(Alignment.Center)
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black.copy(alpha = 0.95f)
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
        ) {
            if (summaries.isEmpty()) {
                EmptyStateView()
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 24.dp, horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    itemsIndexed(summaries) { index, summary ->
                        SummaryCard(
                            title = "Repeat ${summary.repeatIndex}",
                            subtitle = "Factor: ${String.format("%.2f", calculateFactor(summary.score, summary.totalTime))}",
                            metrics = getMetricsForSummary(summary),
                            summaryIndex = index,
                            onDeductScore = { deductScore(summaries, index, originalScores) },
                            onRestoreScore = { restoreScore(summaries, index, originalScores) },
                            onCardClick = { onViewResult(summary) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyStateView() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Filled.Info,
            contentDescription = null,
            tint = Color.Red,
            modifier = Modifier.size(48.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "No Results Available",
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
            fontWeight = FontWeight.Medium
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Complete a drill to see your results here",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun SummaryCard(
    title: String,
    subtitle: String,
    metrics: List<SummaryMetric>,
    summaryIndex: Int,
    onDeductScore: () -> Unit,
    onRestoreScore: () -> Unit,
    onCardClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onCardClick),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color(0xFF1A1A1A),
                            Color(0xFF2A0A0A)
                        )
                    )
                )
                .padding(20.dp)
        ) {
            // Header with title and buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Icon and title
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .background(Color.Black, CircleShape)
                            .shadow(8.dp, CircleShape, ambientColor = Color.Red.copy(alpha = 0.3f))
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Star,
                            contentDescription = null,
                            tint = Color.Red,
                            modifier = Modifier.align(Alignment.Center)
                        )
                    }

                    Column {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Action buttons
                PenaltyButton(onClick = onDeductScore)
                Spacer(modifier = Modifier.width(8.dp))
                RestoreButton(onClick = onRestoreScore)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Divider
            Divider(
                color = Color.White.copy(alpha = 0.2f),
                thickness = 1.dp
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Metrics grid
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                metrics.forEach { metric ->
                    MetricView(
                        metric = metric,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun MetricView(
    metric: SummaryMetric,
    modifier: Modifier = Modifier
) {
    val animatedValue by animateFloatAsState(
        targetValue = metric.value.toFloatOrNull() ?: 0f,
        animationSpec = tween(durationMillis = 500),
        label = "metric_animation"
    )

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(18.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF2A2A2A),
                        Color(0xFF3A0A0A)
                    )
                )
            )
            .padding(vertical = 14.dp, horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Icon and label
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = metric.icon,
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(14.dp)
            )
            Text(
                text = metric.label.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.7f),
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.6.sp
            )
        }

        // Value
        Text(
            text = if (metric.value.contains(".")) {
                String.format("%.2f", animatedValue)
            } else {
                metric.value
            },
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )

        // Footnote if present
        metric.footnote?.let { footnote ->
            Text(
                text = footnote,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.6f),
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun PenaltyButton(onClick: () -> Unit) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.92f else 1.0f,
        animationSpec = tween(durationMillis = 150),
        label = "penalty_button_scale"
    )

    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(40.dp)
            .scale(scale)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black, CircleShape)
                .shadow(6.dp, CircleShape, ambientColor = Color(0xFFFFA500).copy(alpha = 0.3f))
        ) {
            Text(
                text = "PE",
                color = Color(0xFFFFA500), // Orange
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.Center)
            )
        }
    }
}

@Composable
private fun RestoreButton(onClick: () -> Unit) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.92f else 1.0f,
        animationSpec = tween(durationMillis = 150),
        label = "restore_button_scale"
    )

    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(40.dp)
            .scale(scale)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black, CircleShape)
                .shadow(6.dp, CircleShape, ambientColor = Color.Green.copy(alpha = 0.3f))
        ) {
            Icon(
                imageVector = Icons.Default.Refresh,
                contentDescription = "Restore",
                tint = Color.Green,
                modifier = Modifier
                    .size(16.dp)
                    .align(Alignment.Center)
            )
        }
    }
}

// Helper functions
private fun getMetricsForSummary(summary: DrillRepeatSummary): List<SummaryMetric> {
    return listOf(
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "Total Time",
            value = formatTime(summary.totalTime)
        ),
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "Shots",
            value = "${summary.numShots}"
        ),
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "Fastest",
            value = formatTime(summary.fastest)
        ),
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "First Shot",
            value = formatTime(summary.firstShot)
        ),
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "Score",
            value = "${summary.score}"
        )
    )
}

private fun formatTime(time: Double): String {
    return if (time.isFinite() && time > 0) {
        String.format("%.2f s", time)
    } else {
        "--"
    }
}

private fun calculateFactor(score: Int, time: Double): Double {
    return if (time > 0) score.toDouble() / time else 0.0
}

private fun deductScore(
    summaries: List<DrillRepeatSummary>,
    index: Int,
    originalScores: MutableMap<UUID, Int>
) {
    if (index in summaries.indices) {
        summaries[index].score -= 10
    }
}

private fun restoreScore(
    summaries: List<DrillRepeatSummary>,
    index: Int,
    originalScores: MutableMap<UUID, Int>
) {
    if (index in summaries.indices) {
        val summary = summaries[index]
        originalScores[summary.id]?.let { originalScore ->
            summary.score = originalScore
        }
    }
}

private data class SummaryMetric(
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val label: String,
    val value: String,
    val footnote: String? = null
)