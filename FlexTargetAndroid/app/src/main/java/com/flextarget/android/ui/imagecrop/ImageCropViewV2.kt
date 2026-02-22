package com.flextarget.android.ui.imagecrop

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary

@Composable
fun ImageCropViewV2(onDismiss: () -> Unit) {
    val viewModel: ImageCropViewModelV2 = viewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val selectedImage by viewModel.image.collectAsState()
    val scale by viewModel.scale.collectAsState()
    val offsetX by viewModel.offsetX.collectAsState()
    val offsetY by viewModel.offsetY.collectAsState()

    DisposableEffect(Unit) {
        onDispose { viewModel.clearImage() }
    }

    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            scope.launch {
                try {
                    context.contentResolver.openInputStream(it)?.use { stream ->
                        val bitmap = BitmapFactory.decodeStream(stream)
                        bitmap?.let { bmp -> viewModel.setImage(bmp) }
                    }
                } catch (e: Exception) {}
            }
        }
    }

    val previewSize = 480.dp

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onDismiss) {
                Text("←", color = Color.White)
            }
            Spacer(modifier = Modifier.weight(1f))
            Button(
                onClick = { imagePickerLauncher.launch("image/*") },
                modifier = Modifier.height(44.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Gray),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("Select", color = Color.White)
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(previewSize)
                .background(Color.Black)
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        val newScale = (scale * zoom).coerceIn(1f, 3f)
                        viewModel.setScale(newScale)
                        val newOffsetX = offsetX + pan.x
                        val newOffsetY = offsetY + pan.y
                        if (selectedImage != null) {
                            val containerSizePx = 480f
                            val scaledWidth = containerSizePx * newScale
                            val scaledHeight = containerSizePx * newScale
                            val maxOffsetX = (scaledWidth - containerSizePx) / 2f
                            val clampedX = newOffsetX.coerceIn(-maxOffsetX, maxOffsetX)
                            val maxOffsetY = (scaledHeight - containerSizePx) / 2f
                            val clampedY = newOffsetY.coerceIn(-maxOffsetY, maxOffsetY)
                            viewModel.setOffset(clampedX, clampedY)
                        }
                    }
                }
        ) {
            selectedImage?.let { bitmap ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(0.dp))
                ) {
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "Selected photo",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .graphicsLayer(
                                scaleX = scale,
                                scaleY = scale,
                                translationX = offsetX,
                                translationY = offsetY
                            )
                    )
                }
            }

            if (selectedImage == null) {
                Text(
                    "No image selected",
                    color = Color.Gray,
                    modifier = Modifier.align(Alignment.Center)
                )
            }

            AsyncImage(
                model = "file:///android_asset/custom-target-guide.svg",
                contentDescription = "Target guide overlay",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .height(previewSize)
                    .align(Alignment.Center)
                    .background(Color.Transparent)
            )

            AsyncImage(
                model = "file:///android_asset/custom-target-border.svg",
                contentDescription = "Target border overlay",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .height(previewSize)
                    .align(Alignment.Center)
                    .background(Color.Transparent)
            )
        }

        // Confirm and Transfer Button - below preview area
        Button(
            onClick = {
                scope.launch {
                    viewModel.transferCroppedImage(
                        onSuccess = { message ->
                            // TODO: Show success toast or notification
                            onDismiss()
                        },
                        onError = { error ->
                            // TODO: Show error toast
                            // For now, log it
                            android.util.Log.e("ImageCropTransfer", "Transfer error: $error")
                        }
                    )
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD32F2F)),
            enabled = selectedImage != null
        ) {
            Text(
                "CONFIRM AND TRANSFER",
                color = md_theme_dark_onPrimary,
                fontSize = MaterialTheme.typography.titleMedium.fontSize
            )
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}
