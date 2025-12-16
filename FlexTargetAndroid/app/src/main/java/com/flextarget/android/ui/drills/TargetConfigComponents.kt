package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.ble.DiscoveredPeripheral
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData

@Composable
fun TargetConfigRow(
    config: DrillTargetsConfigData,
    availableDevices: List<NetworkDevice>,
    isDragging: Boolean,
    onDeviceClick: () -> Unit,
    onTypeClick: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .background(if (isDragging) Color.DarkGray else Color.Transparent),
        colors = CardDefaults.cardColors(containerColor = Color.DarkGray)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Sequence number
            Text(
                text = config.seqNo.toString(),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.width(32.dp)
            )

            // Drag handle
            Icon(
                Icons.Default.Menu,
                contentDescription = "Drag handle",
                tint = Color.Gray,
                modifier = Modifier.size(24.dp)
            )

            // Device selection
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Device",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onDeviceClick)
                        .background(Color.Black.copy(alpha = 0.3f))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (config.targetName.isEmpty()) "Select Device" else config.targetName,
                        color = if (config.targetName.isEmpty()) Color.Gray else Color.Red,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        Icons.Filled.ArrowDropDown,
                        contentDescription = "Select device",
                        tint = Color.Red
                    )
                }
            }

            // Link indicator
            Text(
                text = "•",
                color = Color.Gray,
                style = MaterialTheme.typography.bodyLarge
            )

            // Target type selection
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Type",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodySmall
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onTypeClick)
                        .background(Color.Black.copy(alpha = 0.3f))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Target type icon (placeholder - would need actual icons)
                    Icon(
                        Icons.Default.CheckCircle,
                        contentDescription = config.targetType,
                        tint = Color.White,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = config.targetType,
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    Icon(
                        Icons.Filled.ArrowDropDown,
                        contentDescription = "Select type",
                        tint = Color.White
                    )
                }
            }

            // Delete button
            IconButton(onClick = onDelete) {
                Icon(
                    Icons.Filled.Delete,
                    contentDescription = "Delete",
                    tint = Color.Red
                )
            }
        }
    }
}

@Composable
fun DevicePickerDialog(
    availableDevices: List<NetworkDevice>,
    selectedDevice: String,
    onDeviceSelected: (String) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Select Device") },
        text = {
            Column {
                availableDevices.forEach { device ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onDeviceSelected(device.name) }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = device.name,
                            color = Color.White,
                            modifier = Modifier.weight(1f)
                        )
                        if (selectedDevice == device.name) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = "Selected",
                                tint = Color.Red
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        containerColor = Color.Black,
        titleContentColor = Color.White,
        textContentColor = Color.White
    )
}

@Composable
fun TargetTypePickerDialog(
    targetTypes: List<String>,
    selectedType: String,
    onTypeSelected: (String) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Select Target Type") },
        text = {
            Column {
                targetTypes.forEach { type ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onTypeSelected(type) }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Target type icon (placeholder)
                        Icon(
                            Icons.Default.CheckCircle,
                            contentDescription = type,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = type,
                            color = Color.White,
                            modifier = Modifier.weight(1f)
                        )
                        if (selectedType == type) {
                            Icon(
                                Icons.Filled.Check,
                                contentDescription = "Selected",
                                tint = Color.Red
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        },
        containerColor = Color.Black,
        titleContentColor = Color.White,
        textContentColor = Color.White
    )
}