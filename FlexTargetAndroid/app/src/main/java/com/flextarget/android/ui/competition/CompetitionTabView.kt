package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Leaderboard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController

@Composable
fun CompetitionTabView(navController: NavHostController) {
    val selectedScreen = remember { mutableStateOf<CompetitionScreen?>(null) }

    when (selectedScreen.value) {
        CompetitionScreen.COMPETITIONS -> {
            CompetitionListView(
                onBack = { selectedScreen.value = null }
            )
        }
        CompetitionScreen.ATHLETES -> {
            AthletesManagementView(
                onBack = { selectedScreen.value = null }
            )
        }
        CompetitionScreen.LEADERBOARD -> {
            LeaderboardView(
                onBack = { selectedScreen.value = null }
            )
        }
        null -> {
            CompetitionMenuView(
                onCompetitionsClick = { selectedScreen.value = CompetitionScreen.COMPETITIONS },
                onAthletesClick = { selectedScreen.value = CompetitionScreen.ATHLETES },
                onLeaderboardClick = { selectedScreen.value = CompetitionScreen.LEADERBOARD }
            )
        }
    }
}

@Composable
private fun CompetitionMenuView(
    onCompetitionsClick: () -> Unit,
    onAthletesClick: () -> Unit,
    onLeaderboardClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Competitions Menu Item
            CompetitionMenuItem(
                icon = Icons.Default.EmojiEvents,
                title = "Competitions",
                description = "View and manage competitions",
                onClick = onCompetitionsClick
            )

            // Athletes/Shooters Menu Item
            CompetitionMenuItem(
                icon = Icons.Default.Groups,
                title = "Shooters",
                description = "Manage shooters and athletes",
                onClick = onAthletesClick
            )

            // Leaderboard Menu Item
            CompetitionMenuItem(
                icon = Icons.Default.Leaderboard,
                title = "Leaderboard",
                description = "View competition leaderboard",
                onClick = onLeaderboardClick
            )
        }
    }
}

@Composable
private fun CompetitionMenuItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    description: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(
                color = Color.Gray.copy(alpha = 0.1f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            tint = Color.Red,
            modifier = Modifier.size(32.dp)
        )

        Column(
            modifier = Modifier
                .weight(1f),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = title,
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = description,
                color = Color.Gray,
                style = MaterialTheme.typography.bodySmall
            )
        }

        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = "Navigate",
            tint = Color.Gray,
            modifier = Modifier.size(24.dp)
        )
    }
}

enum class CompetitionScreen {
    COMPETITIONS,
    ATHLETES,
    LEADERBOARD
}
