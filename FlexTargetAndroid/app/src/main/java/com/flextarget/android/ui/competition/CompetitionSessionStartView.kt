package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flextarget.android.R
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.local.entity.DrillTargetsConfigEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.di.AppContainer
import com.flextarget.android.ui.drills.DrillSummaryView
import com.flextarget.android.ui.drills.TimerSessionView
import com.flextarget.android.ui.theme.AppTypography
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.theme.md_theme_dark_primary
import com.flextarget.android.ui.viewmodel.CompetitionSessionSetupViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel
import kotlinx.coroutines.launch
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompetitionSessionStartView(
    onBack: () -> Unit,
    drillViewModel: DrillViewModel,
    bleManager: com.flextarget.android.data.ble.BLEManager
) {
    val context = LocalContext.current
    val drillUiState by drillViewModel.drillUiState.collectAsState()
    val setupViewModel: CompetitionSessionSetupViewModel = viewModel(
        factory = CompetitionSessionSetupViewModelFactory()
    )
    val uiState by setupViewModel.uiState.collectAsState()
    val coroutineScope = rememberCoroutineScope()

    var selectedDrillId by remember { mutableStateOf<UUID?>(null) }
    var showTimerSession by remember { mutableStateOf(false) }
    var timerSessionTargets by remember { mutableStateOf<List<DrillTargetsConfigEntity>>(emptyList()) }
    var showCompetitionSummary by remember { mutableStateOf(false) }
    var showDrillSummary by remember { mutableStateOf(false) }
    var drillSummaries by remember { mutableStateOf<List<DrillRepeatSummary>>(emptyList()) }

    val selectedDrill = drillUiState.drills.firstOrNull { it.id == selectedDrillId }
    val selectedShooter = uiState.selectedShooter
    val androidBleManager = bleManager.androidManager

    val canStart = selectedDrill != null && selectedShooter != null && bleManager.isConnected && !uiState.isLoading

    LaunchedEffect(Unit) {
        setupViewModel.loadMatchesIfNeeded()
    }

    if (showTimerSession && selectedDrill != null && androidBleManager != null) {
        TimerSessionView(
            drillSetup = selectedDrill,
            targets = timerSessionTargets,
            bleManager = androidBleManager,
            drillResultRepository = DrillResultRepository.getInstance(context),
            competitionId = null,
            athleteId = null,
            onDrillComplete = { summaries ->
                drillSummaries = summaries
                showTimerSession = false
                showCompetitionSummary = true
            },
            onDrillFailed = {
                showTimerSession = false
            },
            onBack = {
                showTimerSession = false
            }
        )
        return
    }

    if (showCompetitionSummary && selectedDrill != null) {
        val selectedStageName = uiState.stages.firstOrNull { it.id == uiState.selectedStageId }?.name
        CompetitionTargetGridSummaryView(
            drillSetup = selectedDrill,
            targets = timerSessionTargets,
            summaries = drillSummaries,
            shooterName = selectedShooter?.name,
            stageName = selectedStageName,
            onBack = { showCompetitionSummary = false },
            onReview = { updatedSummaries ->
                drillSummaries = updatedSummaries
                showCompetitionSummary = false
                showDrillSummary = true
            }
        )
        return
    }

    if (showDrillSummary && selectedDrill != null) {
        DrillSummaryView(
            drillSetup = selectedDrill,
            summaries = drillSummaries,
            onBack = { showDrillSummary = false },
            onViewResult = {},
            onReplay = {},
            isCompetitionDrill = true,
            athleteName = selectedShooter?.name ?: "",
            onCompetitionSubmit = {}
        )
        return
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.competition_session_start), color = md_theme_dark_onPrimary) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.Red)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Black)
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.08f))
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    SessionSelectorRow(
                        title = stringResource(R.string.competition_session_drill),
                        value = selectedDrill?.name ?: stringResource(R.string.competition_session_select_drill),
                        options = drillUiState.drills.mapNotNull { drill ->
                            val label = drill.name ?: return@mapNotNull null
                            drill.id.toString() to label
                        },
                        onSelect = { selected -> selectedDrillId = UUID.fromString(selected) }
                    )

                    SessionSelectorRow(
                        title = stringResource(R.string.competition_session_match),
                        value = uiState.matches.firstOrNull { it.id == uiState.selectedMatchId }?.name
                            ?: stringResource(R.string.competition_session_select_match),
                        options = uiState.matches.map { it.id.toString() to it.name },
                        onSelect = { setupViewModel.selectMatch(it.toInt()) }
                    )

                    SessionSelectorRow(
                        title = stringResource(R.string.competition_session_stage),
                        value = uiState.stages.firstOrNull { it.id == uiState.selectedStageId }?.name
                            ?: stringResource(R.string.competition_session_select_stage),
                        options = uiState.stages.map { it.id.toString() to it.name },
                        onSelect = { setupViewModel.selectStage(it.toInt()) },
                        disabled = uiState.selectedMatchId == null
                    )

                    SessionSelectorRow(
                        title = stringResource(R.string.competition_session_squad),
                        value = uiState.squads.firstOrNull { it.id == uiState.selectedSquadId }?.name
                            ?: stringResource(R.string.competition_session_select_squad),
                        options = uiState.squads.map { it.id.toString() to it.name },
                        onSelect = { setupViewModel.selectSquad(it.toInt()) },
                        disabled = uiState.selectedMatchId == null
                    )

                    SessionSelectorRow(
                        title = stringResource(R.string.competition_session_shooter),
                        value = selectedShooter?.let { shooterDisplayLabel(it, includeBib = false) }
                            ?: stringResource(R.string.competition_session_select_shooter),
                        options = uiState.availableShooters.map {
                            it.id.toString() to shooterDisplayLabel(it, includeBib = true)
                        },
                        onSelect = { setupViewModel.selectShooter(it.toInt()) },
                        disabled = uiState.selectedSquadId == null
                    )
                }
            }

            if (uiState.isLoading) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator(color = md_theme_dark_onPrimary)
                }
            }

            uiState.errorMessage?.let { message ->
                Text(
                    text = message,
                    color = Color(0xFFFFB74D),
                    style = AppTypography.bodySmall
                )
            }

            Button(
                onClick = {
                    val drillId = selectedDrillId ?: return@Button
                    val drill = drillUiState.drills.firstOrNull { it.id == drillId } ?: return@Button
                    if (androidBleManager == null) {
                        return@Button
                    }

                    val scopeRepo = DrillSetupRepository.getInstance(context)
                    coroutineScope.launch {
                        timerSessionTargets = scopeRepo.getDrillSetupWithTargets(drill.id)?.targets ?: emptyList()
                        showTimerSession = true
                    }
                },
                enabled = canStart,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = md_theme_dark_onPrimary,
                    disabledContainerColor = Color.Gray
                ),
                shape = RoundedCornerShape(24.dp)
            ) {
                Text(
                    text = if (selectedShooter == null) {
                        stringResource(R.string.select_shooter_to_start)
                    } else {
                        stringResource(R.string.start_competition_drill)
                    },
                    color = md_theme_dark_primary,
                    style = AppTypography.bodyLarge,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = stringResource(R.string.competition_session_start_hint),
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

@Composable
private fun SessionSelectorRow(
    title: String,
    value: String,
    options: List<Pair<String, String>>,
    onSelect: (String) -> Unit,
    disabled: Boolean = false
) {
    var expanded by remember { mutableStateOf(false) }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = title,
            color = Color.Gray,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.width(84.dp)
        )

        Box(modifier = Modifier.weight(1f)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(8.dp))
                    .clickable(enabled = !disabled && options.isNotEmpty()) { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = value,
                    color = if (disabled) Color.Gray else Color.White,
                    style = AppTypography.bodySmall,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = Color.Gray
                )
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                modifier = Modifier.fillMaxWidth(0.92f)
            ) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option.second) },
                        onClick = {
                            onSelect(option.first)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

private fun shooterDisplayLabel(
    shooter: com.flextarget.android.data.remote.api.IpscShooter,
    includeBib: Boolean
): String {
    val parts = mutableListOf<String>()
    if (includeBib) {
        parts.add(shooter.bibNumber)
    }
    parts.add(shooter.name)

    val metadata = mutableListOf<String>()
    if (shooter.divisionName.isNotEmpty()) {
        metadata.add(shooter.divisionName)
    }
    if (!shooter.categoryName.isNullOrEmpty()) {
        metadata.add(shooter.categoryName)
    }

    if (metadata.isNotEmpty()) {
        parts.add(metadata.joinToString(" / "))
    }

    return parts.joinToString(" · ")
}

private class CompetitionSessionSetupViewModelFactory : androidx.lifecycle.ViewModelProvider.Factory {
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(CompetitionSessionSetupViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return CompetitionSessionSetupViewModel(
                repository = AppContainer.ipscRepository,
                preferences = AppContainer.preferences
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}
