package com.flextarget.android.ui.ble

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.DiscoveredPeripheral

@Composable
fun ConnectSmartTargetView(
    bleManager: BLEManager = BLEManager.shared,
    onDismiss: () -> Unit
) {
    var selectedPeripheral by remember { mutableStateOf<DiscoveredPeripheral?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(16.dp)
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Connect Smart Target",
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )

            Button(
                onClick = onDismiss,
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
            ) {
                Text("Cancel", color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Connection status
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color.Gray.copy(alpha = 0.2f))
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val statusColor = when {
                    bleManager.isConnected -> Color.Green
                    bleManager.isScanning -> Color.Yellow
                    else -> Color.Red
                }

                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(statusColor, RoundedCornerShape(6.dp))
                )

                Spacer(modifier = Modifier.width(12.dp))

                Column {
                    Text(
                        text = when {
                            bleManager.isConnected -> "Connected"
                            bleManager.isScanning -> "Scanning..."
                            else -> "Disconnected"
                        },
                        color = Color.White,
                        fontWeight = FontWeight.Medium
                    )

                    bleManager.connectedPeripheral?.let { peripheral ->
                        Text(
                            text = peripheral.name,
                            color = Color.Gray,
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Scan/Stop button
        Button(
            onClick = {
                if (bleManager.isScanning) {
                    bleManager.stopScan()
                } else {
                    bleManager.startScan()
                }
            },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(
                containerColor = if (bleManager.isScanning) Color.Red else Color.Green
            )
        ) {
            Text(
                text = if (bleManager.isScanning) "Stop Scanning" else "Start Scanning",
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Discovered devices list
        Text(
            text = "Available Devices",
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium
        )

        Spacer(modifier = Modifier.height(12.dp))

        LazyColumn(
            modifier = Modifier.weight(1f)
        ) {
            items(bleManager.discoveredPeripherals) { peripheral ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.Gray.copy(alpha = 0.1f))
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = peripheral.name,
                                color = Color.White,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = peripheral.device.address,
                                color = Color.Gray,
                                fontSize = 12.sp
                            )
                        }

                        Button(
                            onClick = {
                                selectedPeripheral = peripheral
                                bleManager.connectToSelectedPeripheral(peripheral)
                            },
                            enabled = !bleManager.isConnected,
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Blue)
                        ) {
                            Text("Connect", color = Color.White)
                        }
                    }
                }
            }

            if (bleManager.discoveredPeripherals.isEmpty() && !bleManager.isScanning) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No devices found. Tap 'Start Scanning' to search for devices.",
                            color = Color.Gray,
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                    }
                }
            }
        }

        // Error message
        bleManager.error?.let { error ->
            Spacer(modifier = Modifier.height(16.dp))
            Card(
                colors = CardDefaults.cardColors(containerColor = Color.Red.copy(alpha = 0.2f))
            ) {
                Text(
                    text = error.message,
                    color = Color.Red,
                    modifier = Modifier.padding(16.dp)
                )
            }
        }
    }
}