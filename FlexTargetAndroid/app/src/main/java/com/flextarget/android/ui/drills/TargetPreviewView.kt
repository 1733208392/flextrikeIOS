package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import com.flextarget.android.R
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.foundation.shape.RoundedCornerShape
import android.graphics.BitmapFactory
import com.flextarget.android.data.model.ShotData

/**
 * Preview display showing the target image with bullet hole overlays
 * Designed to match iOS implementation with proper 9:16 aspect ratio and styling
 * Loads target images from assets folder
 */
@Composable
fun TargetPreviewView(
    shots: List<ShotData>,
    currentShotIndex: Int,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val parentWidthPx = remember { mutableFloatStateOf(0f) }
    val parentHeightPx = remember { mutableFloatStateOf(0f) }
    
    Box(
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { size ->
                parentWidthPx.floatValue = size.width.toFloat()
                parentHeightPx.floatValue = size.height.toFloat()
            }
    ) {
        if (shots.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                Text(stringResource(R.string.no_shots_to_display), color = Color.Gray)
            }
            return@Box
        }

        // Get the current shot and active target type
        val currentShot = shots.getOrNull(currentShotIndex)
        val activeTargetType = currentShot?.content?.actualTargetType ?: "ipsc"

        // Get all shots up to current that match the current target type
        val relevantShots = shots
            .take(currentShotIndex + 1)
            .filter { it.content.actualTargetType == activeTargetType }

        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            // Target image from assets
            val assetName = TargetAssetMapper.getTargetImageAssetName(activeTargetType)
            val imageBitmap = loadImageFromAssets(context, assetName)

            if (imageBitmap != null) {
                Image(
                    bitmap = imageBitmap,
                    contentDescription = "Target",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit,
                    alignment = Alignment.Center
                )
            } else {
                // Fallback: show solid gray background with target type label
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.DarkGray),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = activeTargetType.uppercase(),
                        color = Color.White.copy(alpha = 0.5f),
                        style = MaterialTheme.typography.headlineSmall
                    )
                }
            }

            // Overlay bullet holes for relevant shots - rendered on top of image
            // First render scoring zone shots (back layer)
            relevantShots
                .filter { isScoringZone(it.content.actualHitArea) }
                .forEach { shot ->
                    renderBulletHole(
                        shot,
                        shots.indexOf(shot) == currentShotIndex,
                        parentWidthPx.floatValue,
                        parentHeightPx.floatValue
                    )
                }

            // Then render non-scoring zone shots (front layer)
            relevantShots
                .filter { !isScoringZone(it.content.actualHitArea) }
                .forEach { shot ->
                    renderBulletHole(
                        shot,
                        shots.indexOf(shot) == currentShotIndex,
                        parentWidthPx.floatValue,
                        parentHeightPx.floatValue
                    )
                }

            // Target name label at top-left
            val displayTargetName = currentShot?.device

            Box(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(12.dp)
                    .background(Color.Black.copy(alpha = 0.7f), shape = RoundedCornerShape(4.dp))
                    .padding(6.dp)
            ) {
                Text(
                    text = displayTargetName?.uppercase() ?:"",
                    color = Color.White,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
    }
}

/**
 * Render a bullet hole with optional highlight
 * Positions bullet hole based on normalized coordinates from 9:16 aspect ratio (720x1280 space)
 * Uses bullet_hole drawable
 */
@Composable
private fun BoxScope.renderBulletHole(
    shot: ShotData,
    isSelected: Boolean,
    parentWidthPx: Float,
    parentHeightPx: Float
) {
    val density = LocalDensity.current
    
    val hitPos = shot.content.actualHitPosition
    // Normalize coordinates based on target image space: 720(width) x 1280(height)
    val xFraction = (hitPos.x / 720.0).toFloat().coerceIn(0f, 1f)
    val yFraction = (hitPos.y / 1280.0).toFloat().coerceIn(0f, 1f)

    // Calculate offset in dp based on parent size in pixels
    val offsetXDp = with(density) { (xFraction * parentWidthPx).toDp() } - 8.dp
    val offsetYDp = with(density) { (yFraction * parentHeightPx).toDp() } - 8.dp

    Box(
        modifier = Modifier
            .align(Alignment.TopStart)
            .offset(x = offsetXDp, y = offsetYDp)
            .size(width = 16.dp, height = 16.dp)
    ) {
        // Bullet hole drawable
        Image(
            painter = painterResource(id = R.drawable.ft_bullet_hole),
            contentDescription = "Bullet hole",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit
        )

        // Selection highlight (yellow border) for current shot
        if (isSelected) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(2.dp, Color.Yellow)
            )
        }
    }
}

/**
 * Check if a hit area is a scoring zone
 */
private fun isScoringZone(hitArea: String): Boolean {
    val trimmed = hitArea.trim().lowercase()
    return trimmed in listOf("azone", "czone", "dzone", "head", "body")
}

/**
 * Load image from assets folder
 */
private fun loadImageFromAssets(context: android.content.Context, assetName: String): ImageBitmap? {
    return try {
        val inputStream = context.assets.open(assetName)
        val bitmap = BitmapFactory.decodeStream(inputStream)
        inputStream.close()
        bitmap?.asImageBitmap()
    } catch (e: Exception) {
        null
    }
}
