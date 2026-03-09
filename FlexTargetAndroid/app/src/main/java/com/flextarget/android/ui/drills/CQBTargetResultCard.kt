package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.decode.SvgDecoder
import coil.request.ImageRequest
import com.flextarget.android.R
import com.flextarget.android.data.model.CQBShotResult

@Composable
fun CQBTargetResultCard(result: CQBShotResult) {
    val context = LocalContext.current
    
    val assetPath = when (result.targetName) {
        "cqb_front" -> "cqb_front.svg"
        "cqb_swing" -> "cqb_swing.svg"
        "cqb_hostage" -> "cqb_hostoage.svg" // Note: confirmed filename is 'cqb_hostoage.svg' from list_dir
        "disguised_enemy" -> "disguise_enemy.svg"
        else -> null
    }

    Box(
        modifier = Modifier
            .width(90.dp)
            .height(110.dp)
    ) {
        // Card background
        Card(
            modifier = Modifier.fillMaxSize(),
            elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF2a2a2a)),
            shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                if (assetPath != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(context)
                            .data("file:///android_asset/$assetPath")
                            .decoderFactory(SvgDecoder.Factory())
                            .build(),
                        contentDescription = result.targetName,
                        modifier = Modifier
                            .size(60.dp)
                            .padding(4.dp)
                    )
                } else {
                    Text(
                        text = stringResource(
                            id = when (result.targetName) {
                                "cqb_front" -> R.string.cqb_front
                                "cqb_swing" -> R.string.cqb_swing
                                "cqb_hostage" -> R.string.cqb_hostage
                                "disguised_enemy" -> R.string.disguised_enemy
                                else -> R.string.cqb // fallback
                            }
                        ),
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(4.dp),
                        maxLines = 2
                    )
                }
            }
        }

        // Colored overlay based on pass/fail status
        val overlayColor = if (result.cardStatus == CQBShotResult.CardStatus.green) {
            Color(0xFF4CAF50) // Green
        } else {
            Color(0xFFDD0000) // Red
        }
        
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    color = overlayColor.copy(alpha = 0.5f),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
                )
        )
    }
}
