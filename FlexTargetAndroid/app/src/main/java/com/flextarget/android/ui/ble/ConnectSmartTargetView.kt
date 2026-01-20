package com.flextarget.android.ui.ble

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.DiscoveredPeripheral
import com.flextarget.android.ui.imagecrop.ImageCropViewV2
import kotlinx.coroutines.delay

@Composable
fun ConnectSmartTargetView(
    bleManager: BLEManager = BLEManager.shared,
    onDismiss: () -> Unit,
    targetPeripheralName: String? = null,
    isAlreadyConnected: Boolean = false,
    onConnected: (() -> Unit)? = null
) {
    var statusText by remember { mutableStateOf("CONNECTING") }
    var showReconnect by remember { mutableStateOf(false) }
    var showProgress by remember { mutableStateOf(false) }
    var selectedPeripheral by remember { mutableStateOf<DiscoveredPeripheral?>(null) }
    var activeTargetName by remember { mutableStateOf<String?>(null) }
    var showImageCrop by remember { mutableStateOf(false) }
    var showBLETestTool by remember { mutableStateOf(false) }

    fun goToMain() {
        onConnected?.invoke() ?: onDismiss()
    }

    fun handleReconnect() {
        statusText = "Trying to connect..."
        showReconnect = false
        selectedPeripheral = null
        bleManager.startScan()
        showProgress = true
    }

    fun connectToSelectedPeripheral(peripheral: DiscoveredPeripheral) {
        selectedPeripheral = peripheral
        statusText = "Trying to connect..."
        showProgress = true

        bleManager.connectToSelectedPeripheral(peripheral)
    }

    // Handle initial state
    LaunchedEffect(Unit) {
        if (isAlreadyConnected) {
            statusText = "Target Connected"
        } else {
            // If a target peripheral name was passed in, begin scanning
            if (targetPeripheralName != null) {
                activeTargetName = targetPeripheralName
                statusText = "Trying to connect..."
                showReconnect = false
                selectedPeripheral = null
                bleManager.startScan()
                showProgress = true
                statusText = "Scanning for $targetPeripheralName"
            } else {
                statusText = "Ready to scan"
                showProgress = false
            }
        }
    }

    var hasHandledInitialConnection by remember { mutableStateOf(false) }

    // Handle connection state changes
    LaunchedEffect(bleManager.isConnected) {
        if (bleManager.isConnected && !hasHandledInitialConnection) {
            hasHandledInitialConnection = true
            if (!isAlreadyConnected) {
                statusText = "Connected"
                showReconnect = false
                showProgress = false
                goToMain()
            }
        }
    }

    // Handle scanning logic
    LaunchedEffect(bleManager.isScanning, activeTargetName) {
        if (bleManager.isScanning && activeTargetName != null) {
            delay(2000) // 2 second delay to allow BLE to power on
            if (bleManager.isScanning) {
                val target = activeTargetName
                if (target != null) {
                    val match = bleManager.discoveredPeripherals.find { it.name == target }
                    if (match != null) {
                        bleManager.stopScan()
                        connectToSelectedPeripheral(match)
                    } else {
                        // Target not found
                        bleManager.stopScan()
                        statusText = "Target not found"
                        showReconnect = true
                        showProgress = false
                    }
                } else if (bleManager.discoveredPeripherals.isEmpty()) {
                    bleManager.stopScan()
                    statusText = "No targets found"
                    showReconnect = true
                    showProgress = false
                }
            }
        }
    }

    // Handle connection timeout
    LaunchedEffect(selectedPeripheral) {
        selectedPeripheral?.let { peripheral ->
            delay(10000)
            if (!bleManager.isConnected && selectedPeripheral == peripheral) {
                bleManager.disconnect()
                statusText = "Bluetooth service not found"
                showReconnect = true
                showProgress = false
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        val configuration = LocalConfiguration.current
        val iconHeight = configuration.screenHeightDp.dp / 3

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Visual Target Frame (using SVG icon)
            AsyncImage(
                model = "file:///android_asset/smart-target-icon.svg",
                contentDescription = "Smart Target Icon",
                modifier = Modifier
                    .height(iconHeight)
                    .padding(top = 20.dp),
                contentScale = ContentScale.Fit
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Status text with progress indicator
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = statusText,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center
                    )

                    if (showProgress) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    }
                }

                // Reconnect button
                if (showReconnect) {
                    Button(
                        onClick = { handleReconnect() },
                        modifier = Modifier
                            .fillMaxWidth(0.75f)
                            .height(44.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "Reconnect",
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                // Connected state buttons
                if (isAlreadyConnected) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        Button(
                            onClick = {
                                bleManager.disconnect()
                                onDismiss()
                            },
                            modifier = Modifier
                                .fillMaxWidth(0.75f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "Disconnect",
                                color = Color.White,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }

                        // Image Transfer button
                        Button(
                            onClick = {
                                showImageCrop = true
                            },
                            modifier = Modifier
                                .fillMaxWidth(0.75f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Blue),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "My Target",
                                color = Color.White,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }

                        // BLE Test Tool button
                        Button(
                            onClick = {
                                showBLETestTool = true
                            },
                            modifier = Modifier
                                .fillMaxWidth(0.75f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF, 0x99, 0x00)),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "BLE Test Tool",
                                color = Color.White,
                                fontSize = 20.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
        }

        // Close button (top right)
        IconButton(
            onClick = onDismiss,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(20.dp)
                .size(44.dp)
                .background(Color.White.copy(alpha = 0.2f), CircleShape)
        ) {
            Text(
                text = "✕",
                color = Color.White,
                fontSize = 20.sp
            )
        }

        // Error alert
        bleManager.error?.let { error ->
            AlertDialog(
                onDismissRequest = { /* Handle dismiss */ },
                title = { Text("Error") },
                text = { Text(error.message ?: "Unknown error occurred") },
                confirmButton = {
                    TextButton(onClick = { /* Handle OK */ }) {
                        Text("OK")
                    }
                }
            )
        }

        // Image Crop View
        if (showImageCrop) {
            ImageCropViewV2(
                onDismiss = { showImageCrop = false }
            )
        }

        // BLE Test Tool View
        if (showBLETestTool) {
            BLETestToolView(
                onDismiss = { showBLETestTool = false }
            )
        }
    }
}