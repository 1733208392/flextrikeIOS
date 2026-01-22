package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.local.entity.DrillResultWithShots
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.DrillRepeatSummary
import com.flextarget.android.data.model.ShotData
import com.flextarget.android.ui.qr.QRScannerView
import com.flextarget.android.ui.ble.ConnectSmartTargetView
import com.google.gson.Gson

@Composable
fun DrillMainPageView(
    bleManager: BLEManager = BLEManager.shared,
    onShowDrillList: () -> Unit = {},
    onShowConnectView: () -> Unit = {},
    onShowInfo: () -> Unit = {},
    onShowQRScanner: () -> Unit = {},
    onDrillSelected: (List<com.flextarget.android.data.local.entity.DrillResultWithShots>) -> Unit = {}
) {
    var showConnectView by remember { mutableStateOf(false) }
    var showInfo by remember { mutableStateOf(false) }
    var showQRScanner by remember { mutableStateOf(false) }

    MainContent(
        bleManager = bleManager,
        onShowDrillList = onShowDrillList,
        onShowConnectView = { showConnectView = true },
        onShowInfo = { showInfo = true },
        onShowQRScanner = { showQRScanner = true },
        onDrillSelected = onDrillSelected
    )

    if (showConnectView) {
        ConnectSmartTargetView(
            bleManager = bleManager,
            onDismiss = { showConnectView = false },
            isAlreadyConnected = bleManager.isConnected
        )
    }

    if (showInfo) {
        // Placeholder for InformationPage
        AlertDialog(
            onDismissRequest = { showInfo = false },
            title = { Text(stringResource(R.string.information)) },
            text = { Text(stringResource(R.string.information_page_placeholder)) },
            confirmButton = {
                TextButton(onClick = { showInfo = false }) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }

    if (showQRScanner) {
        QRScannerView(
            onQRScanned = { scannedText ->
                // Set auto-connect target and show connect view
                bleManager.setAutoConnectTarget(scannedText)
                showQRScanner = false
                showConnectView = true
            },
            onDismiss = {
                showQRScanner = false
            }
        )
    }
}

@Composable
private fun MainContent(
    bleManager: BLEManager,
    onShowDrillList: () -> Unit,
    onShowConnectView: () -> Unit,
    onShowInfo: () -> Unit,
    onShowQRScanner: () -> Unit,
    onDrillSelected: (List<DrillResultWithShots>) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.statusBars),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            RecentTrainingView(
                modifier = Modifier
                    .padding(horizontal = 16.dp)
                    .padding(top = 80.dp), // Increased from 16.dp to 80.dp to account for BLE status toolbar
                onDrillSelected = onDrillSelected
            )

            // Menu Buttons
            Column(
                verticalArrangement = Arrangement.spacedBy(20.dp),
                modifier = Modifier.padding(top = 24.dp)
            ) {
                MainMenuButton(
                    icon = Icons.Default.PlayArrow,
                    text = "Drills",
                    color = Color.Red,
                    onClick = onShowDrillList
                )

                // Disabled IPSC button
                MainMenuButton(
                    icon = Icons.Default.Star,
                    text = "IPSC Questionaries",
                    color = Color.Gray,
                    enabled = false,
                    onClick = {}
                )

                // Disabled IDPA button
                MainMenuButton(
                    icon = Icons.Default.Settings,
                    text = "IDPA Questionaries",
                    color = Color.Gray,
                    enabled = false,
                    onClick = {}
                )
            }

            // Home Indicator
            Box(
                modifier = Modifier
                    .width(120.dp)
                    .height(6.dp)
                    .background(Color.White.copy(alpha = 0.7f), RoundedCornerShape(3.dp))
                    .padding(bottom = 12.dp)
            )
        }

        // Toolbar
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // Top toolbar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // BLE Connection Status
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .background(Color.Gray.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
                        .padding(vertical = 4.dp, horizontal = 12.dp)
                        .clickable {
                            if (bleManager.isConnected) {
                                onShowConnectView()
                            } else {
                                onShowQRScanner()
                            }
                        }
                ) {
                    // TODO: Add proper BLE connect/disconnect icons
                    Text(
                        text = if (bleManager.isConnected) "Connected" else "Disconnected",
                        color = Color.Gray,
                        fontSize = 12.sp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = bleManager.connectedPeripheralName ?: "Target",
                        color = Color.White,
                        fontSize = 14.sp
                    )
                }

                // Info Button
                IconButton(onClick = onShowInfo) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Info",
                        tint = Color.White
                    )
                }
            }
        }
    }
}

@Composable
private fun MainMenuButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
    color: Color,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .background(Color.Gray.copy(alpha = 0.3f), RoundedCornerShape(24.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(28.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = text,
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Normal
        )
        Spacer(modifier = Modifier.weight(1f))
        Icon(
            imageVector = Icons.Default.KeyboardArrowRight,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(20.dp)
        )
    }
}