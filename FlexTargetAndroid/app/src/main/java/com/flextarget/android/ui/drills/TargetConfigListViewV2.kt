package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.Image
import androidx.compose.ui.text.font.FontWeight
import coil.compose.AsyncImage
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import org.intellij.lang.annotations.JdkConstants
import org.json.JSONObject
import com.flextarget.android.ui.theme.ttNormFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetConfigListViewV2(
    bleManager: BLEManager,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onUpdateTargetTypes: (Int, List<String>) -> Unit,
    onAddTarget: () -> Unit = {},
    onDone: () -> Unit,
    onBack: () -> Unit
) {
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    val darkGray = Color(red = 0.44f, green = 0.44f, blue = 0.44f)

    val primaryConfig = targetConfigs.firstOrNull() ?: return
    
    var selectedTargetTypes by remember { 
        mutableStateOf(primaryConfig.parseTargetTypes())
    }
    var currentTypeIndex by remember { mutableStateOf(0) }
    var isDeleteMode by remember { mutableStateOf(false) }
    var isSelectingMode by remember { mutableStateOf(false) }

    val availableTargetTypes = when (drillMode) {
        "ipsc" -> listOf("ipsc", "hostage", "paddle", "popper", "special_1", "special_2")
        "idpa" -> listOf("idpa", "idpa_ns", "idpa_black_1", "idpa_black_2")
        "cqb" -> listOf("cqb_swing", "cqb_front", "cqb_move", "disguised_enemy", "cqb_hostage")
        else -> listOf("ipsc")
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        primaryConfig.targetName,
                        color = accentRed,
                        fontFamily = ttNormFontFamily,
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        onDone()
                        onBack()
                    }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back), tint = accentRed)
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(containerColor = Color.Black)
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .pointerInput(isDeleteMode) {
                    if (isDeleteMode) {
                        detectTapGestures(onTap = { isDeleteMode = false })
                    }
                },
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
                Spacer(modifier = Modifier.height(10.dp))

                // Target Rectangle Section with Carousel
                TargetRectSection(
                    selectedTargetTypes = selectedTargetTypes,
                    currentTypeIndex = currentTypeIndex,
                    onTypeIndexChange = { currentTypeIndex = it },
                    accentColor = accentRed,
                    darkGrayColor = darkGray,
                    isDeleteMode = isDeleteMode && !isSelectingMode,
                    onDeleteModeChange = { 
                        isDeleteMode = it
                        if (it) isSelectingMode = false
                    },
                    onRemoveType = { index ->
                        selectedTargetTypes = selectedTargetTypes.toMutableList().also { it.removeAt(index) }
                        onUpdateTargetTypes(0, selectedTargetTypes)
                        isDeleteMode = false
                    }
                )

                Spacer(modifier = Modifier.height(10.dp))

                // Target Type Selection View
                TargetTypeSelectionViewV2(
                    deviceName = primaryConfig.targetName,
                    availableTargetTypes = availableTargetTypes,
                    selectedTargetTypes = selectedTargetTypes,
                    accentColor = accentRed,
                    isSelectingMode = isSelectingMode && !isDeleteMode,
                    onSelectingModeChange = { 
                        isSelectingMode = it
                        if (it) isDeleteMode = false
                    },
                    onTypesChanged = { newTypes ->
                        selectedTargetTypes = newTypes
                        onUpdateTargetTypes(0, newTypes)
                    }
                )

                Spacer(modifier = Modifier.weight(1f))
            }
    }
}

private fun getIconForTargetType(type: String): String {
    return when (type) {
        "hostage" -> "hostage.png"
        "ipsc" -> "ipsc.png"
        "special_1" -> "ipsc_black_1.png"
        "special_2" -> "ipsc_black_2.png"
        "paddle" -> "paddle.png"
        "popper" -> "popper.png"
        // "rotation" -> "rotation.svg"
        "idpa" -> "idpa.svg"
        "idpa_ns" -> "idpa-ns.svg"
        "idpa_black_1" -> "idpa-hard-cover-1.svg"
        "idpa_black_2" -> "idpa-hard-cover-2.svg"
        "cqb_front" -> "cqb_front.svg"
        "cqb_hostage" -> "cqb_hostoage.svg"
        "cqb_swing" -> "cqb_swing.svg"
        "cqb_move" -> "cqb_move.svg"
        "disguised_enemy" -> "disguise_enemy.svg"
        else -> "ipsc.png" // default icon
    }
}

private fun getDrawableResourceId(type: String): Int {
    return when (type) {
        "hostage" -> R.drawable.hostage
        "ipsc" -> R.drawable.ipsc
        "special_1" -> R.drawable.ipsc_black_1
        "special_2" -> R.drawable.ipsc_black_2
        "paddle" -> R.drawable.paddle
        "popper" -> R.drawable.popper
        else -> 0
    }
}

@Composable
private fun TargetRectSection(
    selectedTargetTypes: List<String>,
    currentTypeIndex: Int,
    onTypeIndexChange: (Int) -> Unit,
    accentColor: Color,
    darkGrayColor: Color,
    isDeleteMode: Boolean,
    onDeleteModeChange: (Boolean) -> Unit,
    onRemoveType: (Int) -> Unit
) {
    // Wiggle animation for delete mode 
    var rotationState by remember { mutableStateOf(-2f) }
    
    if (isDeleteMode) {
        LaunchedEffect(isDeleteMode) {
            var isForward = true
            while (isDeleteMode) {
                for (i in 0 until 10) {
                    rotationState = if (isForward) -2f + (i * 0.4f) else 2f - (i * 0.4f)
                    kotlinx.coroutines.delay(10)
                }
                isForward = !isForward
            }
        }
    } else {
        rotationState = 0f
    }
    
    val displayRotation = rotationState

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Target Rectangle with Carousel
        Box(
            modifier = Modifier
                .size(180.dp, 320.dp)
                .drawBehind {
                    val borderStroke = 8.dp.toPx()
                    drawRect(
                        color = accentColor,
                        topLeft = androidx.compose.ui.geometry.Offset(borderStroke / 2, borderStroke / 2),
                        size = androidx.compose.ui.geometry.Size(
                            size.width - borderStroke,
                            size.height - borderStroke
                        ),
                        style = androidx.compose.ui.graphics.drawscope.Stroke(borderStroke)
                    )
                }
                .pointerInput(Unit) {
                    detectTapGestures(
                        onLongPress = {
                            if (!selectedTargetTypes.isEmpty()) {
                                onDeleteModeChange(!isDeleteMode)
                            }
                        }
                    )
                }
                .pointerInput(currentTypeIndex) {
                    var totalDragX = 0f
                    detectDragGestures(
                        onDragStart = {
                            totalDragX = 0f
                        },
                        onDragEnd = {
                            // Check total drag distance
                            if (totalDragX < 50 && currentTypeIndex < selectedTargetTypes.size - 1) {
                                // Swiped Left - go to next target
                                onTypeIndexChange(currentTypeIndex + 1)
                            } else if (totalDragX > -50 && currentTypeIndex > 0) {
                                // Swiped Right - go to previous target
                                onTypeIndexChange(currentTypeIndex - 1)
                            }
                            totalDragX = 0f
                        }
                    ) { change, dragAmount ->
                        totalDragX += dragAmount.x
                        change.consume()
                    }
                },
            contentAlignment = Alignment.Center
        ) {
            if (selectedTargetTypes.isEmpty()) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = stringResource(R.string.add_target_type),
                    modifier = Modifier.size(80.dp),
                    tint = accentColor.copy(alpha = 0.75f)
                )
            } else {
                // Show current type icon with wiggle if in delete mode
                val currentType = selectedTargetTypes[minOf(currentTypeIndex, selectedTargetTypes.size - 1)]
                val fileName = getIconForTargetType(currentType)
                
                val maxHeight = 316.dp  // 320dp - 4dp padding on each side
                
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .rotate(displayRotation),
                    contentAlignment = Alignment.Center
                ) {
                    if (fileName.endsWith(".png")) {
                        // Load PNG from drawable resources
                        val drawableResId = getDrawableResourceId(currentType)
                        if (drawableResId != 0) {
                            Image(
                                painter = painterResource(id = drawableResId),
                                contentDescription = currentType,
                                modifier = Modifier
                                    .fillMaxWidth(0.9f)
                                    .heightIn(max = maxHeight)
                                    .padding(2.dp),
                                contentScale = ContentScale.FillWidth
                            )
                        }
                    } else {
                        // Load SVG from assets
                        AsyncImage(
                            model = "file:///android_asset/$fileName",
                            contentDescription = currentType,
                            modifier = Modifier
                                .fillMaxWidth(
                                    fraction = if (currentType == "paddle" || currentType == "popper") 0.5f else 1f
                                )
                                .heightIn(max = maxHeight)
                                .padding(4.dp),
                            contentScale = ContentScale.Fit
                        )
                    }
                }
            }

            // Delete button in delete mode - TOP RIGHT
            if (isDeleteMode && selectedTargetTypes.isNotEmpty()) {
                IconButton(
                    onClick = {
                        onRemoveType(currentTypeIndex)
                    },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(end = 16.dp, top = 16.dp)
                        .background(accentColor, shape = androidx.compose.foundation.shape.CircleShape)
                        .size(28.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = stringResource(R.string.delete),
                        tint = Color.Black,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }

            // Page Indicator Dots - BOTTOM CENTER
            if (selectedTargetTypes.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp)
                ) {
                    repeat(selectedTargetTypes.size) { index ->
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(
                                    color = if (index == currentTypeIndex) accentColor else Color.Gray,
                                    shape = androidx.compose.foundation.shape.CircleShape
                                )
                                .clickable {
                                    onTypeIndexChange(index)
                                }
                        )
                    }
                }
            }
        }

        // Instruction text when targets exist
        if (selectedTargetTypes.isNotEmpty()) {
            Text(
                stringResource(R.string.instruction_long_press_delete),
                fontFamily = ttNormFontFamily,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = accentColor,
                modifier = Modifier.padding(top = 12.dp)
            )
        } else {
            // Instruction text when no targets
            Text(
                stringResource(R.string.instruction_long_press_add),
                fontFamily = ttNormFontFamily,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = accentColor,
                modifier = Modifier.padding(top = 12.dp)
            )
        }
    }
}

@Composable
private fun TargetTypeSelectionViewV2(
    deviceName: String,
    availableTargetTypes: List<String>,
    selectedTargetTypes: List<String>,
    accentColor: Color,
    isSelectingMode: Boolean,
    onSelectingModeChange: (Boolean) -> Unit,
    onTypesChanged: (List<String>) -> Unit
) {
    var rotationState by remember { mutableStateOf(0f) }

    val filteredAvailableTargetTypes = remember(availableTargetTypes, selectedTargetTypes) {
        availableTargetTypes.filter { it !in selectedTargetTypes }
    }

    // Shared wiggle animation for all target type icons
    if (isSelectingMode) {
        LaunchedEffect(isSelectingMode) {
            var isForward = true
            while (isSelectingMode) {
                for (i in 0 until 10) {
                    rotationState = if (isForward) -2f + (i * 0.4f) else 2f - (i * 0.4f)
                    kotlinx.coroutines.delay(10)
                }
                isForward = !isForward
            }
        }
    } else {
        rotationState = 0f
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Tap area above LazyRow to close selection
        Spacer(
            modifier = Modifier
                .fillMaxWidth()
                .height(12.dp)
                .clickable(
                    enabled = isSelectingMode,
                    indication = null,
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                ) {
                    if (isSelectingMode) {
                        onSelectingModeChange(false)
                    }
                }
        )

        // Type Icons Grid/Row - scrollable with swipe anywhere
        LazyRow(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .background(
                    color = Color.Black,
                )
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(18.dp),
            contentPadding = PaddingValues(2.dp)
        ) {
            itemsIndexed(filteredAvailableTargetTypes) { _, type ->
                val svgFileName = getIconForTargetType(type)
                val displayRotation = if (isSelectingMode) rotationState else 0f

                Box(
                    modifier = Modifier
                        .size(90.dp, 160.dp)
                        .pointerInput(type) {
                            detectTapGestures(
                                onTap = {
                                    // Any tap closes selection mode
                                    if (isSelectingMode) {
                                        onSelectingModeChange(false)
                                    }
                                },
                                onLongPress = {
                                    onSelectingModeChange(!isSelectingMode)
                                }
                            )
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .rotate(displayRotation),
                        contentAlignment = Alignment.Center
                    ) {
                        if (svgFileName.endsWith(".png")) {
                            // Load PNG from drawable resources
                            val drawableResId = getDrawableResourceId(type)
                            if (drawableResId != 0) {
                                Image(
                                    painter = painterResource(id = drawableResId),
                                    contentDescription = type,
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .padding(8.dp),
                                    contentScale = ContentScale.Inside
                                )
                            }
                        } else {
                            // Load SVG from assets
                            AsyncImage(
                                model = "file:///android_asset/$svgFileName",
                                contentDescription = type,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(8.dp),
                                contentScale = ContentScale.Fit
                            )
                        }
                    }

                    // Plus button when in selecting mode - TOP RIGHT
                    if (isSelectingMode) {
                        IconButton(
                            onClick = {
                                onTypesChanged(selectedTargetTypes + type)
                            },
                            modifier = Modifier
                                .align(Alignment.TopEnd)
                                .padding(end = 4.dp, top = 4.dp)
                                .background(accentColor, shape = androidx.compose.foundation.shape.CircleShape)
                                .size(28.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = stringResource(R.string.add),
                                tint = Color.Black,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }

        // Divider line - below target icons
        Divider(
            modifier = Modifier
                .width(300.dp)
                .height(3.dp)
                .align(Alignment.CenterHorizontally),
            color = accentColor,
        )

        // Tap area below LazyRow to close selection
        Spacer(
            modifier = Modifier
                .fillMaxWidth()
                .height(12.dp)
                .clickable(
                    enabled = isSelectingMode,
                    indication = null,
                    interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
                ) {
                    if (isSelectingMode) {
                        onSelectingModeChange(false)
                    }
                }
        )
    }
}