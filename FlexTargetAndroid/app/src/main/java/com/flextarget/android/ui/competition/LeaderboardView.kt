package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.flextarget.android.data.local.entity.CompetitionEntity
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import com.flextarget.android.data.repository.CompetitionRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ShotData
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.google.gson.Gson
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import com.flextarget.android.ui.drills.DrillSummaryView
import androidx.compose.foundation.clickable
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import kotlin.math.abs

// Placeholder data class for Ranking
data class RankingRow(
    val rank: Int,
    val athleteName: String,
    val score: String,
    val shotCount: Int
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardView(
    onBack: () -> Unit,
    viewModel: CompetitionViewModel
) {
    val uiState by viewModel.competitionUiState.collectAsState()
    val isLoading = uiState.isLoading
    val errorMessage = uiState.error
    val selectedLeaderboardCompetition = remember { mutableStateOf<CompetitionEntity?>(null) }
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val showDrillSummary = remember { mutableStateOf(false) }
    val selectedDrillSummary = remember { mutableStateOf<DrillRepeatSummary?>(null) }
    val selectedDrillSetup = remember { mutableStateOf<DrillSetupEntity?>(null) }
    val selectedAthleteName = remember { mutableStateOf("") }

    if (showDrillSummary.value && selectedDrillSummary.value != null && selectedDrillSetup.value != null) {
        DrillSummaryView(
            drillSetup = selectedDrillSetup.value!!,
            summaries = listOf(selectedDrillSummary.value!!),
            onBack = { showDrillSummary.value = false },
            onViewResult = { /* No-op */ },
            onReplay = { /* No-op */ },
            athleteName = selectedAthleteName.value
        )
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
        // Top Bar
        TopAppBar(
            title = { Text(stringResource(R.string.competitions_leaderboard)) },
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

        // Competition Selector
        if (uiState.competitions.isNotEmpty()) {
            CompetitionDropdown(
                competitions = uiState.competitions,
                selectedCompetition = selectedLeaderboardCompetition.value,
                onSelectionChanged = {
                    selectedLeaderboardCompetition.value = it
                    viewModel.loadRankings(it.id)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(12.dp)
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = stringResource(R.string.no_competitions_available),
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        }

        // Content Area
        when {
            selectedLeaderboardCompetition.value == null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.select_competition_to_view_rankings),
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
            isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        CircularProgressIndicator(
                            color = Color.Red,
                            modifier = Modifier.size(48.dp)
                        )
                        Text(
                            text = stringResource(R.string.loading_ranking),
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
            errorMessage != null -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.CloudOff,
                            contentDescription = null,
                            tint = Color.Red,
                            modifier = Modifier.size(48.dp)
                        )
                        Text(
                            text = stringResource(R.string.error_loading_ranking),
                            color = Color.White,
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = errorMessage ?: "",
                            color = Color.Gray,
                            style = MaterialTheme.typography.labelSmall,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
            uiState.rankings.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.no_ranking_data_available),
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(uiState.rankings) { ranking ->
                        RankingListItem(
                            RankingRow(
                                rank = ranking.rank,
                                athleteName = ranking.playerNickname ?: "Unknown",
                                score = ranking.score.toString(),
                                shotCount = 0 // Info not directly available in ranking data for now
                            ),
                            onClick = {
                                val competition = selectedLeaderboardCompetition.value
                                if (competition != null && ranking.playerNickname != null) {
                                    coroutineScope.launch {
                                        try {
                                            val gamePlay = viewModel.getGamePlayForAthlete(competition.id, ranking.playerNickname!!)
                                            if (gamePlay != null && competition.drillSetupId != null) {
                                                val gson = Gson()
                                                val summary: DrillRepeatSummary = gson.fromJson(gamePlay.detail, DrillRepeatSummary::class.java)
                                                
                                                val drillSetup = DrillSetupRepository.getInstance(context)
                                                    .getDrillSetupById(competition.drillSetupId!!)
                                                
                                                if (drillSetup != null) {
                                                    selectedDrillSummary.value = summary
                                                    selectedDrillSetup.value = drillSetup
                                                    selectedAthleteName.value = ranking.playerNickname ?: ""
                                                    showDrillSummary.value = true
                                                }
                                            }
                                        } catch (e: Exception) {
                                            // Handle error, maybe show toast
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    }
}



@Composable
private fun CompetitionDropdown(
    competitions: List<CompetitionEntity>,
    selectedCompetition: CompetitionEntity?,
    onSelectionChanged: (CompetitionEntity) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded = remember { mutableStateOf(false) }

    Box(modifier = modifier) {
        Button(
            onClick = { expanded.value = true },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Gray.copy(alpha = 0.2f)
            ),
            shape = RoundedCornerShape(8.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = selectedCompetition?.name ?: stringResource(R.string.choose_competition),
                    color = Color.Red,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f)
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = Color.Red
                )
            }
        }

        DropdownMenu(
            expanded = expanded.value,
            onDismissRequest = { expanded.value = false },
            modifier = Modifier
                .fillMaxWidth()
                .background(Color.DarkGray)
        ) {
            competitions.forEach { competition ->
                DropdownMenuItem(
                    text = { Text(competition.name, color = Color.White) },
                    onClick = {
                        onSelectionChanged(competition)
                        expanded.value = false
                    }
                )
            }
        }
    }
}

@Composable
private fun RankingListItem(ranking: RankingRow, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() },
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Rank Badge
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(
                        color = when (ranking.rank) {
                            1 -> Color(0xFFFFD700)
                            2 -> Color(0xFFC0C0C0)
                            3 -> Color(0xFFCD7F32)
                            else -> Color.Gray.copy(alpha = 0.3f)
                        },
                        shape = RoundedCornerShape(4.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = ranking.rank.toString(),
                    color = md_theme_dark_onPrimary,
                    style = MaterialTheme.typography.titleSmall
                )
            }

            // Athlete Info
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = ranking.athleteName,
                    color = Color.White,
                    style = MaterialTheme.typography.bodyMedium
                )
            }

            // Score
            Text(
                text = ranking.score,
                color = md_theme_dark_onPrimary,
                style = MaterialTheme.typography.headlineSmall
            )
        }
    }
}
