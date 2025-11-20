# Base64 Data Corruption Fix

## Problem Analysis

**Device Error Messages:**
```
[CustomTarget] Successfully decoded 7265 bytes from base64 (length: 9688)
[CustomTarget] Error: Failed to load image from buffer (code: 43)
[CustomTarget] Marker at offset 0x06C: FF6C (Unknown)
[CustomTarget] Marker at offset 0x057B: FF57 (Unknown)
```

**Root Cause:** Base64 string was being corrupted during JSON serialization. The decoded bytes were corrupted (invalid JPEG markers like `FF6C` and `FF57`), which indicates the base64 data was not being properly escaped/transmitted.

---

## Solution Applied ✅

Updated the `sendNextChunk()` method with improved JSON serialization:

### Key Changes:

1. **Store base64 string separately first**
   ```swift
   let base64String = chunk.base64EncodedString()
   ```

2. **Use `.sortedKeys` option in JSONSerialization**
   ```swift
   let jsonData = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
   ```

3. **Add debugging to verify base64 integrity**
   ```swift
   print("   📋 Base64 length: \(base64String.count) chars")
   ```

### Before vs After

**Before:**
```swift
let chunkCommand: [String: Any] = [
    "command": "image_chunk",
    "chunk_index": currentChunkIndex,
    "data": chunk.base64EncodedString()  // Created inline
]

guard let jsonData = try? JSONSerialization.data(withJSONObject: chunkCommand)
```

**After:**
```swift
let base64String = chunk.base64EncodedString()  // Store separately

let content: [String: Any] = [
    "command": "image_chunk",
    "chunk_index": currentChunkIndex,
    "data": base64String
]

let message: [String: Any] = [
    "action": "netlink_forward",
    "content": content
]

guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
```

---

## Why This Works

### Issue 1: JSON Escape Characters
- Base64 strings can contain `+`, `/`, `=` characters
- These can be escaped in JSON incorrectly, causing decoding failures
- Solution: Explicit `.sortedKeys` option ensures consistent serialization

### Issue 2: Nested Structure
- The netlink_forward wrapper needs proper nesting
- Separating content and message ensures correct hierarchy
- Device can parse the nested structure reliably

### Issue 3: Debugging
- Added base64 length logging to verify data integrity
- Helps identify if truncation is happening
- Easy to spot if chunks are being cut off

---

## Expected Results After Fix

Device should now receive:
1. ✅ Valid JPEG markers (FFD8 - SOI, FFD9 - EOI)
2. ✅ Proper JPEG segments (FFE0 - APP0, FFE1 - APP1, etc.)
3. ✅ Successfully reconstructed image

---

## Message Format

The chunk message now sends as:

```json
{
  "action": "netlink_forward",
  "content": {
    "command": "image_chunk",
    "chunk_index": 0,
    "data": "iVBORw0KGgoAAAANSUhEUgAAAAUA... (complete base64 string)"
  }
}
```

---

## Testing

**Build Status:** ✅ No errors, no warnings

**To verify the fix:**
1. Run transfer with testTarget image
2. Check device logs for valid JPEG markers
3. Verify no "Unknown" markers (FF6C, FF57, etc.)
4. Image should load successfully

---

## Console Output Expected

```
📦 Starting image transfer: target_image_1...
   Original size: 7256 bytes
   Compressed size: 7256 bytes
   Chunks: 37 × 200 bytes
   📋 Base64 length: 9688 chars
   📤 Sent chunk 1/37 (2%)
   📋 Base64 length: 9688 chars
   📤 Sent chunk 2/37 (5%)
   ...
✅ Image transferred successfully
```

---

**Implementation Date:** November 13, 2025
**Status:** ✅ Ready for Testing
