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
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.flextarget.android.data.ble.DiscoveredPeripheral
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData

private fun getIconForTargetType(type: String): String {
    return when (type) {
        "hostage" -> "hostage.svg"
        "ipsc" -> "ipsc.svg"
        "special_1" -> "ipsc-black-1.svg"
        "special_2" -> "ipsc-black-2.svg"
        "paddle" -> "ipsc-paddle.svg"
        "popper" -> "ipsc-popper.svg"
        "rotation" -> "rotation.svg"
        "idpa" -> "idpa.svg"
        "idpa_ns" -> "idpa-ns.svg"
        "idpa_black_1" -> "idpa-hard-cover-1.svg"
        "idpa_black_2" -> "idpa-hard-cover-2.svg"
        "cqb_front" -> "cqb_front.svg"
        "cqb_hostage" -> "cqb_hostoage.svg"
        "cqb_swing" -> "cqb_swing.svg"
        "disguised_enemy" -> "disguise_enemy.svg"
        else -> "ipsc.svg" // default icon
    }
}

@Composable
fun getDisplayNameForTargetType(type: String): String {
    return stringResource(
        id = when (type) {
            "hostage" -> R.string.hostage
            "ipsc" -> R.string.ipsc
            "special_1" -> R.string.special_1
            "special_2" -> R.string.special_2
            "paddle" -> R.string.paddle
            "popper" -> R.string.popper
            "rotation" -> R.string.rotation
            "idpa" -> R.string.idpa
            "idpa_ns" -> R.string.idpa_ns
            "idpa_black_1" -> R.string.idpa_black_1
            "idpa_black_2" -> R.string.idpa_black_2
            "cqb_front" -> R.string.cqb_front
            "cqb_hostage" -> R.string.cqb_hostage
            "cqb_swing" -> R.string.cqb_swing
            "disguised_enemy" -> R.string.disguised_enemy
            else -> R.string.ipsc // default
        }
    )
}

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
                    text = stringResource(R.string.device),
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
                        text = if (config.targetName.isEmpty()) stringResource(R.string.select_device) else config.targetName,
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
                    text = stringResource(R.string.type),
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
                    // Target type icon
                    AsyncImage(
                        model = "file:///android_asset/${getIconForTargetType(config.targetType)}",
                        contentDescription = config.targetType,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = getDisplayNameForTargetType(config.targetType),
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
        title = { Text(stringResource(R.string.select_device)) },
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
                Text(stringResource(R.string.cancel))
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
        title = { Text(stringResource(R.string.select_target_type)) },
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
                        // Target type icon
                        AsyncImage(
                            model = "file:///android_asset/${getIconForTargetType(type)}",
                            contentDescription = type,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Text(
                            text = getDisplayNameForTargetType(type),
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
                Text(stringResource(R.string.cancel))
            }
        },
        containerColor = Color.Black,
        titleContentColor = Color.White,
        textContentColor = Color.White
    )
}