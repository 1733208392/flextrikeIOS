package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetConfigListViewV2(
    bleManager: BLEManager,
    targetConfigs: List<DrillTargetsConfigData>,
    drillMode: String,
    onUpdateTargetTypes: (Int, List<String>) -> Unit,
    onDone: () -> Unit,
    onBack: () -> Unit
) {
    val accentRed = Color(red = 0.87f, green = 0.22f, blue = 0.14f)
    val darkGray = Color(red = 0.098f, green = 0.098f, blue = 0.098f)

    val primaryConfig = targetConfigs.firstOrNull() ?: return
    
    var selectedTargetTypes by remember { 
        mutableStateOf(primaryConfig.parseTargetTypes())
    }
    var currentTypeIndex by remember { mutableStateOf(0) }

    val availableTargetTypes = when (drillMode) {
        "ipsc" -> listOf("ipsc", "hostage", "paddle", "popper", "rotation", "special_1", "special_2")
        "idpa" -> listOf("idpa", "idpa_ns", "idpa_black_1", "idpa_black_2")
        "cqb" -> listOf("cqb_swing", "cqb_front", "cqb_move", "disguised_enemy", "cqb_hostage")
        else -> listOf("ipsc")
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        primaryConfig.targetName.ifEmpty { stringResource(R.string.targets_screen) },
                        color = accentRed
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        onDone()
                        onBack()
                    }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = accentRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Black)
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
                .verticalScroll(rememberScrollState()),
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
                isDraggingOver = false
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Target Type Selection View
            TargetTypeSelectionViewV2(
                availableTargetTypes = availableTargetTypes,
                selectedTargetTypes = selectedTargetTypes,
                drillMode = drillMode,
                accentColor = accentRed,
                darkGrayColor = darkGray,
                onTypesChanged = { newTypes ->
                    selectedTargetTypes = newTypes
                    onUpdateTargetTypes(0, newTypes)
                }
            )

            // Divider line
            Divider(
                modifier = Modifier
                    .width(240.dp)
                    .height(4.dp),
                color = accentRed
            )

            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun TargetRectSection(
    selectedTargetTypes: List<String>,
    currentTypeIndex: Int,
    onTypeIndexChange: (Int) -> Unit,
    accentColor: Color,
    darkGrayColor: Color,
    isDraggingOver: Boolean
) {
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
                },
            contentAlignment = Alignment.Center
        ) {
            if (selectedTargetTypes.isEmpty()) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Add target type",
                    modifier = Modifier.size(80.dp),
                    tint = if (isDraggingOver) accentColor else Color.White.copy(alpha = 0.75f)
                )
            } else {
                // Show current type image
                val currentType = selectedTargetTypes[minOf(currentTypeIndex, selectedTargetTypes.size - 1)]
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = currentType.take(2).uppercase(),
                        fontSize = 48.sp,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                        color = Color.White,
                        modifier = Modifier.padding(18.dp)
                    )
                }
            }

            // Badge showing count
            if (selectedTargetTypes.isNotEmpty()) {
                Text(
                    "${selectedTargetTypes.size}",
                    fontSize = 36.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    color = accentColor,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(end = 20.dp, top = 20.dp)
                )
            }
        }

        // Page Indicator Dots
        if (selectedTargetTypes.size > 1) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 8.dp)
            ) {
                repeat(selectedTargetTypes.size) { index ->
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .background(
                                color = if (index == currentTypeIndex) accentColor else darkGrayColor,
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
}

@Composable
private fun TargetTypeSelectionViewV2(
    availableTargetTypes: List<String>,
    selectedTargetTypes: List<String>,
    drillMode: String,
    accentColor: Color,
    darkGrayColor: Color,
    onTypesChanged: (List<String>) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Instruction Text
        Text(
            "Please drag the target type into above rectangle to complete the selection",
            color = Color.Gray,
            fontSize = 12.sp,
            modifier = Modifier.padding(horizontal = 24.dp)
        )

        // Type Icons Grid/Row
        LazyRow(
            modifier = Modifier
                .fillMaxWidth()
                .height(160.dp)
                .background(
                    color = Color(red = 0.098f, green = 0.098f, blue = 0.098f),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp)
                )
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(18.dp),
            contentPadding = PaddingValues(2.dp)
        ) {
            itemsIndexed(availableTargetTypes) { _, type ->
                Box(
                    modifier = Modifier
                        .size(90.dp, 160.dp)
                        .border(1.dp, accentColor, androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
                        .clickable {
                            if (!selectedTargetTypes.contains(type)) {
                                onTypesChanged(selectedTargetTypes + type)
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = type.take(4).uppercase(),
                        fontSize = 16.sp,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                        color = accentColor,
                        modifier = Modifier.padding(10.dp)
                    )
                }
            }
        }

        // Divider
        Divider(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp),
            color = accentColor
        )
    }
}
