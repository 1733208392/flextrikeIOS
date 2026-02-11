package com.flextarget.android.ui.ble

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.DiscoveredPeripheral

/**
 * A Compose dialog for selecting a BLE device from a list.
 * Shows available discovered peripherals with a single-selection option.
 */
@Composable
fun MultiDevicePickerDialog(
    bleManager: BLEManager,
    onDismiss: () -> Unit
) {
    var selectedPeripheral by remember { mutableStateOf<DiscoveredPeripheral?>(null) }
    val discoveredPeripherals = bleManager.discoveredPeripherals

    if (discoveredPeripherals.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = {
                Text(text = "Select Device")
            },
            text = {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 300.dp)
                ) {
                    items(discoveredPeripherals) { peripheral ->
                        DeviceItem(
                            peripheral = peripheral,
                            isSelected = selectedPeripheral?.id == peripheral.id,
                            onSelected = {
                                selectedPeripheral = peripheral
                            }
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        selectedPeripheral?.let { peripheral ->
                            // Connect to selected peripheral
                            bleManager.connectToSelectedPeripheral(peripheral)
                        }
                        onDismiss()
                    },
                    enabled = selectedPeripheral != null
                ) {
                    Text("Connect")
                }
            },
            dismissButton = {
                Button(
                    onClick = onDismiss
                ) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun DeviceItem(
    peripheral: DiscoveredPeripheral,
    isSelected: Boolean,
    onSelected: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelected)
            .background(
                if (isSelected) MaterialTheme.colorScheme.primaryContainer
                else Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RadioButton(
            selected = isSelected,
            onClick = onSelected,
            modifier = Modifier.padding(end = 12.dp)
        )
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = peripheral.name,
                style = MaterialTheme.typography.bodyLarge
            )
            Text(
                text = peripheral.id.toString(),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
