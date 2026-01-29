package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.DiscoveredPeripheral
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import org.burnoutcrew.reorderable.ReorderableItem
import org.burnoutcrew.reorderable.ReorderableLazyListState
import org.burnoutcrew.reorderable.reorderable
import org.burnoutcrew.reorderable.rememberReorderableLazyListState
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetConfigListView(
    bleManager: BLEManager,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onAddTarget: () -> Unit,
    onDeleteTarget: (Int) -> Unit,
    onUpdateTargetDevice: (Int, String) -> Unit,
    onUpdateTargetType: (Int, String) -> Unit,
    onDone: () -> Unit,
    onBack: () -> Unit
) {
    var showMaxTargetsAlert by remember { mutableStateOf(false) }
    var showDevicePicker by remember { mutableStateOf<DrillTargetsConfigData?>(null) }
    var showTypePicker by remember { mutableStateOf<DrillTargetsConfigData?>(null) }

    // Query device list on appear
    LaunchedEffect(Unit) {
        queryDeviceList(bleManager)
    }

    // Auto-add targets from device list
    LaunchedEffect(bleManager.networkDevices, bleManager.lastDeviceListUpdate) {
        if (bleManager.networkDevices.isNotEmpty()) {
            addAllAvailableTargets(bleManager.networkDevices, targetConfigs, drillMode, onAddTarget)
        }
    }

    // val reorderableState = rememberReorderableLazyListState(
    //     onMove = { from, to ->
    //         targetConfigs.apply {
    //             add(to.index, removeAt(from.index))
    //             // Update sequence numbers
    //             forEachIndexed { index, config ->
    //                 this[index] = config.copy(seqNo = index + 1)
    //             }
    //         }
    //     }
    // )

    val maxTargets = bleManager.networkDevices.size
    val canAddMore = targetConfigs.size < maxTargets

    // Content without Scaffold since navigation is handled at parent level
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // List of targets
            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                itemsIndexed(targetConfigs) { index, config ->
                    TargetConfigRow(
                        config = config,
                        availableDevices = getAvailableDevices(bleManager.networkDevices, targetConfigs, config),
                        isDragging = false,
                        onDeviceClick = { showDevicePicker = config },
                        onTypeClick = { showTypePicker = config },
                        onDelete = { onDeleteTarget(index) }
                    )
                }
            }

            // Save Button
            Button(
                onClick = onDone,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
            ) {
                Text(stringResource(R.string.save), color = Color.White)
            }
        }
    }

    // Max targets alert
    if (showMaxTargetsAlert) {
        AlertDialog(
            onDismissRequest = { showMaxTargetsAlert = false },
            title = { Text(stringResource(R.string.maximum_targets_reached)) },
            text = { Text(stringResource(R.string.max_targets_message, maxTargets, targetConfigs.size)) },
            confirmButton = {
                TextButton(onClick = { showMaxTargetsAlert = false }) {
                    Text(stringResource(R.string.ok))
                }
            }
        )
    }

    // Device picker
    showDevicePicker?.let { config ->
        DevicePickerDialog(
            availableDevices = getAvailableDevices(bleManager.networkDevices, targetConfigs, config),
            selectedDevice = config.targetName,
            onDeviceSelected = { deviceName ->
                val configIndex = targetConfigs.indexOfFirst { it.id == config.id }
                if (configIndex != -1) {
                    onUpdateTargetDevice(configIndex, deviceName)
                }
                showDevicePicker = null
            },
            onDismiss = { showDevicePicker = null }
        )
    }

    // Type picker
    showTypePicker?.let { config ->
        TargetTypePickerDialog(
            targetTypes = DrillTargetsConfigData.getTargetTypesForDrillMode(drillMode),
            selectedType = config.targetType,
            onTypeSelected = { type ->
                val configIndex = targetConfigs.indexOfFirst { it.id == config.id }
                if (configIndex != -1) {
                    onUpdateTargetType(configIndex, type)
                }
                showTypePicker = null
            },
            onDismiss = { showTypePicker = null }
        )
    }
}

private fun queryDeviceList(bleManager: BLEManager) {
    if (!bleManager.isConnected) {
        println("BLE not connected, cannot query device list")
        return
    }

    val command = mapOf("action" to "netlink_query_device_list")
    val jsonString = JSONObject(command).toString()

    println("Query message length: ${jsonString.toByteArray().size}")
    bleManager.writeJSON(jsonString)
    println("Sent netlink_query_device_list command: $jsonString")
}

private fun addAllAvailableTargets(
    networkDevices: List<NetworkDevice>,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onAddTarget: () -> Unit
) {
    val currentDeviceNames = targetConfigs.map { it.targetName }.toSet()
    val availableDevices = networkDevices.filter { !currentDeviceNames.contains(it.name) }
    
    // Add each available device as a target
    availableDevices.forEach { _ ->
        onAddTarget()
    }
}

private fun getAvailableDevices(
    networkDevices: List<NetworkDevice>,
    targetConfigs: List<DrillTargetsConfigData>,
    currentConfig: DrillTargetsConfigData
): List<NetworkDevice> {
    return networkDevices.filter { device ->
        !targetConfigs.any { config ->
            config.targetName == device.name && config.id != currentConfig.id
        }
    }
}