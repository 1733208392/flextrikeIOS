/*
 IMAGE CROP FEATURE - MASK GEOMETRY DIAGRAM
 
 This file documents the exact layout and dimensions of the silhouette mask
 
 CANVAS LAYOUT (9:16 portrait ratio)
 ═══════════════════════════════════════════════════════════════════════════
 
 Reference dimensions: 180 × 320 points (at standard scale)
 Aspect ratio: 9:16
 
                                 CANVAS (180×320)
       ┌─────────────────────────────────────────────────────────┐
       │                                                           │
       │                      ╭─────────╮                         │ ┐
       │                      │         │                         │ │
       │                      │  HEAD   │ diameter = 106.7pt      │ │ 1/3 height
       │                      │ radius  │                         │ │ (head + top space)
       │                      │= 53.3pt │                         │ │
       │                      ╰─────────╯                         │ ┘
       │                                                           │
       │                 width = 90pt (1/2 canvas)                │ ┐
       │              ╔══════════════════════════════╗            │ │
       │              ║                              ║            │ │ 2/3 height
       │              ║        BODY (CAPSULE)       ║            │ │
       │              ║      rounded rectangle      ║            │ │
       │              ║   corner radius = 45pt     ║            │ │
       │              ║   height = 213.3pt         ║            │ │
       │              ║                              ║            │ │
       │              ╚══════════════════════════════╝            │ ┘
       │                                                           │
       └─────────────────────────────────────────────────────────┘
       
       ← 180 points →
 

 DETAILED HEAD SPECIFICATIONS
 ═══════════════════════════════════════════════════════════════════════════
 
 Type: Circle (Perfect ellipse)
 Position: Center horizontally, at top of canvas
 
 Calculation:
   - Frame height: 320 points
   - Head height ratio: 1/3 of frame = 320/3 = 106.67 points
   - Diameter: 106.67 points (entire head height)
   - Radius: 53.33 points
   - Center X: 180/2 = 90 points (centered)
   - Center Y: 53.33 points (radius from top)
 
 Bounds:
   - Min X: 90 - 53.33 = 36.67
   - Min Y: 53.33 - 53.33 = 0
   - Max X: 90 + 53.33 = 143.33
   - Max Y: 53.33 + 53.33 = 106.67
   - Size: 106.67 × 106.67


 DETAILED BODY SPECIFICATIONS  
 ═══════════════════════════════════════════════════════════════════════════
 
 Type: Capsule (Rounded rectangle)
 Shape: Rectangle with all corners rounded
 Position: Center horizontally, below head
 
 Calculation:
   - Frame width: 180 points
   - Body width ratio: 1/2 of frame = 180/2 = 90 points
   - Frame height: 320 points
   - Head radius: 53.33 points
   - Body start Y: 2 × radius = 106.67 points
   - Body height: 320 - 106.67 = 213.33 points
   - Center X: (180 - 90) / 2 = 45 points offset
   - Corner radius: width / 2 = 90/2 = 45 points
 
 Bounds:
   - Min X: 45
   - Min Y: 106.67
   - Max X: 135
   - Max Y: 320
   - Size: 90 × 213.33
   - Corners: 45 point radius (creates capsule shape)


 VISUAL MEASUREMENTS
 ═══════════════════════════════════════════════════════════════════════════
 
 From top to bottom:
   0pt    ┌─ Canvas top
          │
  53pt    ├─ Head center Y
          │
 106pt    ├─ Head bottom / Body top
          │
 213pt    ├─ Body midpoint
          │
 320pt    └─ Canvas bottom
 
 Left to right:
    0pt   ├─ Canvas left
          │
   45pt   ├─ Body left edge
          │
   90pt   ├─ Canvas center / Head center
          │
  135pt   ├─ Body right edge
          │
  180pt   └─ Canvas right


 COLOR & OPACITY SPECIFICATIONS
 ═══════════════════════════════════════════════════════════════════════════
 
 Background (outside mask): Semi-transparent dark overlay
   - Color: Black
   - Opacity: 0.3 (30%)
   - Blends with underlying content
 
 Mask stroke (outline):
   - Color: White
   - Opacity: 0.6 (60%)
   - Line width: 2 points
   - Applied to both head and body


 SCALING BEHAVIOR
 ═══════════════════════════════════════════════════════════════════════════
 
 The mask maintains 9:16 ratio but can be scaled:
 
 Example at different sizes:
 
   Half size (90 × 160):
     - Head radius: 26.67pt
     - Body width: 45pt
     - Body height: 106.67pt
   
   Double size (360 × 640):
     - Head radius: 106.67pt
     - Body width: 180pt
     - Body height: 426.67pt
   
   Custom (W × H where H = W × 16/9):
     - Head radius: H × 1/6
     - Body width: W × 1/2
     - Body height: H × 2/3


 MASK GEOMETRY CODE REFERENCE
 ═══════════════════════════════════════════════════════════════════════════
 
 From SilhouetteMask.swift:
 
 ```swift
 let frameWidth = rect.width        // 180 (reference)
 let frameHeight = rect.height      // 320 (reference)
 
 // Head (circle)
 let headRadius = frameHeight / 6           // 53.33
 let headCenterX = frameWidth / 2           // 90
 let headCenterY = headRadius               // 53.33
 
 // Body (capsule)
 let bodyWidth = frameWidth / 2             // 90
 let bodyHeight = frameHeight - (2 * headRadius)  // 213.33
 let bodyX = (frameWidth - bodyWidth) / 2   // 45
 let bodyY = 2 * headRadius                 // 106.67
 let bodyCornerRadius = bodyWidth / 2       // 45
 ```


 TRANSFORMATION WITH ZOOM/DRAG
 ═══════════════════════════════════════════════════════════════════════════
 
 The mask remains static while the image transforms:
 
 Original:                  After Scale (1.5x):        After Drag:
 ┌──────────────┐          ┌──────────────┐           ┌──────────────┐
 │ Image        │          │ Image        │           │   Image      │
 │              │          │  (larger)    │           │   (shifted)  │
 │              │    or    │              │    or     │              │
 │              │          │              │           │              │
 └──────────────┘          └──────────────┘           └──────────────┘
 
 ╭─────────╮               ╭─────────╮               ╭─────────╮
 │ MASK    │               │ MASK    │               │ MASK    │
 │ (static)│               │ (static)│               │ (static)│
 ╰─────────╯               ╰─────────╯               ╰─────────╯


 INTERACTION ZONES
 ═══════════════════════════════════════════════════════════════════════════
 
 The mask guides the user where to position:
 
 Head zone: 0-106pt (vertical)
   - Position face/head of subject here
   - Centered horizontally
 
 Body zone: 106-320pt (vertical)
   - Position torso/body of subject here
   - Centered horizontally
   - Wider than head zone
 
 Surrounding area (dark overlay):
   - Area outside mask is darkened
   - Indicates area that will be cropped out
   - Visual guide for framing
 

 RATIO CALCULATIONS
 ═══════════════════════════════════════════════════════════════════════════
 
 Canvas: 9:16 (width : height)
 
 Head proportion:
   - Vertical: 1/3 of canvas height
   - Horizontal: Centered (diameter = 1/3 of height)
 
 Body proportion:
   - Vertical: Remaining 2/3 of canvas height
   - Horizontal: 1/2 of canvas width
 
 If you want to change proportions, modify in MaskConfiguration:
   
   // Example: Make head 1/4 instead of 1/3
   static let headHeightRatio: CGFloat = 1.0 / 4.0
   
   // Example: Make body wider (3/4 instead of 1/2)
   static let bodyWidthRatio: CGFloat = 3.0 / 4.0
*/
