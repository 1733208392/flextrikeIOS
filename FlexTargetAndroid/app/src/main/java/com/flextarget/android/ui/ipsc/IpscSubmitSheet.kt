package com.flextarget.android.ui.ipsc

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ScoringUtility
import com.flextarget.android.data.remote.api.IpscMatch
import com.flextarget.android.data.remote.api.IpscShooter
import com.flextarget.android.data.remote.api.IpscSquad

private val DarkBg = Color(0xFF0D0D0D)
private val CardBg = Color(0xFF1A1A1A)
private val AccentRed = Color(0xFFDE3823)
private val TextPrimary = Color.White
private val TextSecondary = Color(0xFFAAAAAA)

/**
 * Full-screen dialog that walks the user through:
 *  Step 1 — pick a match  (接口 3)
 *  Step 2 — pick a shooter from the squad queue  (接口 1)
 *  Step 3 — choose repeat (if multiple) + enter stage ID, then submit  (接口 2)
 */
@Composable
fun IpscSubmitDialog(
    viewModel: IpscSubmitViewModel,
    summaries: List<DrillRepeatSummary>,
    onDismiss: () -> Unit
) {
    val step by viewModel.step.collectAsState()

    // Kick off match loading when the dialog first appears
    LaunchedEffect(Unit) {
        if (step is IpscSubmitStep.Idle) viewModel.start()
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(DarkBg)
        ) {
            when (val s = step) {
                is IpscSubmitStep.Idle,
                is IpscSubmitStep.LoadingMatches -> LoadingStep("Loading matches…")

                is IpscSubmitStep.MatchPicker -> MatchPickerStep(
                    matches = s.matches,
                    onSelectMatch = { viewModel.selectMatch(it) },
                    onRefresh = { viewModel.refreshMatches() },
                    onDismiss = onDismiss
                )

                is IpscSubmitStep.LoadingSquads -> LoadingStep("Loading shooters…")

                is IpscSubmitStep.ShooterPicker -> ShooterPickerStep(
                    squads = s.squads,
                    matchId = s.matchId,
                    onSelectShooter = { viewModel.selectShooter(s.matchId, it) },
                    onRefresh = { viewModel.refreshSquads(s.matchId) },
                    onBack = { viewModel.back() },
                    onDismiss = onDismiss
                )

                is IpscSubmitStep.Confirm -> ConfirmStep(
                    matchId = s.matchId,
                    shooter = s.shooter,
                    summaries = summaries,
                    onSubmit = { stageId, summary ->
                        viewModel.submit(s.matchId, s.shooter, stageId, summary)
                    },
                    onBack = { viewModel.back() },
                    onDismiss = onDismiss
                )

                is IpscSubmitStep.Submitting -> LoadingStep("Submitting…")

                is IpscSubmitStep.Success -> SuccessStep(
                    hitFactor = s.hitFactor,
                    totalPoints = s.totalPoints,
                    onClose = onDismiss
                )

                is IpscSubmitStep.Error -> ErrorStep(
                    message = s.message,
                    onRetry = s.retryAction,
                    onDismiss = onDismiss
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Loading
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun LoadingStep(label: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            CircularProgressIndicator(color = AccentRed, strokeWidth = 3.dp)
            Text(label, color = TextSecondary, fontSize = 14.sp)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Match Picker
// ─────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MatchPickerStep(
    matches: List<IpscMatch>,
    onSelectMatch: (Int) -> Unit,
    onRefresh: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        CenterAlignedTopAppBar(
            title = { Text("Select Match", color = TextPrimary, fontWeight = FontWeight.SemiBold) },
            navigationIcon = {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Close", tint = AccentRed)
                }
            },
            actions = {
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = TextSecondary)
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = DarkBg)
        )

        if (matches.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No active matches found.", color = TextSecondary, textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(matches) { match ->
                    MatchCard(match = match, onClick = { onSelectMatch(match.id) })
                }
            }
        }
    }
}

@Composable
private fun MatchCard(match: IpscMatch, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(match.name, color = TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                Spacer(Modifier.height(4.dp))
                Text(match.date, color = TextSecondary, fontSize = 13.sp)
            }
            MatchStatusBadge(status = match.status)
        }
    }
}

@Composable
private fun MatchStatusBadge(status: String) {
    val (bgColor, label) = when (status.lowercase()) {
        "active" -> Color(0xFF2E7D32) to "Active"
        "completed" -> Color(0xFF37474F) to "Done"
        else -> Color(0xFF555555) to status.replaceFirstChar { it.uppercase() }
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(label, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Shooter Picker
// ─────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShooterPickerStep(
    squads: List<IpscSquad>,
    matchId: Int,
    onSelectShooter: (IpscShooter) -> Unit,
    onRefresh: () -> Unit,
    onBack: () -> Unit,
    onDismiss: () -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        CenterAlignedTopAppBar(
            title = { Text("Select Shooter", color = TextPrimary, fontWeight = FontWeight.SemiBold) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = AccentRed)
                }
            },
            actions = {
                IconButton(onClick = onRefresh) {
                    Icon(Icons.Default.Refresh, contentDescription = "Refresh", tint = TextSecondary)
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = DarkBg)
        )

        val allShooters = squads.flatMap { it.shooters }
        if (allShooters.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("No shooters found in this match.", color = TextSecondary, textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                squads.filter { it.shooters.isNotEmpty() }.forEach { squad ->
                    item(key = "header_${squad.id}") {
                        SquadHeader(squad = squad)
                    }
                    items(squad.shooters, key = { "shooter_${it.id}" }) { shooter ->
                        ShooterCard(shooter = shooter, onClick = { onSelectShooter(shooter) })
                    }
                    item(key = "spacer_${squad.id}") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun SquadHeader(squad: IpscSquad) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            squad.name.uppercase(),
            color = AccentRed,
            fontWeight = FontWeight.Bold,
            fontSize = 12.sp,
            letterSpacing = 1.sp
        )
        Text(
            "${squad.shooters.size} / ${squad.shooterCount} shooters",
            color = TextSecondary,
            fontSize = 11.sp
        )
    }
    Divider(color = Color.White.copy(alpha = 0.1f), thickness = 0.5.dp)
    Spacer(Modifier.height(6.dp))
}

@Composable
private fun ShooterCard(shooter: IpscShooter, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(10.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Bib badge
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Color(0xFF2A2A2A))
                    .border(1.dp, AccentRed.copy(alpha = 0.6f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(shooter.bibNumber, color = AccentRed, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(shooter.name, color = TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
                Spacer(Modifier.height(2.dp))
                val shooterMeta = listOfNotNull(
                    shooter.divisionName.takeIf { it.isNotEmpty() },
                    shooter.categoryName?.takeIf { it.isNotEmpty() }
                        ?: shooter.powerFactor.takeIf { it.isNotEmpty() }?.replaceFirstChar { it.uppercase() }
                ).joinToString(" · ")
                Text(
                    shooterMeta,
                    color = TextSecondary,
                    fontSize = 12.sp
                )
            }

            ShooterStatusBadge(status = shooter.status)
        }
    }
}

@Composable
private fun ShooterStatusBadge(status: String) {
    val (bgColor, label) = when (status.lowercase()) {
        "waiting" -> Color(0xFF424242) to "Waiting"
        "shooting" -> Color(0xFFF57F17) to "Shooting"
        "done" -> Color(0xFF1B5E20) to "Done"
        else -> Color(0xFF424242) to status.replaceFirstChar { it.uppercase() }
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .padding(horizontal = 8.dp, vertical = 3.dp)
    ) {
        Text(label, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Confirm & Submit
// ─────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConfirmStep(
    matchId: Int,
    shooter: IpscShooter,
    summaries: List<DrillRepeatSummary>,
    onSubmit: (stageId: String, summary: DrillRepeatSummary) -> Unit,
    onBack: () -> Unit,
    onDismiss: () -> Unit
) {
    var stageId by remember { mutableStateOf("") }
    var selectedSummaryIndex by remember { mutableStateOf(0) }
    val selectedSummary = summaries.getOrElse(selectedSummaryIndex) { summaries.first() }

    Column(modifier = Modifier.fillMaxSize()) {
        CenterAlignedTopAppBar(
            title = { Text("Confirm & Submit", color = TextPrimary, fontWeight = FontWeight.SemiBold) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = AccentRed)
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = DarkBg)
        )

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Shooter summary card
            item {
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = CardBg),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Shooter", color = TextSecondary, fontSize = 12.sp)
                        Spacer(Modifier.height(6.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF2A2A2A))
                                    .border(1.dp, AccentRed.copy(alpha = 0.6f), CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(shooter.bibNumber, color = AccentRed, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                            }
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text(shooter.name, color = TextPrimary, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                                Text(
                                    "${shooter.divisionName} · ${shooter.powerFactor.replaceFirstChar { it.uppercase() }}",
                                    color = TextSecondary,
                                    fontSize = 12.sp
                                )
                            }
                        }
                    }
                }
            }

            // Stage ID input
            item {
                OutlinedTextField(
                    value = stageId,
                    onValueChange = { stageId = it.filter { c -> c.isDigit() } },
                    label = { Text("Stage ID", color = TextSecondary) },
                    placeholder = { Text("Enter stage number", color = Color(0xFF666666)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AccentRed,
                        unfocusedBorderColor = Color(0xFF444444),
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        cursorColor = AccentRed
                    ),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            // Repeat picker (only when more than 1 repeat)
            if (summaries.size > 1) {
                item {
                    Text("Select Repeat", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Spacer(Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        summaries.forEachIndexed { index, summary ->
                            val isSelected = index == selectedSummaryIndex
                            FilterChip(
                                selected = isSelected,
                                onClick = { selectedSummaryIndex = index },
                                label = { Text("R${summary.repeatIndex}", fontSize = 13.sp) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = AccentRed,
                                    selectedLabelColor = Color.White,
                                    containerColor = Color(0xFF2A2A2A),
                                    labelColor = TextSecondary
                                ),
                                border = FilterChipDefaults.filterChipBorder(
                                    borderColor = Color(0xFF444444),
                                    selectedBorderColor = AccentRed
                                )
                            )
                        }
                    }
                }
            }

            // Score preview card
            item {
                ScorePreviewCard(summary = selectedSummary)
            }

            // Submit button
            item {
                val canSubmit = stageId.isNotBlank()
                Box(modifier = Modifier.navigationBarsPadding()) {
                    Button(
                        onClick = { if (canSubmit) onSubmit(stageId, selectedSummary) },
                        enabled = canSubmit,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AccentRed,
                            contentColor = Color.White,
                            disabledContainerColor = Color(0xFF444444),
                            disabledContentColor = Color(0xFF888888)
                        )
                    ) {
                        Icon(Icons.Default.Upload, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Submit Score", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun ScorePreviewCard(summary: DrillRepeatSummary) {
    val hitZones = summary.adjustedHitZones
        ?: ScoringUtility.calculateEffectiveCounts(summary.shots, null)
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Score Preview — Repeat ${summary.repeatIndex}", color = TextSecondary, fontSize = 12.sp)
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                listOf("A", "C", "D", "M", "N", "PE").forEach { zone ->
                    ScoreZoneItem(zone = zone, value = hitZones[zone] ?: 0)
                }
            }
            Spacer(Modifier.height(12.dp))
            Divider(color = Color.White.copy(alpha = 0.1f))
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                LabelValueItem(label = "Time", value = String.format("%.2fs", summary.totalTime))
                LabelValueItem(label = "First Shot", value = if (summary.firstShot > 0) String.format("%.2fs", summary.firstShot) else "-")
                LabelValueItem(label = "Fastest", value = if (summary.fastest > 0) String.format("%.2fs", summary.fastest) else "-")
            }
        }
    }
}

@Composable
private fun ScoreZoneItem(zone: String, value: Int) {
    val color = when (zone) {
        "A" -> Color(0xFF4CAF50)
        "C" -> Color(0xFFFFEB3B)
        "D" -> Color(0xFFFF9800)
        "M", "N", "PE" -> AccentRed
        else -> TextSecondary
    }
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(zone, color = TextSecondary, fontSize = 10.sp, fontWeight = FontWeight.Medium)
        Spacer(Modifier.height(2.dp))
        Text(value.toString(), color = color, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun LabelValueItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = TextSecondary, fontSize = 10.sp)
        Spacer(Modifier.height(2.dp))
        Text(value, color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Success
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun SuccessStep(hitFactor: Double, totalPoints: Int, onClose: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            Icon(
                Icons.Default.CheckCircle,
                contentDescription = "Success",
                tint = Color(0xFF4CAF50),
                modifier = Modifier.size(72.dp)
            )
            Text("Score Submitted!", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 22.sp)

            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(20.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("HIT FACTOR", color = TextSecondary, fontSize = 11.sp)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            String.format("%.4f", hitFactor),
                            color = Color(0xFF4CAF50),
                            fontWeight = FontWeight.Black,
                            fontSize = 28.sp
                        )
                    }
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .height(50.dp)
                            .background(Color.White.copy(alpha = 0.1f))
                    )
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("POINTS", color = TextSecondary, fontSize = 11.sp)
                        Spacer(Modifier.height(4.dp))
                        Text(
                            totalPoints.toString(),
                            color = TextPrimary,
                            fontWeight = FontWeight.Black,
                            fontSize = 28.sp
                        )
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
            Button(
                onClick = onClose,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2A2A2A))
            ) {
                Text("Done", fontWeight = FontWeight.SemiBold, fontSize = 16.sp, color = TextPrimary)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Error
// ─────────────────────────────────────────────────────────────────────────────

@Composable
private fun ErrorStep(message: String, onRetry: (() -> Unit)?, onDismiss: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            Text("⚠", fontSize = 48.sp)
            Text("Something went wrong", color = TextPrimary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Text(message, color = TextSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)

            if (onRetry != null) {
                Button(
                    onClick = onRetry,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(52.dp),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AccentRed)
                ) {
                    Text("Retry", fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                }
            }

            OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                shape = RoundedCornerShape(12.dp),
                border = ButtonDefaults.outlinedButtonBorder.copy(
                    brush = androidx.compose.ui.graphics.SolidColor(Color(0xFF555555))
                )
            ) {
                Text("Cancel", color = TextSecondary, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
