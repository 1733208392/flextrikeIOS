package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.model.CQBShotResult
import com.flextarget.android.data.model.DrillRepeatSummary

@Composable
fun CQBDrillSummaryView(
    summaries: List<DrillRepeatSummary>,
    modifier: Modifier = Modifier
) {
    LazyColumn(modifier = modifier.fillMaxSize()) {
        items(summaries) { summary ->
            CQBDrillCard(summary = summary)
        }
    }
}

@Composable
private fun CQBDrillCard(summary: DrillRepeatSummary) {
    // Log the cqbPassed value
    android.util.Log.d("CQBDrillSummaryView", "Repeat #${summary.repeatIndex}: cqbPassed=${summary.cqbPassed}, cqbResults=${summary.cqbResults?.size ?: 0} results")
    
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1a1a1a))
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Title
            Text(
                text = "Repeat #${summary.repeatIndex}",
                style = MaterialTheme.typography.headlineSmall,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                modifier = Modifier.padding(bottom = 16.dp)
            )

            // Metrics Section
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFF2a2a2a), shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    .padding(12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Total Shots Metric
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(R.string.cqb_total_shots),
                        color = Color.Gray,
                        fontSize = 12.sp,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = "${summary.numShots}",
                        color = Color.White,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }

                // Duration Metric
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(R.string.cqb_duration),
                        color = Color.Gray,
                        fontSize = 12.sp,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = String.format("%.3f", summary.totalTime) + "s",
                        color = Color.White,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }

                // Status Section
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val passed = summary.cqbPassed ?: false
                    if (passed) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = "Passed",
                            tint = Color(0xFF4CAF50),
                            modifier = Modifier
                                .size(24.dp)
                                .padding(end = 4.dp)
                        )
                        Text(
                            text = stringResource(R.string.cqb_passed),
                            color = Color(0xFF4CAF50),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    } else {
                        Text(
                            text = stringResource(R.string.cqb_failed),
                            color = Color.Red,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // CQB Results
            summary.cqbResults?.let { results ->
                if (results.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(16.dp))

                    Text(
                        text = stringResource(R.string.cqb_threat),
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    results.filter { it.isThreat }.forEach { result ->
                        TargetCardRow(result = result)
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Text(
                        text = stringResource(R.string.cqb_non_threat),
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                        fontWeight = FontWeight.Bold
                    )
                    results.filter { !it.isThreat }.forEach { result ->
                        TargetCardRow(result = result)
                    }
                }
            }
        }
    }
}

@Composable
private fun TargetCardRow(result: CQBShotResult) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color(0xFF2a2a2a), shape = androidx.compose.foundation.shape.RoundedCornerShape(6.dp))
            .padding(12.dp)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        // Target Name
        Text(
            text = stringResource(
                id = when (result.targetName) {
                    "cqb_front" -> R.string.cqb_front
                    "cqb_swing" -> R.string.cqb_swing
                    "cqb_hostage" -> R.string.cqb_hostage
                    "disguised_enemy" -> R.string.disguised_enemy
                    else -> R.string.cqb // fallback
                }
            ),
            color = Color.White,
            fontSize = 14.sp
        )

        // Shots
        Text(
            text = stringResource(
                R.string.cqb_shots_format,
                result.actualValidShots,
                result.expectedShots
            ),
            color = Color.Gray,
            fontSize = 12.sp
        )

        // Status
        val statusText = when (result.cardStatus) {
            CQBShotResult.CardStatus.green -> "✓"
            CQBShotResult.CardStatus.red -> "✗"
        }
        Text(
            text = statusText,
            color = when (result.cardStatus) {
                CQBShotResult.CardStatus.green -> Color(0xFF4CAF50)
                CQBShotResult.CardStatus.red -> Color.Red
            },
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
    }
}