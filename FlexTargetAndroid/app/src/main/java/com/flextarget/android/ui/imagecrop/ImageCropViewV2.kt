package com.flextarget.android.ui.imagecrop

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Space
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.Image
import androidx.compose.foundation.magnifier
import androidx.compose.ui.graphics.asImageBitmap
import coil.compose.AsyncImage
import kotlinx.coroutines.launch
import androidx.compose.ui.res.stringResource
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import com.flextarget.android.R
import com.flextarget.android.ui.theme.md_theme_dark_onPrimary
import com.flextarget.android.ui.theme.md_theme_dark_primary

@Composable
fun ImageCropViewV2(onDismiss: () -> Unit) {
    val viewModel: ImageCropViewModelV2 = viewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val selectedImage by viewModel.image.collectAsState()
    val scale by viewModel.scale.collectAsState()
    val offsetX by viewModel.offsetX.collectAsState()
    val offsetY by viewModel.offsetY.collectAsState()
    val transferProgress by viewModel.transferProgress.collectAsState()
    val isTransferring by viewModel.isTransferring.collectAsState()
    
    // Track actual measured dimensions of the preview container
    var containerWidth by remember { mutableStateOf(480f) }
    var containerHeight by remember { mutableStateOf(480f) }

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
        TopAppBar(
            title = { Text(stringResource(R.string.upload_target_image_title), color = md_theme_dark_onPrimary) },
            navigationIcon = {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = md_theme_dark_onPrimary)
                }
            },
            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                containerColor = Color.Black
            )
        )

        Spacer(modifier = Modifier.height(24.dp))

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(previewSize)
                .background(Color.Black)
                .onSizeChanged { size ->
                    // Update ViewModel with actual pixel dimensions (accounts for device density)
                    containerWidth = size.width.toFloat()
                    containerHeight = size.height.toFloat()
                    viewModel.setPreviewSize(containerWidth, containerHeight)
                }
                .pointerInput(Unit) {
                    detectTransformGestures { _, pan, zoom, _ ->
                        val newScale = (scale * zoom).coerceIn(1f, 3f)
                        viewModel.setScale(newScale)
                        val newOffsetX = offsetX + pan.x
                        val newOffsetY = offsetY + pan.y
                        if (selectedImage != null) {
                            val scaledWidth = containerWidth * newScale
                            val scaledHeight = containerHeight * newScale
                            val maxOffsetX = (scaledWidth - containerWidth) / 2f
                            val clampedX = newOffsetX.coerceIn(-maxOffsetX, maxOffsetX)
                            val maxOffsetY = (scaledHeight - containerHeight) / 2f
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

            // Progress indicator overlay (shown during transfer)
            if (isTransferring) {
                LinearProgressIndicator(
                    progress = (transferProgress / 100f).coerceIn(0f, 1f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .align(Alignment.TopCenter),
                    color = md_theme_dark_onPrimary,
                    trackColor = Color.DarkGray
                )
            }
        }

        Spacer(modifier = Modifier.height(48.dp))

        // Action button below preview: Select or Confirm & Transfer
        Button(
            onClick = {
                if (selectedImage == null) {
                    imagePickerLauncher.launch("image/*")
                } else {
                    scope.launch {
                        viewModel.transferCroppedImage(
                            onSuccess = { _ -> onDismiss() },
                            onError = { error -> android.util.Log.e("ImageCropTransfer", "Transfer error: $error") }
                        )
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth(0.75f)
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = md_theme_dark_onPrimary),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text(
                if (selectedImage == null) stringResource(R.string.select) else "CONFIRM & TRANSFER",
                color = md_theme_dark_primary,
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
}
