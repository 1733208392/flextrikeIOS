package com.flextarget.android.ui.qr

import android.Manifest
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.statusBars

private const val TAG = "QRScannerView"

@Composable
fun QRScannerView(
    onQRScanned: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current

    var hasCameraPermission by remember { mutableStateOf(false) }
    var scannedText by remember { mutableStateOf<String?>(null) }
    var showResult by remember { mutableStateOf(false) }
    var scanY by remember { mutableStateOf(0f) }

    // Camera permission launcher
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasCameraPermission = granted
    }

    // Check and request camera permission
    LaunchedEffect(Unit) {
        val permission = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
        if (permission == PackageManager.PERMISSION_GRANTED) {
            hasCameraPermission = true
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    // Animate scanning line
    LaunchedEffect(Unit) {
        while (true) {
            scanY = 0f
            delay(2000)
            scanY = 300f
            delay(2000)
        }
    }

    Box(modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.statusBars)) {
        if (hasCameraPermission) {
            // Camera preview with QR scanning
            QRScannerCameraView(
                onQRCodeScanned = { code ->
                    if (!showResult) {
                        scannedText = code
                        showResult = true
                        onQRScanned(code)
                    }
                },
                scanY = scanY
            )
        } else {
            // Permission denied view
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Camera permission is required for QR scanning",
                    color = Color.White,
                    fontSize = 16.sp
                )
            }
        }

        // Back button
        Box(modifier = Modifier.fillMaxSize()) {
            Text(
                text = "←",
                color = Color.Red,
                fontSize = 24.sp,
                modifier = Modifier.align(Alignment.TopStart).clickable { onDismiss() }.padding(16.dp)
            )
        }

        // Result overlay
        if (showResult && scannedText != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.85f)),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(20.dp)
                ) {
                    Text(
                        text = "QR Code Scanned",
                        style = MaterialTheme.typography.headlineSmall,
                        color = Color.White
                    )

                    Text(
                        text = scannedText!!,
                        style = MaterialTheme.typography.bodyLarge,
                        color = Color.White,
                        modifier = Modifier
                            .background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(10.dp))
                            .padding(16.dp)
                    )

                    Button(
                        onClick = onDismiss,
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Green)
                    ) {
                        Text("Done", color = Color.White)
                    }
                }
            }
        }
    }
}

@Composable
private fun QRScannerCameraView(
    onQRCodeScanned: (String) -> Unit,
    scanY: Float
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val previewView = remember { PreviewView(context) }
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }

    // QR Scanner
    val barcodeScanner = remember {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
        BarcodeScanning.getClient(options)
    }

    // Image analysis for QR scanning
    val imageAnalysis = remember {
        ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { analysis ->
                analysis.setAnalyzer(ContextCompat.getMainExecutor(context)) { imageProxy ->
                    processImageProxy(barcodeScanner, imageProxy, onQRCodeScanned)
                }
            }
    }

    // Camera setup
    LaunchedEffect(cameraProviderFuture) {
        val cameraProvider = cameraProviderFuture.get()
        val preview = Preview.Builder().build().also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }

        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                imageAnalysis
            )
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
        }
    }

    // Lifecycle observer to handle camera cleanup
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_DESTROY) {
                barcodeScanner.close()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Camera preview
        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize()
        )

        // Dark overlay with transparent scan area
        Canvas(modifier = Modifier.fillMaxSize()) {
            // Draw dark overlay
            drawRect(Color.Black.copy(alpha = 0.7f))

            // Create transparent scan area (75% of screen width)
            val scanAreaSize = size.width * 0.75f
            val scanAreaLeft = (size.width - scanAreaSize) / 2
            val scanAreaTop = (size.height - scanAreaSize) / 2

            // Clear the scan area
            drawRect(
                Color.Transparent,
                topLeft = Offset(scanAreaLeft, scanAreaTop),
                size = Size(scanAreaSize, scanAreaSize)
            )

            // Draw corner brackets
            drawCornerBrackets(scanAreaLeft, scanAreaTop, scanAreaSize)

            // Draw animated scanning line
            val lineY = scanAreaTop + scanY
            if (lineY >= scanAreaTop && lineY <= scanAreaTop + scanAreaSize) {
                drawLine(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.Green.copy(alpha = 0f),
                            Color.Green.copy(alpha = 0.8f),
                            Color.Green.copy(alpha = 0f)
                        )
                    ),
                    start = Offset(scanAreaLeft + 20, lineY),
                    end = Offset(scanAreaLeft + scanAreaSize - 20, lineY),
                    strokeWidth = 3f
                )
            }
        }

        // Instructions
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 100.dp),
            verticalArrangement = Arrangement.Bottom,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Align QR code within the frame",
                color = Color.White,
                fontSize = 16.sp,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawCornerBrackets(
    left: Float,
    top: Float,
    size: Float
) {
    val bracketLength = 30f
    val bracketThickness = 4f

    // Top-left corner
    drawLine(
        Color.Green,
        start = Offset(left, top + bracketLength),
        end = Offset(left, top),
        strokeWidth = bracketThickness
    )
    drawLine(
        Color.Green,
        start = Offset(left, top),
        end = Offset(left + bracketLength, top),
        strokeWidth = bracketThickness
    )

    // Top-right corner
    drawLine(
        Color.Green,
        start = Offset(left + size - bracketLength, top),
        end = Offset(left + size, top),
        strokeWidth = bracketThickness
    )
    drawLine(
        Color.Green,
        start = Offset(left + size, top),
        end = Offset(left + size, top + bracketLength),
        strokeWidth = bracketThickness
    )

    // Bottom-left corner
    drawLine(
        Color.Green,
        start = Offset(left, top + size - bracketLength),
        end = Offset(left, top + size),
        strokeWidth = bracketThickness
    )
    drawLine(
        Color.Green,
        start = Offset(left, top + size),
        end = Offset(left + bracketLength, top + size),
        strokeWidth = bracketThickness
    )

    // Bottom-right corner
    drawLine(
        Color.Green,
        start = Offset(left + size - bracketLength, top + size),
        end = Offset(left + size, top + size),
        strokeWidth = bracketThickness
    )
    drawLine(
        Color.Green,
        start = Offset(left + size, top + size),
        end = Offset(left + size, top + size - bracketLength),
        strokeWidth = bracketThickness
    )
}

private fun processImageProxy(
    barcodeScanner: BarcodeScanner,
    imageProxy: ImageProxy,
    onQRCodeScanned: (String) -> Unit
) {
    val mediaImage = imageProxy.image
    if (mediaImage != null) {
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        barcodeScanner.process(image)
            .addOnSuccessListener { barcodes ->
                // Process only the first QR code
                barcodes.firstOrNull()?.rawValue?.let { qrCode ->
                    Log.d(TAG, "QR Code scanned: $qrCode")
                    onQRCodeScanned(qrCode)
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "Barcode scanning failed", e)
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    } else {
        imageProxy.close()
    }
}