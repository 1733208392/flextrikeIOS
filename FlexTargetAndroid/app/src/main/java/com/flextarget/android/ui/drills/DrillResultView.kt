package com.flextarget.android.ui.drills

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.R
import com.flextarget.android.data.local.entity.DrillSetupEntity
import com.flextarget.android.data.model.*
import java.util.*

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
    val context = LocalContext.current
    val displayShots = repeatSummary?.shots ?: shots

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
                    text = "Drill Results",
                    color = Color.White,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold
                )
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.Default.ArrowBack,
                        contentDescription = "Back",
                        tint = Color.White
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
                .fillMaxSize()
                .weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
        // Target display area
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            TargetDisplayView(
                targets = targets,
                shots = displayShots,
                selectedTargetIndex = selectedTargetIndex,
                selectedShotIndex = selectedShotIndex,
                onTargetSelected = { selectedTargetIndex = it },
                onShotSelected = { selectedShotIndex = it },
                frameWidth = frameWidth,
                frameHeight = frameHeight,
                modifier = Modifier
                    .padding(16.dp)
            )
        }

        // Shot list
        Divider(color = Color.White.copy(alpha = 0.3f))
        ShotListView(
            shots = displayShots,
            selectedTargetIndex = selectedTargetIndex,
            selectedShotIndex = selectedShotIndex,
            targets = targets,
            onShotSelected = { selectedShotIndex = it },
            modifier = Modifier
                .height(200.dp)
                .padding(horizontal = 16.dp)
        )

        // Status bar
//        Row(
//            modifier = Modifier
//                .fillMaxWidth()
//                .padding(horizontal = 20.dp, vertical = 20.dp),
//            horizontalArrangement = Arrangement.SpaceBetween,
//            verticalAlignment = Alignment.CenterVertically
//        ) {
//            Text(
//                text = "Drill Completed",
//                style = MaterialTheme.typography.headlineSmall,
//                color = Color.White
//            )
//            Text(
//                text = "${displayShots.size} shots",
//                style = MaterialTheme.typography.bodyLarge,
//                color = Color.White.copy(alpha = 0.85f)
//            )
//        }
        }
    }
}

/**
 * Maps target types to their corresponding image asset filenames.
 */
private fun getTargetImageAssetName(targetType: String): String {
    return when (targetType.lowercase()) {
        "ipsc" -> "ipsc.live.target.png"
        "hostage" -> "hostage.live.target.png"
        "popper" -> "popper.live.target.png"
        "paddle" -> "paddle.live.target.png"
        "special_1" -> "ipsc.special.1.live.target.png"
        "special_2" -> "ipsc.special.2.live.target.png"
        "rotation" -> "drills_back.jpg"
        else -> "ipsc.live.target.png" // Default to IPSC
    }
}

/**
 * Displays targets with bullet holes positioned according to shot coordinates.
 * Ported from iOS TargetDisplayView.
 */
@Composable
private fun TargetDisplayView(
    targets: List<DrillTargetsConfigData>,
    shots: List<ShotData>,
    selectedTargetIndex: Int,
    selectedShotIndex: Int?,
    onTargetSelected: (Int) -> Unit,
    onShotSelected: (Int?) -> Unit,
    frameWidth: androidx.compose.ui.unit.Dp,
    frameHeight: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val currentTarget = targets.getOrNull(selectedTargetIndex)
    val targetType = currentTarget?.targetType ?: "ipsc"
    val imageAssetName = getTargetImageAssetName(targetType)

    Box(modifier = modifier) {
        // Target background with image
        Box(
            modifier = Modifier
                .size(frameWidth, frameHeight)
        //        .clip(RoundedCornerShape(8.dp))
                .background(Color.Black)
        //      .border(2.dp, Color.White, RoundedCornerShape(8.dp))
        ) {
            // Load and display target image from assets
            AsyncImage(
                model = ImageRequest.Builder(context)
                    .data("file:///android_asset/$imageAssetName")
                    .crossfade(true)
                    .build(),
                contentDescription = "Target image",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )

            // Target name overlay
            currentTarget?.targetName?.let { name ->
                Text(
                    text = name,
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(6.dp)
//                        .background(Color.Black.copy(alpha = 0.8f), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }

            // Bullet holes overlay
            Canvas(modifier = Modifier.fillMaxSize()) {
                val canvasWidth = size.width
                val canvasHeight = size.height

                shots.forEachIndexed { index, shot ->
                    // Check if shot matches current target
                    val shotDevice = shot.device?.trim()?.lowercase()
                    val targetName = currentTarget?.targetName?.trim()?.lowercase()
                    val shotTargetType = shot.content.actualTargetType.lowercase()

                    val matchesTarget = when {
                        targetName != null && shotDevice == targetName -> true
                        targetType == shotTargetType -> true
                        else -> false
                    }

                    if (matchesTarget) {
                        // Transform coordinates from 720x1280 to canvas size
                        val transformedX = (shot.content.actualHitPosition.x / 720.0) * canvasWidth.toDouble()
                        val transformedY = (shot.content.actualHitPosition.y / 1280.0) * canvasHeight.toDouble()

                        val isScoring = isScoringZone(shot.content.actualHitArea)
                        val isSelected = selectedShotIndex == index

                        // Draw bullet hole with different appearance for scoring vs non-scoring
                        val holeColor = if (isScoring) Color.White else Color.Red.copy(alpha = 0.7f)
                        val holeSize = if (isSelected) 21f else 15f

                        // Draw selection circle if selected
                        if (isSelected) {
                            drawCircle(
                                color = Color.Yellow.copy(alpha = 0.8f),
                                radius = holeSize / 2 + 3,
                                center = Offset(transformedX.toFloat(), transformedY.toFloat())
                            )
                        }

                        // Draw bullet hole
                        drawCircle(
                            color = holeColor,
                            radius = holeSize / 2,
                            center = Offset(transformedX.toFloat(), transformedY.toFloat())
                        )

                        // Add border for non-scoring shots
                        if (!isScoring) {
                            drawCircle(
                                color = Color.Red,
                                radius = holeSize / 2,
                                center = Offset(transformedX.toFloat(), transformedY.toFloat()),
                                style = Stroke(width = 2f)
                            )
                        }
                    }
                }
            }

            // Special handling for rotation targets
            if (targetType.lowercase() == "rotation") {
                RotationOverlay(
                    shots = shots,
                    selectedShotIndex = selectedShotIndex,
                    frameWidth = frameWidth,
                    frameHeight = frameHeight
                )
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
    targets: List<DrillTargetsConfigData>,
    onShotSelected: (Int?) -> Unit,
    modifier: Modifier = Modifier
) {
    val currentTarget = targets.getOrNull(selectedTargetIndex)

    // Filter shots for current target
    val targetShots = shots.mapIndexedNotNull { index, shot ->
        val shotDevice = shot.device?.trim()?.lowercase()
        val targetName = currentTarget?.targetName?.trim()?.lowercase()
        val shotTargetType = shot.content.actualTargetType.lowercase()

        val matchesTarget = when {
            targetName != null && shotDevice == targetName -> true
            currentTarget?.targetType == shotTargetType -> true
            else -> false
        }

        if (matchesTarget) index to shot else null
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        itemsIndexed(targetShots) { position, (shotIndex, shot) ->
            ShotListItem(
                shotNumber = shotIndex + 1,
                hitArea = translateHitArea(shot.content.actualHitArea),
                timeDiff = shot.content.actualTimeDiff,
                isSelected = selectedShotIndex == shotIndex,
                isEven = position % 2 == 0,
                onClick = { onShotSelected(if (selectedShotIndex == shotIndex) null else shotIndex) }
            )
        }
    }
}

/**
 * Individual shot item in the list.
 */
@Composable
private fun ShotListItem(
    shotNumber: Int,
    hitArea: String,
    timeDiff: Double,
    isSelected: Boolean,
    isEven: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp, horizontal = 16.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (isEven) Color.White.copy(alpha = 0.03f)
                else Color.White.copy(alpha = 0.06f)
            )
            .border(
                width = if (isSelected) 2.dp else 0.dp,
                color = if (isSelected) Color.Red.copy(alpha = 0.95f) else Color.Transparent,
                shape = RoundedCornerShape(10.dp)
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
        Text(
            text = String.format("%.2f", timeDiff),
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
        shots = mockShots
    )

    DrillResultView(
        drillSetup = mockDrillSetup,
        targets = mockTargets,
        repeatSummary = mockRepeatSummary
    )
}