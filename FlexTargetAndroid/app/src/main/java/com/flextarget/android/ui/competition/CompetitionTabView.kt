package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Leaderboard
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.compose.runtime.getValue
import com.flextarget.android.R
import com.flextarget.android.ui.admin.LoginScreen
import com.flextarget.android.ui.admin.RegistrationScreen
import com.flextarget.android.ui.admin.ForgotPasswordScreen
import com.flextarget.android.ui.theme.AppTypography
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.viewmodel.AuthViewModel
import com.flextarget.android.ui.viewmodel.CompetitionViewModel
import com.flextarget.android.ui.viewmodel.DrillViewModel

@Composable
fun CompetitionTabView(
    navController: NavHostController,
    authViewModel: AuthViewModel,
    competitionViewModel: CompetitionViewModel,
    drillViewModel: DrillViewModel,
    bleManager: com.flextarget.android.data.ble.BLEManager
) {
    val authState by authViewModel.authUiState.collectAsState()
    val uiState by competitionViewModel.competitionUiState.collectAsState()
    val drillUiState by drillViewModel.drillUiState.collectAsState()
    val selectedScreen = remember { mutableStateOf<CompetitionScreen?>(null) }
    val showRegistration = remember { mutableStateOf(false) }
    val showForgotPassword = remember { mutableStateOf(false) }

    if (!authState.isAuthenticated) {
        when {
            showRegistration.value -> {
                com.flextarget.android.ui.admin.RegistrationScreen(
                    authViewModel = authViewModel,
                    onRegistrationSuccess = {
                        showRegistration.value = false
                    },
                    onBackClick = {
                        showRegistration.value = false
                    }
                )
            }
            showForgotPassword.value -> {
                com.flextarget.android.ui.admin.ForgotPasswordScreen(
                    onResetSuccess = {
                        showForgotPassword.value = false
                    },
                    onBackClick = {
                        showForgotPassword.value = false
                    }
                )
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black)
                ) {
                    LoginScreen(
                        authViewModel = authViewModel,
                        onLoginSuccess = { /* State will update via Flow */ },
                        onRegisterClick = {
                            showRegistration.value = true
                        },
                        onForgotPasswordClick = {
                            showForgotPassword.value = true
                        }
                    )
                }
            }
        }
    } else {
        // If a competition is selected, show detail view
        uiState.selectedCompetition?.let { competition ->
            CompetitionDetailView(
                competition = competition,
                onBack = { competitionViewModel.selectCompetition(null) },
                viewModel = competitionViewModel,
                drillViewModel = drillViewModel,
                bleManager = bleManager
            )
        } ?: run {
            // Otherwise show the appropriate screen based on menu selection
            when (selectedScreen.value) {
                CompetitionScreen.COMPETITIONS -> {
                    CompetitionListView(
                        onBack = { selectedScreen.value = null },
                        viewModel = competitionViewModel,
                        drillViewModel = drillViewModel,
                        bleManager = bleManager
                    )
                }
                CompetitionScreen.ATHLETES -> {
                    AthletesManagementView(
                        onBack = { selectedScreen.value = null },
                        viewModel = competitionViewModel
                    )
                }
                CompetitionScreen.LEADERBOARD -> {
                    LeaderboardView(
                        onBack = { selectedScreen.value = null },
                        viewModel = competitionViewModel
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
    }
}

@Composable
private fun CompetitionMenuView(
    onCompetitionsClick: () -> Unit,
    onAthletesClick: () -> Unit,
    onLeaderboardClick: () -> Unit
) {
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(stringResource(R.string.tab_competition), color = md_theme_dark_onPrimary) },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Black
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
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
                    title = stringResource(R.string.competitions_title),
                    description = stringResource(R.string.competitions_menu_desc),
                    onClick = onCompetitionsClick
                )

                // Athletes/Shooters Menu Item
                CompetitionMenuItem(
                    icon = Icons.Default.Groups,
                    title = stringResource(R.string.shooters),
                    description = stringResource(R.string.shooters_menu_desc),
                    onClick = onAthletesClick
                )

                // Leaderboard Menu Item
                CompetitionMenuItem(
                    icon = Icons.Default.Leaderboard,
                    title = stringResource(R.string.competitions_leaderboard),
                    description = stringResource(R.string.leaderboard_menu_desc),
                    onClick = onLeaderboardClick
                )
            }
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
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color.White.copy(alpha = 0.05f),
                shape = RoundedCornerShape(8.dp)
            ),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = md_theme_dark_onPrimary,
                modifier = Modifier.size(32.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = title.uppercase(),
                    color = md_theme_dark_onPrimary,
                    style = AppTypography.bodyLarge
                )
                Text(
                    text = description,
                    color = Color.Gray,
                    style = AppTypography.labelSmall
                )
            }

            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "Navigate",
                tint = md_theme_dark_onPrimary,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

enum class CompetitionScreen {
    COMPETITIONS,
    ATHLETES,
    LEADERBOARD
}
