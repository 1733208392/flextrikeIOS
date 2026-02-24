package com.flextarget.android.ui.admin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Smartphone
import androidx.compose.material.icons.filled.SignalCellularAlt
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary

@Composable
fun ManualDeviceSelectionView(
    bleManager: BLEManager = BLEManager.shared,
    onBack: () -> Unit,
    onDeviceSelected: (String) -> Unit
) {
    // Start scanning when view is opened
    LaunchedEffect(Unit) {
        bleManager.startScan()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        CenterAlignedTopAppBar(
            title = { Text(stringResource(R.string.available_devices), color = md_theme_dark_onPrimary) },
            navigationIcon = {
                IconButton(onClick = {
                    bleManager.stopScan()
                    onBack()
                }) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = md_theme_dark_onPrimary)
                }
            },
            actions = {
                IconButton(
                    onClick = { 
                        if (bleManager.isScanning) {
                            bleManager.stopScan()
                        } else {
                            bleManager.startScan()
                        }
                    }
                ) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = "Scan",
                        tint = md_theme_dark_onPrimary)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
            )
        )

        if (bleManager.discoveredPeripherals.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Smartphone,
                        contentDescription = null,
                        tint = Color.Gray,
                        modifier = Modifier.size(64.dp)
                    )
                    Text(
                        if (bleManager.isScanning) stringResource(R.string.scanning) else stringResource(R.string.no_devices_found),
                        color = Color.Gray,
                        style = MaterialTheme.typography.bodyLarge
                    )
                    Button(
                        onClick = { bleManager.startScan() },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(stringResource(R.string.scan_again))
                    }
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(bleManager.discoveredPeripherals) { peripheral ->
                    DeviceListItem(
                        name = peripheral.name,
                        address = peripheral.device.address,
                        onClick = {
                            bleManager.connectToSelectedPeripheral(peripheral)
                            onDeviceSelected(peripheral.name)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun DeviceListItem(
    name: String,
    address: String,
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
                imageVector = Icons.Default.Smartphone,
                contentDescription = null,
                tint = md_theme_dark_onPrimary,
                modifier = Modifier.size(40.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = name.replace("GR-WOLF ET", "").trim().uppercase(),
                    color = md_theme_dark_onPrimary,
                    style = MaterialTheme.typography.bodyLarge,
                    // fontWeight = FontWeight.Bold
                )
                Text(
                    text = address,
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}
