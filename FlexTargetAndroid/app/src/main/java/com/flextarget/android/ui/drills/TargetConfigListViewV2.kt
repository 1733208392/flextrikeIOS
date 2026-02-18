package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.scrollable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.NetworkDevice
import com.flextarget.android.data.model.DrillTargetsConfigData
import com.google.accompanist.pager.ExperimentalPagerApi
import com.google.accompanist.pager.HorizontalPager
import com.google.accompanist.pager.rememberPagerState
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class, ExperimentalPagerApi::class)
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
    var isDraggingOverSelection by remember { mutableStateOf(false) }
    
    val pagerState = rememberPagerState()
    
    // Update pager state when selected types change
    LaunchedEffect(selectedTargetTypes) {
        if (selectedTargetTypes.isNotEmpty()) {
            pagerState.scrollToPage(minOf(currentTypeIndex, selectedTargetTypes.size - 1))
        }
    }

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
                        primaryConfig.targetName.ifEmpty { stringResource(R.string.targets) },
                        color = accentRed
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        onDone()
                        onBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = accentRed)
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
                pagerState = pagerState,
                accentColor = accentRed,
                darkGrayColor = darkGray,
                isDraggingOver = isDraggingOverSelection
            )

            Spacer(modifier = Modifier.height(20.dp))

            // Target Type Selection View
            TargetTypeSelectionViewV2(
                availableTargetTypes = availableTargetTypes,
                selectedTargetTypes = selectedTargetTypes,
                drillMode = drillMode,
                accentColor = accentRed,
                darkGrayColor = darkGray,
                onDragOver = { isDraggingOverSelection = it },
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

@OptIn(ExperimentalPagerApi::class)
@Composable
private fun TargetRectSection(
    selectedTargetTypes: List<String>,
    currentTypeIndex: Int,
    onTypeIndexChange: (Int) -> Unit,
    pagerState: com.google.accompanist.pager.PagerState,
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
                        topLeft = Offset(borderStroke / 2, borderStroke / 2),
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
                HorizontalPager(
                    count = selectedTargetTypes.size,
                    state = pagerState,
                    modifier = Modifier.fillMaxSize()
                ) { page ->
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        val typeIcon = getIconResourceId(selectedTargetTypes[page])
                        Icon(
                            painter = painterResource(id = typeIcon),
                            contentDescription = selectedTargetTypes[page],
                            modifier = Modifier
                                .size(120.dp)
                                .padding(18.dp),
                            tint = Color.White
                        )
                    }
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
                                color = if (index == pagerState.currentPage) accentColor else darkGrayColor,
                                shape = androidx.compose.foundation.shape.CircleShape
                            )
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
    onDragOver: (Boolean) -> Unit,
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
                    val typeIcon = getIconResourceId(type)
                    Icon(
                        painter = painterResource(id = typeIcon),
                        contentDescription = type,
                        modifier = Modifier
                            .size(70.dp)
                            .padding(10.dp),
                        tint = Color.White
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

private fun getIconResourceId(targetType: String): Int {
    return when (targetType) {
        "ipsc" -> R.drawable.ic_ipsc
        "hostage" -> R.drawable.ic_hostage
        "paddle" -> R.drawable.ic_paddle
        "popper" -> R.drawable.ic_popper
        "rotation" -> R.drawable.ic_rotation
        "special_1" -> R.drawable.ic_special_1
        "special_2" -> R.drawable.ic_special_2
        "idpa" -> R.drawable.ic_idpa
        "idpa_ns" -> R.drawable.ic_idpa_ns
        "idpa_black_1" -> R.drawable.ic_idpa_black_1
        "idpa_black_2" -> R.drawable.ic_idpa_black_2
        "cqb_swing" -> R.drawable.ic_cqb_swing
        "cqb_front" -> R.drawable.ic_cqb_front
        "cqb_move" -> R.drawable.ic_cqb_move
        "disguised_enemy" -> R.drawable.ic_disguised_enemy
        "cqb_hostage" -> R.drawable.ic_cqb_hostage
        else -> R.drawable.ic_ipsc
    }
}
