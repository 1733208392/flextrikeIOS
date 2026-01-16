package com.flextarget.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.ui.drills.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TabNavigationView(
    bleManager: BLEManager = BLEManager.shared
) {
    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = Color.Black,
                contentColor = Color.Red
            ) {
                val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route

                NavigationBarItem(
                    icon = { Icon(Icons.Default.SportsBaseball, contentDescription = "Drills") },
                    label = { Text("Drills") },
                    selected = currentRoute == "drills",
                    onClick = {
                        navController.navigate("drills") {
                            popUpTo(navController.graph.startDestinationId)
                            launchSingleTop = true
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.Red,
                        selectedTextColor = Color.Red,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray,
                        indicatorColor = Color.Red.copy(alpha = 0.1f)
                    )
                )

                NavigationBarItem(
                    icon = { Icon(Icons.Default.History, contentDescription = "History") },
                    label = { Text("History") },
                    selected = currentRoute == "history",
                    onClick = {
                        navController.navigate("history") {
                            popUpTo(navController.graph.startDestinationId)
                            launchSingleTop = true
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.Red,
                        selectedTextColor = Color.Red,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray,
                        indicatorColor = Color.Red.copy(alpha = 0.1f)
                    )
                )

                NavigationBarItem(
                    icon = { Icon(Icons.Default.EmojiEvents, contentDescription = "Competition") },
                    label = { Text("Competition") },
                    selected = currentRoute == "competition",
                    onClick = {
                        navController.navigate("competition") {
                            popUpTo(navController.graph.startDestinationId)
                            launchSingleTop = true
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.Red,
                        selectedTextColor = Color.Red,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray,
                        indicatorColor = Color.Red.copy(alpha = 0.1f)
                    )
                )

                NavigationBarItem(
                    icon = { Icon(Icons.Default.AdminPanelSettings, contentDescription = "Admin") },
                    label = { Text("Admin") },
                    selected = currentRoute == "admin",
                    onClick = {
                        navController.navigate("admin") {
                            popUpTo(navController.graph.startDestinationId)
                            launchSingleTop = true
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.Red,
                        selectedTextColor = Color.Red,
                        unselectedIconColor = Color.Gray,
                        unselectedTextColor = Color.Gray,
                        indicatorColor = Color.Red.copy(alpha = 0.1f)
                    )
                )
            }
        },
        containerColor = Color.Black
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = "drills",
            modifier = Modifier.background(Color.Black)
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
                CompetitionTabContent()
            }

            composable("admin") {
                AdminTabContent()
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
private fun DrillsTabContent(
    bleManager: BLEManager,
    navController: NavHostController
) {
    var showDrillList by remember { mutableStateOf(false) }
    var showConnectView by remember { mutableStateOf(false) }
    var showInfo by remember { mutableStateOf(false) }
    var showQRScanner by remember { mutableStateOf(false) }
    var selectedDrillSetup by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var selectedDrillSummaries by remember { mutableStateOf<List<DrillRepeatSummary>?>(null) }

    if (showDrillList) {
        DrillListView(
            bleManager = bleManager,
            onBack = { showDrillList = false }
        )
    } else if (selectedDrillSetup != null && selectedDrillSummaries != null) {
        DrillSummaryView(
            drillSetup = selectedDrillSetup!!,
            summaries = selectedDrillSummaries!!,
            onBack = {
                selectedDrillSetup = null
                selectedDrillSummaries = null
            },
            onViewResult = { summary ->
                // TODO: Navigate to individual result view
            }
        )
    } else {
        DrillMainPageView(
            bleManager = bleManager,
            onShowDrillList = { showDrillList = true },
            onShowConnectView = { showConnectView = true },
            onShowInfo = { showInfo = true },
            onShowQRScanner = { showQRScanner = true },
            onDrillSelected = { results ->
                // Convert results to drill setup and summaries
                val firstResult = results.firstOrNull()
                if (firstResult != null) {
                    // For now, create a mock drill setup
                    val mockSetup = DrillSetupEntity(
                        name = "Recent Drill",
                        desc = "Recent training session"
                    )

                    // Convert results to summaries
                    val summaries = results.mapIndexed { index, result ->
                        val shots = result.shots.mapNotNull { shot ->
                            shot.data?.let { data ->
                                try {
                                    com.google.gson.Gson().fromJson(data, com.flextarget.android.data.model.ShotData::class.java)
                                } catch (e: Exception) {
                                    null
                                }
                            }
                        }
                        val totalTime = if (result.drillResult.totalTime > 0) result.drillResult.totalTime else shots.sumOf { it.content.actualTimeDiff }
                        val fastestShot = shots.minOfOrNull { it.content.actualTimeDiff } ?: 0.0

                        DrillRepeatSummary(
                            repeatIndex = index + 1,
                            totalTime = totalTime,
                            numShots = shots.size,
                            firstShot = shots.firstOrNull()?.content?.actualTimeDiff ?: 0.0,
                            fastest = fastestShot,
                            score = 0,
                            shots = shots
                        )
                    }

                    selectedDrillSetup = mockSetup
                    selectedDrillSummaries = summaries
                }
            }
        )
    }

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

    if (showInfo) {
        // TODO: Implement info view
        showInfo = false
    }
}

@Composable
private fun HistoryTabContent(navController: NavHostController) {
    var selectedDrillSetup by remember { mutableStateOf<DrillSetupEntity?>(null) }
    var selectedSummaries by remember { mutableStateOf<List<DrillRepeatSummary>?>(null) }

    if (selectedDrillSetup != null && selectedSummaries != null) {
        DrillSummaryView(
            drillSetup = selectedDrillSetup!!,
            summaries = selectedSummaries!!,
            onBack = {
                selectedDrillSetup = null
                selectedSummaries = null
            },
            onViewResult = { summary ->
                // TODO: Navigate to individual result view
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
private fun CompetitionTabContent() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = androidx.compose.ui.Alignment.Center
    ) {
        Text(
            "Competition Tab\nComing Soon",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
    }
}

@Composable
private fun AdminTabContent() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = androidx.compose.ui.Alignment.Center
    ) {
        Text(
            "Admin Tab\nComing Soon",
            color = Color.White,
            style = MaterialTheme.typography.headlineMedium,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
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