package com.flextarget.android.ui.drills

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.flextarget.android.ui.theme.ttNormFontFamily

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameDrillResultView(
    gameName: String,
    score: String,
    hits: String,
    misses: String,
    onReplay: () -> Unit = {},
    onDone: () -> Unit
) {
    val accentRed = Color(0xffde3823)
    val darkBackground = Color.Black

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "GAME RESULTS",
                        color = accentRed,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = ttNormFontFamily
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onDone) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = accentRed
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = darkBackground
                )
            )
        },
        containerColor = darkBackground
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Header Info
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = gameName.uppercase(),
                    color = accentRed,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = ttNormFontFamily
                )
                Spacer(modifier = Modifier.height(40.dp))
                
                // Big Score Display
                Text(
                    text = "SCORE",
                    color = Color.Gray,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = ttNormFontFamily
                )
                Text(
                    text = score,
                    color = accentRed,
                    fontSize = 72.sp,
                    fontWeight = FontWeight.Black,
                    fontFamily = ttNormFontFamily,
                    textAlign = TextAlign.Center
                )
            }

            // Stats Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                GameStatItem(label = "HITS", value = hits, color = Color.Green)
                GameStatItem(label = "MISSES", value = misses, color = accentRed)
            }

            // Buttons
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 60.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Button(
                    onClick = onReplay,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = accentRed),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        Icons.Default.Refresh,
                        contentDescription = null,
                        tint = Color(0xff191919)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "REPLAY",
                        color = Color(0xff191919),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = ttNormFontFamily
                    )
                }

                OutlinedButton(
                    onClick = onDone,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    border = androidx.compose.foundation.BorderStroke(1.dp, Color.Gray),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.White)
                ) {
                    Text(
                        "DONE",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = ttNormFontFamily
                    )
                }
            }
        }
    }
}

@Composable
fun GameStatItem(label: String, value: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = label,
            color = Color.Gray,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = ttNormFontFamily
        )
        Text(
            text = value,
            color = color,
            fontSize = 32.sp,
            fontWeight = FontWeight.Black,
            fontFamily = ttNormFontFamily
        )
    }
}
