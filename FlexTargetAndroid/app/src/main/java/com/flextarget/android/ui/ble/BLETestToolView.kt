package com.flextarget.android.ui.ble

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.BorderStroke
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.data.ble.BLEManager
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import androidx.compose.runtime.DisposableEffect

@Composable
fun BLETestToolView(
    bleManager: BLEManager = BLEManager.shared,
    onDismiss: () -> Unit
) {
    var commandInput by remember { mutableStateOf("") }
    var responseText by remember { mutableStateOf("") }
    var sendButtonEnabled by remember { mutableStateOf(true) }
    val responseScrollState = rememberScrollState()

    // Setup callback to capture responses
    DisposableEffect(Unit) {
        val testToolListener: (Map<String, Any>) -> Unit = { response ->
            // Add response to display
            val gson = GsonBuilder().setPrettyPrinting().create()
            val formattedResponse = gson.toJson(response)
            responseText = "Response: $formattedResponse\n\n$responseText"
        }
        
        bleManager.addNetlinkForwardListener(testToolListener)

        onDispose {
            // Remove listener on dispose
            bleManager.removeNetlinkForwardListener(testToolListener)
        }
    }

    fun sendCommand() {
        if (commandInput.trim().isEmpty()) {
            responseText = "Error: Command input is empty\n\n$responseText"
            return
        }

        // Validate JSON format
        try {
            val gson = Gson()
            gson.fromJson(commandInput, Map::class.java)
        } catch (e: Exception) {
            responseText = "Error: Invalid JSON format - ${e.message}\n\n$responseText"
            return
        }

        sendButtonEnabled = false
        responseText = "Sending: $commandInput\n\n$responseText"

        // Send the command
        bleManager.writeJSON(commandInput)

        // Re-enable button after a short delay
        bleManager.androidManager?.let { manager ->
            val isConnected = manager.isConnected
            if (isConnected) {
                responseText = "Command sent successfully\n\n$responseText"
            } else {
                responseText = "Error: BLE device not connected\n\n$responseText"
            }
        } ?: run {
            responseText = "Error: BLE Manager not initialized\n\n$responseText"
        }

        sendButtonEnabled = true
    }

    fun clearResponses() {
        responseText = ""
        commandInput = ""
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Title
            Text(
                text = "BLE Communication Test Tool",
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 8.dp)
            )

            // Connection status
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Status:",
                    color = Color.Gray,
                    fontSize = 14.sp
                )
                Text(
                    text = if (bleManager.isConnected) "Connected" else "Disconnected",
                    color = if (bleManager.isConnected) Color.Green else Color.Red,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Command input label
            Text(
                text = "Command (JSON):",
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )

            // Command input field
            OutlinedTextField(
                value = commandInput,
                onValueChange = { commandInput = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 100.dp, max = 150.dp),
                placeholder = { Text("Enter JSON command...", color = Color.Gray) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                    focusedBorderColor = Color.Red,
                    unfocusedBorderColor = Color.Gray,
                    cursorColor = Color.Red,
                    focusedPlaceholderColor = Color.Gray,
                    unfocusedPlaceholderColor = Color.DarkGray
                ),
                textStyle = androidx.compose.material3.LocalTextStyle.current.copy(
                    fontFamily = FontFamily.Monospace,
                    fontSize = 12.sp
                ),
                shape = RoundedCornerShape(8.dp)
            )

            // Send button
            Button(
                onClick = { sendCommand() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                enabled = sendButtonEnabled && bleManager.isConnected,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Red,
                    disabledContainerColor = Color.Gray
                ),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(
                    text = "Send",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            // Response label
            Text(
                text = "Response:",
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold
            )

            // Response display area
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                color = Color(0x1F, 0x1F, 0x1F),
                shape = RoundedCornerShape(8.dp),
                border = BorderStroke(1.dp, Color.Gray)
            ) {
                Text(
                    text = if (responseText.isEmpty()) "Responses will appear here..." else responseText,
                    color = if (responseText.isEmpty()) Color.Gray else Color.White,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier
                        .fillMaxWidth()
                        .verticalScroll(responseScrollState)
                        .padding(12.dp)
                )
            }

            // Clear button
            Button(
                onClick = { clearResponses() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF, 0x66, 0x00)),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text(
                    text = "Clear",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
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
    }
}
