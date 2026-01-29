package com.flextarget.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.LayoutDirection
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.data.repository.DrillSetupRepository
import com.flextarget.android.di.AppContainer
import com.flextarget.android.ui.competition.CompetitionTabView
import com.flextarget.android.ui.drills.DrillListView
import com.flextarget.android.ui.drills.DrillSummaryView
import com.flextarget.android.ui.drills.DrillReplayView
import com.flextarget.android.ui.drills.DrillResultView
import com.flextarget.android.ui.drills.HistoryTabView
import com.flextarget.android.ui.admin.AdminTabView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.flextarget.android.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TabNavigationView(
    bleManager: BLEManager = BLEManager.shared
) {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route
            CompactBottomBar(
                currentRoute = currentRoute,
                onNavigate = { route ->
                    navController.navigate(route) {
                        popUpTo(navController.graph.startDestinationId)
                        launchSingleTop = true
                    }
                }
            )
        },
        containerColor = Color.Black,
        contentWindowInsets = WindowInsets(0)
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "drills",
            modifier = Modifier
                .background(Color.Black)
                .padding(
                    top = paddingValues.calculateTopPadding(),
                    start = paddingValues.calculateLeftPadding(LayoutDirection.Ltr),
                    end = paddingValues.calculateRightPadding(LayoutDirection.Ltr)
                )
        ) {
            composable("drills") {
                DrillsTabContent(
                    bleManager = bleManager,
                    navController = navController
                )
            }

            composable("history") {
                HistoryTabContent(navController = navController)
            }

            composable("competition") {
                CompetitionTabView(
                    navController = navController,
                    authViewModel = AppContainer.authViewModel,
                    competitionViewModel = AppContainer.competitionViewModel,
                    drillViewModel = AppContainer.drillViewModel,
                    bleManager = bleManager
                )
            }

            composable("admin") {
                AdminTabView(
                    bleManager = bleManager,
                    authViewModel = AppContainer.authViewModel,
                    otaViewModel = AppContainer.otaViewModel,
                    bleViewModel = AppContainer.bleViewModel
                )
            }

            // Drill-related screens
            composable("drill_list") {
                DrillListView(
                    bleManager = bleManager,
                    onBack = { navController.popBackStack() }
                )
            }

            composable("drill_summary/{drillSetupId}") { backStackEntry ->
                val drillSetupId = backStackEntry.arguments?.getString("drillSetupId")?.toLongOrNull()
                if (drillSetupId != null) {
                    DrillSummaryScreen(
                        drillSetupId = drillSetupId,
                        navController = navController
                    )
                }
            }

            composable("drill_result/{drillSetupId}/{repeatIndex}") { backStackEntry ->
                val drillSetupId = backStackEntry.arguments?.getString("drillSetupId")?.toLongOrNull()
                val repeatIndex = backStackEntry.arguments?.getString("repeatIndex")?.toIntOrNull()
                if (drillSetupId != null && repeatIndex != null) {
                    DrillResultScreen(
                        drillSetupId = drillSetupId,
                        repeatIndex = repeatIndex,
                        navController = navController
                    )
                }
            }
        }
    }
}

@Composable
private fun CompactBottomBar(
    currentRoute: String?,
    onNavigate: (String) -> Unit
) {
    // Compact, custom bottom bar with explicit height and minimal vertical padding
    Surface(color = Color.Black) {
        Column(
            modifier = Modifier
                .windowInsetsPadding(WindowInsets.navigationBars)
                .fillMaxWidth()
                .height(54.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
            ) {
                BottomBarItem(
                    route = "drills",
                    label = stringResource(R.string.tab_drills),
                    icon = Icons.Default.SportsBaseball,
                    selected = currentRoute == "drills",
                    onClick = onNavigate
                )
                BottomBarItem(
                    route = "history",
                    label = stringResource(R.string.tab_history),
                    icon = Icons.Default.History,
                    selected = currentRoute == "history",
                    onClick = onNavigate
                )
                BottomBarItem(
                    route = "competition",
                    label = stringResource(R.string.tab_competition),
                    icon = Icons.Default.EmojiEvents,
                    selected = currentRoute == "competition",
                    onClick = onNavigate
                )
                BottomBarItem(
                    route = "admin",
                    label = stringResource(R.string.tab_admin),
                    icon = Icons.Default.AdminPanelSettings,
                    selected = currentRoute == "admin",
                    onClick = onNavigate
                )
            }
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.BottomBarItem(
    route: String,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: Boolean,
    onClick: (String) -> Unit
) {
    val iconColor = if (selected) Color.Red else Color.Gray
    val textColor = if (selected) Color.Red else Color.Gray
    Column(
        modifier = Modifier
            .weight(1f)
            .padding(vertical = 4.dp)
            .clickable { onClick(route) },
        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp, androidx.compose.ui.Alignment.CenterVertically)
    ) {
        Icon(imageVector = icon, contentDescription = label, tint = iconColor, modifier = Modifier.size(22.dp))
        Text(text = label, color = textColor, style = MaterialTheme.typography.labelSmall, maxLines = 1)
    }
}

@Composable
private fun DrillsTabContent(
    bleManager: BLEManager,
    navController: NavHostController
) {
    var showConnectView by remember { mutableStateOf(false) }
    var showQRScanner by remember { mutableStateOf(false) }

    DrillListView(
        bleManager = bleManager,
        onBack = null,
        onShowConnectView = { showConnectView = true },
        onShowQRScanner = { showQRScanner = true }
    )

    // Handle other views
    if (showConnectView) {
        com.flextarget.android.ui.ble.ConnectSmartTargetView(
            bleManager = bleManager,
            onDismiss = { showConnectView = false },
            isAlreadyConnected = bleManager.isConnected
        )
    }

    if (showQRScanner) {
        com.flextarget.android.ui.qr.QRScannerView(
            onQRScanned = { scannedText ->
                // Set auto-connect target and show connect view
                bleManager.setAutoConnectTarget(scannedText)
                showQRScanner = false
                showConnectView = true
            },
            onDismiss = { showQRScanner = false }
        )
    }
}

@Composable
private fun HistoryTabContent(navController: NavHostController) {
    val context = LocalContext.current
    val drillSetupRepository = remember { DrillSetupRepository.getInstance(context) }
    
    var selectedDrillSetup by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var selectedSummaries by remember { mutableStateOf<List<DrillRepeatSummary>?>(null) }
    var selectedResultSummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var selectedReplaySummary by remember { mutableStateOf<DrillRepeatSummary?>(null) }
    var drillTargets by remember { mutableStateOf(emptyList<com.flextarget.android.data.model.DrillTargetsConfigData>()) }
    var showDrillResult by remember { mutableStateOf(false) }
    var showDrillReplay by remember { mutableStateOf(false) }

    // Fetch targets when drill setup changes
    LaunchedEffect(selectedDrillSetup) {
        selectedDrillSetup?.let { setup ->
            val setupWithTargets = drillSetupRepository.getDrillSetupWithTargets(setup.id)
            drillTargets = setupWithTargets?.targets?.map { targetEntity ->
                com.flextarget.android.data.model.DrillTargetsConfigData(
                    id = targetEntity.id,
                    seqNo = targetEntity.seqNo,
                    targetName = targetEntity.targetName ?: "",
                    targetType = targetEntity.targetType ?: "ipsc",
                    timeout = targetEntity.timeout,
                    countedShots = targetEntity.countedShots
                )
            } ?: emptyList()
        }
    }

    if (showDrillReplay && selectedDrillSetup != null && selectedReplaySummary != null) {
        DrillReplayView(
            drillSetup = selectedDrillSetup!!,
            shots = selectedReplaySummary!!.shots,
            onBack = {
                showDrillReplay = false
                selectedReplaySummary = null
            }
        )
    } else if (showDrillResult && selectedDrillSetup != null && selectedResultSummary != null) {
        DrillResultView(
            drillSetup = selectedDrillSetup!!,
            targets = drillTargets,
            repeatSummary = selectedResultSummary,
            onBack = {
                showDrillResult = false
                selectedResultSummary = null
            }
        )
    } else if (selectedDrillSetup != null && selectedSummaries != null) {
        DrillSummaryView(
            drillSetup = selectedDrillSetup!!,
            summaries = selectedSummaries!!,
            onBack = {
                selectedDrillSetup = null
                selectedSummaries = null
            },
            onViewResult = { summary ->
                selectedResultSummary = summary
                showDrillResult = true
            },
            onReplay = { summary ->
                selectedReplaySummary = summary
                showDrillReplay = true
            }
        )
    } else {
        HistoryTabView(
            onNavigateToSummary = { setup, summaries ->
                selectedDrillSetup = setup
                selectedSummaries = summaries
            }
        )
    }
}

@Composable
private fun DrillSummaryScreen(
    drillSetupId: Long,
    navController: NavHostController
) {
    // TODO: Implement drill summary screen
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = androidx.compose.ui.Alignment.Center
    ) {
        Text(
            "Drill Summary\nSetup ID: $drillSetupId",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

@Composable
private fun DrillResultScreen(
    drillSetupId: Long,
    repeatIndex: Int,
    navController: NavHostController
) {
    // TODO: Implement drill result screen
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = androidx.compose.ui.Alignment.Center
    ) {
        Text(
            "Drill Result\nSetup ID: $drillSetupId\nRepeat: $repeatIndex",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}