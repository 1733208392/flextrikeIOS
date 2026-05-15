package com.flextarget.android.ui.drills

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import org.json.JSONObject
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.media.AudioManager
import coil.compose.AsyncImage
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import androidx.compose.foundation.shape.RoundedCornerShape
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
    onDrillModeChange: (String) -> Unit,
    onBack: () -> Unit,
    onStartDrill: (() -> Unit)? = null
) {
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    val deviceList = bleManager.networkDevices
    val context = LocalContext.current
    
    var localConfigs by remember(targetConfigs) {
        mutableStateOf(targetConfigs)
    }
    
    var localDrillMode by remember(drillMode) {
        mutableStateOf(drillMode)
    }

    // Device name of the most recently hit physical popper (drives per-cell animation)
    var popperHitTargetName by remember { mutableStateOf<String?>(null) }

    // Register BLE popper hit callback and clean up on disposal
    DisposableEffect(bleManager) {
        bleManager.onPopperHitReceived = { targetName ->
            // Only animate if this target has a physical popper configured
            if (localConfigs.any { it.targetName == targetName && it.hasPhysicalPopper }) {
                popperHitTargetName = targetName
                val audioManager = context.getSystemService(android.content.Context.AUDIO_SERVICE) as AudioManager
                audioManager.playSoundEffect(AudioManager.FX_KEY_CLICK, 1.0f)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    popperHitTargetName = null
                }, 600)
            }
        }
        onDispose {
            bleManager.onPopperHitReceived = null
        }
    }
    
    // Initialize target configs on first appearance
    LaunchedEffect(deviceList, drillMode) {
        if (localConfigs.isEmpty() && deviceList.isNotEmpty()) {
            localConfigs = initializeTargetConfigs(deviceList, drillMode)
            onUpdateTargetConfigs(localConfigs)
        }
    }
    
    // Handle drill mode changes
    fun changeDrillMode(newMode: String) {
        if (newMode != localDrillMode) {
            localDrillMode = newMode
            onDrillModeChange(newMode)
            
            // Update all target types to the default for the new mode
            val updatedConfigs = localConfigs.map { config ->
                val defaultType = when (newMode.lowercase()) {
                    "ipsc" -> "ipsc"
                    "idpa" -> "idpa"
                    "cqb" -> "cqb_front"
                    else -> "ipsc"
                }
                config.copy(targetType = defaultType)
            }
            localConfigs = updatedConfigs
            onUpdateTargetConfigs(updatedConfigs)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Drill Mode Segment Control
            Spacer(modifier = Modifier.height(16.dp))
            Surface(
                modifier = Modifier
                    .fillMaxWidth(0.7f)
                    .height(44.dp),
                shape = RoundedCornerShape(12.dp),
                color = Color.Gray.copy(alpha = 0.2f),
                shadowElevation = 0.dp
            ) {
                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.spacedBy(0.dp)
                ) {
                    // IPSC Button
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .clickable {
                                changeDrillMode("ipsc")
                            },
                        shape = RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp),
                        color = if (localDrillMode == "ipsc") md_theme_dark_onPrimary else Color.Gray.copy(alpha = 0.2f),
                        shadowElevation = 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center
                        ) {
                            if (localDrillMode == "ipsc") {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp),
                                    tint = Color.White
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                            }
                            Text(
                                "IPSC",
                                color = if (localDrillMode == "ipsc") Color.White else Color.Gray,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }

                    // CQB Button
                    Surface(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .clickable {
                                changeDrillMode("cqb")
                            },
                        shape = RoundedCornerShape(topEnd = 12.dp, bottomEnd = 12.dp),
                        color = if (localDrillMode == "cqb") md_theme_dark_onPrimary else Color.Gray.copy(alpha = 0.2f),
                        shadowElevation = 0.dp
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center
                        ) {
                            if (localDrillMode == "cqb") {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp),
                                    tint = Color.White
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                            }
                            Text(
                                "CQB",
                                color = if (localDrillMode == "cqb") Color.White else Color.Gray,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Target grid with connection canvas (LazyVerticalGrid handles scrolling)
            Box(
                modifier = Modifier.weight(1f),
                contentAlignment = Alignment.TopCenter
            ) {
                TargetGridContent(
                    deviceList = deviceList,
                    targetConfigs = localConfigs,
                    drillMode = localDrillMode,
                    accentColor = accentRed,
                    popperHitTargetName = popperHitTargetName,
                    onDeviceSelected = { deviceName ->
                        // Navigation to TargetConfigListViewV2 happens in the parent
                        onNavigateToConfig(deviceName)
                    },
                    onGreeting = { deviceName ->
                        val content = JSONObject().apply { put("command", "greeting") }
                        val message = JSONObject().apply {
                            put("action", "netlink_forward")
                            put("dest", deviceName)
                            put("content", content)
                        }
                        println("[TargetLinkView] Sending greeting to: $deviceName")
                        bleManager.writeJSON(message.toString())
                    },
                    onTogglePopper = { deviceName ->
                        val updated = localConfigs.map { config ->
                            if (config.targetName == deviceName) {
                                config.copy(hasPhysicalPopper = !config.hasPhysicalPopper)
                            } else config
                        }
                        localConfigs = updated
                        onUpdateTargetConfigs(updated)
                    }
                )
            }

            // START DRILL button — visible only when a start callback is provided
            if (onStartDrill != null) {
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = onStartDrill,
                    modifier = Modifier
                        .fillMaxWidth(0.85f)
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = accentRed),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        "START DRILL",
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Black
                    )
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TargetGridContent(
    deviceList: List<NetworkDevice>,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    accentColor: Color,
    popperHitTargetName: String?,
    onDeviceSelected: (String) -> Unit,
    onGreeting: (String) -> Unit,
    onTogglePopper: (String) -> Unit
) {
    val gridColumns = 3
    val cellCount = 12 // Fixed 3×4 grid

    val rectangleHeight = 150.dp
    val rectangleWidth = rectangleHeight * 9f / 16f
    val horizontalSpacing = 24.dp
    val verticalSpacing = 24.dp

    // Flat display list: DeviceItem, then PopperItem if hasPhysicalPopper, padded to 12
    val gridItems = remember(deviceList, targetConfigs) {
        buildGridItems(deviceList, targetConfigs)
    }

    // Indices of DeviceItem slots — used to draw sequence connection dots
    val deviceGridIndices = remember(gridItems) {
        gridItems.mapIndexedNotNull { index, item ->
            if (item is GridItem.DeviceItem) index else null
        }
    }

    var cellPositions by remember { mutableStateOf<Map<Int, Offset>>(emptyMap()) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Canvas(modifier = Modifier.matchParentSize()) {
            drawSequenceDots(
                cellPositions = cellPositions,
                deviceGridIndices = deviceGridIndices,
                accentColor = accentColor
            )
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(gridColumns),
            horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
            verticalArrangement = Arrangement.spacedBy(verticalSpacing),
            modifier = Modifier.fillMaxSize()
        ) {
            items(cellCount) { index ->
                when (val item = gridItems[index]) {
                    is GridItem.DeviceItem -> TargetRectangle(
                        device = item.device,
                        config = item.config,
                        width = rectangleWidth,
                        height = rectangleHeight,
                        accentColor = accentColor,
                        onSelected = { onDeviceSelected(item.device.name) },
                        onGreeting = { onGreeting(item.device.name) },
                        onTogglePopper = if (item.config?.hasPhysicalPopper != true) {
                            { onTogglePopper(item.device.name) }
                        } else null,
                        onPositionChanged = { offset ->
                            cellPositions = cellPositions.toMutableMap().apply { this[index] = offset }
                        }
                    )
                    is GridItem.PopperItem -> PopperRectangle(
                        parentDeviceName = item.parentDeviceName,
                        width = rectangleWidth,
                        height = rectangleHeight,
                        accentColor = accentColor,
                        animationTrigger = popperHitTargetName == "${item.parentDeviceName}-01",
                        onRemove = { onTogglePopper(item.parentDeviceName) },
                        onPositionChanged = { offset ->
                            cellPositions = cellPositions.toMutableMap().apply { this[index] = offset }
                        }
                    )
                    is GridItem.EmptyItem -> EmptyTargetCell(
                        width = rectangleWidth,
                        height = rectangleHeight,
                        onPositionChanged = { offset ->
                            cellPositions = cellPositions.toMutableMap().apply { this[index] = offset }
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TargetRectangle(
    device: NetworkDevice?,
    config: DrillTargetsConfigData?,
    width: Dp,
    height: Dp,
    accentColor: Color,
    onSelected: () -> Unit,
    onGreeting: () -> Unit,
    onTogglePopper: (() -> Unit)?, // null = popper already attached; hide + button
    onPositionChanged: (Offset) -> Unit
) {
    Box(
        modifier = Modifier
            .width(width)
            .height(height)
            .border(width = 6.dp, color = if (device != null) accentColor else Color.Gray.copy(alpha = 0.5f))
            .background(Color.Gray.copy(alpha = 0.1f))
            .combinedClickable(
                enabled = device != null,
                onClick = { onSelected() },
                onDoubleClick = { onGreeting() }
            )
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
                if (config != null && config.targetType.isNotEmpty() && config.targetType != "[]") {
                    val iconModel = getTargetIconResource(config.primaryTargetType())
                    if (iconModel != null) {
                        AsyncImage(
                            model = iconModel,
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
                    val defaultIconModel = getTargetIconResource("ipsc")
                    if (defaultIconModel != null) {
                        AsyncImage(
                            model = defaultIconModel,
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

            // + button — only shown when no popper is linked yet
            if (onTogglePopper != null) {
                IconButton(
                    onClick = onTogglePopper,
                    modifier = Modifier
                        .size(72.dp)
                        .align(Alignment.BottomEnd)
                        .offset(x = 8.dp, y = 8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Add Popper",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(42.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PopperRectangle(
    parentDeviceName: String,
    width: Dp,
    height: Dp,
    accentColor: Color,
    animationTrigger: Boolean,
    onRemove: () -> Unit,
    onPositionChanged: (Offset) -> Unit
) {
    val scale by animateFloatAsState(
        targetValue = if (animationTrigger) 1.3f else 1.0f,
        animationSpec = tween(durationMillis = 200),
        label = "popperCellScale"
    )

    Box(
        modifier = Modifier
            .width(width)
            .height(height)
            .border(width = 6.dp, color = accentColor)
            .background(Color.Gray.copy(alpha = 0.1f))
            .onGloballyPositioned { coordinates ->
                val center = Offset(
                    x = coordinates.positionInParent().x + coordinates.size.width / 2f,
                    y = coordinates.positionInParent().y + coordinates.size.height / 2f
                )
                onPositionChanged(center)
            },
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxSize()
        ) {
            Image(
                painter = painterResource(R.drawable.popper),
                contentDescription = "Physical Popper",
                modifier = Modifier
                    .fillMaxWidth(0.6f)
                    .aspectRatio(1f)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = parentDeviceName,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = accentColor,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 4.dp)
            )
        }

        // × button to unlink this physical popper
        IconButton(
            onClick = onRemove,
            modifier = Modifier
                .size(72.dp)
                .align(Alignment.BottomEnd)
                .padding(6.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Remove Popper",
                tint = accentColor,
                modifier = Modifier.size(42.dp)
            )
        }
    }
}

@Composable
private fun EmptyTargetCell(
    width: Dp,
    height: Dp,
    onPositionChanged: (Offset) -> Unit
) {
    Box(
        modifier = Modifier
            .width(width)
            .height(height)
            .border(width = 6.dp, color = Color.Gray.copy(alpha = 0.5f))
            .background(Color.Gray.copy(alpha = 0.1f))
            .onGloballyPositioned { coordinates ->
                val center = Offset(
                    x = coordinates.positionInParent().x + coordinates.size.width / 2f,
                    y = coordinates.positionInParent().y + coordinates.size.height / 2f
                )
                onPositionChanged(center)
            }
    )
}

private fun DrawScope.drawSequenceDots(
    cellPositions: Map<Int, Offset>,
    deviceGridIndices: List<Int>,
    accentColor: Color
) {
    val dotRadius = 6f
    for (i in 0 until deviceGridIndices.size - 1) {
        val fromIdx = deviceGridIndices[i]
        val toIdx = deviceGridIndices[i + 1]
        val fromPos = cellPositions[fromIdx] ?: continue
        val toPos = cellPositions[toIdx] ?: continue
        val midpoint = Offset(
            x = (fromPos.x + toPos.x) / 2f,
            y = (fromPos.y + toPos.y) / 2f
        )
        drawCircle(color = accentColor, radius = dotRadius, center = midpoint)
    }
}

private sealed class GridItem {
    data class DeviceItem(
        val device: NetworkDevice,
        val config: DrillTargetsConfigData?
    ) : GridItem()

    data class PopperItem(
        val parentDeviceName: String
    ) : GridItem()

    object EmptyItem : GridItem()
}

private fun buildGridItems(
    deviceList: List<NetworkDevice>,
    targetConfigs: List<DrillTargetsConfigData>
): List<GridItem> {
    val items = mutableListOf<GridItem>()
    for (device in deviceList) {
        if (items.size >= 12) break
        val config = targetConfigs.firstOrNull { it.targetName == device.name }
        items.add(GridItem.DeviceItem(device, config))
        if (config?.hasPhysicalPopper == true && items.size < 12) {
            items.add(GridItem.PopperItem(device.name))
        }
    }
    while (items.size < 12) items.add(GridItem.EmptyItem)
    return items
}
private fun getTargetIconResource(targetType: String): Any? {
    // Return drawable resource ID or asset URI based on target type
    return when (targetType.lowercase()) {
        // IPSC targets (drawable resources)
        "ipsc" -> R.drawable.ipsc
        "hostage" -> R.drawable.hostage
        "special_1" -> R.drawable.ipsc_black_1
        "special_2" -> R.drawable.ipsc_black_2
        "paddle" -> R.drawable.paddle
        "popper" -> R.drawable.popper
        
        // CQB targets (SVG assets)
        "cqb_front" -> "file:///android_asset/cqb_front.svg"
        "cqb_swing" -> "file:///android_asset/cqb_swing.svg"
        "cqb_hostage" -> "file:///android_asset/cqb_hostoage.svg"  // Note: asset file has typo
        "disguised_enemy" -> "file:///android_asset/disguise_enemy.svg"
        
        // IDPA targets (SVG assets)
        "idpa" -> "file:///android_asset/idpa.svg"
        "idpa_ns" -> "file:///android_asset/idpa-ns.svg"
        "idpa_black_1" -> "file:///android_asset/idpa-hard-cover-1.svg"
        "idpa_black_2" -> "file:///android_asset/idpa-hard-cover-2.svg"
        
        else -> null // No fallback - handled by TargetRectangle
    }
}

private fun initializeTargetConfigs(
    deviceList: List<NetworkDevice>,
    drillMode: String
): List<DrillTargetsConfigData> {
    // Follow zig-zag pattern for seqNo assignment: 0,1,2,5,4,3,6,7,8,11,10,9
    // These are grid positions, devices are assigned sequentially
    val zigzagOrder = listOf(0, 1, 2, 5, 4, 3, 6, 7, 8, 11, 10, 9)
    val configs = mutableListOf<DrillTargetsConfigData>()
    
    for ((seqNo, device) in deviceList.withIndex()) {
        val defaultType = when (drillMode.lowercase()) {
            "ipsc" -> "ipsc"
            "idpa" -> "idpa"
            "cqb" -> "cqb_front"
            else -> "ipsc"
        }
        
        configs.add(
            DrillTargetsConfigData(
                seqNo = seqNo + 1,
                targetName = device.name,
                targetType = defaultType,
                timeout = 30.0,
                countedShots = 5
            )
        )
    }
    
    return configs.sortedBy { it.seqNo }
}
