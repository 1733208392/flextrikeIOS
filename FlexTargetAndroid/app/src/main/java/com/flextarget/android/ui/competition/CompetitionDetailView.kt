package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import androidx.compose.ui.window.Dialog
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel
import com.flextarget.android.ui.drills.TimerSessionView
import com.flextarget.android.ui.drills.DrillSummaryView
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.model.DrillRepeatSummary
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompetitionDetailView(
    competition: CompetitionEntity,
    onBack: () -> Unit,
    viewModel: CompetitionViewModel,
    drillViewModel: DrillViewModel,
    bleManager: com.flextarget.android.data.ble.BLEManager
) {
    val uiState by viewModel.competitionUiState.collectAsState()
    val drillUiState by drillViewModel.drillUiState.collectAsState()
    val dateFormat = SimpleDateFormat("MMM dd, yyyy", Locale.getDefault())
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var showAthletePicker by remember { mutableStateOf(false) }
    var showTimerSession by remember { mutableStateOf(false) }
    var timerSessionTargets by remember { mutableStateOf<List<DrillTargetsConfigEntity>>(emptyList()) }
    var showDrillSummary by remember { mutableStateOf(false) }
    var drillSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }

    val linkedDrill = drillUiState.drills.find { it.id == competition.drillSetupId }
    val androidBleManager = bleManager.androidManager

    if (showTimerSession && linkedDrill != null && androidBleManager != null) {
        TimerSessionView(
            drillSetup = linkedDrill,
            targets = timerSessionTargets,
            bleManager = androidBleManager,
            drillResultRepository = DrillResultRepository.getInstance(context),
            competitionId = competition.id,
            athleteId = uiState.selectedAthlete?.id,
            onDrillComplete = { summaries ->
                drillSummaries = summaries
                showTimerSession = false
                showDrillSummary = true
            },
            onDrillFailed = {
                showTimerSession = false
            },
            onBack = {
                showTimerSession = false
            }
        )
    } else if (showDrillSummary && linkedDrill != null) {
        DrillSummaryView(
            drillSetup = linkedDrill,
            summaries = drillSummaries,
            isCompetitionDrill = true,
            onCompetitionSubmit = {
                // Submit main result (first repeat)
                drillSummaries.firstOrNull()?.let { summary ->
                    val gson = com.google.gson.Gson()
                    val detail = gson.toJson(summary)
                    viewModel.submitGamePlay(
                        score = summary.score,
                        detail = detail,
                        onSuccess = {
                            showDrillSummary = false
                            onBack()
                        },
                        onFailure = { error ->
                            // TODO: Show error alert
                            println("Submission error: $error")
                        }
                    )
                }
            },
            onBack = { 
                showDrillSummary = false
                onBack()
            },
            onViewResult = { /* Navigate to result if needed */ },
            onReplay = { }
        )
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
        TopAppBar(
            title = { Text(stringResource(R.string.details)) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White,
                navigationIconContentColor = Color.Red
            )
        )

        // Header Info
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color.White.copy(alpha = 0.1f)
            )
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = competition.name,
                    color = Color.White,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )

                if (!competition.venue.isNullOrEmpty()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.LocationOn, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(18.dp))
                        Text(
                            text = competition.venue ?: "",
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.DateRange, contentDescription = null, tint = Color.Red, modifier = Modifier.size(18.dp))
                    Text(
                        text = dateFormat.format(competition.date),
                        color = Color.Red,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(start = 8.dp)
                    )
                }

                linkedDrill?.let {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Adjust, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Text(
                            text = it.name ?: "",
                            color = Color.White,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                } ?: run {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Error, contentDescription = null, tint = Color.Yellow, modifier = Modifier.size(18.dp))
                        Text(
                            text = stringResource(R.string.no_linked_drill_found),
                            color = Color.Yellow,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(start = 8.dp)
                        )
                    }
                }
            }
        }

        // Shooter selection card
        Text(
            text = stringResource(R.string.active_shooter),
            color = Color.White,
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
        )

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            shape = RoundedCornerShape(8.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color.White.copy(alpha = 0.05f)
            ),
            onClick = { showAthletePicker = true }
        ) {
            Row(
                modifier = Modifier
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Person, contentDescription = null, tint = Color.Red)
                    Text(
                        text = uiState.selectedAthlete?.name ?: stringResource(R.string.select_shooter),
                        color = if (uiState.selectedAthlete != null) Color.White else Color.Gray,
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(start = 12.dp)
                    )
                }
                Icon(Icons.Default.ChevronRight, contentDescription = null, tint = Color.Gray)
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Start Button
        Button(
            onClick = { 
                if (uiState.selectedAthlete == null) {
                    showAthletePicker = true
                } else if (linkedDrill != null && androidBleManager != null) {
                    coroutineScope.launch {
                        val repo = DrillSetupRepository.getInstance(context)
                        timerSessionTargets = repo.getDrillSetupWithTargets(linkedDrill.id)?.targets ?: emptyList()
                        showTimerSession = true
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .height(56.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Red,
                disabledContainerColor = Color.Gray
            ),
            shape = RoundedCornerShape(8.dp),
            enabled = linkedDrill != null && androidBleManager?.isConnected == true
        ) {
            Text(
                text = if (uiState.selectedAthlete == null) stringResource(R.string.select_shooter_to_start) else stringResource(R.string.start_competition_drill),
                fontWeight = FontWeight.Bold
            )
        }
    }
}

    if (showAthletePicker) {
        AthletePickerDialog(
            athletes = uiState.athletes,
            onDismiss = { showAthletePicker = false },
            onSelect = {
                viewModel.selectAthlete(it)
                showAthletePicker = false
            }
        )
    }
}

@Composable
fun AthletePickerDialog(
    athletes: List<com.flextarget.android.data.local.entity.AthleteEntity>,
    onDismiss: () -> Unit,
    onSelect: (com.flextarget.android.data.local.entity.AthleteEntity) -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.7f),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = stringResource(R.string.select_athlete),
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(bottom = 16.dp)
                )

                if (athletes.isEmpty()) {
                    Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Text(stringResource(R.string.no_athletes_found), color = Color.Gray, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                    }
                } else {
                    LazyColumn(modifier = Modifier.weight(1f)) {
                        items(athletes) { athlete ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onSelect(athlete) }
                                    .padding(vertical = 12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .background(Color.Red.copy(alpha = 0.2f), RoundedCornerShape(16.dp)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(athlete.name?.take(1)?.uppercase() ?: "?", color = Color.Red)
                                }
                                Text(
                                    text = athlete.name ?: "",
                                    color = Color.White,
                                    modifier = Modifier.padding(start = 12.dp)
                                )
                            }
                            Divider(
                                color = Color.Gray.copy(alpha = 0.2f),
                                thickness = 1.dp
                            )
                        }
                    }
                }

                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.End)
                ) {
                    Text(stringResource(R.string.cancel), color = Color.Red)
                }
            }
        }
    }
}
