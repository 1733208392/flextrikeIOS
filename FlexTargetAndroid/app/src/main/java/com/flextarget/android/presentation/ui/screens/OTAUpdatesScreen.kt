package com.flextarget.android.presentation.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.flextarget.android.data.repository.OTAState
import com.flextarget.android.presentation.viewmodel.OTAViewModel
import kotlinx.coroutines.delay

/**
 * OTA Updates Screen
 * 
 * Manages over-the-air updates with the following flow:
 * 1. Check for available updates
 * 2. Download and prepare (10min timeout)
 * 3. Verify integrity (30s timeout)
 * 4. Install and complete
 * 
 * Shows progress indication, update details, and installation status.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OTAUpdatesScreen(
    otaViewModel: OTAViewModel = hiltViewModel()
) {
    val otaUiState by otaViewModel.otaUiState.collectAsState()
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("System Updates") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                actions = {
                    IconButton(
                        onClick = { otaViewModel.checkForUpdates() },
                        enabled = otaUiState.state == OTAState.IDLE
                    ) {
                        Icon(Icons.Filled.Refresh, contentDescription = "Check for updates")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Update status card
            OTAStatusCard(
                state = otaUiState.state,
                currentVersion = otaUiState.currentVersion,
                availableVersion = otaUiState.availableVersion
            )
            
            // Update details (if available)
            if (otaUiState.state in listOf(OTAState.UPDATE_AVAILABLE, OTAState.PREPARING, OTAState.READY)) {
                OTADetailsCard(
                    version = otaUiState.availableVersion ?: "",
                    description = otaUiState.description,
                    mandatory = otaUiState.mandatory
                )
            }
            
            // Progress indicator (if updating)
            if (otaUiState.state in listOf(OTAState.CHECKING, OTAState.PREPARING, OTAState.VERIFYING, OTAState.INSTALLING)) {
                OTAProgressCard(
                    state = otaUiState.state,
                    progress = otaUiState.progress
                )
            }
            
            // Error message (if failed)
            if (!otaUiState.error.isNullOrEmpty()) {
                ErrorCard(error = otaUiState.error!!)
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            // Action buttons
            OTAActionButtons(
                state = otaUiState.state,
                onCheckClicked = { otaViewModel.checkForUpdates() },
                onPrepareClicked = { otaViewModel.prepareUpdate() },
                onVerifyClicked = { otaViewModel.verifyUpdate() },
                onInstallClicked = { otaViewModel.installUpdate() },
                onCancelClicked = { otaViewModel.cancelUpdate() }
            )
        }
    }
}

/**
 * OTA status card showing current state
 */
@Composable
fun OTAStatusCard(
    state: OTAState,
    currentVersion: String? = null,
    availableVersion: String? = null
) {
    val (icon, label, color) = when (state) {
        OTAState.IDLE -> Triple(Icons.Filled.SystemUpdate, "Up to Date", Color.Green)
        OTAState.CHECKING -> Triple(Icons.Filled.Search, "Checking for updates...", Color.Blue)
        OTAState.UPDATE_AVAILABLE -> Triple(Icons.Filled.Update, "Update Available", Color.Yellow)
        OTAState.PREPARING -> Triple(Icons.Filled.Download, "Downloading update...", Color.Cyan)
        OTAState.READY -> Triple(Icons.Filled.CheckCircle, "Ready to install", Color.Blue)
        OTAState.VERIFYING -> Triple(Icons.Filled.VerifiedUser, "Verifying...", Color.Yellow)
        OTAState.INSTALLING -> Triple(Icons.Filled.AutoAwesome, "Installing...", Color.Cyan)
        OTAState.COMPLETE -> Triple(Icons.Filled.Done, "Installation Complete", Color.Green)
        OTAState.ERROR -> Triple(Icons.Filled.Error, "Update Failed", Color.Red)
    }
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = color.copy(alpha = 0.1f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 12.dp)
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = label,
                    tint = color,
                    modifier = Modifier.size(32.dp)
                )
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = label,
                    style = MaterialTheme.typography.titleMedium,
                    color = color
                )
            }
            
            // Version info
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Current version: ${currentVersion ?: "Unknown"}", style = MaterialTheme.typography.bodySmall)
                if (!availableVersion.isNullOrEmpty()) {
                    Text("Latest: $availableVersion", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

/**
 * Update details card
 */
@Composable
fun OTADetailsCard(
    version: String,
    description: String,
    mandatory: Boolean
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text("Update Details", style = MaterialTheme.typography.labelLarge)
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text("Version: $version", style = MaterialTheme.typography.bodyMedium)
            
            if (mandatory) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.WarningAmber,
                        contentDescription = "Mandatory",
                        tint = Color.Red,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Mandatory update", style = MaterialTheme.typography.bodySmall, color = Color.Red)
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

/**
 * Progress indicator card
 */
@Composable
fun OTAProgressCard(
    state: OTAState,
    progress: Int
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.tertiaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = when (state) {
                    OTAState.CHECKING -> "Checking for updates..."
                    OTAState.PREPARING -> "Downloading and preparing... (10 min timeout)"
                    OTAState.VERIFYING -> "Verifying integrity... (30 sec timeout)"
                    OTAState.INSTALLING -> "Installing update..."
                    else -> "Processing..."
                },
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(bottom = 8.dp)
            )
            
            LinearProgressIndicator(
                progress = progress / 100f,
                modifier = Modifier.fillMaxWidth()
            )
            
            Text(
                text = "$progress%",
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier
                    .align(Alignment.End)
                    .padding(top = 4.dp)
            )
        }
    }
}

/**
 * Error card
 */
@Composable
fun ErrorCard(error: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Red.copy(alpha = 0.1f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Filled.Error,
                contentDescription = "Error",
                tint = Color.Red,
                modifier = Modifier.size(24.dp)
            )
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = Color.Red
            )
        }
    }
}

/**
 * Action buttons for OTA operations
 */
@Composable
fun OTAActionButtons(
    state: OTAState,
    onCheckClicked: () -> Unit,
    onPrepareClicked: () -> Unit,
    onVerifyClicked: () -> Unit,
    onInstallClicked: () -> Unit,
    onCancelClicked: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        when (state) {
            OTAState.IDLE -> {
                Button(
                    onClick = onCheckClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Check for Updates")
                }
            }
            OTAState.UPDATE_AVAILABLE -> {
                Button(
                    onClick = onPrepareClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Download Update")
                }
            }
            OTAState.READY -> {
                Button(
                    onClick = onVerifyClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Verify & Install")
                }
            }
            OTAState.COMPLETE -> {
                Button(
                    onClick = onCheckClicked,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                ) {
                    Text("Check Again")
                }
            }
            else -> {}
        }
        
        // Cancel button for in-progress operations
        AnimatedVisibility(visible = state in listOf(OTAState.CHECKING, OTAState.PREPARING, OTAState.VERIFYING)) {
            OutlinedButton(
                onClick = onCancelClicked,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                Text("Cancel")
            }
        }
    }
}

/**
 * OTA Updates Screen Preview
 */
@androidx.compose.ui.tooling.preview.Preview(showBackground = true)
@Composable
fun OTAUpdatesScreenPreview() {
    MaterialTheme {
        OTAUpdatesScreen()
    }
}
