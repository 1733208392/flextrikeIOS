package com.flextarget.android.ui.drills

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
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
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(8.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Repeat ${summary.repeatIndex}",
                style = MaterialTheme.typography.headlineSmall
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Total Shots
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(text = stringResource(R.string.cqb_total_shots))
                Text(text = "${summary.numShots}")
            }

            // Duration
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(text = stringResource(R.string.cqb_duration))
                Text(text = "${summary.totalTime} s") // Assuming totalTime is in seconds
            }

            // Passed/Failed
            summary.cqbPassed?.let { passed ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (passed) stringResource(R.string.cqb_passed) else stringResource(R.string.cqb_failed),
                        color = if (passed) Color.Green else Color.Red
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // CQB Results
            summary.cqbResults?.let { results ->
                if (results.isNotEmpty()) {
                    Text(
                        text = stringResource(R.string.cqb_threat),
                        style = MaterialTheme.typography.titleMedium
                    )
                    results.filter { it.isThreat }.forEach { result ->
                        TargetCardRow(result = result)
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = stringResource(R.string.cqb_non_threat),
                        style = MaterialTheme.typography.titleMedium
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
            )
        )

        // Shots
        Text(
            text = stringResource(
                R.string.cqb_shots_format,
                result.actualValidShots,
                result.expectedShots
            )
        )

        // Status
        val statusText = when (result.cardStatus) {
            CQBShotResult.CardStatus.green -> "✓"
            CQBShotResult.CardStatus.red -> "✗"
        }
        Text(
            text = statusText,
            color = when (result.cardStatus) {
                CQBShotResult.CardStatus.green -> Color.Green
                CQBShotResult.CardStatus.red -> Color.Red
            }
        )
    }
}