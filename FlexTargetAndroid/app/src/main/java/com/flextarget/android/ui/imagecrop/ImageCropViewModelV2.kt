package com.flextarget.android.ui.imagecrop

import android.graphics.Bitmap
import android.util.Log
import androidx.lifecycle.ViewModel
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.ImageTransferManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * ViewModel for Image Crop Guide with cropping and transfer support
 * Manages image, scale, offset state and cropping logic
 */
class ImageCropViewModelV2 : ViewModel() {
    private val bleManager = BLEManager.shared
    private val imageTransferManager = ImageTransferManager(bleManager)
    
    private val _image = MutableStateFlow<Bitmap?>(null)
    val image: StateFlow<Bitmap?> = _image.asStateFlow()

    private val _scale = MutableStateFlow(1f)
    val scale: StateFlow<Float> = _scale.asStateFlow()

    private val _offsetX = MutableStateFlow(0f)
    val offsetX: StateFlow<Float> = _offsetX.asStateFlow()

    private val _offsetY = MutableStateFlow(0f)
    val offsetY: StateFlow<Float> = _offsetY.asStateFlow()

    // Store actual preview dimensions in pixels (accounts for device density)
    private val _previewWidthPx = MutableStateFlow(480f)
    val previewWidthPx: StateFlow<Float> = _previewWidthPx.asStateFlow()

    private val _previewHeightPx = MutableStateFlow(480f)
    val previewHeightPx: StateFlow<Float> = _previewHeightPx.asStateFlow()

    // Transfer progress state
    private val _transferProgress = MutableStateFlow(0)
    val transferProgress: StateFlow<Int> = _transferProgress.asStateFlow()

    private val _isTransferring = MutableStateFlow(false)
    val isTransferring: StateFlow<Boolean> = _isTransferring.asStateFlow()

    fun setPreviewSize(widthPx: Float, heightPx: Float) {
        _previewWidthPx.value = widthPx
        _previewHeightPx.value = heightPx
    }

    fun setImage(bitmap: Bitmap) {
        _image.value = bitmap
        // Reset transform when new image is selected
        _scale.value = 1f
        _offsetX.value = 0f
        _offsetY.value = 0f
    }

    fun setScale(scale: Float) {
        _scale.value = scale.coerceIn(1f, 5f)
    }

    fun setOffset(offsetX: Float, offsetY: Float) {
        _offsetX.value = offsetX
        _offsetY.value = offsetY
    }

    fun clearImage() {
        _image.value = null
        _scale.value = 1f
        _offsetX.value = 0f
        _offsetY.value = 0f
    }

    /**
     * Crop the image based on the guide boundaries (720x1280 aspect ratio, 9:16)
     * and the current transform (scale and offset).
     * 
     * The guide is displayed in the preview with a 9:16 aspect ratio.
     * The image is displayed using ContentScale.Crop, which applies an initial scaling.
     * User zoom/pan are applied on top via graphicsLayer.
     * 
     * Transformation chain:
     * 1. Original image coords → scaled by ContentScale.Crop → positioned (centered)
     * 2. Scaled+positioned image → transformed by user (zoom + pan)
     * 3. Result → displayed in preview
     * 
     * To reverse: preview coords → undo user transform → undo ContentScale positioning
     *             → undo ContentScale scaling → original image coords
     */
    fun cropImageForTransfer(): Bitmap? {
        val bitmap = _image.value ?: return null
        val currentScale = _scale.value
        val currentOffsetX = _offsetX.value
        val currentOffsetY = _offsetY.value

        // Get actual preview dimensions in pixels
        val previewHeightPx = _previewHeightPx.value
        val previewWidthPx = _previewWidthPx.value
        
        // Guide dimensions (9:16 aspect ratio, spans full preview height)
        val guideHeight = previewHeightPx
        val guideWidth = guideHeight * (9f / 16f)
        val guideLeft = (previewWidthPx - guideWidth) / 2f
        val guideTop = 0f

        Log.d("ImageCropTransfer", "Crop calculation:")
        Log.d("ImageCropTransfer", "  Preview: ${previewWidthPx.toInt()}x${previewHeightPx.toInt()} px")
        Log.d("ImageCropTransfer", "  Guide: ${guideWidth.toInt()}x${guideHeight.toInt()} px at (${guideLeft.toInt()}, ${guideTop.toInt()})")
        Log.d("ImageCropTransfer", "  Original bitmap: ${bitmap.width}x${bitmap.height} px")
        Log.d("ImageCropTransfer", "  User scale: $currentScale, Offset: ($currentOffsetX, $currentOffsetY)")

        // Step 1: Calculate ContentScale.Crop parameters
        // Crop scales content to fill the container: scale = max(w_ratio, h_ratio)
        val scaleX = previewWidthPx / bitmap.width
        val scaleY = previewHeightPx / bitmap.height
        val contentScaleValue = maxOf(scaleX, scaleY)
        
        // Calculate the displayed size after ContentScale.Crop
        val displayedWidth = bitmap.width * contentScaleValue
        val displayedHeight = bitmap.height * contentScaleValue
        
        // Calculate centering offset (how much the image is offset when centered in preview)
        val offsetXDisplay = (previewWidthPx - displayedWidth) / 2f
        val offsetYDisplay = (previewHeightPx - displayedHeight) / 2f
        
        Log.d("ImageCropTransfer", "  ContentScale.Crop: scale=$contentScaleValue")
        Log.d("ImageCropTransfer", "  Displayed size: ${displayedWidth.toInt()}x${displayedHeight.toInt()}")
        Log.d("ImageCropTransfer", "  Display offset: ($offsetXDisplay, $offsetYDisplay)")

        // Step 2: Map guide corners from preview coords → original image coords
        // Reverse user transform: displayCoord = (previewCoord - userOffset) / userScale
        val cropLeft_display = (guideLeft - currentOffsetX) / currentScale
        val cropTop_display = (guideTop - currentOffsetY) / currentScale
        val cropRight_display = (guideLeft + guideWidth - currentOffsetX) / currentScale
        val cropBottom_display = (guideTop + guideHeight - currentOffsetY) / currentScale
        
        // Reverse ContentScale positioning and scaling: imageCoord = (displayCoord - displayOffset) / contentScale
        val cropLeft = ((cropLeft_display - offsetXDisplay) / contentScaleValue).toInt().coerceAtLeast(0)
        val cropTop = ((cropTop_display - offsetYDisplay) / contentScaleValue).toInt().coerceAtLeast(0)
        val cropRight = ((cropRight_display - offsetXDisplay) / contentScaleValue).toInt().coerceAtMost(bitmap.width)
        val cropBottom = ((cropBottom_display - offsetYDisplay) / contentScaleValue).toInt().coerceAtMost(bitmap.height)
        
        val cropWidth = (cropRight - cropLeft).coerceAtLeast(1)
        val cropHeight = (cropBottom - cropTop).coerceAtLeast(1)

        Log.d("ImageCropTransfer", "  Crop region: ${cropWidth}x${cropHeight} at ($cropLeft, $cropTop)")

        // Create cropped bitmap (target 720x1280)
        val targetWidth = 720
        val targetHeight = 1280
        val croppedBitmap = Bitmap.createBitmap(bitmap, cropLeft, cropTop, cropWidth, cropHeight)
        
        // Scale to target dimensions
        val finalBitmap = Bitmap.createScaledBitmap(croppedBitmap, targetWidth, targetHeight, true)
        Log.d("ImageCropTransfer", "  Final transfer bitmap: ${finalBitmap.width}x${finalBitmap.height} px")
        return finalBitmap
    }

    /**
     * Transfer the cropped image to the target device via BLE
     * Matches the iOS implementation exactly with:
     * - JPEG compression quality: 0.2
     * - Chunk size: 200 bytes
     * - Inter-chunk delay: 200ms
     * - netlink_forward protocol
     */
    fun transferCroppedImage(
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
        onProgress: (Int) -> Unit = {}
    ) {
        val croppedBitmap = cropImageForTransfer()
        if (croppedBitmap == null) {
            onError("Failed to crop image for transfer")
            return
        }

        Log.d("ImageCropTransfer", "Starting image transfer: 720x1280 JPEG")
        
        _isTransferring.value = true
        _transferProgress.value = 0
        
        imageTransferManager.transferImage(
            image = croppedBitmap,
            imageName = "target_image",
            compressionQuality = 0.2f,  // iOS matches this exactly
            progress = { progress ->
                Log.d("ImageCropTransfer", "Transfer progress: $progress%")
                _transferProgress.value = progress
                onProgress(progress)
            },
            completion = { success, message ->
                _isTransferring.value = false
                if (success) {
                    Log.d("ImageCropTransfer", "Transfer completed successfully")
                    _transferProgress.value = 0
                    onSuccess(message)
                } else {
                    Log.e("ImageCropTransfer", "Transfer failed: $message")
                    _transferProgress.value = 0
                    onError(message)
                }
            }
        )
    }

    override fun onCleared() {
        super.onCleared()
        imageTransferManager.cancelTransfer()
    }
}
