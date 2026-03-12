package com.flextarget.android.ui.drills

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.local.entity.DrillResultEntity
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.repository.DrillResultRepository
import com.flextarget.android.ui.theme.ttNormFontFamily
import com.flextarget.android.R
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.util.Date
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GamingControllerView(
    drillSetup: DrillSetupEntity,
    bleManager: AndroidBLEManager,
    onGameEnd: () -> Unit = {},
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val drillResultRepository = remember { DrillResultRepository.getInstance(context) }
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    var score by remember { mutableStateOf("0") }
    var hitCount by remember { mutableStateOf("0") }
    var missCount by remember { mutableStateOf("0") }
    var isGameStarted by remember { mutableStateOf(false) }
    var showResult by remember { mutableStateOf(false) }
    var touchpadScale by remember { mutableStateOf(1.0f) }
    var lastLaunchTime by remember { mutableStateOf(0L) }
    var isStopping by remember { mutableStateOf(false) }
    
    val coroutineScope = rememberCoroutineScope()

    fun saveGameResult() {
        coroutineScope.launch {
            val stats = JSONObject().apply {
                put("hits", hitCount.toIntOrNull() ?: 0)
                put("misses", missCount.toIntOrNull() ?: 0)
            }
            
            val result = DrillResultEntity(
                id = UUID.randomUUID(),
                date = Date(),
                drillId = drillSetup.id,
                drillSetupId = drillSetup.id,
                sessionId = UUID.randomUUID(),
                totalTime = 0.0,
                adjustedHitZones = stats.toString()
            )
            
            withContext(Dispatchers.IO) {
                drillResultRepository.insertDrillResult(result)
            }
            println("[GamingControllerView] Result saved to database")
        }
    }

    // Setup result listener
    LaunchedEffect(Unit) {
        bleManager.netlinkForwardMessage.collect { json ->
            try {
                // The JSON structure is {"type":"forward","content":{"game":"clay pigeon",...}}
                val content = json.optJSONObject("content") ?: return@collect
                val game = content.optString("game")
                if (game == "clay pigeon") {
                    // Check if it has a score or hit/miss, indicating a result message
                    if (content.has("score") || content.has("hit") || content.has("miss")) {
                        score = content.optString("score", "0")
                        hitCount = content.optString("hit", "0")
                        missCount = content.optString("miss", "0")
                        
                        // If we are already in the process of stopping, show result immediately or after short delay
                        if (isStopping || content.optString("cmd") == "stop" || content.has("score")) {
                            if (isGameStarted) {
                                saveGameResult()
                            }
                            delay(500) // Small grace period to ensure command-response sequence is clear
                            showResult = true
                            isGameStarted = false
                            isStopping = false
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun sendGameCommand(cmd: String, direction: String? = null) {
        if (cmd == "start") {
            hitCount = "0"
            missCount = "0"
            score = "0"
        }
        // In Android, we need the device name from the targets
        // This is a simplified lookup assuming single target as per requirements
        // Accessing networkDevices from BLEManager.shared since AndroidBLEManager might not have it directly
        val targetName = com.flextarget.android.data.ble.BLEManager.shared.networkDevices.firstOrNull()?.name ?: "Target"
        
        val content = JSONObject().apply {
            put("game", "clay pigeon")
            put("cmd", cmd)
            direction?.let { put("direct", it) }
        }
        
        val message = JSONObject().apply {
            put("action", "netlink_forward")
            put("dest", targetName)
            put("content", content)
        }
        
        println("[GamingControllerView] Sending command: $cmd, direction: $direction, message: $message")
        bleManager.sendMessage(message.toString())
    }

    if (showResult) {
        GameDrillResultView(
            gameName = "Clay Pigeon",
            score = score,
            hits = hitCount,
            misses = missCount,
            onReplay = {
                showResult = false
                isGameStarted = true
                sendGameCommand("start")
            },
            onDone = {
                onBack()
            }
        )
    } else {
        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                title = {
                    Text(
                        "Clay Pigeon",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = accentRed,
                        fontFamily = ttNormFontFamily
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = accentRed)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Black)
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Content Area
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    // Touchpad
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(0.9f)
                            .aspectRatio(1f)
                            .scale(touchpadScale)
                            .background(
                                Brush.linearGradient(
                                    colors = listOf(Color.Gray.copy(alpha = 0.3f), Color.Gray.copy(alpha = 0.1f))
                                ),
                                shape = CircleShape
                            )
                            .drawBehind {
                                drawCircle(
                                    color = accentRed.copy(alpha = 0.5f),
                                    radius = size.minDimension / 2,
                                    style = Stroke(width = 4.dp.toPx())
                                )
                            }
                            .pointerInput(isGameStarted) {
                                if (isGameStarted) {
                                    detectDragGestures(
                                        onDragStart = { touchpadScale = 0.95f },
                                        onDragEnd = { touchpadScale = 1.0f },
                                        onDragCancel = { touchpadScale = 1.0f },
                                        onDrag = { change, _ ->
                                            change.consume()
                                        }
                                    )
                                }
                            }
                            // Alternative simple swipe detection for the requirement
                            .pointerInput(isGameStarted) {
                                if (isGameStarted) {
                                    detectDragGestures(
                                        onDragStart = { touchpadScale = 0.95f },
                                        onDragEnd = { 
                                            touchpadScale = 1.0f
                                        },
                                        onDrag = { change, dragAmount -> 
                                            change.consume()
                                            // Simplified: immediately respond to significant drag
                                            // Add debouncing to prevent multiple rapid sends
                                            val currentTime = System.currentTimeMillis()
                                            if (dragAmount.getDistance() > 30f && (currentTime - lastLaunchTime > 800)) {
                                                lastLaunchTime = currentTime
                                                val x = dragAmount.x
                                                val y = dragAmount.y
                                                var direction = "center"
                                                if (y < -20f) {
                                                    direction = if (x > 20f) "right" else if (x < -20f) "left" else "center"
                                                } else if (x > 40f) {
                                                    direction = "right"
                                                } else if (x < -40f) {
                                                    direction = "left"
                                                }
                                                println("[GamingControllerView] Swipe detected! distance=${dragAmount.getDistance()}, direction=$direction")
                                                sendGameCommand("launch", direction)
                                            }
                                        }
                                    )
                                }
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.KeyboardArrowUp,
                            contentDescription = null,
                            modifier = Modifier.size(80.dp),
                            tint = accentRed.copy(alpha = 0.2f)
                        )
                        
                        // Visual direction hints
                        Box(modifier = Modifier.fillMaxSize().padding(40.dp)) {
                            Icon(Icons.Default.KeyboardArrowUp, null, Modifier.align(Alignment.TopCenter), accentRed.copy(alpha = 0.4f))
                            Icon(Icons.Default.KeyboardArrowLeft, null, Modifier.align(Alignment.CenterStart), accentRed.copy(alpha = 0.4f))
                            Icon(Icons.Default.KeyboardArrowRight, null, Modifier.align(Alignment.CenterEnd), accentRed.copy(alpha = 0.4f))
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(30.dp))
                    
                    Text(
                        "Swipe to Launch",
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Bottom Buttons
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 80.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                if (!isGameStarted) {
                    Button(
                        onClick = { 
                            isGameStarted = true
                            showResult = false
                            sendGameCommand("start")
                        },
                        modifier = Modifier.weight(1f).height(56.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Green),
                        shape = RoundedCornerShape(16.dp)
                    ) {
                        Text("Start Game", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                } else {
                    Button(
                        onClick = { 
                            isStopping = true
                            sendGameCommand("stop")
                            // Give it a grace period to receive the result via BLE
                            coroutineScope.launch {
                                delay(2000) 
                                if (isStopping) {
                                    // If we haven't received the result yet, FORCE show anyway or handle timeout
                                    showResult = true
                                    isGameStarted = false
                                    isStopping = false
                                }
                            }
                        },
                        enabled = !isStopping,
                        modifier = Modifier.weight(1f).height(56.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = accentRed),
                        shape = RoundedCornerShape(16.dp)
                    ) {
                        Text("Stop Game", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}
}

@Composable
fun ResultMetric(label: String, value: String, color: Color = Color.White) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, fontSize = 12.sp, color = Color.Gray)
        Text(value, fontSize = 36.sp, fontWeight = FontWeight.Black, color = color)
    }
}
