package com.flextarget.android.ui.drills

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.flextarget.android.R
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.times
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.*

/**
 * View for displaying drill results with target visualization and shot details.
 * Ported from iOS DrillResultView.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrillResultView(
    drillSetup: DrillSetupEntity,
    targets: List<DrillTargetsConfigData>,
    repeatSummary: DrillRepeatSummary? = null,
    shots: List<ShotData> = emptyList(),
    onBack: () -> Unit = {}
) {
    val displayShots = repeatSummary?.shots ?: shots
    
    // Convert to type-safe display format using new architecture
    val displayTargets = targets.toDisplayTargets()

    // DEBUG: Log initialization
    println("[DrillResultView] Initialized with ${displayTargets.size} targets, ${displayShots.size} shots")
    displayTargets.forEachIndexed { index, target ->
        when (target) {
            is DrillTargetState.SingleTarget -> {
                println("[DrillResultView]   Target $index (Single): name=${target.targetName}, type=${target.targetType.value}")
            }
            is DrillTargetState.ExpandedMultiTarget -> {
                println("[DrillResultView]   Target $index (Expanded): deviceId=${target.deviceId.value}, type=${target.targetType.value}, seqNo=${target.seqNo}")
            }
        }
    }

    // State for target selection and shot selection
    var selectedTargetIndex by remember { mutableStateOf(0) }
    var selectedShotIndex by remember { mutableStateOf<Int?>(null) }

    // Calculate frame dimensions (9:16 aspect ratio, 2/3 of available height)
    val screenHeight = 800.dp // This would be dynamic in real implementation
    val frameHeight = screenHeight * 2 / 3
    val frameWidth = frameHeight * 9 / 16

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top App Bar
        TopAppBar(
            title = {
                Text(
                    text = "DRILL RESULTS",
                    color = md_theme_dark_onPrimary,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold
                )
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.Default.ArrowBack,
                        contentDescription = "Back",
                        tint = Color(0xffde3823)
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black
            )
        )

        // Main content
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            TargetDisplayView(
                targets = displayTargets,
                shots = displayShots,
                selectedTargetIndex = selectedTargetIndex,
                selectedShotIndex = selectedShotIndex,
                onTargetSelected = { selectedTargetIndex = it },
                modifier = Modifier.weight(0.7f).fillMaxWidth()
            )

            // Shot list
            Divider(color = Color.White.copy(alpha = 0.3f))
            ShotListView(
                shots = displayShots,
                selectedTargetIndex = selectedTargetIndex,
                selectedShotIndex = selectedShotIndex,
                targets = displayTargets,
                onShotSelected = { selectedShotIndex = it },
                modifier = Modifier
                    .weight(0.3f)
                    .fillMaxWidth()
            )
        }
    }
}

/**
 * Map target type to drawable resource ID
 */
private fun getTargetImageResId(targetType: String): Int? {
    return when (targetType.lowercase()) {
        "ipsc" -> R.drawable.ipsc_live_target
        "hostage" -> R.drawable.hostage_live_target
        "popper" -> R.drawable.popper_live_target
        "paddle" -> R.drawable.paddle_live_target
        "special_1" -> R.drawable.ipsc_special_1_live_target
        "special_2" -> R.drawable.ipsc_special_2_live_target
        "cqb_front" -> R.drawable.cqb_front_live_target
        "cqb_hostage" -> R.drawable.cqb_hostage_live_target
        "cqb_swing" -> R.drawable.cqb_swing_live_target
        "idpa" -> R.drawable.idpa_live_target
        "idpa_ns" -> R.drawable.idpa_ns_live_target
        "idpa-back-1" -> R.drawable.idpa_hard_cover_1_live_target
        "idpa-back-2" -> R.drawable.idpa_hard_cover_2_live_target
        "disguised_enemy" -> R.drawable.disguised_enemy_live_target
        "disguised_enemy_surrender" -> R.drawable.disguised_enemy_surrender_live_target
        else -> null
    }
}

/**
 * Determines if a shot matches a target configuration.
 * Uses explicit type-based matching for expanded multi-targets,
 * device name matching for single targets.
 * 
 * This function is the SAME as in ShotMatchingTests - they must stay in sync!
 */
private fun shotMatchesTarget(shot: ShotData, target: DrillTargetState): Boolean {
    val shotDevice = shot.device?.trim()?.lowercase()
    val shotTargetType = shot.content.actualTargetType.lowercase()

    return when (target) {
        is DrillTargetState.ExpandedMultiTarget -> {
            // For expanded targets, ONLY match by type
            // Never use device fallback (prevents all-shots-on-all-targets bug)
            shotTargetType == target.targetType.value.lowercase()
        }
        is DrillTargetState.SingleTarget -> {
            // For single targets, match by device name
            shotDevice == target.targetName.lowercase()
        }
    }
}

/**
 * Displays targets with bullet holes positioned according to shot coordinates.
 * Ported from iOS TargetDisplayView.
 */
@Composable
private fun TargetDisplayView(
    targets: List<DrillTargetState>,
    shots: List<ShotData>,
    selectedTargetIndex: Int,
    selectedShotIndex: Int?,
    onTargetSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val currentTarget = targets.getOrNull(selectedTargetIndex)
    val targetType = when (currentTarget) {
        is DrillTargetState.SingleTarget -> currentTarget.targetType.value
        is DrillTargetState.ExpandedMultiTarget -> currentTarget.targetType.value
        null -> "ipsc"
    }
    val targetResId = getTargetImageResId(targetType)
    
    println("[TargetDisplayView] Displaying target ${selectedTargetIndex + 1}/${targets.size}: targetType=$targetType, resId=$targetResId")
    if (currentTarget != null) {
        when (currentTarget) {
            is DrillTargetState.SingleTarget -> println("[TargetDisplayView]   Type: SingleTarget(name=${currentTarget.targetName})")
            is DrillTargetState.ExpandedMultiTarget -> println("[TargetDisplayView]   Type: ExpandedMultiTarget(deviceId=${currentTarget.deviceId.value}, seqNo=${currentTarget.seqNo})")
        }
    }

    Box(
        modifier = modifier
            .pointerInput(selectedTargetIndex, targets.size) {
                if (targets.size > 1) {
                    detectHorizontalDragGestures { change, dragAmount ->
                        change.consume()
                        // Swipe threshold in pixels
                        if (dragAmount < -50) {
                            // Swipe left: go to next target
                            val nextIndex = (selectedTargetIndex + 1) % targets.size
                            onTargetSelected(nextIndex)
                        } else if (dragAmount > 50) {
                            // Swipe right: go to previous target
                            val prevIndex = if (selectedTargetIndex == 0) targets.size - 1 else selectedTargetIndex - 1
                            onTargetSelected(prevIndex)
                        }
                    }
                }
            }
    ) {
        // Target background with image
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            // Load and display target image from drawable resources
            val targetResIdLocal = targetResId
            if (targetResIdLocal != null) {
                androidx.compose.foundation.Image(
                    painter = painterResource(id = targetResIdLocal),
                    contentDescription = "Target image",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize()
                )
            }

            // Target name overlay in top right corner
            val displayName = when (currentTarget) {
                is DrillTargetState.SingleTarget -> currentTarget.targetName
                is DrillTargetState.ExpandedMultiTarget -> currentTarget.targetName
                null -> "Target"
            }
            Text(
                text = displayName,
                color = Color.White,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(8.dp)
            )

            // Bullet holes overlay using drawable images
            BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                shots.forEachIndexed { index, shot ->
                    // Check if shot matches current target using consolidated logic
                    val matchesTarget = currentTarget?.let { shotMatchesTarget(shot, it) } ?: false

                    if (matchesTarget) {
                        // Transform coordinates from 720x1280 to box size
                        val transformedX = (shot.content.actualHitPosition.x / 720.0)
                        val transformedY = (shot.content.actualHitPosition.y / 1280.0)

                        val isSelected = selectedShotIndex == index
                        val bulletHoleSize = if (isSelected) 32.dp else 24.dp

                        // Render bullet hole drawable at transformed position
                        androidx.compose.foundation.Image(
                            painter = painterResource(id = R.drawable.bullet_hole2),
                            contentDescription = "Bullet hole $index",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier
                                .size(bulletHoleSize)
                                .align(Alignment.TopStart)
                                .offset(
                                    x = (transformedX * maxWidth) - bulletHoleSize / 2,
                                    y = (transformedY * maxHeight) - bulletHoleSize / 2
                                )
                                .then(
                                    if (isSelected) {
                                        Modifier.border(
                                            width = 2.dp,
                                            color = Color.Yellow.copy(alpha = 0.8f),
                                            shape = CircleShape
                                        )
                                    } else {
                                        Modifier
                                    }
                                )
                        )
                    }
                }
            }
        }

        // Target selector (if multiple targets)
        if (targets.size > 1) {
            Row(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 8.dp)
                    .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(16.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                targets.forEachIndexed { index, target ->
                    val isSelected = index == selectedTargetIndex
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (isSelected) Color.Red else Color.White.copy(alpha = 0.5f))
                            .clickable { onTargetSelected(index) }
                    )
                }
            }
        }
    }
}

/**
 * Special overlay for rotation targets with coordinate transformation.
 * Ported from iOS RotationOverlayView.
 */
@Composable
private fun RotationOverlay(
    shots: List<ShotData>,
    selectedShotIndex: Int?,
    frameWidth: androidx.compose.ui.unit.Dp,
    frameHeight: androidx.compose.ui.unit.Dp
) {
    // This would implement the complex rotation overlay logic
    // For now, just a placeholder
    Box(modifier = Modifier.size(frameWidth, frameHeight)) {
        Text(
            text = "Rotation Target Overlay",
            color = Color.White,
            modifier = Modifier.align(Alignment.Center)
        )
    }
}

/**
 * Displays the list of shots for the current target.
 * Ported from iOS shot list in DrillResultView.
 */
@Composable
private fun ShotListView(
    shots: List<ShotData>,
    selectedTargetIndex: Int,
    selectedShotIndex: Int?,
    targets: List<DrillTargetState>,
    onShotSelected: (Int?) -> Unit,
    modifier: Modifier = Modifier
) {
    val currentTarget = targets.getOrNull(selectedTargetIndex)
    val scrollState = rememberLazyListState()

    // Calculate cumulative timestamps for all shots (iOS-compatible)
    val shotTimestamps = TimingCalculator.calculateShotTimestamps(shots)

    // Filter shots for current target using consolidated matching logic
    val targetShots = shots.mapIndexedNotNull { index, shot ->
        if (currentTarget != null && shotMatchesTarget(shot, currentTarget)) {
            index to shot
        } else {
            null
        }
    }

    Box(modifier = modifier.fillMaxHeight()) {
        LazyColumn(
            state = scrollState,
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp)
        ) {
            itemsIndexed(targetShots) { position, (shotIndex, shot) ->
                // Get cumulative time for this shot from the timestamp map
                val cumulativeTime = shotTimestamps.find { it.first == shotIndex }?.second ?: shot.content.actualTimeDiff
                
                ShotListItem(
                    shotNumber = shotIndex + 1,
                    hitArea = translateHitArea(shot.content.actualHitArea),
                    cumulativeTime = cumulativeTime,
                    timeDiff = shot.content.actualTimeDiff,
                    isSelected = selectedShotIndex == shotIndex,
                    isEven = position % 2 == 0,
                    onClick = { onShotSelected(if (selectedShotIndex == shotIndex) null else shotIndex) }
                )
            }
        }

        // Scroll indicator (appears when content is scrollable)
        if (targetShots.size > 0) {
            val canScrollDown = scrollState.canScrollForward
            if (canScrollDown) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 4.dp)
                        .size(24.dp)
                        .background(Color.White.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "▼",
                        color = Color.White,
                        fontSize = 10.sp
                    )
                }
            }
        }
    }
}

/**
 * Individual shot item in the list.
 * Displays cumulative time (matching iOS behavior) along with delta time.
 */
@Composable
private fun ShotListItem(
    shotNumber: Int,
    hitArea: String,
    cumulativeTime: Double,
    timeDiff: Double,
    isSelected: Boolean,
    isEven: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp, horizontal = 8.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isEven) Color.White.copy(alpha = 0.03f)
                else Color.White.copy(alpha = 0.06f)
            )
            .border(
                width = if (isSelected) 2.dp else 0.dp,
                color = if (isSelected) Color.Red.copy(alpha = 0.95f) else Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "#$shotNumber",
            modifier = Modifier.width(64.dp),
            textAlign = TextAlign.Center,
            color = Color.White
        )
        Text(
            text = hitArea,
            modifier = Modifier.width(80.dp),
            textAlign = TextAlign.Center,
            color = Color.White
        )
        // Display cumulative time to match iOS chronological ordering
        Text(
            text = String.format("%.2f", cumulativeTime),
            modifier = Modifier.width(80.dp),
            textAlign = TextAlign.Center,
            color = Color.White.copy(alpha = 0.9f)
        )
    }
}

/**
 * Checks if a hit area is a scoring zone.
 * Ported from iOS isScoringZone function.
 */
private fun isScoringZone(hitArea: String): Boolean {
    val trimmed = hitArea.trim().lowercase()
    return trimmed == "azone" || trimmed == "czone" || trimmed == "dzone"
}

/**
 * Translates hit area codes to display text.
 * Ported from iOS translateHitArea function.
 */
private fun translateHitArea(hitArea: String): String {
    val trimmed = hitArea.trim().lowercase()
    return when (trimmed) {
        "azone" -> "A Zone"
        "czone" -> "C Zone"
        "dzone" -> "D Zone"
        "miss" -> "Miss"
        "barrel_miss" -> "Barrel Miss"
        "circlearea" -> "Circle Area"
        "standarea" -> "Stand Area"
        "popperzone" -> "Popper Zone"
        "blackzone" -> "Black Zone"
        "blackzoneleft" -> "Black Zone Left"
        "blackzoneright" -> "Black Zone Right"
        "whitezone" -> "White Zone"
        else -> hitArea
    }
}

// Preview function for testing
@Composable
fun DrillResultViewPreview() {
    // Create mock data for preview
    val mockDrillSetup = DrillSetupEntity(
        name = "Test Drill",
        desc = "Test drill description"
    )

    val mockTargets = listOf(
        DrillTargetsConfigData(
            targetName = "Target 1",
            targetType = "hostage"
        )
    )

    val mockShots = listOf(
        ShotData(
            content = Content(
                command = "shot",
                hitArea = "A",
                hitPosition = Position(x = 360.0, y = 640.0),
                targetType = "hostage",
                timeDiff = 1.25
            )
        ),
        ShotData(
            content = Content(
                command = "shot",
                hitArea = "C",
                hitPosition = Position(x = 400.0, y = 700.0),
                targetType = "hostage",
                timeDiff = 2.1
            )
        )
    )

    val mockRepeatSummary = DrillRepeatSummary(
        repeatIndex = 1,
        totalTime = 3.5,
        numShots = 2,
        firstShot = 1.25,
        fastest = 0.85,
        score = 15,
        shots = mockShots,
        drillResultId = null
    )

    DrillResultView(
        drillSetup = mockDrillSetup,
        targets = mockTargets,
        repeatSummary = mockRepeatSummary
    )
}