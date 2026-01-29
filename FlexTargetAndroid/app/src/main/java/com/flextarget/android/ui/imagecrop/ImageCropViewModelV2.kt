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
     * The guide is 480dp tall centered in the preview area.
     * Guide width = 480 * (9/16) = 270dp
     * Guide left edge = (480 - 270) / 2 = 105dp
     * Guide top edge = 0dp
     */
    fun cropImageForTransfer(): Bitmap? {
        val bitmap = _image.value ?: return null
        val currentScale = _scale.value
        val currentOffsetX = _offsetX.value
        val currentOffsetY = _offsetY.value

        // Preview dimensions in pixels (assuming 480dp = ~1080px at typical density)
        val previewSizePx = 480f
        
        // Guide dimensions (9:16 aspect ratio, 480dp height)
        val guideHeight = previewSizePx
        val guideWidth = guideHeight * (9f / 16f) // ~270px
        val guideLeft = (previewSizePx - guideWidth) / 2f
        val guideTop = 0f

        // Calculate the inverse transform to map guide coords back to original image coords
        // Image in preview = original * scale + offset
        // Original = (preview - offset) / scale
        
        val cropLeft = ((guideLeft - currentOffsetX) / currentScale).toInt().coerceAtLeast(0)
        val cropTop = ((guideTop - currentOffsetY) / currentScale).toInt().coerceAtLeast(0)
        val cropWidth = ((guideWidth) / currentScale).toInt().coerceAtMost(bitmap.width - cropLeft)
        val cropHeight = ((guideHeight) / currentScale).toInt().coerceAtMost(bitmap.height - cropTop)

        // Create cropped bitmap (target 720x1280)
        val targetWidth = 720
        val targetHeight = 1280
        val croppedBitmap = Bitmap.createBitmap(bitmap, cropLeft, cropTop, cropWidth, cropHeight)
        
        // Scale to target dimensions
        return Bitmap.createScaledBitmap(croppedBitmap, targetWidth, targetHeight, true)
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
        
        imageTransferManager.transferImage(
            image = croppedBitmap,
            imageName = "target_image",
            compressionQuality = 0.2f,  // iOS matches this exactly
            progress = { progress ->
                Log.d("ImageCropTransfer", "Transfer progress: $progress%")
                onProgress(progress)
            },
            completion = { success, message ->
                if (success) {
                    Log.d("ImageCropTransfer", "Transfer completed successfully")
                    onSuccess(message)
                } else {
                    Log.e("ImageCropTransfer", "Transfer failed: $message")
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
