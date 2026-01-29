package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.local.entity.totalScore
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel
import com.flextarget.android.ui.drills.TimerSessionView
import com.flextarget.android.ui.drills.DrillSummaryView
import com.flextarget.android.ui.drills.DrillReplayView
import com.flextarget.android.ui.drills.DrillResultView
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.DrillTargetsConfigData
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
    var competitionResults by remember { mutableStateOf<List<DrillResultWithShots>>(emptyList()) }
    var selectedResultDrill by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var selectedResultSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }
    var showResultSummary by remember { mutableStateOf(false) }
    var showResultReplay by remember { mutableStateOf(false) }
    var showResultDetails by remember { mutableStateOf(false) }
    var selectedReplaySummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var selectedDetailsSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var resultDrillTargets by remember { mutableStateOf<List<DrillTargetsConfigEntity>>(emptyList()) }
    var resultAthleteNameForDisplay by remember { mutableStateOf("") }

    val linkedDrill = drillUiState.drills.find { it.id == competition.drillSetupId }
    val androidBleManager = bleManager.androidManager

    // Load competition results
    LaunchedEffect(competition.id) {
        val resultRepo = DrillResultRepository.getInstance(context)
        resultRepo.getDrillResultsWithShotsByCompetitionId(competition.id).collect { results ->
            competitionResults = results
        }
    }

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
    } else if (showResultReplay && selectedResultDrill != null && selectedReplaySummary != null) {
        // Show drill replay from competition results
        DrillReplayView(
            drillSetup = selectedResultDrill!!,
            shots = selectedReplaySummary!!.shots,
            onBack = {
                showResultReplay = false
                selectedReplaySummary = null
            }
        )
    } else if (showResultDetails && selectedResultDrill != null && selectedDetailsSummary != null) {
        // Show drill result details from competition results
        val targetsData = resultDrillTargets.map { entity ->
            DrillTargetsConfigData(
                id = entity.id,
                seqNo = 0,
                targetName = entity.targetType ?: "ipsc",
                targetType = entity.targetType ?: "ipsc",
                timeout = 30.0,
                countedShots = 5
            )
        }
        
        DrillResultView(
            drillSetup = selectedResultDrill!!,
            targets = targetsData,
            repeatSummary = selectedDetailsSummary,
            shots = selectedDetailsSummary!!.shots,
            onBack = {
                showResultDetails = false
                selectedDetailsSummary = null
            }
        )
    } else if (showResultSummary && selectedResultDrill != null) {
        // Show drill summary from competition results
        DrillSummaryView(
            drillSetup = selectedResultDrill!!,
            summaries = selectedResultSummaries,
            isCompetitionDrill = true,
            athleteName = resultAthleteNameForDisplay,
            onBack = {
                showResultSummary = false
                selectedResultDrill = null
                selectedResultSummaries = emptyList()
            },
            onViewResult = { summary ->
                // Navigate to DrillResultView to see detailed results
                selectedDetailsSummary = summary
                showResultDetails = true
            },
            onReplay = { summary ->
                // Navigate to DrillReplayView
                selectedReplaySummary = summary
                showResultReplay = true
            },
            onCompetitionSubmit = {
                // Submit main result (first repeat)
                // Use the passed-in athlete name to ensure submission
                if (resultAthleteNameForDisplay.isNotEmpty()) {
                    selectedResultSummaries.firstOrNull()?.let { summary ->
                        val gson = com.google.gson.Gson()
                        val detail = gson.toJson(summary)
                        viewModel.submitGamePlay(
                            score = summary.score,
                            detail = detail,
                            athleteName = resultAthleteNameForDisplay,
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
                }
            }
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

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
            ) {
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
                                Icon(
                                    Icons.Default.LocationOn,
                                    contentDescription = null,
                                    tint = Color.Gray,
                                    modifier = Modifier.size(18.dp)
                                )
                                Text(
                                    text = competition.venue ?: "",
                                    color = Color.Gray,
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.padding(start = 8.dp)
                                )
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.DateRange,
                                contentDescription = null,
                                tint = Color.Red,
                                modifier = Modifier.size(18.dp)
                            )
                            Text(
                                text = dateFormat.format(competition.date),
                                color = Color.Red,
                                style = MaterialTheme.typography.bodyLarge,
                                modifier = Modifier.padding(start = 8.dp)
                            )
                        }

                        linkedDrill?.let {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Adjust,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(18.dp)
                                )
                                Text(
                                    text = it.name ?: "",
                                    color = Color.White,
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.padding(start = 8.dp)
                                )
                            }
                        } ?: run {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Error,
                                    contentDescription = null,
                                    tint = Color.Yellow,
                                    modifier = Modifier.size(18.dp)
                                )
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
                            Icon(
                                Icons.Default.Person,
                                contentDescription = null,
                                tint = Color.Red
                            )
                            Text(
                                text = uiState.selectedAthlete?.name
                                    ?: stringResource(R.string.select_shooter),
                                color = if (uiState.selectedAthlete != null) Color.White else Color.Gray,
                                style = MaterialTheme.typography.bodyLarge,
                                modifier = Modifier.padding(start = 12.dp)
                            )
                        }
                        Icon(
                            Icons.Default.ChevronRight,
                            contentDescription = null,
                            tint = Color.Gray
                        )
                    }
                }

                // Results List Section
                if (competitionResults.isNotEmpty()) {
                    Text(
                        text = stringResource(R.string.results),
                        color = Color.White,
                        style = MaterialTheme.typography.titleSmall,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                    )

                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 200.dp)
                            .padding(horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(competitionResults) { resultWithShots ->
                            Card(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        selectedResultDrill = linkedDrill
                                        
                                        // Get athlete name from the result
                                        resultAthleteNameForDisplay = uiState.athletes.find { it.id == resultWithShots.drillResult.athleteId }?.name
                                            ?: ""
                                        
                                        // Parse shots from the result
                                        val parsedShots = resultWithShots.shots.mapNotNull { shot ->
                                            try {
                                                val gson = com.google.gson.Gson()
                                                gson.fromJson(shot.data, com.flextarget.android.data.model.ShotData::class.java)
                                            } catch (e: Exception) {
                                                null
                                            }
                                        }
                                        
                                        // Calculate firstShot (time of first shot)
                                        val firstShot = if (parsedShots.isNotEmpty()) {
                                            parsedShots.first().content.actualTimeDiff
                                        } else {
                                            0.0
                                        }
                                        
                                        // Calculate fastest (minimum time between shots)
                                        val fastest = if (parsedShots.isNotEmpty()) {
                                            parsedShots.map { it.content.actualTimeDiff }.minOrNull() ?: 0.0
                                        } else {
                                            0.0
                                        }
                                        
                                        selectedResultSummaries = listOf(
                                            DrillRepeatSummary(
                                                repeatIndex = 0,
                                                totalTime = resultWithShots.drillResult.totalTime?.toDouble() ?: 0.0,
                                                numShots = resultWithShots.shots.size,
                                                firstShot = firstShot,
                                                fastest = fastest,
                                                score = resultWithShots.totalScore.toInt(),
                                                shots = parsedShots
                                            )
                                        )
                                        
                                        // Load drill targets
                                        if (linkedDrill != null) {
                                            coroutineScope.launch {
                                                val drillRepo = DrillSetupRepository.getInstance(context)
                                                val drillWithTargets = drillRepo.getDrillSetupWithTargets(linkedDrill.id)
                                                resultDrillTargets = drillWithTargets?.targets ?: emptyList()
                                            }
                                        }
                                        
                                        showResultSummary = true
                                    },
                                shape = RoundedCornerShape(8.dp),
                                colors = CardDefaults.cardColors(
                                    containerColor = Color.White.copy(alpha = 0.05f)
                                )
                            ) {
                                Row(
                                    modifier = Modifier
                                        .padding(12.dp)
                                        .fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        // Get athlete name from uiState.athletes
                                        val athleteName =
                                            uiState.athletes.find { it.id == resultWithShots.drillResult.athleteId }?.name
                                                ?: stringResource(R.string.unknown_athlete)
                                        Text(
                                            text = athleteName,
                                            color = Color.White,
                                            style = MaterialTheme.typography.bodyLarge,
                                            fontWeight = FontWeight.SemiBold
                                        )
                                        Text(
                                            text = resultWithShots.drillResult.date?.let {
                                                dateFormat.format(
                                                    it
                                                )
                                            } ?: "Unknown Date",
                                            color = Color.Gray,
                                            style = MaterialTheme.typography.bodySmall,
                                            modifier = Modifier.padding(top = 4.dp)
                                        )
                                    }
                                    Column(horizontalAlignment = Alignment.End) {
                                        Text(
                                            text = resultWithShots.totalScore.toInt()
                                                .toString(),
                                            color = Color.Red,
                                            style = MaterialTheme.typography.bodyLarge,
                                            fontWeight = FontWeight.Bold
                                        )
                                        if (resultWithShots.drillResult.submittedAt != null) {
                                            Icon(
                                                Icons.Default.Check,
                                                contentDescription = null,
                                                tint = Color.Green,
                                                modifier = Modifier
                                                    .size(16.dp)
                                                    .padding(top = 4.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = stringResource(R.string.no_results_yet),
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }

                // Fixed Start Button at bottom
                Button(
                    onClick = {
                        if (uiState.selectedAthlete == null) {
                            showAthletePicker = true
                        } else if (linkedDrill != null && androidBleManager != null) {
                            coroutineScope.launch {
                                val repo = DrillSetupRepository.getInstance(context)
                                timerSessionTargets =
                                    repo.getDrillSetupWithTargets(linkedDrill.id)?.targets
                                        ?: emptyList()
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
                        text = if (uiState.selectedAthlete == null) stringResource(R.string.select_shooter_to_start) else stringResource(
                            R.string.start_competition_drill
                        ),
                        fontWeight = FontWeight.Bold
                    )
                }

            }  // Closes inner Column
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
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            stringResource(R.string.no_athletes_found),
                            color = Color.Gray,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
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
                                        .background(
                                            Color.Red.copy(alpha = 0.2f),
                                            RoundedCornerShape(16.dp)
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        athlete.name?.take(1)?.uppercase() ?: "?",
                                        color = Color.Red
                                    )
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
