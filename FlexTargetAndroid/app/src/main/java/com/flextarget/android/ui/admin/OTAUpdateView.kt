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
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.collectAsState
import com.flextarget.android.ui.viewmodel.OTAViewModel
import com.flextarget.android.ui.viewmodel.BLEViewModel
import com.flextarget.android.ui.viewmodel.AuthViewModel
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.repository.OTAState
import android.util.Log
import kotlinx.coroutines.launch
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.theme.md_theme_dark_primary
import com.flextarget.android.ui.theme.AppTypography

@Composable
fun OTAUpdateView(
    otaViewModel: OTAViewModel,
    bleViewModel: BLEViewModel,
    authViewModel: AuthViewModel,
    onBack: () -> Unit = {}
) {
    // State from ViewModels
    val otaUiState = otaViewModel.otaUiState.collectAsState().value
    val authUiState = authViewModel.authUiState.collectAsState().value
    val coroutineScope = rememberCoroutineScope()
    
    Log.d("OTAUpdateView", "OTAUpdateView composable rendered, OTA state: ${otaUiState.state}")
    Log.d("OTAUpdateView", "Current version from state: ${otaUiState.currentVersion}")
    
    // BLE and device auth managers
    val bleManager = BLEManager.shared
    
    // Check authentication - show login if user is not authenticated
    if (!authUiState.isAuthenticated) {
        LoginScreen(
            authViewModel = authViewModel,
            onLoginSuccess = { /* Stay on OTA screen after login */ }
        )
        return
    }
    
    // Auto-check for available version on initial load
    LaunchedEffect(Unit) {
        if (!bleManager.isConnected) {
            Log.d("OTAUpdateView", "BLE not connected, skipping auto-check")
            return@LaunchedEffect
        }
        
        // Explicitly query device version on view launch
        Log.d("OTAUpdateView", "Querying device version on view launch")
        bleManager.androidManager?.queryVersion()
        
        coroutineScope.launch {
            Log.d("OTAUpdateView", "Auto-checking for updates on initial load")
            val authDataResult = bleViewModel.getDeviceAuthData()
            authDataResult.onSuccess { authData: String ->
                Log.d("OTAUpdateView", "Auth data retrieved successfully, checking for updates")
                otaViewModel.checkForUpdates(authData)
            }.onFailure { error: Throwable ->
                Log.e("OTAUpdateView", "Failed to get auth data for auto-check: ${error.message}", error)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // TopAppBar with back arrow and title
        CenterAlignedTopAppBar(
            title = {
                Text(
                    stringResource(com.flextarget.android.R.string.ota_title),
                    style = AppTypography.bodyLarge,
                    color = md_theme_dark_onPrimary,
                )
            },
            navigationIcon = {
                    IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = stringResource(com.flextarget.android.R.string.back),
                        tint = md_theme_dark_onPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
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
                // Current Version Info - Centered
                item {
                    StatusCard(
                            title = stringResource(com.flextarget.android.R.string.ota_current_version),
                            version = otaUiState.currentVersion ?: "---",
                        )
                }

                // OTA State Messages
                when (otaUiState.state) {
                    OTAState.CHECKING -> {
                        item {
                            CheckingCard(stepMessage = otaUiState.description.ifEmpty { stringResource(com.flextarget.android.R.string.ota_checking) })
                        }
                    }
                    OTAState.ERROR -> {
                        item {
                                ErrorCard(
                                errorMessage = otaUiState.error ?: stringResource(com.flextarget.android.R.string.error_unknown),
                                onRetry = {
                                    if (!bleManager.isConnected) {
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
                    OTAState.PREPARING -> {
                        item {
                            PreparingCard(
                                progress = otaUiState.progress,
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.WAITING_FOR_READY_TO_DOWNLOAD -> {
                        item {
                            WaitingCard(
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.DOWNLOADING -> {
                        item {
                            DownloadingCard(
                                progress = otaUiState.progress,
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.RELOADING -> {
                        item {
                            ReloadingCard(
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.VERIFYING -> {
                        item {
                            VerifyingCard(
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.COMPLETED -> {
                        item {
                            CompletedCard(
                                version = otaUiState.availableVersion ?: ""
                            )
                        }
                    }
                    OTAState.IDLE -> {
                        item {
                            UpToDateCard(
                                lastCheckTime = otaUiState.lastCheck,
                                currentVersion = otaUiState.currentVersion,
                                availableVersion = otaUiState.availableVersion
                            )
                        }
                    }
                }

                // Unified Button
                if (bleManager.isConnected) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp)
                        ) {
                            UnifiedOTAButton(
                                otaState = otaUiState.state,
                                onCheckClick = {
                                    Log.d("OTAUpdateView", "Check for updates button tapped")
                                    Log.d("OTAUpdateView", "BLE manager isConnected=${bleManager.isConnected}")
                                    
                                    if (!bleManager.isConnected) {
                                        Log.e("OTAUpdateView", "Cannot check for updates: BLE device not connected")
                                        return@UnifiedOTAButton
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
                                        }
                                    }
                                },
                                onUpdateClick = {
                                    otaViewModel.prepareUpdate()
                                }
                            )
                        }
                    }
                }

                // Info Card
                item {
                    InfoCard(
                        title = stringResource(com.flextarget.android.R.string.ota_about_title),
                        description = stringResource(com.flextarget.android.R.string.ota_about_description)
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
                stringResource(com.flextarget.android.R.string.connection_required).uppercase(),
                color = md_theme_dark_onPrimary,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                stringResource(com.flextarget.android.R.string.connect_device_prompt),
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
                Text(stringResource(com.flextarget.android.R.string.go_to_device_management), color = Color.White, fontWeight = FontWeight.Bold)
            }
        }
    }
}

@Composable
private fun StatusCard(
    title: String,
    version: String,
    status: String = ""
) {
    Log.d("StatusCard", "Displaying version: $version")
    
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
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {

            Text(
                version.uppercase(),
                color = md_theme_dark_onPrimary,
                style = AppTypography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            Text(
                title,
                color = Color.Gray,
                style = AppTypography.labelSmall
            )

            if (status.isNotEmpty()) {
                Text(
                    status,
                    color = Color.Green,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}

@Composable
private fun UnifiedOTAButton(
    otaState: OTAState,
    onCheckClick: () -> Unit,
    onUpdateClick: () -> Unit
) {
    var buttonText = stringResource(com.flextarget.android.R.string.check_now)
    var isEnabled = true

    when (otaState) {
        OTAState.CHECKING -> {
            buttonText = stringResource(com.flextarget.android.R.string.ota_checking)
            isEnabled = false
        }
        OTAState.UPDATE_AVAILABLE -> {
            buttonText = stringResource(com.flextarget.android.R.string.update_now)
            isEnabled = true
        }
        OTAState.PREPARING, OTAState.WAITING_FOR_READY_TO_DOWNLOAD,
        OTAState.DOWNLOADING, OTAState.RELOADING, OTAState.VERIFYING -> {
            buttonText = stringResource(com.flextarget.android.R.string.ota_updating)
            isEnabled = false
        }
        else -> {
            buttonText = stringResource(com.flextarget.android.R.string.check_now)
            isEnabled = true
        }
    }

    Button(
        onClick = {
            if (otaState == OTAState.UPDATE_AVAILABLE) {
                onUpdateClick()
            } else {
                onCheckClick()
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = md_theme_dark_onPrimary,
            disabledContainerColor = md_theme_dark_onPrimary.copy(alpha = 0.6f)
        ),
        shape = RoundedCornerShape(8.dp),
        enabled = isEnabled
    ) {
        Text(
            buttonText,
            color = md_theme_dark_primary,
            style = AppTypography.bodyLarge,
//            fontWeight = FontWeight.Bold
        )
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
                color = md_theme_dark_onPrimary,
                strokeWidth = 3.dp
            )
            Text(
                stepMessage.ifEmpty { stringResource(com.flextarget.android.R.string.ota_checking) },
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
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
            containerColor = Color.White.copy(alpha = 0.1f)
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
                        stringResource(com.flextarget.android.R.string.ota_failed).uppercase(),
                        color = md_theme_dark_onPrimary,
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
                Text(stringResource(com.flextarget.android.R.string.retry), color = Color.White, fontWeight = FontWeight.Bold)
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
            containerColor = Color.White.copy(alpha = 0.1f)
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
                        stringResource(com.flextarget.android.R.string.ota_available).uppercase(),
                        color = md_theme_dark_onPrimary,
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
                stringResource(com.flextarget.android.R.string.ota_available_description),
                color = Color.White,
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

@Composable
private fun UpToDateCard(
    lastCheckTime: String?,
    currentVersion: String?,
    availableVersion: String?
) {
    // Only show "up to date" message if current version equals available version
    val isUpToDate = currentVersion != null &&
                     availableVersion != null && 
                     currentVersion == availableVersion
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
                if (isUpToDate) stringResource(com.flextarget.android.R.string.ota_target_up_to_date).uppercase() else stringResource(com.flextarget.android.R.string.ota_ready_to_check).uppercase(),
                color = md_theme_dark_onPrimary,
                style = MaterialTheme.typography.bodyLarge,
//                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            if (lastCheckTime != null && isUpToDate) {
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
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = md_theme_dark_onPrimary,
                    modifier = Modifier.size(20.dp)
                )
                Column {
                    Text(
                        title,
                        color = md_theme_dark_onPrimary,
                        style = AppTypography.labelSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        description,
                        color = Color.Gray,
                        style = AppTypography.labelSmall
                    )
                }
            }
            
            // Warning section
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.Top
            ) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = null,
                    tint = Color.Red,
                    modifier = Modifier.size(20.dp)
                )
                Column {
                    Text(
                        stringResource(com.flextarget.android.R.string.warning),
                        color = md_theme_dark_onPrimary,
                        style = AppTypography.labelSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        stringResource(com.flextarget.android.R.string.ota_warning_unplug),
                        color = Color.Gray,
                        style = AppTypography.labelSmall
                    )
                }
            }
        }
    }
}

@Composable
private fun PreparingCard(
    progress: Int,
    version: String
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = Color.Red,
                strokeWidth = 3.dp
            )
            Text(
                "Preparing Update",
                color = Color.White,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun WaitingCard(
    version: String
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = Color.Red,
                strokeWidth = 3.dp
            )
            Text(
                "WAITING",
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = AppTypography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun DownloadingCard(
    progress: Int,
    version: String
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = md_theme_dark_onPrimary,
                strokeWidth = 3.dp
            )
            Text(
                "DOWNLOADING",
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = AppTypography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun ReloadingCard(
    version: String
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = Color.Red,
                strokeWidth = 3.dp
            )
            Text(
                "RELOADING...",
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = AppTypography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun VerifyingCard(
    version: String
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            CircularProgressIndicator(
                modifier = Modifier.size(48.dp),
                color = Color.Red,
                strokeWidth = 3.dp
            )
            Text(
                "VERIFYING",
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = AppTypography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun CompletedCard(
    version: String
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
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
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = Color.Green,
                modifier = Modifier.size(48.dp)
            )
            Text(
                "UPDATE COMPLETED",
                color = md_theme_dark_onPrimary,
                style = AppTypography.bodyLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                "Version $version",
                color = Color.Gray,
                style = AppTypography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}
