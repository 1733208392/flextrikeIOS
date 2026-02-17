package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.flextarget.android.R
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ScoringUtility
import kotlin.math.abs

@Composable
fun IDPADrillSummaryView(
    summaries: List<DrillRepeatSummary>,
    modifier: Modifier = Modifier,
    onViewResult: (DrillRepeatSummary) -> Unit = {},
    onReplay: (DrillRepeatSummary) -> Unit = {}
) {
    var showEditDialog by remember { mutableStateOf(false) }
    var editingSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    
    Box(modifier = modifier.fillMaxSize()) {
        if (summaries.isEmpty()) {
            EmptyStateView()
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                itemsIndexed(summaries) { index, summary ->
                    IDPADrillCard(
                        summary = summary,
                        index = index,
                        onEditZones = {
                            editingSummary = summary
                            showEditDialog = true
                        },
                        onViewResult = { onViewResult(summary) },
                        onReplay = { onReplay(summary) }
                    )
                }
            }
        }
    }

    // Edit Dialog
    if (showEditDialog && editingSummary != null) {
        IDPAZoneEditDialog(
            summary = editingSummary!!,
            onSave = { updatedZones ->
                editingSummary?.idpaZones = updatedZones
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
private fun IDPADrillCard(
    summary: DrillRepeatSummary,
    index: Int,
    modifier: Modifier = Modifier,
    onEditZones: () -> Unit = {},
    onViewResult: () -> Unit = {},
    onReplay: () -> Unit = {}
) {
    val breakdown = ScoringUtility.getIDPAZoneBreakdown(summary.shots)
    val pointsDown = ScoringUtility.calculateIDPAPointsDown(summary.shots)
    val finalTime = ScoringUtility.calculateIDPAFinalTime(summary.totalTime, pointsDown)

    Card(
        modifier = modifier
            .fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A1A)),
        elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header: Repeat number
            Text(
                text = String.format(stringResource(R.string.repeat_number), summary.repeatIndex),
                style = MaterialTheme.typography.titleMedium,
                color = Color.White,
                fontWeight = FontWeight.SemiBold
            )

            // Metrics row: Raw Time, Points Down, Final Time
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
                    .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(8.dp))
                    .padding(12.dp)
                    .clickable(onClick = onViewResult),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                MetricBox(
                    label = stringResource(R.string.idpa_raw_time),
                    value = formatTime(summary.totalTime),
                    modifier = Modifier.weight(1f)
                )

                MetricBox(
                    label = stringResource(R.string.idpa_points_down),
                    value = "${abs(pointsDown)}",
                    modifier = Modifier.weight(1f)
                )

                MetricBox(
                    label = stringResource(R.string.idpa_final_time),
                    value = formatTime(finalTime),
                    valueColor = Color.Red,
                    modifier = Modifier.weight(1f)
                )
            }

            // Zone breakdown
            IDPAZoneBreakdownView(breakdown = breakdown, pointsDown = pointsDown)

            // Replay button
            Button(
                onClick = onReplay,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Red.copy(alpha = 0.3f),
                    contentColor = Color.White
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.drill_replay),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp
                )
            }

            // Edit zones button
            Button(
                onClick = onEditZones,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Blue.copy(alpha = 0.3f),
                    contentColor = Color.White
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(
                    text = stringResource(R.string.edit_zones),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
private fun MetricBox(
    label: String,
    value: String,
    valueColor: Color = Color.White,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = label.uppercase(),
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.7f),
            fontWeight = FontWeight.SemiBold,
            fontSize = 10.sp
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleSmall,
            color = valueColor,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun IDPAZoneBreakdownView(
    breakdown: Map<String, Int>,
    pointsDown: Int,
    modifier: Modifier = Modifier
) {
    val zoneColors = mapOf(
        "Head" to Color(0xFF80FF80),    // Light green
        "Body" to Color(0xFFFFCC33),    // Yellow
        "Other" to Color(0xFFFF8033),   // Orange
        "Miss" to Color(0xFFFF5555)     // Red
    )

    val zonePoints = mapOf(
        "Head" to 0,
        "Body" to -1,
        "Other" to -3,
        "Miss" to -5
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.03f))
            .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = stringResource(R.string.idpa_zones_breakdown),
            style = MaterialTheme.typography.labelSmall,
            color = Color.White.copy(alpha = 0.7f),
            fontWeight = FontWeight.SemiBold
        )

        // Zone badges
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            listOf("Head", "Body", "Other", "Miss").forEach { zone ->
                val count = breakdown[zone] ?: 0
                val points = zonePoints[zone] ?: 0
                val color = zoneColors[zone] ?: Color.Gray

                IDPAZoneBadge(
                    zone = zone,
                    count = count,
                    points = points,
                    color = color,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // Total points down
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.idpa_total_points_down),
                style = MaterialTheme.typography.labelSmall,
                color = Color.White.copy(alpha = 0.7f),
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = "-${abs(pointsDown)}",
                style = MaterialTheme.typography.titleSmall,
                color = Color.Red,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun IDPAZoneBadge(
    zone: String,
    count: Int,
    points: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.1f))
            .border(2.dp, color, RoundedCornerShape(12.dp))
            .padding(12.dp),
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
                text = zone.take(1),
                color = Color.White,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.labelMedium
            )
        }
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = "$count",
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
        Text(
            text = if (points == 0) "0" else "$points",
            color = if (points < 0) Color.Red else Color.Green,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.labelSmall,
            fontSize = 10.sp
        )
    }
}

@Composable
private fun EmptyStateView() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
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
private fun IDPAZoneEditDialog(
    summary: DrillRepeatSummary,
    onSave: (Map<String, Int>) -> Unit,
    onCancel: () -> Unit
) {
    val breakdown = ScoringUtility.getIDPAZoneBreakdown(summary.shots)

    var headCount by remember { mutableStateOf(breakdown["Head"] ?: 0) }
    var bodyCount by remember { mutableStateOf(breakdown["Body"] ?: 0) }
    var otherCount by remember { mutableStateOf(breakdown["Other"] ?: 0) }
    var missCount by remember { mutableStateOf(breakdown["Miss"] ?: 0) }

    Dialog(onDismissRequest = onCancel) {
        Card(
            modifier = Modifier
                .fillMaxWidth(0.85f)
                .padding(16.dp),
            shape = RoundedCornerShape(24.dp),
            colors = CardDefaults.cardColors(containerColor = Color.Black)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                Text(
                    text = stringResource(R.string.edit_idpa_zones),
                    style = MaterialTheme.typography.headlineSmall,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                // Zone editors
                ZoneEditorField(stringResource(R.string.idpa_zone_head), headCount) { headCount = it }
                ZoneEditorField(stringResource(R.string.idpa_zone_body), bodyCount) { bodyCount = it }
                ZoneEditorField(stringResource(R.string.idpa_zone_other), otherCount) { otherCount = it }
                ZoneEditorField(stringResource(R.string.idpa_zone_miss), missCount) { missCount = it }

                Row(
                    modifier = Modifier
                        .fillMaxWidth(),
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
                                "Head" to headCount,
                                "Body" to bodyCount,
                                "Other" to otherCount,
                                "Miss" to missCount
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
private fun ZoneEditorField(
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
                    tint = Color.Blue
                )
            }
        }
    }
}

private fun formatTime(time: Double): String {
    return if (time.isFinite() && time > 0) {
        String.format("%.1f s", time)
    } else {
        "--"
    }
}
