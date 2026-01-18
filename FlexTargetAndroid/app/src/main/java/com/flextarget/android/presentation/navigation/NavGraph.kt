package com.flextarget.android.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavController
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.flextarget.android.di.AppContainer
import com.flextarget.android.presentation.ui.screens.CompetitionsListScreen
import com.flextarget.android.presentation.ui.screens.DrillExecutionScreen
import com.flextarget.android.presentation.ui.screens.LoginScreen
import com.flextarget.android.presentation.ui.screens.OTAUpdatesScreen
import java.util.UUID

/**
 * Navigation Routes
 */
object NavRoutes {
    const val LOGIN = "login"
    const val COMPETITIONS = "competitions"
    const val DRILL_EXECUTION = "drill_execution/{drillId}"
    const val OTA_UPDATES = "ota_updates"
    const val SETTINGS = "settings"
    
    fun drillExecution(drillId: UUID) = "drill_execution/$drillId"
}

/**
 * Navigation actions helper
 */
class NavigationActions(private val navController: NavController) {
    
    fun navigateToCompetitions() {
        navController.navigate(NavRoutes.COMPETITIONS) {
            popUpTo(navController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
    }
    
    fun navigateToDrillExecution(drillId: UUID) {
        navController.navigate(NavRoutes.drillExecution(drillId))
    }
    
    fun navigateToOTAUpdates() {
        navController.navigate(NavRoutes.OTA_UPDATES)
    }
    
    fun navigateToSettings() {
        navController.navigate(NavRoutes.SETTINGS)
    }
    
    fun navigateToLogin() {
        navController.navigate(NavRoutes.LOGIN) {
            popUpTo(navController.graph.findStartDestination().id) {
                inclusive = true
            }
            launchSingleTop = true
        }
    }
    
    fun navigateBack() {
        navController.popBackStack()
    }
}

/**
 * Main navigation graph for the app
 * 
 * Navigation structure:
 * - Login (entry point if not authenticated)
 * - Competitions (home after login)
 * - Drill Execution (from competition)
 * - OTA Updates (side menu)
 * - Settings (side menu)
 */
@Composable
fun FlexTargetNavHost(
    navController: NavHostController,
    startDestination: String = NavRoutes.LOGIN,
    navigationActions: NavigationActions = NavigationActions(navController)
) {
    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        // Login screen
        composable(NavRoutes.LOGIN) {
            LoginScreen(
                authViewModel = AppContainer.authViewModel,
                onLoginSuccess = {
                    navigationActions.navigateToCompetitions()
                }
            )
        }
        
        // Competitions list screen
        composable(NavRoutes.COMPETITIONS) {
            CompetitionsListScreen(
                competitionViewModel = AppContainer.competitionViewModel,
                onCompetitionSelected = { competitionId ->
                    // In real app, would store selected competition and navigate to drill selection
                    // For now, navigate directly to OTA as next feature demo
                }
            )
        }
        
        // Drill execution screen
        composable(
            NavRoutes.DRILL_EXECUTION,
            arguments = listOf(
                navArgument("drillId") {
                    type = NavType.StringType
                }
            )
        ) { backStackEntry ->
            val drillId = backStackEntry.arguments?.getString("drillId")?.let { UUID.fromString(it) }
            DrillExecutionScreen(
                drillViewModel = AppContainer.drillViewModel,
                bleViewModel = AppContainer.bleViewModel,
                drillId = drillId,
                onExecutionComplete = { score, shotCount ->
                    navigationActions.navigateBack()
                }
            )
        }
        
        // OTA updates screen
        composable(NavRoutes.OTA_UPDATES) {
            OTAUpdatesScreen(
                otaViewModel = AppContainer.otaViewModel
            )
        }
    }
}

/**
 * Top-level navigation scaffold with navigation rail/drawer
 * Provides navigation between main sections
 */
@Composable
fun FlexTargetAppNavigation(
    navController: NavHostController,
    isAuthenticated: Boolean
) {
    val navigationActions = NavigationActions(navController)
    val startDestination = if (isAuthenticated) NavRoutes.COMPETITIONS else NavRoutes.LOGIN
    
    FlexTargetNavHost(
        navController = navController,
        startDestination = startDestination,
        navigationActions = navigationActions
    )
}
