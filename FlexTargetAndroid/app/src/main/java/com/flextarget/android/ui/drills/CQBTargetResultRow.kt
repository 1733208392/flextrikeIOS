package com.flextarget.android.ui.drills

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Divider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.flextarget.android.data.model.CQBShotResult

@Composable
fun CQBTargetResultRow(
    results: List<CQBShotResult>,
    modifier: Modifier = Modifier
) {
    if (results.isEmpty()) {
        return
    }

    Spacer(modifier = Modifier.height(12.dp))
    
    Divider(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        color = Color.White.copy(alpha = 0.1f),
        thickness = 1.dp
    )

    LazyRow(
        modifier = modifier
            .fillMaxWidth()
            .height(130.dp)
            .padding(horizontal = 12.dp, vertical = 12.dp),
    ) {
        items(results) { result ->
            CQBTargetResultCard(result = result)
            Spacer(modifier = Modifier.width(12.dp))
        }
    }

    Divider(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp),
        color = Color.White.copy(alpha = 0.1f),
        thickness = 1.dp
    )
}
