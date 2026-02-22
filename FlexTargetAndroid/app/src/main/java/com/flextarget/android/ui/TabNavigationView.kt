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
import com.flextarget.android.data.model.DrillTargetsConfigData
import com.flextarget.android.data.model.toExpandedDataObjects
import com.flextarget.android.ui.theme.FlexTargetTheme
import android.net.Uri
import com.flextarget.android.ui.Screen
import com.flextarget.android.ui.theme.DarkColorScheme
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TabNavigationView(
    bleManager: BLEManager = BLEManager.shared
) {
    FlexTargetTheme {
        val navController = rememberNavController()

    // Auto navigate to admin tab when shouldShowRemoteControl is true
    LaunchedEffect(bleManager.shouldShowRemoteControl) {
        if (bleManager.shouldShowRemoteControl) {
            println("[TabNavigationView] Navigating to admin tab")
            navController.navigate("admin") {
                popUpTo(navController.graph.startDestinationId)
                launchSingleTop = true
            }
        }
    }

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
            startDestination = Screen.Drills.route,
            modifier = Modifier
                .background(Color.Black)
                .padding(
                    top = paddingValues.calculateTopPadding(),
                    start = paddingValues.calculateLeftPadding(LayoutDirection.Ltr),
                    end = paddingValues.calculateRightPadding(LayoutDirection.Ltr)
                )
        ) {
            composable(Screen.Drills.route) {
                DrillsTabContent(
                    bleManager = bleManager,
                    navController = navController
                )
            }

            // QR Scanner route
            composable(Screen.QRScanner.route) {
                com.flextarget.android.ui.qr.QRScannerView(
                    onQRScanned = { scannedText ->
                        // set auto connect target and navigate to connect view
                        bleManager.setAutoConnectTarget(scannedText)
                        val encoded = Uri.encode(scannedText)
                        navController.navigate("${Screen.ConnectTarget.route}/$encoded") {
                            popUpTo(Screen.Drills.route)
                            launchSingleTop = true
                        }
                    },
                    onDismiss = { navController.popBackStack() },
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

            composable(Screen.Admin.route) {
                AdminTabView(
                    bleManager = bleManager,
                    authViewModel = AppContainer.authViewModel,
                    otaViewModel = AppContainer.otaViewModel,
                    bleViewModel = AppContainer.bleViewModel
                )
            }

            // Connect target routes (no arg and with target arg)
            composable("${Screen.ConnectTarget.route}") { backStackEntry ->
                com.flextarget.android.ui.ble.ConnectSmartTargetView(
                    bleManager = bleManager,
                    onDismiss = { navController.popBackStack() },
                    targetPeripheralName = null,
                    isAlreadyConnected = bleManager.isConnected
                )
            }

            composable("${Screen.ConnectTarget.route}/{target}") { backStackEntry ->
                val encoded = backStackEntry.arguments?.getString("target")
                val decoded = encoded?.let { Uri.decode(it) }
                com.flextarget.android.ui.ble.ConnectSmartTargetView(
                    bleManager = bleManager,
                    onDismiss = { navController.popBackStack() },
                    targetPeripheralName = decoded,
                    isAlreadyConnected = bleManager.isConnected
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
                    icon = Icons.Default.TrackChanges,
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
    val iconColor = if (selected) md_theme_dark_onPrimary else Color.Gray
    val textColor = if (selected) md_theme_dark_onPrimary else Color.Gray
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
    DrillListView(
        bleManager = bleManager,
        onBack = null,
        onShowConnectView = {
            // Navigate to connect without a preselected target
            navController.navigate(Screen.ConnectTarget.route) {
                popUpTo(Screen.Drills.route)
                launchSingleTop = true
            }
        },
        onShowQRScanner = {
            // Navigate to the full-screen QR scanner
            navController.navigate(Screen.QRScanner.route) {
                popUpTo(Screen.Drills.route)
                launchSingleTop = true
            }
        }
    )
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
            drillTargets = (setupWithTargets?.targets ?: emptyList()).toExpandedDataObjects()
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
            "DRILL SUMMARY\nSETUP ID: $drillSetupId".uppercase(),
            color = md_theme_dark_onPrimary,
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
            "DRILL RESULT\nSETUP ID: $drillSetupId\nREPEAT: $repeatIndex".uppercase(),
            color = md_theme_dark_onPrimary,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}