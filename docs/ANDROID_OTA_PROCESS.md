# Android OTA Update Process Documentation

## Overview

This document outlines the Android OTA (Over-The-Air) update process for the FlexTarget application, which enables firmware updates for smart target devices via Bluetooth Low Energy (BLE) communication.

## Architecture Components

### Core Components
1. **OTARepository** - Core business logic and state management
2. **OTAUpdateView** - UI components showing progress through different states
3. **OTAViewModel** - Bridges UI and repository, handles user actions
4. **BLEManager/AndroidBLEManager** - Handles Bluetooth communication with device
5. **WorkManager (OTACheckWorker)** - Background periodic update checking

### Supporting Components
- **FlexTargetAPI** - Network API for fetching update metadata
- **AuthManager** - Device authentication and token management
- **AppPreferences** - Local storage for update state and preferences

## OTA States

The OTA process uses the following state machine:

```kotlin
enum class OTAState {
    IDLE,                    // No update in progress
    CHECKING,               // Checking for new version
    UPDATE_AVAILABLE,       // New version found
    PREPARING,              // Preparing device for OTA
    WAITING_FOR_READY_TO_DOWNLOAD, // Waiting for device ready signal
    DOWNLOADING,            // Downloading update to device
    RELOADING,              // Reloading device after download
    VERIFYING,              // Verifying update integrity
    COMPLETED,              // Update completed successfully
    ERROR                   // Update failed
}
```

## Complete OTA Flow

### Phase 1: Update Discovery

#### 1.1 Periodic Background Checks
- **Component**: `OTACheckWorker` (WorkManager)
- **Frequency**: Every 15 minutes
- **Process**:
  - Calls `OTARepository.checkForUpdates(deviceToken)`
  - API endpoint: `POST /ota/game`
  - Request body: `{"auth_data": "device_token"}`
  - Compares server version with current device version
  - Shows notification if update available

#### 1.2 Manual Update Check
- **Trigger**: User action in UI
- **Method**: `OTAViewModel.checkForUpdates()`
- **Process**: Same as background check but with immediate UI feedback

### Phase 2: Update Preparation

#### 2.1 User Initiation
- **UI Component**: `UpdateAvailableCard`
- **Action**: User taps "Update Now" button
- **Method**: `OTAViewModel.prepareUpdate()`
- **State Change**: `IDLE` → `PREPARING`

#### 2.2 Local Preparation
- **Method**: `OTARepository.prepareUpdate()`
- **Process**:
  - Downloads update file from server (`fileUrl`)
  - Shows progress (0-100%) in `PreparingCard`
  - Validates file integrity using checksum
  - **State Change**: `PREPARING` → `WAITING_FOR_READY_TO_DOWNLOAD`

### Phase 3: Device Communication

#### 3.1 BLE Command: Prepare Device
- **BLE Command**:
  ```json
  {"action": "prepare_game_disk_ota"}
  ```
- **Expected Response**:
  ```json
  {"type": "notice", "action": "prepare_game_disk_ota", "state": "success"}
  ```
  or
  ```json
  {"type": "notice", "action": "prepare_game_disk_ota", "state": "failure", "failure_reason": "..."}
  ```
- **Timeout**: 10 minutes
- **Handler**: `AndroidBLEManager.processMessage()`

#### 3.2 Device Ready Signal
- **Device Message**:
  ```json
  {"type": "forward", "content": {"notification": "ready_to_download"}}
  ```
- **Callback**: `BLEManager.shared.onReadyToDownload?.invoke()`
- **State Change**: `WAITING_FOR_READY_TO_DOWNLOAD` → `DOWNLOADING`

#### 3.3 Update Transfer
- **Method**: `OTARepository.installUpdate()`
- **BLE Command**:
  ```json
  {
    "action": "forward",
    "content": {
      "action": "start_game_upgrade",
      "address": "download_url",
      "checksum": "file_checksum",
      "version": "target_version"
    }
  }
  ```
- **UI Component**: `DownloadingCard` with progress
- **Timeout**: Device-dependent

### Phase 4: Post-Update Verification

#### 4.1 Download Complete
- **Device Message**:
  ```json
  {"type": "forward", "content": {"notification": "download_complete", "version": "new_version"}}
  ```
- **Callback**: `BLEManager.shared.onDownloadComplete?.invoke(version)`
- **State Change**: `DOWNLOADING` → `RELOADING`

#### 4.2 Device Reload
- **BLE Command**:
  ```json
  {"action": "reload_ui"}
  ```
- **UI Component**: `ReloadingCard`
- **Process**: Wait 1 second, then send `{"action": "finish_game_disk_ota"}` to exit OTA mode, wait another 1 second
- **State Change**: `RELOADING` → `VERIFYING` (after 2 seconds total)

#### 4.3 Version Verification
- **BLE Command**:
  ```json
  {"action": "forward", "content": {"command": "query_version"}}
  ```
- **Expected Response**:
  ```json
  {"type": "version", "version": "current_version"}
  ```
  or
  ```json
  {"type": "forward", "content": {"version": "current_version"}}
  ```
- **Process**: Compares received version with target version
- **Success**: `VERIFYING` → `COMPLETED`
- **Failure**: Retry verification loop (up to 60 seconds)

### Phase 5: Completion

#### 5.1 Success Finalization
- **UI Component**: `CompletedCard`
- **Process**: Updates local version tracking, clears temporary state

#### 5.2 Error Handling
- **Trigger**: Any failure in the process
- **State Change**: Any state → `ERROR`
- **UI**: Error message display, retry/cancel options
- **Method**: `OTARepository.cancelUpdate()` for abortion

## BLE Message Formats

### Command Messages
All commands use the `"action"` field:

```json
// Simple action
{"action": "prepare_game_disk_ota"}

// Auth data request (timestamp in seconds)
{"action": "get_auth_data", "timestamp": 1738100000}

// Forwarded command
{"action": "forward", "content": {"command": "query_version"}}

// Complex action
{"action": "forward", "content": {"action": "start_game_upgrade", "address": "...", "checksum": "..."}}
```

### Response Messages
Responses use the `"type"` field:

```json
// Notice responses
{"type": "notice", "action": "prepare_game_disk_ota", "state": "success"}

// Forwarded notifications
{"type": "forward", "content": {"notification": "ready_to_download"}}

// Version responses
{"type": "version", "version": "1.2.3"}
```

## UI Components

### State-Specific Cards
- **UpdateAvailableCard**: Shows update info, "Update Now" button
- **PreparingCard**: Progress bar during file download
- **WaitingCard**: "Waiting for device to be ready..."
- **DownloadingCard**: Transfer progress to device
- **ReloadingCard**: "Device restarting..."
- **VerifyingCard**: "Verifying update..."
- **CompletedCard**: Success confirmation with version info

### Progress Tracking
- **OTAProgress**: Contains state, progress percentage, version, error messages
- **Real-time Updates**: Flow-based reactive UI updates
- **Error Display**: User-friendly error messages with retry options

## Timeout Management

| Phase | Timeout | Purpose |
|-------|---------|---------|
| Device Preparation | 10 minutes | Waiting for device to enter OTA mode |
| Ready to Download | 30 seconds | Waiting for device ready signal |
| Verification | 60 seconds | Version polling after update |

## Technical Implementation Details

### Asynchronous Operations
- **Coroutines**: `suspend` functions with `Dispatchers.IO`
- **BLE Responses**: `suspendCancellableCoroutine` for async BLE waiting
- **Network Calls**: Retrofit with OkHttp for API communication

### Timestamp Format
- **Device Communication**: All timestamps sent to device must be in **seconds** since Unix epoch
- **Implementation**: Use `System.currentTimeMillis() / 1000` (divide by 1000 to convert from milliseconds)
- **Reason**: Device firmware expects u32 timestamps, milliseconds would overflow u32 range

### State Persistence
- **UserDefaults equivalent**: `AppPreferences` for storing update state
- **WorkManager**: Persistent background task scheduling
- **State Recovery**: App restart resilience

### Error Handling
- **BLE Errors**: Connection failures, timeouts, invalid responses
- **Network Errors**: API failures, authentication issues
- **File Errors**: Download failures, checksum mismatches
- **Device Errors**: OTA preparation failures, version verification failures

## API Endpoints

### Update Discovery
- **Endpoint**: `POST /ota/game`
- **Body**: `{"auth_data": "device_token"}`
- **Response**:
  ```json
  {
    "code": 0,
    "msg": "success",
    "data": {
      "version": "1.2.3",
      "address": "https://...",
      "checksum": "sha256_hash"
    }
  }
  ```

### Update History
- **Endpoint**: `POST /ota/game/history`
- **Body**: `{"auth_data": "device_token", "page": 1, "limit": 10}`
- **Response**: Array of version objects

## Current Implementation Status

### ✅ Completed Features
- BLE message format alignment with iOS
- UI state management and progress display
- Basic OTA flow state machine
- Network API integration
- Background update checking
- BLE callback connections and command sending
- Device version querying implementation

### ⚠️ Partially Implemented
- Timeout handling (structure exists, needs refinement)

### ❌ Missing Features
- Actual firmware file download logic
- Complete timeout and retry mechanisms
- Error recovery flows

## Dependencies

### Android Libraries
- **Retrofit**: Network API calls
- **WorkManager**: Background task scheduling
- **Kotlin Coroutines**: Asynchronous operations
- **Gson**: JSON serialization
- **Android BLE APIs**: Bluetooth communication

### Architecture Patterns
- **MVVM**: ViewModel-based UI architecture
- **Repository Pattern**: Data access abstraction
- **Observer Pattern**: BLE callback handling
- **State Flow**: Reactive UI updates

## Testing Considerations

### Unit Tests
- OTA state transitions
- BLE message parsing
- API response handling
- Timeout scenarios

### Integration Tests
- Full OTA flow simulation
- BLE device communication
- Network failure scenarios

### Manual Testing
- Real device OTA updates
- Network connectivity issues
- BLE connection stability
- Update interruption recovery

---

*This documentation reflects the Android OTA implementation as of January 28, 2026. The implementation follows the same patterns as the iOS version for cross-platform compatibility.*</content>
<parameter name="filePath">/Volumes/SSD2/Projects/FlexTargetiOSAndroid/docs/ANDROID_OTA_PROCESS.md