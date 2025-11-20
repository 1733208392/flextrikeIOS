// QUICK REFERENCE - Image Crop Feature
// Use this as a quick lookup for common tasks

import SwiftUI

// ============================================================================
// 1. BASIC INTEGRATION - Just add this to your view
// ============================================================================

NavigationLink(destination: ImageCropView()) {
    HStack {
        Image(systemName: "photo.badge.plus")
        Text("Position Photo")
    }
}

// ============================================================================
// 2. WITH CALLBACK - Handle the cropped image
// ============================================================================

@State private var croppedImage: UIImage?

NavigationLink(destination: ImageCropViewWithCallback(onCropComplete: { image in
    self.croppedImage = image
})) {
    Text("Crop Image")
}

// ============================================================================
// 3. MASK SPECIFICATIONS (Reference)
// ============================================================================

/*
 Canvas: 9:16 portrait ratio (180x320 points)
 
 HEAD (Circle):
   - Diameter: 1/3 of frame height = 106.7 points (at 320px height)
   - Radius: 53.3 points
   - Centered horizontally at top
 
 BODY (Capsule):
   - Width: 1/2 of frame width = 90 points (at 180px width)
   - Height: Frame height - 2×head diameter = 213.3 points
   - Corner radius: Width / 2 = 45 points (creates capsule)
   - Centered horizontally, below head
 
 OVERLAY:
   - Surrounding area: Black 30% opacity
   - Mask strokes: White 60% opacity
*/

// ============================================================================
// 4. CUSTOMIZATION EXAMPLES
// ============================================================================

// Example A: Change mask head size
// In SilhouetteMask.swift, modify:
let headRadius = frameHeight / 8  // Instead of / 6 (now 1/4 instead of 1/3)

// Example B: Change max zoom level
// In ImageCropViewModel.swift:
var maxScale: CGFloat = 10.0  // Was 5.0

// Example C: Change button color
// In ImageCropView.swift:
.background(Color.blue)  // Instead of Color.red

// Example D: Change canvas size
// In ImageCropView.swift:
.frame(height: 400)  // Instead of 320
// And update mask view:
SilhouetteMaskView(width: 225, height: 400)  // Maintains 9:16 ratio

// ============================================================================
// 5. ACCESSING VIEW MODEL
// ============================================================================

// Create instance
@StateObject private var viewModel = ImageCropViewModel()

// Access properties
let currentZoom = viewModel.scale  // 1.0 to 5.0
let currentOffset = viewModel.offset  // CGSize(width, height)
let selectedPhoto = viewModel.selectedImage  // UIImage?

// Call methods
viewModel.resetTransform()  // Reset to original
viewModel.cropImage(within: frame, canvasSize: size)  // Crop

// ============================================================================
// 6. GESTURE HANDLING
// ============================================================================

// Pinch to zoom: 1x to 5x (automatic in view)
// Two fingers together/apart to zoom in/out

// Drag to position: (automatic in view)
// Touch and drag image to reposition

// Both gestures work simultaneously
// No need to configure - it's built in

// ============================================================================
// 7. LIVE PREVIEW
// ============================================================================

// Enable in any view by setting:
viewModel.showLivePreview = true

// Or use the "Preview" button built into ImageCropView
// Shows full-screen preview with mask overlay

// ============================================================================
// 8. EXPORT CROPPED IMAGE
// ============================================================================

// TODO: Implement in "Apply Crop" button action
// Example approaches:

// Approach 1: Save to Photos Library
if let image = viewModel.croppedImage {
    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
}

// Approach 2: Pass to next view
let croppedImage = viewModel.croppedImage
NavigationStack {
    ProcessImageView(image: croppedImage)
}

// Approach 3: Save locally
let documentsPath = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)[0]
let imagePath = documentsPath.appendingPathComponent("cropped.jpg")
try? viewModel.croppedImage?.jpegData(compressionQuality: 0.8)?.write(to: imagePath)

// ============================================================================
// 9. TESTING / PREVIEWING
// ============================================================================

#Preview {
    ImageCropView()
}

#Preview {
    ImageCropExampleView()
}

// ============================================================================
// 10. DEBUGGING TIPS
// ============================================================================

/*
 - Check gesture isn't working: Verify frame size in view
 - Mask looks wrong: Check MaskConfiguration ratios
 - Image not showing: Verify PhotosPickerItem conversion
 - Performance issues: Check image resolution before loading
 - Color doesn't match: Search for Color.red and replace
 - Zoom limits seem wrong: Verify minScale/maxScale in ViewModel
*/

// ============================================================================
// 11. FILE LOCATIONS
// ============================================================================

/*
 ImageCropView.swift              → Main UI & controls
 ImageCropViewModel.swift         → State & business logic
 SilhouetteMask.swift             → Mask rendering & overlays
 ImageCropUtilities.swift         → Helper functions & constants
 ImageCropExample.swift           → Full integration example
 ImageCropFeature.md              → Complete documentation
 
 Location: /flextarget/View/ImageCrop/
*/

// ============================================================================
// 12. COMMON TASKS
// ============================================================================

// Reset zoom and position
viewModel.resetTransform()

// Show/hide preview
viewModel.showLivePreview.toggle()

// Get current zoom percentage
let percentage = Int(viewModel.scale * 100)  // "150%", "200%", etc.

// Check if image is selected
if viewModel.selectedImage != nil {
    // Image is loaded
}

// Check if cropped result is ready
if let result = viewModel.croppedImage {
    // Process result
}

// ============================================================================
