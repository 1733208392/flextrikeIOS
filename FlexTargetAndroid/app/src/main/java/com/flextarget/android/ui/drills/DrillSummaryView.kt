package com.flextarget.android.ui.drills

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.zIndex
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.window.Dialog
import com.flextarget.android.R
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ScoringUtility
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillSummaryView(
    drillSetup: DrillSetupEntity,
    summaries: List<DrillRepeatSummary>,
    onBack: () -> Unit,
    onViewResult: (DrillRepeatSummary) -> Unit,
    onReplay: (DrillRepeatSummary) -> Unit,
    isCompetitionDrill: Boolean = false,
    athleteName: String = "",
    onCompetitionSubmit: () -> Unit = {}
) {
    val originalScores = remember { mutableStateMapOf<UUID, Int>() }

    // Initialize original scores on first composition
    LaunchedEffect(summaries) {
        summaries.forEach { summary ->
            if (!originalScores.containsKey(summary.id)) {
                originalScores[summary.id] = summary.score
            }
        }
    }

    var showEditDialog by remember { mutableStateOf(false) }
    var editingSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }

    val drillName = drillSetup.name ?: "Untitled Drill"
    val isCQBMode = drillSetup.mode?.lowercase() == "cqb"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        TopAppBar(
            title = {
                Text(
                    text = stringResource(R.string.drill_results_summary),
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

        Column(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            ) {
                if (summaries.isEmpty()) {
                    EmptyStateView()
                } else if (isCQBMode) {
                    CQBDrillSummaryView(summaries = summaries)
                } else {
                    val bottomPadding = if (isCompetitionDrill) 16.dp else 24.dp
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(top = 24.dp, bottom = bottomPadding, start = 16.dp, end = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        itemsIndexed(summaries) { index, summary ->
                            Column {
                                SummaryCard(
                                    title = "Repeat ${summary.repeatIndex}",
                                    subtitle = "Factor: ${String.format("%.1f", calculateFactor(summary.score, summary.totalTime))}",
                                    metrics = getMetricsForSummary(summary, drillSetup),
                                    summaryIndex = index,
                                    onDeductScore = { deductScore(summaries, index, originalScores) },
                                    onRestoreScore = { restoreScore(summaries, index, originalScores) },
                                    onCardClick = { onViewResult(summary) },
                                    onEditHitZones = {
                                        editingSummary = summary
                                        showEditDialog = true
                                    }
                                )
                                
                                // Play button below the card
//                                PlayReplayButton(
//                                    onReplay = {
//                                        try {
//                                            onReplay(summary)
//                                        } catch (e: Exception) {
//                                            e.printStackTrace()
//                                        }
//                                    }
//                                )
                                // Competition Submit Footer
                                if (isCompetitionDrill && summaries.isNotEmpty() && !isCQBMode) {
                                    CompetitionSubmitFooter(
                                        onReplay = {
                                            summaries.lastOrNull()?.let { summary ->
                                                onReplay(summary)
                                            }
                                        },
                                        onSubmit = onCompetitionSubmit
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Edit Dialog
    if (showEditDialog && editingSummary != null) {
        SummaryEditDialog(
            summary = editingSummary!!,
            drillSetup = drillSetup,
            onSave = { updatedZones ->
                editingSummary?.adjustedHitZones = updatedZones
                editingSummary?.score = ScoringUtility.calculateScoreFromAdjustedHitZones(updatedZones, null)
                showEditDialog = false
                editingSummary = null
            },
            onCancel = {
                showEditDialog = false
                editingSummary = null
            }
        )
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
            text = stringResource(R.string.no_results_available),
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
            fontWeight = FontWeight.Medium
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = stringResource(R.string.complete_drill_message),
            style = MaterialTheme.typography.bodyMedium,
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SummaryEditDialog(
    summary: DrillRepeatSummary,
    drillSetup: DrillSetupEntity,
    onSave: (Map<String, Int>) -> Unit,
    onCancel: () -> Unit
) {
    val effectiveCounts = ScoringUtility.calculateEffectiveCounts(summary.shots, null)
    val initialCounts = summary.adjustedHitZones ?: effectiveCounts

    var aCount by remember { mutableStateOf(initialCounts["A"] ?: 0) }
    var cCount by remember { mutableStateOf(initialCounts["C"] ?: 0) }
    var dCount by remember { mutableStateOf(initialCounts["D"] ?: 0) }
    var nCount by remember { mutableStateOf(initialCounts["N"] ?: 0) }
    var mCount by remember { mutableStateOf(initialCounts["M"] ?: 0) }
    var peCount by remember { mutableStateOf(initialCounts["PE"] ?: 0) }

    Dialog(onDismissRequest = onCancel) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = Color.Black)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = stringResource(R.string.edit_hit_zone_counts),
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(24.dp))

                // Zone editors
                ZoneEditor(stringResource(R.string.a_zone), aCount) { aCount = it }
                ZoneEditor(stringResource(R.string.c_zone), cCount) { cCount = it }
                ZoneEditor(stringResource(R.string.d_zone), dCount) { dCount = it }
                ZoneEditor(stringResource(R.string.no_shoot_zone), nCount) { nCount = it }
                ZoneEditor(stringResource(R.string.miss_zone), mCount) { mCount = it }
                ZoneEditor(stringResource(R.string.penalty_zone), peCount) { peCount = it }

                Spacer(modifier = Modifier.height(24.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    OutlinedButton(
                        onClick = onCancel,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Color.White
                        )
                    ) {
                        Text(stringResource(R.string.cancel))
                    }
                    Button(
                        onClick = {
                            val updatedZones = mapOf(
                                "A" to aCount,
                                "C" to cCount,
                                "D" to dCount,
                                "N" to nCount,
                                "M" to mCount,
                                "PE" to peCount
                            )
                            onSave(updatedZones)
                        },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.Red
                        )
                    ) {
                        Text(stringResource(R.string.save))
                    }
                }
            }
        }
    }
}

@Composable
private fun ZoneEditor(
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            color = Color.White,
            style = MaterialTheme.typography.bodyLarge
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            IconButton(
                onClick = { if (value > 0) onValueChange(value - 1) },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    Icons.Default.Remove,
                    contentDescription = "Decrease",
                    tint = Color.Red
                )
            }

            Text(
                text = value.toString(),
                color = Color.White,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.width(32.dp),
                textAlign = TextAlign.Center
            )

            IconButton(
                onClick = { onValueChange(value + 1) },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = "Increase",
                    tint = Color.Red
                )
            }
        }
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
    onCardClick: () -> Unit,
    onEditHitZones: () -> Unit
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
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Left side: Icon and title
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f)
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
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Divider
            Divider(
                color = Color.White.copy(alpha = 0.2f),
                thickness = 1.dp
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Metrics grid (2x3 layout - excluding Hit Zones)
            // 2 rows x 3 columns for better readability
            val metricsToDisplay = metrics.filter { !it.label.contains("Hit") }
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // First row: 3 metrics
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(60.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    metricsToDisplay.slice(0..2).forEachIndexed { index, metric ->
                        MetricView(
                            metric = metric,
                            modifier = Modifier.weight(1f),
                            onClick = if (metric.isClickable) {
                                // First metric (Total Time) navigates to DrillResultView
                                if (index == 0) onCardClick else onEditHitZones
                            } else null
                        )
                    }
                }
                
                // Second row: 3 metrics
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(60.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    metricsToDisplay.slice(3..5).forEachIndexed { index, metric ->
                        MetricView(
                            metric = metric,
                            modifier = Modifier.weight(1f),
                            onClick = if (metric.isClickable) {
                                // Index in filtered list is index+3, adjust for callback logic
                                if (index + 3 == 0) onCardClick else onEditHitZones
                            } else null
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Hit Zones badges row
            val hitZonesMetric = metrics.find { it.label.contains("Hit") }
            if (hitZonesMetric != null) {
                HitZonesBadgesRow(
                    metric = hitZonesMetric,
                    onClick = onEditHitZones
                )
            }
        }
    }
}

@Composable
private fun MetricView(
    metric: SummaryMetric,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null
) {
    // Extract numeric value for animation, but display the full formatted string
    val numericValue = metric.value
        .replace(" s", "")  // Remove time unit
        .replace(",", "")  // Remove commas if any
        .toFloatOrNull() ?: 0f

    val animatedValue by animateFloatAsState(
        targetValue = numericValue,
        animationSpec = tween(durationMillis = 500),
        label = "metric_animation"
    )

    Column(
        modifier = modifier
            .fillMaxHeight()
            .clip(RoundedCornerShape(18.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF2A2A2A),
                        Color(0xFF3A0A0A)
                    )
                )
            )
            .then(if (metric.isClickable) Modifier.clickable(onClick = onClick ?: {}) else Modifier),
//            .padding(vertical = 20.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically)
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

        // Value - animate the numeric part but display with proper formatting
        val displayText = if (metric.value.contains(" s")) {
            // For time values, animate the number but keep the "s" unit
            String.format("%.1f s", animatedValue)
        } else if (metric.value.contains(".")) {
            // For other decimal values, animate them
            String.format("%.1f", animatedValue)
        } else {
            // For integer values, display as-is
            metric.value
        }
        
        Text(
            text = displayText,
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
private fun HitZonesBadgesRow(
    metric: SummaryMetric,
    onClick: () -> Unit
) {
    val zoneLetters = listOf("A", "C", "D", "N", "M", "PE")
    val zoneColors = mapOf(
        "A" to Color(0xFFFF4444),
        "C" to Color(0xFFFF8800),
        "D" to Color(0xFFFFBB33),
        "N" to Color(0xFFCC0000),
        "M" to Color(0xFFFF5588),
        "PE" to Color(0xFFFF9900)
    )

    // Parse hit zones from metric value
    val countMap = mutableMapOf<String, Int>()
    metric.value.split(" ").forEach { part ->
        if (part.contains(":")) {
            val (zone, count) = part.split(":")
            countMap[zone] = count.toIntOrNull() ?: 0
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        zoneLetters.forEach { zone ->
            HitZoneBadge(
                zone = zone,
                count = countMap[zone] ?: 0,
                color = zoneColors[zone] ?: Color.Gray,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun HitZoneBadge(
    zone: String,
    count: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                brush = Brush.linearGradient(
                    colors = listOf(
                        Color(0xFF2A1A1A),
                        Color(0xFF3A0A0A)
                    )
                )
            )
            .border(2.dp, color, RoundedCornerShape(12.dp))
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(color, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = zone,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelMedium
            )
        }
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = count.toString(),
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
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
                text = stringResource(R.string.pe_abbrev),
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

@Composable
private fun PlayReplayButton(
    onReplay: () -> Unit
) {
    var isPressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1.0f,
        animationSpec = tween(durationMillis = 150),
        label = "play_button_scale"
    )
    val backgroundColor by animateFloatAsState(
        targetValue = if (isPressed) 1.0f else 0.95f,
        animationSpec = tween(durationMillis = 150),
        label = "play_button_bg"
    )

    Button(
        onClick = {
            isPressed = false
            onReplay()
        },
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .scale(scale)
            .shadow(8.dp, RoundedCornerShape(12.dp), ambientColor = Color.Red.copy(alpha = 0.5f)),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Red.copy(alpha = backgroundColor),
            contentColor = Color.White
        ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Icon(
            imageVector = Icons.Default.PlayArrow,
            contentDescription = null,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            stringResource(R.string.replay_drill),
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp
        )
    }
}

@Composable
private fun CompetitionSubmitFooter(
    onReplay: () -> Unit,
    onSubmit: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .background(Color.Black),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Button(
            onClick = onReplay,
            modifier = Modifier
                .weight(1f)
                .height(48.dp)
                .shadow(8.dp, RoundedCornerShape(12.dp), ambientColor = Color.Blue.copy(alpha = 0.3f)),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Red,
                contentColor = Color.White
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                stringResource(R.string.replay_drill),
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
        }

        Button(
            onClick = onSubmit,
            modifier = Modifier
                .weight(1f)
                .height(48.dp)
                .shadow(8.dp, RoundedCornerShape(12.dp), ambientColor = Color.Blue.copy(alpha = 0.3f)),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Blue,
                contentColor = Color.White
            ),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(Icons.Default.Upload, contentDescription = null, modifier = Modifier.size(20.dp))
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                stringResource(R.string.submit_competition_result),
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp
            )
        }
    }
}

// Helper functions
private fun getMetricsForSummary(summary: DrillRepeatSummary, drillSetup: DrillSetupEntity): List<SummaryMetric> {
    // Calculate effective counts
    val effectiveCounts = ScoringUtility.calculateEffectiveCounts(summary.shots, null)
    val adjustedCounts = summary.adjustedHitZones ?: effectiveCounts

    val hitZonesText = "A:${adjustedCounts["A"] ?: 0} C:${adjustedCounts["C"] ?: 0} D:${adjustedCounts["D"] ?: 0} M:${adjustedCounts["M"] ?: 0} N:${adjustedCounts["N"] ?: 0} PE:${adjustedCounts["PE"] ?: 0}"

    val metrics = listOf(
        SummaryMetric(
            icon = Icons.Outlined.Schedule,
            label = "Total Time",
            value = formatTime(summary.totalTime),
            isClickable = true
        ),
        SummaryMetric(
            icon = Icons.Outlined.Info,
            label = "Shots",
            value = "${summary.numShots}"
        ),
        SummaryMetric(
            icon = Icons.Filled.ElectricBolt,
            label = "Fastest",
            value = formatTime(summary.fastest)
        ),
        SummaryMetric(
            icon = Icons.Outlined.Schedule,
            label = "First Shot",
            value = formatTime(summary.firstShot)
        ),
        SummaryMetric(
            icon = Icons.Filled.LocalFireDepartment,
            label = "Score",
            value = "${summary.score}"
        ),
        SummaryMetric(
            icon = Icons.Outlined.Percent,
            label = "Factor",
            value = String.format("%.1f", calculateFactor(summary.score, summary.totalTime))
        ),
        SummaryMetric(
            icon = Icons.Default.Info,
            label = "Hit Zones",
            value = hitZonesText,
            isClickable = true
        )
    )

    return metrics
}

private fun formatTime(time: Double): String {
    return if (time.isFinite() && time > 0) {
        String.format("%.1f s", time)
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
    val footnote: String? = null,
    val isClickable: Boolean = false
)