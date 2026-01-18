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

// Placeholder data class for Ranking
data class RankingRow(
    val rank: Int,
    val athleteName: String,
    val score: String,
    val shotCount: Int
)

@Composable
fun LeaderboardView(onBack: () -> Unit) {
    val competitions = remember { mutableStateOf(emptyList<CompetitionItem>()) }
    val selectedCompetition = remember { mutableStateOf<CompetitionItem?>(null) }
    val rankingRows = remember { mutableStateOf(emptyList<RankingRow>()) }
    val isLoading = remember { mutableStateOf(false) }
    val errorMessage = remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        TopAppBar(
            title = { Text("Leaderboard") },
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
        if (competitions.value.isNotEmpty()) {
            CompetitionDropdown(
                competitions = competitions.value,
                selectedCompetition = selectedCompetition.value,
                onSelectionChanged = {
                    selectedCompetition.value = it
                    isLoading.value = true
                    // Fetch ranking logic would go here
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
                    text = "No competitions available",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        }

        // Content Area
        when {
            isLoading.value -> {
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
                            text = "Loading ranking...",
                            color = Color.Gray,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
            errorMessage.value != null -> {
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
                            text = "Error loading ranking",
                            color = Color.White,
                            style = MaterialTheme.typography.bodyLarge,
                            textAlign = TextAlign.Center
                        )
                        Text(
                            text = errorMessage.value ?: "",
                            color = Color.Gray,
                            style = MaterialTheme.typography.labelSmall,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
            rankingRows.value.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No ranking data available",
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
                    items(rankingRows.value) { ranking ->
                        RankingListItem(ranking)
                    }
                }
            }
        }
    }
}

@Composable
private fun CompetitionDropdown(
    competitions: List<CompetitionItem>,
    selectedCompetition: CompetitionItem?,
    onSelectionChanged: (CompetitionItem) -> Unit,
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
                    text = selectedCompetition?.name ?: "Choose competition",
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
                .background(Color.Gray.copy(alpha = 0.9f))
        ) {
            competitions.forEach { competition ->
                DropdownMenuItem(
                    text = { Text(competition.name) },
                    onClick = {
                        onSelectionChanged(competition)
                        expanded.value = false
                    },
                    modifier = Modifier.background(Color.Gray.copy(alpha = 0.9f))
                )
            }
        }
    }
}

@Composable
private fun RankingListItem(ranking: RankingRow) {
    Card(
        modifier = Modifier.fillMaxWidth(),
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
                    color = if (ranking.rank <= 3) Color.Black else Color.White,
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
                Text(
                    text = "${ranking.shotCount} shots",
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            // Score
            Text(
                text = ranking.score,
                color = Color.Red,
                style = MaterialTheme.typography.headlineSmall
            )
        }
    }
}
