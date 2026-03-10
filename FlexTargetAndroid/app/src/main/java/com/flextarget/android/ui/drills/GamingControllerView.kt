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
import com.flextarget.android.data.ble.AndroidBLEManager
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.ui.theme.ttNormFontFamily
import kotlinx.coroutines.launch
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GamingControllerView(
    drillSetup: DrillSetupEntity,
    bleManager: AndroidBLEManager,
    onGameEnd: () -> Void = {},
    onBack: () -> Unit
) {
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    var score by remember { mutableStateOf("0") }
    var hitCount by remember { mutableStateOf("0") }
    var missCount by remember { mutableStateOf("0") }
    var isGameStarted by remember { mutableStateOf(false) }
    var showResult by remember { mutableStateOf(false) }
    var touchpadScale by remember { mutableStateOf(1.0f) }
    
    val coroutineScope = rememberCoroutineScope()

    // Setup result listener
    LaunchedEffect(Unit) {
        bleManager.netlinkForwardMessage.collect { json ->
            try {
                val content = json.optJSONObject("content") ?: return@collect
                val game = content.optString("game")
                if (game == "clay pigeon") {
                    if (content.has("score")) score = content.optString("score", "0")
                    if (content.has("hit")) hitCount = content.optString("hit", "0")
                    if (content.has("miss")) missCount = content.optString("miss", "0")
                    
                    if (content.has("score")) {
                        showResult = true
                        isGameStarted = false
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun sendGameCommand(cmd: String, direction: String? = null) {
        // In Android, we need the device name from the targets
        // This is a simplified lookup assuming single target as per requirements
        val targetName = bleManager.networkDevices.value.firstOrNull()?.name ?: "Target"
        
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
        
        bleManager.sendMessage(message.toString())
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { },
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
                .padding(horizontal = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Title
            Text(
                "Clay Pigeon",
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = accentRed,
                fontFamily = ttNormFontFamily,
                modifier = Modifier.padding(top = 20.dp)
            )

            // Content Area
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.Center
            ) {
                if (!showResult) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        // Touchpad
                        Box(
                            modifier = Modifier
                                .size(280.dp)
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
                                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4.dp.toPx())
                                    )
                                }
                                .pointerInput(isGameStarted) {
                                    if (isGameStarted) {
                                        detectDragGestures(
                                            onDragStart = { touchpadScale = 0.95f },
                                            onDragEnd = { touchpadScale = 1.0f },
                                            onDragCancel = { touchpadScale = 1.0f },
                                            onDrag = { change, dragAmount ->
                                                change.consume()
                                                // Handle swipe direction detection on drag end 
                                                // Logic performed in onDragEnd for simplicity
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
                                                if (dragAmount.getDistance() > 30f) {
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
                                                    sendGameCommand("launch", direction)
                                                    // Consume gesture so it doesn't repeat immediately
                                                }
                                            }
                                        )
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                painter = painterResource(id = android.R.drawable.stat_sys_touch), // Placeholder icon
                                contentDescription = null,
                                modifier = Modifier.size(80.dp),
                                tint = accentRed.copy(alpha = 0.2f)
                            )
                            
                            // Visual direction hints
                            Box(modifier = Modifier.fillMaxSize().padding(40.dp)) {
                                Icon(painterResource(R.drawable.ic_arrow_up), null, Modifier.align(Alignment.TopCenter), accentRed.copy(alpha = 0.4f))
                                Icon(painterResource(R.drawable.ic_arrow_left), null, Modifier.align(Alignment.CenterStart), accentRed.copy(alpha = 0.4f))
                                Icon(painterResource(R.drawable.ic_arrow_right), null, Modifier.align(Alignment.CenterEnd), accentRed.copy(alpha = 0.4f))
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
                } else {
                    // Result Card
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(20.dp)
                    ) {
                        Text("Game Over", fontSize = 24.sp, color = Color.White)
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            ResultMetric("SCORE", score)
                            ResultMetric("HIT", hitCount, Color.Green)
                            ResultMetric("MISS", missCount, accentRed)
                        }
                        
                        Button(
                            onClick = { 
                                showResult = false
                                isGameStarted = true
                                sendGameCommand("start")
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = accentRed),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier.width(160.dp)
                        ) {
                            Icon(Icons.Default.Refresh, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text("Replay")
                        }
                    }
                }
            }

            // Bottom Buttons
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 30.dp),
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
                } else if (!showResult) {
                    Button(
                        onClick = { 
                            sendGameCommand("stop")
                        },
                        modifier = Modifier.weight(1f).height(56.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = accentRed),
                        shape = RoundedCornerShape(16.dp)
                    ) {
                        Text("Stop Game", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                } else {
                    Button(
                        onClick = { 
                            onGameEnd()
                            onBack()
                        },
                        modifier = Modifier.weight(1f).height(56.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Gray.copy(alpha = 0.3f)),
                        shape = RoundedCornerShape(16.dp)
                    ) {
                        Text("Done", color = Color.White, fontWeight = FontWeight.Bold)
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
