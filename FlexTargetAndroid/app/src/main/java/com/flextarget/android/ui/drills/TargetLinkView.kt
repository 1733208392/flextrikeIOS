package com.flextarget.android.ui.drills

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary

/**
 * TargetLinkView - Multi-target grid assignment view for network drills.
 * Displays a 3x4 grid of connected devices with snake-pattern sequencing.
 * Equivalent to iOS TargetLinkView.swift
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetLinkView(
    bleManager: BLEManager,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onUpdateTargetConfigs: (List<DrillTargetsConfigData>) -> Unit,
    onNavigateToConfig: (String) -> Unit,
    onBack: () -> Unit
) {
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    val deviceList = bleManager.networkDevices
    
    var localConfigs by remember(targetConfigs) {
        mutableStateOf(targetConfigs)
    }
    
    // Initialize target configs on first appearance
    LaunchedEffect(deviceList, drillMode) {
        if (localConfigs.isEmpty() && deviceList.isNotEmpty()) {
            localConfigs = initializeTargetConfigs(deviceList, drillMode)
            onUpdateTargetConfigs(localConfigs)
        }
    }
    
    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.target_link),
                        color = accentRed,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = accentRed
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = Color.Black
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
        ) {
            // Target grid with connection canvas (LazyVerticalGrid handles scrolling)
            TargetGridContent(
                deviceList = deviceList,
                targetConfigs = localConfigs,
                drillMode = drillMode,
                accentColor = accentRed,
                onDeviceSelected = { deviceName ->
                    // Navigation to TargetConfigListViewV2 happens in the parent
                    onNavigateToConfig(deviceName)
                }
            )
        }
    }
}

@Composable
private fun TargetGridContent(
    deviceList: List<NetworkDevice>,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    accentColor: Color,
    onDeviceSelected: (String) -> Unit
) {
    val gridColumns = 3
    val gridRows = 4
    val cellCount = gridColumns * gridRows
    
    val rectangleHeight = 150.dp
    val rectangleWidth = rectangleHeight * 9f / 16f // 9x16 aspect ratio
    val horizontalSpacing = 24.dp
    val verticalSpacing = 40.dp
    
    // Store positions of rectangles for drawing lines
    var cellPositions by remember { mutableStateOf<Map<Int, Offset>>(emptyMap()) }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Connection lines canvas (drawn behind the grid, doesn't affect layout)
        Canvas(
            modifier = Modifier
                .matchParentSize()
        ) {
            drawConnectionLines(
                cellPositions = cellPositions,
                deviceListSize = deviceList.size,
                accentColor = accentColor,
                gridColumns = gridColumns
                )
        }
        
        // Grid of target rectangles (scrollable)
        LazyVerticalGrid(
            columns = GridCells.Fixed(gridColumns),
            horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
            verticalArrangement = Arrangement.spacedBy(verticalSpacing),
            modifier = Modifier
                .fillMaxSize()
        ) {
            items(cellCount) { index ->
                val device = if (index < deviceList.size) deviceList[index] else null
                val config = device?.let { dev ->
                    targetConfigs.firstOrNull { it.targetName == dev.name }
                }
                
                TargetRectangle(
                    device = device,
                    config = config,
                    width = rectangleWidth,
                    height = rectangleHeight,
                    accentColor = accentColor,
                    onSelected = {
                        device?.let { onDeviceSelected(it.name) }
                    },
                    onPositionChanged = { centerOffset ->
                        cellPositions = cellPositions.toMutableMap().apply {
                            this[index] = centerOffset
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun TargetRectangle(
    device: NetworkDevice?,
    config: DrillTargetsConfigData?,
    width: Dp,
    height: Dp,
    accentColor: Color,
    onSelected: () -> Unit,
    onPositionChanged: (Offset) -> Unit
) {
    Box(
        modifier = Modifier
            .width(width)
            .height(height)
            .border(width = 6.dp, color = if (device != null) accentColor else Color.Gray.copy(alpha = 0.5f))
            .background(Color.Gray.copy(alpha = 0.1f))
            .clickable(enabled = device != null) { onSelected() }
            .onGloballyPositioned { coordinates ->
                val center = Offset(
                    x = coordinates.positionInParent().x + coordinates.size.width / 2f,
                    y = coordinates.positionInParent().y + coordinates.size.height / 2f
                )
                onPositionChanged(center)
            },
        contentAlignment = Alignment.Center
    ) {
        if (device != null) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
                modifier = Modifier.fillMaxSize()
            ) {
                // Target icon/image
                if (config != null && config.targetType.isNotEmpty() && config.targetType != "[]") {
                    val iconRes = getTargetIconResource(config.primaryTargetType())
                    if (iconRes != 0) {
                        AsyncImage(
                            model = iconRes,
                            contentDescription = config.targetType,
                            modifier = Modifier
                                .fillMaxWidth(0.6f)
                                .aspectRatio(1f),
                            contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                            error = painterResource(R.drawable.ic_launcher_foreground)
                        )
                    } else {
                        Icon(
                            painter = painterResource(R.drawable.ic_launcher_foreground),
                            contentDescription = "Target",
                            modifier = Modifier
                                .fillMaxWidth(0.4f)
                                .aspectRatio(1f),
                            tint = Color.Gray
                        )
                    }
                } else {
                    // Use IPSC target as default
                    val defaultIconRes = getTargetIconResource("ipsc")
                    if (defaultIconRes != 0) {
                        AsyncImage(
                            model = defaultIconRes,
                            contentDescription = "IPSC Target",
                            modifier = Modifier
                                .fillMaxWidth(0.6f)
                                .aspectRatio(1f),
                            contentScale = androidx.compose.ui.layout.ContentScale.Fit,
                            error = painterResource(R.drawable.ic_launcher_foreground)
                        )
                    } else {
                        Icon(
                            painter = painterResource(R.drawable.ic_launcher_foreground),
                            contentDescription = "Default Target",
                            modifier = Modifier
                                .fillMaxWidth(0.4f)
                                .aspectRatio(1f),
                            tint = Color.Gray
                        )
                    }
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                // Device name
                Text(
                    text = device.name,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = accentColor,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 4.dp)
                )
            }
        }
    }
}

private fun DrawScope.drawConnectionLines(
    cellPositions: Map<Int, Offset>,
    deviceListSize: Int,
    accentColor: Color,
    gridColumns: Int
) {
    val dotRadius = 6f
    val maxCellIndex = 12 // 3x4 grid = 12 cells total
    
    // Snake pattern for 3x4 grid: 0→1→2, 2↓5, 5→4→3, 3↓6, 6→7→8, 8↓11, 11→10→9
    val snakePattern = listOf(
        0 to 1, 1 to 2, // Row 0: 0→1→2 (left to right)
        2 to 5, // Transition: 2↓5 (down)
        5 to 4, 4 to 3, // Row 1: 5→4→3 (right to left)
        3 to 6, // Transition: 3↓6 (down)
        6 to 7, 7 to 8, // Row 2: 6→7→8 (left to right)
        8 to 11, // Transition: 8↓11 (down)
        11 to 10, 10 to 9 // Row 3: 11→10→9 (right to left)
    )
    
    for ((fromIndex, toIndex) in snakePattern) {
        // Skip if indices are beyond grid
        if (fromIndex >= maxCellIndex || toIndex >= maxCellIndex) continue
        if (fromIndex !in cellPositions || toIndex !in cellPositions) continue
        
        val fromPoint = cellPositions[fromIndex] ?: continue
        val toPoint = cellPositions[toIndex] ?: continue
        
        // Calculate midpoint between the two targets
        val midpoint = Offset(
            x = (fromPoint.x + toPoint.x) / 2f,
            y = (fromPoint.y + toPoint.y) / 2f
        )
        
        // Determine dot color: accent color if both targets are active, grey otherwise
        val dotColor = if (fromIndex < deviceListSize && toIndex < deviceListSize) {
            // Both targets have devices
            accentColor
        } else {
            // One or both targets are empty
            Color.Gray.copy(alpha = 0.3f)
        }
        
        // Draw dot at the connection point
        drawCircle(
            color = dotColor,
            radius = dotRadius,
            center = midpoint
        )
    }
}

private fun getTargetIconResource(targetType: String): Int {
    // Return drawable resource ID based on target type
    return when (targetType.lowercase()) {
        "ipsc" -> R.drawable.ipsc
        "hostage" -> R.drawable.hostage
        "special_1" -> R.drawable.ipsc_black_1
        "special_2" -> R.drawable.ipsc_black_2
        "paddle" -> R.drawable.paddle
        "popper" -> R.drawable.popper
        else -> 0 // Placeholder
    }
}

private fun initializeTargetConfigs(
    deviceList: List<NetworkDevice>,
    drillMode: String
): List<DrillTargetsConfigData> {
    // Follow zig-zag pattern for seqNo assignment: 0,1,2,5,4,3,6,7,8,11,10,9
    val zigzagOrder = listOf(0, 1, 2, 5, 4, 3, 6, 7, 8, 11, 10, 9)
    val configs = mutableListOf<DrillTargetsConfigData>()
    
    for ((zigzagIndex, deviceIndex) in zigzagOrder.withIndex()) {
        if (deviceIndex >= deviceList.size) break
        
        val device = deviceList[deviceIndex]
        val defaultType = when (drillMode.lowercase()) {
            "ipsc" -> "ipsc"
            "idpa" -> "idpa"
            "cqb" -> "cqb_front"
            else -> "ipsc"
        }
        
        configs.add(
            DrillTargetsConfigData(
                seqNo = zigzagIndex + 1,
                targetName = device.name,
                targetType = defaultType,
                timeout = 30.0,
                countedShots = 5
            )
        )
    }
    
    return configs.sortedBy { it.seqNo }
}
