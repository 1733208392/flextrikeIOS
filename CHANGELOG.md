# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
### Changed
### Fixed
- N/A

## [0.1.0] - 2026-01-18
- Initial iOS and Android Apps
## [0.1.] - 2026-01-18
Please process below error message from the device and alert user
{
  "type" : "notice",
  "action" : "netlink_query_device_list",
  "state" : "failure",
  "message" : "netlink is not enabled",
  "failure_reason" : "execution_error"
}
for both Android and iOS implementation.

User Profile Functional Test Issues
- Tap Update Profile Button is not responsive, 
1. still not responsive
2. 401 Unauthorized
3. 400 Bad Request (invliad parameter)
4. 500 Server Internal Error {"code":500,"msg":"No fields to update"}
    2.1.4 修改当前用户信息接口地址： /user/edit提交方式： POST数据格式： JSON认证要求：用户认证调用参数：username 【str】用户名称返回结果：code【int】结果代码，“0”为正常，其它为出错msg【str】结果描述data【dict-list】结果数据user_uuid【str】用户的UUID

    1.3 令牌使用方法在HTTP请求头中使用 authorization 头数据进行认证，数据的组成格式为：当调用仅需要“用户认证”的接口时，数据格式为：例如访问令牌的值为 f19adb535e1347289be4bccd59da02ac ，则该头的完整内容为：当调用同时需要“用户认证”和“设备认证”的接口时，数据格式：例如设备令牌的值为 87e09758aa624513b8d9ce5658727e66 ，则该头的完整内容为：Authorization: Bearer 令牌数据Authorization: Bearer 访问令牌Authorization: Bearer f19adb535e1347289be4bccd59da02acAuthorization: Bearer 访问令牌|设备令牌Authorization: Bearer f19adb535e1347289be4bccd59da02ac|87e09758aa624513b8d9ce5658727e66
5. Parameter Validation: Kai is too short??  Waiting for JD's confirmation.

- Tap Change Password Button is not responsive, no result prompt
1. Fixed.
- Logout Button is partially seen
1. fixed

- Login
1. The View's theme is different, please make it consistent with other view - dark and red tint
1. Fixed.

- BLE Connection
1. manual connection / disconnect - passed
2. scan to connect - passed
3. Remove the firmware update button
4. Replace the Target Frame Drew by code with the smart-target-icon.svg under the asset folder for Android 
5. ConnectSmartTargetView UI improvements.

- Custom Target
1. Image Crop Guide - UI improvement
Please refactory this feature with following design
1) UI Design:
- A square image preview area takes full width of the screen and just below the navigation tool bar
- A custom-target-guide.svg overlay(a 720/1280 scale rectangle ) on top of the preview area that takes the full height of the preview area and located in the center
- A select photo button on the top right of the tool bar
- A confirm and transfer button below the image preview area
2) UI Logic:
- User tap select photo button bring up the photo library picker
- After user selected the tool bar, the image will be shown in the preview
- User can pinch and drag the photo in order to fit in the guide.
- The photo's max movement is limited by the custom-target-guide. e.g. the right border of the image can not cross the right border of the custom-target-guide's to the left. the left border of the image can not cross the left border of the custom-target-guide's to the right. the top border of the image can not go under the top border of the custom-target-guide's. the bottom border of the image can not go beyone the top border of the custom-target-guide's. 
- When user taps the confirm and transfer button, the image will be cropped per the custom-target-guide and start transfer to the target device
- The transfer uses base64 and truncked packets

AI PLAN REVIEW
## Plan: Refactor Android Image Crop Guide UI & Logic

**Refactor the Android Image Crop Guide feature to implement the redesigned UI layout with full-width preview, repositioned controls, SVG-based guide and border rendering, and stricter boundary constraints on image movement.**

### Steps

1. **Restructure layout hierarchy & reposition controls** in [ImageCropView.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/ui/compose/ImageCropView.kt)
   - Move image preview canvas to full-width below navigation bar (keep 480.dp height)
   - Move "Choose Photo" button from bottom to toolbar top-right
   - Add confirm/transfer button below preview area (new dedicated controls section)

2. **Render SVG guide and border overlays** in [ImageCropView.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/ui/compose/ImageCropView.kt)
   - Replace Canvas-drawn guide rect with `custom-target-guide.svg` asset (base layer, 9:16 aspect)
   - Overlay `custom-target-border.svg` asset on top as decorative border
   - Center both SVGs over the image preview area with matching dimensions
   - Verify both SVGs render with proper transparency and alignment

3. **Tighten image boundary constraints** in [ImageCropViewModel.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/viewmodel/ImageCropViewModel.kt)
   - Strengthen `clampedOffset()` logic to strictly prevent image borders from crossing guide boundaries
   - Ensure left border cannot move right past guide left edge; right border cannot move left past guide right edge
   - Ensure top border cannot move down past guide top edge; bottom border cannot move up past guide bottom edge
   - Update scale constraints to prevent zooming out such that image leaves gaps within guide bounds
   - Test constraint enforcement during pinch and pan gestures

4. **Refine gesture handling for new constraints** in [ImageCropView.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/ui/compose/ImageCropView.kt)
   - Maintain existing `detectTransformGestures` pinch/pan detection
   - Apply updated clamping logic after each gesture update in real-time

5. **Update control flow & UI state** in [ImageCropView.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/ui/compose/ImageCropView.kt)
   - Move photo selection trigger to new toolbar button (top-right)
   - Keep image picker launcher unchanged (`ActivityResultContracts.GetContent()`)
   - Move transfer button below preview area (enable only when image selected)

6. **Verify transfer protocol & image handling** in [ImageCropViewModel.kt](FlexTargetAndroid/app/src/main/java/com/grwolf/flextarget/viewmodel/ImageCropViewModel.kt)
   - Confirm image cropping uses updated crop frame from new UI layout
   - Verify base64 chunking with 200-byte chunks and 200ms delay matches iOS protocol
   - Ensure JPEG compression (0.2 quality) and 720×1280 output sizing is maintained

### Further Considerations

1. **UI Layout Dimensions**: Should the "confirm and transfer" button occupy the full width below preview or be part of a controls row with other actions? Any specific height/padding preferences? full width with 20dp paadings

2. **SVG Asset Loading**: Are both SVG assets available in the drawable resources, or do they need to be added/converted from the iOS assets folder? Yes, no need to convert from ios folder

Perfect! Let me create a summary of the implementation changes:

Implementation Complete ✅
I've successfully refactored the Android Image Crop Guide UI with all the required improvements:

1. Layout Restructuring ✅
Image Preview Area: Now full-width and positioned directly below the navigation bar (480.dp height)
Navigation Bar: Repositioned at the top with:
Back button (top-left)
"Select" photo button (top-right) - more compact label
Transfer Button: Moved below the preview area with full-width, 20.dp padding margins
Control Flow: Improves UX by clearly separating selection and transfer actions
2. SVG Guide & Border Rendering ✅
Replaced Canvas-drawn rectangles with actual SVG assets from the assets folder
custom-target-guide.svg: Base layer, centered over preview (9:16 aspect ratio)
custom-target-border.svg: Overlay on top as decorative border
Rendering Method: Using Coil's AsyncImage composable with SVG support via coil-svg dependency
Asset URIs: Properly formatted as file:///android_asset/{filename}
3. Enhanced Boundary Constraints ✅
Strengthened clampedOffset() logic: Image borders cannot cross guide rectangle boundaries
Left border stays <= guide left edge
Right border stays >= guide right edge
Top border stays <= guide top edge
Bottom border stays >= guide bottom edge
Improved enforceConstraints() function: Detailed documentation explaining the geometry and clamping algorithm
Scale enforcement: Prevents zooming out such that image leaves gaps within guide bounds
Applied in real-time: Constraints enforced immediately during pinch and drag gestures
4. Gesture Handling ✅
Existing detectTransformGestures maintained for pinch/pan detection
Clamping logic applied: Updated offset clamping immediately after each gesture update
No delays: Constraints enforced in real-time without blocking
5. Transfer Protocol ✅
Unchanged and verified:
Image cropping logic remains the same (720×1280 output, JPEG 0.2 quality)
Base64 chunking with 200-byte chunks maintained
200ms delay between chunks preserved
netlink_forward protocol message format unchanged
Complete compatibility with iOS implementation and Android device protocol
Files Modified
ImageCropView.kt - Layout restructure, SVG rendering, control repositioning
ImageCropViewModel.kt - Enhanced boundary constraint logic with detailed documentation
Build Status
✅ Compilation successful - No errors in modified files
✅ All dependencies available - Coil SVG support already included
✅ Assets present - Both SVG files available in /assets folder

Faults:
# Let us recreate this feature step by step:
1. display the picture user selected in the 480dp x 480dp square preview area and only in this area. Allow user to drag and pinch but always occupys the whole preview area, no blank/black background reveals.

2. Put the custom-target-guide overlay and custom-target-border overlay with height of 480dp on top of the square preview and in the center.

3. Boundries Constraints on the custom-target-guide rectangle boundaries
- Left border stays <= guide left edge
- Right border stays >= guide right edge
- Top border stays <= guide top edge
- Bottom border stays >= guide bottom edge

4. Crop the image per the boundaries of the custom-target-guide when tap the "confirm the transfer" button below.

5. Kick off the image transfer when cropped.
- 2026-01-19 20:10:59.844 32381-32381 ImageTransfer
{"action":"netlink_forward","content":{"command":"image_chunk","chunk_index":0,"data":"\/9j\/4AAQSkZJRgABAQAAAQABAAD\/4gIYSUNDX1BST0ZJTEUAAQEAAAIIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAAGRyWFlaAAABVAAAABRnWFlaAAA="},"dest":"01"}

{"action":"netlink_forward","content":{"chunk_index":20,"command":"image_chunk","data":"HY1EVI7U0S2Q7R6Cl8tD\/DT9vfFKABVCuM8tc8rSmNe3FPA7U7aABSsO5GFwc0oQDOe9SYBox60rDuVFAV\/JkPB5Bp7R4BBJyKlZA6kHqOR9aWE+ZkP99etFguVzGDjkigxt\/eqzhcHNJtAz3p2C5X2Pn71NKSdjVkgelJhe9FhXK2Jc9uKTEvIwKs7TSFWFIdyuTLn7oozJ3XNTFSe1Js4piuQ7pOPl6UFnwRt61KUo2UWC5Dl8Y20c9McGpSpHNJt7UWC5Eww="},"dest":"01"}

{"action":"netlink_forward","content":{"chunk_index":20,"command":"image_chunk","data":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="},"dest":"01"}


adb -s adb-28201JEGR0S884-05PCRi._adb-tls-connect._tcp shell input text '{action:netlink_forward,dest:01,content:{action:netlink_query_device_list}}'


2026-01-20 11:50:20.147 25623-25633 System.out              com.flextarget.android               I  [AndroidBLEManager] Received BLE message: {"type":"notice","action":"unknown","state":"failure","message":"decode data action error! (expected `,` or `}` at line 1 column 203)\n    {\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":0,\"command\":\"image_chunk\",\"data\":\"\\/9j\\/4AAQSkZJRgABAQAAAQABAAD\\/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":1,\"command\":\"image_chunk\",\"data\":\"AAAAAAABAAD21gABAAAAANMtAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACWRlc2MAAADwAAAAJHJYW{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":2,\"command\":\"image_chunk\",\"data\":\"ASgAAAAUYlhZWgAAATwAAAAUd3RwdAAAAVAAAAAUclRSQwAAAWQAAAAoZ1RSQwAAAWQAAAAoYlRSQwAAAWQAAAAoY3BydAAAAYwAAAA8bWx1YwAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":3,\"command\":\"image_chunk\",\"data\":\"AAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":4,\"command\":\"image_chunk\",\"data\":\"AAAABAAAAAJmZgAA8qcAAA1ZAAAT0AAAClsAAAAAAAAAAG1sdWMAAAAAAAAAAQAAAAxlblVTAAAAIAAAABwARwBvAG8AZwBsAGUAIABJAG4AYwAuA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":5,\"command\":\"image_chunk\",\"data\":\"HB4jHhkoIyEjLSsoMDxkQTw3Nzx7WF1JZJGAmZaPgIyKoLTmw6Cq2q2KjMj\\/y9ru9f\\/\\/\\/5vB\\/\\/\\/\\/+v\\/m\\/f\\/4\\/9sAQwErLS08NTx2Q{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":6,\"command\":\"image_chunk\",\"data\":\"+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj\\/wAARCAUAAtADASIAAhEBAxEB\\/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX\\/xAAUEAEAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":7,\"command\":\"image_chunk\",\"data\":\"AQEAAAAAAAAAAAAAAAAAAAAA\\/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP\\/aAAwDAQACEQMRAD8AsgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":8,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":9,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":10,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":11,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":12,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":13,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":14,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":15,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":16,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA{\"action\":\"netlink_forward\",\"content\":{\"chunk_index\":17,\"command\":\"image_chunk\",\"data\":\"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
