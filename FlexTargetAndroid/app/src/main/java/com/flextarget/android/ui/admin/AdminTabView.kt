package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Info
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.ui.viewmodel.AuthViewModel
import com.flextarget.android.ui.viewmodel.OTAViewModel
import com.flextarget.android.ui.viewmodel.BLEViewModel

@Composable
fun AdminTabView(
    bleManager: BLEManager = BLEManager.shared,
    authViewModel: AuthViewModel,
    otaViewModel: OTAViewModel,
    bleViewModel: BLEViewModel
) {
    val showMainMenu = remember { mutableStateOf(true) }
    val showDeviceManagement = remember { mutableStateOf(false) }
    val showUserProfile = remember { mutableStateOf(false) }
    val showLogin = remember { mutableStateOf(false) }
    val showManualDeviceSelect = remember { mutableStateOf(false) }
    val showQRScanner = remember { mutableStateOf(false) }
    val showConnectedDeviceDetails = remember { mutableStateOf(false) }
    val showOTAUpdate = remember { mutableStateOf(false) }

    val authUiState by authViewModel.authUiState.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        when {
            showOTAUpdate.value -> {
                OTAUpdateView(
                    otaViewModel = otaViewModel,
                    bleViewModel = bleViewModel
                )
            }
            showConnectedDeviceDetails.value -> {
                com.flextarget.android.ui.ble.ConnectSmartTargetView(
                    bleManager = bleManager,
                    isAlreadyConnected = true,
                    onDismiss = {
                        showConnectedDeviceDetails.value = false
                        showDeviceManagement.value = true
                    }
                )
            }
            showQRScanner.value -> {
                com.flextarget.android.ui.qr.QRScannerView(
                    onQRScanned = { code ->
                        // Set auto-connect target with scanned device name
                        bleManager.setAutoConnectTarget(code)
                        showQRScanner.value = false
                        showDeviceManagement.value = true
                    },
                    onDismiss = {
                        showQRScanner.value = false
                        showDeviceManagement.value = true
                    }
                )
            }
            showManualDeviceSelect.value -> {
                ManualDeviceSelectionView(
                    bleManager = bleManager,
                    onBack = {
                        showManualDeviceSelect.value = false
                        showDeviceManagement.value = true
                    },
                    onDeviceSelected = { _ ->
                        showManualDeviceSelect.value = false
                        showDeviceManagement.value = true
                    }
                )
            }
            showMainMenu.value -> {
                AdminMainMenuView(
                    isDeviceConnected = bleManager.isConnected,
                    onDeviceManagementClick = {
                        showMainMenu.value = false
                        showDeviceManagement.value = true
                    },
                    onUserProfileClick = {
                        showMainMenu.value = false
                        if (authUiState.isAuthenticated) {
                            showUserProfile.value = true
                        } else {
                            showLogin.value = true
                        }
                    }
                )
            }
            showDeviceManagement.value -> {
                DeviceManagementView(
                    isDeviceConnected = bleManager.isConnected,
                    onBack = {
                        showDeviceManagement.value = false
                        showMainMenu.value = true
                    },
                    onManualSelectClick = {
                        showDeviceManagement.value = false
                        showManualDeviceSelect.value = true
                    },
                    onQRScanClick = {
                        showDeviceManagement.value = false
                        showQRScanner.value = true
                    },
                    onConnectedDeviceClick = {
                        showDeviceManagement.value = false
                        showConnectedDeviceDetails.value = true
                    },
                    onOTAUpdateClick = {
                        showDeviceManagement.value = false
                        showOTAUpdate.value = true
                    }
                )
            }
            showUserProfile.value -> {
                UserProfileView(
                    authViewModel = authViewModel,
                    onBack = {
                        showUserProfile.value = false
                        showMainMenu.value = true
                    }
                )
            }
            showLogin.value -> {
                LoginScreen(
                    authViewModel = authViewModel,
                    onLoginSuccess = {
                        showLogin.value = false
                        showUserProfile.value = true
                    }
                )
            }
        }
    }
}

@Composable
private fun AdminMainMenuView(
    isDeviceConnected: Boolean,
    onDeviceManagementClick: () -> Unit,
    onUserProfileClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        TopAppBar(
            title = { Text("Admin", color = Color.White) },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Device Management
            item {
                AdminMenuButton(
                    icon = Icons.Default.Smartphone,
                    title = "Device Management",
                    description = if (isDeviceConnected) 
                        "Device is connected" 
                    else 
                        "Connect to a device",
                    isActive = isDeviceConnected,
                    onClick = onDeviceManagementClick
                )
            }

            // User Profile
            item {
                AdminMenuButton(
                    icon = Icons.Default.Person,
                    title = "User Profile",
                    description = "Manage user profile",
                    isActive = false,
                    onClick = onUserProfileClick
                )
            }
        }
    }
}

@Composable
private fun AdminMenuButton(
    icon: ImageVector,
    title: String,
    description: String,
    isActive: Boolean,
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
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(32.dp)
            )

            Column(
                modifier = Modifier
                    .weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = title,
                    color = Color.White,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = description,
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            if (isActive) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = null,
                    tint = Color.Green,
                    modifier = Modifier.size(24.dp)
                )
            } else {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = Color.Red,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
}

@Composable
private fun DeviceManagementView(
    isDeviceConnected: Boolean,
    onBack: () -> Unit,
    onManualSelectClick: () -> Unit = {},
    onQRScanClick: () -> Unit = {},
    onConnectedDeviceClick: () -> Unit = {},
    onOTAUpdateClick: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        TopAppBar(
            title = { Text("Device Management", color = Color.White) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.Red)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White
            )
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (isDeviceConnected) {
                // Connected Device Options
                item {
                    DeviceMenuOption(
                        icon = Icons.Default.Smartphone,
                        title = "Connected Device",
                        subtitle = "Manage connection",
                        onClick = onConnectedDeviceClick
                    )
                }

                item {
                    DeviceMenuOption(
                        icon = Icons.Default.Info,
                        title = "OTA Update",
                        subtitle = "Check for and install system updates",
                        onClick = onOTAUpdateClick
                    )
                }
            } else {
                // Disconnected Device Options
                item {
                    DeviceMenuOption(
                        icon = Icons.Default.Smartphone,
                        title = "Manual Select",
                        subtitle = "Browse and select available devices",
                        onClick = onManualSelectClick
                    )
                }

                item {
                    DeviceMenuOption(
                        icon = Icons.Default.Info,
                        title = "Scan QR Code",
                        subtitle = "Scan device QR code",
                        onClick = onQRScanClick
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceMenuOption(
    icon: ImageVector,
    title: String,
    subtitle: String,
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
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(32.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                Text(
                    text = title,
                    color = Color.White,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = subtitle,
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = Color.Red,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
