package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.collectAsState
import com.flextarget.android.ui.viewmodel.OTAViewModel
import com.flextarget.android.ui.viewmodel.BLEViewModel
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.repository.OTAState
import android.util.Log
import kotlinx.coroutines.launch

@Composable
fun OTAUpdateView(
    otaViewModel: OTAViewModel,
    bleViewModel: BLEViewModel
) {
    // State from ViewModels
    val otaUiState = otaViewModel.otaUiState.collectAsState().value
    val coroutineScope = rememberCoroutineScope()
    
    Log.d("OTAUpdateView", "OTAUpdateView composable rendered, OTA state: ${otaUiState.state}")
    
    // BLE and device auth managers
    val bleManager = BLEManager.shared

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {


        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Check if device is connected
            if (!bleManager.isConnected) {
                item {
                    DeviceNotConnectedCard(onNavigateToDeviceManagement = { /* TODO: Navigate to device management */ })
                }
            }
            // Device is connected
            else {
                // Current Version Info
                item {
                    StatusCard(
                        title = "Current Version",
                        version = otaUiState.currentVersion ?: "1.0.0",
                        status = "System Ready"
                    )
                }

                // Check for Updates Button
                item {
                    val isEnabled = otaUiState.state == OTAState.IDLE
                    Log.d("OTAUpdateView", "Button enabled: $isEnabled, current state: ${otaUiState.state}")
                    CheckUpdatesButton(
                        isChecking = otaUiState.state == OTAState.CHECKING,
                        stepMessage = otaUiState.description,
                        onCheckClick = {
                            Log.d("OTAUpdateView", "Check for updates button tapped")
                            val bleState = bleViewModel.bleUiState.value
                            Log.d("OTAUpdateView", "BLE state: isConnected=${bleState.isConnected}, deviceState=${bleState.deviceState}")
                            
                            if (!bleState.isConnected) {
                                Log.e("OTAUpdateView", "Cannot check for updates: BLE device not connected")
                                return@CheckUpdatesButton
                            }
                            
                            coroutineScope.launch {
                                Log.d("OTAUpdateView", "Starting auth data retrieval")
                                // Get auth data from BLE device first
                                val authDataResult = bleViewModel.getDeviceAuthData()
                                authDataResult.onSuccess { authData: String ->
                                    Log.d("OTAUpdateView", "Auth data retrieved successfully, calling checkForUpdates")
                                    otaViewModel.checkForUpdates(authData)
                                }.onFailure { error: Throwable ->
                                    Log.e("OTAUpdateView", "Failed to get auth data: ${error.message}", error)
                                    // Handle error - could show a snackbar or toast
                                    // For now, just log the error
                                }
                            }
                        }
                    )
                }

                // OTA State Messages
                when (otaUiState.state) {
                    OTAState.CHECKING -> {
                        item {
                            CheckingCard(stepMessage = otaUiState.description.ifEmpty { "Checking for updates..." })
                        }
                    }
                    OTAState.ERROR -> {
                        item {
                            ErrorCard(
                                errorMessage = otaUiState.error ?: "Unknown error occurred",
                                onRetry = {
                                    val bleState = bleViewModel.bleUiState.value
                                    if (!bleState.isConnected) {
                                        Log.e("OTAUpdateView", "Cannot retry: BLE device not connected")
                                        return@ErrorCard
                                    }
                                    
                                    coroutineScope.launch {
                                        val authDataResult = bleViewModel.getDeviceAuthData()
                                        authDataResult.onSuccess { authData: String ->
                                            otaViewModel.checkForUpdates(authData)
                                        }.onFailure { error: Throwable ->
                                            Log.e("OTAUpdateView", "Failed to get auth data on retry: ${error.message}", error)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    OTAState.UPDATE_AVAILABLE -> {
                        if (otaUiState.availableVersion != null) {
                            item {
                                UpdateAvailableCard(
                                    availableVersion = otaUiState.availableVersion
                                )
                            }
                        }
                    }
                    OTAState.IDLE -> {
                        item {
                            UpToDateCard(
                                lastCheckTime = otaUiState.lastCheck
                            )
                        }
                    }
                    else -> {}
                }

                // Info Card
                item {
                    InfoCard(
                        title = "About OTA Updates",
                        description = "Over-the-Air (OTA) updates allow you to install the latest features and security improvements for your device. Updates are checked using your device's authentication."
                    )
                }
            }
        }
    }
}

// UI Components

@Composable
private fun DeviceNotConnectedCard(onNavigateToDeviceManagement: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF3a2a1a)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Warning,
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(48.dp)
            )
            Text(
                "Connect Device First",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Connect your device to check for updates",
                color = Color.Gray,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center
            )
            Button(
                onClick = onNavigateToDeviceManagement,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("Go to Device Management", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun StatusCard(
    title: String,
    version: String,
    status: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                title,
                color = Color.Gray,
                style = MaterialTheme.typography.labelSmall
            )
            Text(
                version,
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Text(
                status,
                color = Color.Green,
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}

@Composable
private fun CheckUpdatesButton(
    isChecking: Boolean,
    stepMessage: String,
    onCheckClick: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Button(
            onClick = onCheckClick,
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
            shape = RoundedCornerShape(8.dp),
            enabled = !isChecking
        ) {
            if (isChecking) {
                CircularProgressIndicator(
                    modifier = Modifier.size(24.dp),
                    color = Color.White,
                    strokeWidth = 2.dp
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("Checking...", color = Color.White, fontWeight = FontWeight.Bold)
            } else {
                Text("Check Now", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
        if (stepMessage.isNotEmpty()) {
            Text(
                stepMessage,
                color = Color.Gray,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

@Composable
private fun CheckingCard(stepMessage: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = Color.Red,
                strokeWidth = 3.dp
            )
            Text(
                stepMessage.ifEmpty { "Checking for updates..." },
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun ErrorCard(errorMessage: String, onRetry: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Red.copy(alpha = 0.1f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color.Red,
                    modifier = Modifier.size(32.dp)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Update Check Failed",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        errorMessage,
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
            Button(
                onClick = onRetry,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("Retry", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun UpdateAvailableCard(
    availableVersion: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.Red.copy(alpha = 0.1f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Download,
                    contentDescription = null,
                    tint = Color.Red,
                    modifier = Modifier.size(32.dp)
                )
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "Update Available",
                        color = Color.White,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "Version $availableVersion",
                        color = Color.Gray,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }

            Text(
                "A new system update is available. Update now to get the latest features and security improvements.",
                color = Color.White,
                style = MaterialTheme.typography.bodySmall
            )

            Button(
                onClick = { },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("Update Now", color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun UpToDateCard(lastCheckTime: String?) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color.White.copy(alpha = 0.05f),
                shape = RoundedCornerShape(8.dp)
            )
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = Color.Green,
                modifier = Modifier.size(48.dp)
            )
            Text(
                "Your system is up to date",
                color = Color.White,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            if (lastCheckTime != null) {
                Text(
                    "Last checked: $lastCheckTime",
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun InfoCard(
    title: String,
    description: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color.Gray,
                    modifier = Modifier.size(20.dp)
                )
                Column {
                    Text(
                        title,
                        color = Color.White,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        description,
                        color = Color.Gray,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}
