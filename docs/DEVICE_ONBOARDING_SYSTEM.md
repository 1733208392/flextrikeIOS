# Device Onboarding/Provisioning System Documentation

## Overview

The Device Onboarding system enables seamless initial setup of new smart target devices, transforming them from unprovisioned state to fully operational network-connected targets. This involves BLE communication, WiFi setup, and network configuration across iOS, Android, and Godot platforms.

**Date:** February 1, 2026  
**Status:** Production Ready ✅  
**Platforms:** iOS, Android, Godot  

## Architecture Overview

### Core Components

#### Mobile Applications (iOS/Android)
- **BLE Communication Layer:** Handles Bluetooth Low Energy messaging
- **Provisioning State Management:** Tracks setup progress and verification
- **User Interface:** Progress indicators and error feedback
- **WiFi Credential Handling:** Receives and forwards network passwords

#### Godot Server (Device-side)
- **Onboarding Scene:** Initial device introduction and BLE name resolution
- **WiFi Networks Scene:** Network scanning, selection, and connection
- **WebSocket Listener:** Command routing and real-time communication
- **Auto-Netlink Configuration:** Automatic network service setup

## Message Formats

### BLE Message Protocol

All BLE communication uses JSON-formatted messages sent via characteristic writes with `\r\n` termination.

#### Provisioning Status Messages

**Device → Mobile App (Initial Status)**
```json
{
  "provision_status": "incomplete"
}
```

**Mobile App → Device (WiFi Setup Command)**
```json
{
  "action": "forward",
  "content": {
    "provision_step": "wifi_connection"
  }
}
```

**Mobile App → Device (Status Verification)**
```json
{
  "action": "forward",
  "content": {
    "provision_step": "verify_targetlink_status"
  }
}
```

#### WiFi Setup Messages

**Device → Mobile App (SSID Request)**
```json
{
  "type": "forward",
  "content": {
    "ssid": "NETWORK_NAME"
  }
}
```

**Mobile App → Device (WiFi Credentials)**
```json
{
  "type": "forward",
  "content": {
    "ssid": "NETWORK_NAME",
    "password": "WIFI_PASSWORD"
  }
}
```

#### Netlink Status Messages

**Device → Mobile App (Network Status)**
```json
{
  "type": "forward",
  "content": {
    "started": true,
    "work_mode": "master",
    "wifi_ip": "192.168.1.100",
    "bluetooth_name": "FlexTarget-01"
  }
}
```

## Provisioning Flow

### Phase 1: Device Discovery & Introduction

1. **Device Broadcasts Status**
   - Godot sends `provision_status: "incomplete"` every 5 seconds
   - Onboarding scene displays animated greeting
   - BLE name resolution from netlink status polling

2. **Mobile App Connection**
   - BLE connection established via standard scanning
   - App receives provisioning status message
   - Sets internal `provisionInProgress = true`

### Phase 2: WiFi Network Setup

1. **Scene Transition**
   ```gdscript
   # WebSocketListener.gd
   if step == "wifi_connection":
       auto_netlink_enabled = true
       change_scene("wifi_networks.tscn")
   ```

2. **Network Scanning**
   - Device scans available WiFi networks
   - Displays list with connection status indicators
   - Highlights currently connected network

3. **Credential Exchange**
   - Selected SSID forwarded to mobile app
   - User enters password in mobile app
   - Credentials sent back via BLE

4. **WiFi Connection**
   - Device attempts WiFi connection
   - Polls for IP address availability (up to 30 seconds)
   - Displays connection progress with animations

### Phase 3: Network Configuration

1. **Auto-Netlink Setup** (when enabled)
   - Configures netlink service (channel 17, device "01", mode "master")
   - 1.5-second delay before starting service
   - Transitions to options/configuration scene

2. **Status Verification**
   - Mobile app polls with verification commands
   - Monitors for `work_mode: "master"` and `started: true`
   - Completes provisioning when conditions met

### Phase 4: Completion

1. **Settings Update**
   ```gdscript
   # onboarding.gd
   global_data.settings_dict["first_run_complete"] = true
   ```

2. **Scene Transition**
   - Typing animation completes
   - Transitions to main menu after 3-second delay

## Platform-Specific Implementation

### iOS Implementation

**Files:** `BLEManager.swift`, `RemoteControlView.swift`

**Key Features:**
- `provisionInProgress: Bool` state tracking
- Timer-based verification (5-second intervals)
- UI progress: "Provisioning: Connecting to WiFi..."
- Error handling with user alerts

**Code Example:**
```swift
onProvisionStatusReceived = { [weak self] status in
    if status == "incomplete" {
        self?.provisionInProgress = true
        self?.writeJSON("{\"action\":\"forward\", \"content\": {\"provision_step\": \"wifi_connection\"}}")
        self?.startProvisionVerification()
    }
}
```

### Android Implementation

**Files:** `BLEManager.kt`, `AndroidBLEManager.kt`

**Key Features:**
- `provisionInProgress: MutableState<Boolean>`
- Handler-based verification timer
- Message processing in GATT callbacks
- Consistent with iOS implementation

**Code Example:**
```kotlin
onProvisionStatusReceived = { status ->
    if (status == "incomplete") {
        provisionInProgress = true
        writeJSON("{\"action\":\"forward\", \"content\": {\"provision_step\": \"wifi_connection\"}}")
        startProvisionVerification()
    }
}
```

### Godot Implementation

**Files:** `onboarding.gd`, `WebSocketListener.gd`, `wifi_networks.gd`

**Key Features:**
- Scene-based UI flow management
- WebSocket command routing
- HTTP service integration
- Auto-netlink configuration

**Code Example:**
```gdscript
# WebSocketListener.gd - Provision step handling
if content.has("provision_step"):
    var step = content["provision_step"]
    if step == "wifi_connection":
        GlobalData.auto_netlink_enabled = true
        get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")
```

## Technical Specifications

### Timing & Timeouts

| Operation | Timeout | Purpose |
|-----------|---------|---------|
| Network Scan | 20 seconds | WiFi network discovery |
| IP Polling | 30 seconds | Wait for IP address assignment |
| Verification | 5-second intervals | Status confirmation |
| Auto-Netlink Delay | 1.5 seconds | Service startup stabilization |

### Error Handling

- **BLE Disconnection:** Automatic cleanup and state reset
- **Network Failures:** Retry buttons and user feedback
- **Timeout Handling:** Graceful degradation with error messages
- **Invalid Messages:** Logging and continued operation

### UI/UX Features

- **Animations:** Scanning dots, typing effects, progress indicators
- **Remote Control:** Full navigation support via MenuController
- **Accessibility:** On-screen keyboard for password input
- **Visual Feedback:** Network status icons and highlighting

## Integration Points

### BLE Communication Layer
- Message routing between mobile apps and Godot server
- Real-time status updates and command execution
- Error propagation and user feedback

### Network Services
- WiFi scanning via `HttpService.wifi_scan()`
- Connection management via `HttpService.wifi_connect()`
- Netlink configuration via `HttpService.netlink_config()`

### Settings Persistence
- First-run completion tracking
- Configuration saving to server
- State restoration across sessions

## Testing & Quality Assurance

### Test Coverage
- ✅ BLE message parsing and routing
- ✅ Connection state management
- ✅ Error handling and recovery
- ✅ Timer-based operations
- ✅ Cross-platform consistency

### Validation Criteria
- Successful WiFi connection establishment
- Proper netlink service configuration
- Correct provisioning status verification
- Seamless scene transitions
- Error-free user experience

## Future Enhancements

### Potential Improvements
- **Security:** WPA3 support and credential encryption
- **Performance:** Optimized scanning and connection times
- **User Experience:** Enhanced progress indicators
- **Network:** Multiple SSID support and advanced configuration
- **Diagnostics:** Detailed error logging and troubleshooting

### Extensibility
- Modular design allows for additional provisioning steps
- Message format supports custom parameters
- Scene-based architecture enables feature additions

## Conclusion

The Device Onboarding system provides a robust, user-friendly solution for initial smart target device setup. Its cross-platform consistency, comprehensive error handling, and intuitive user experience make it production-ready for large-scale deployment.

The system's modular architecture and well-defined message protocols ensure maintainability and extensibility for future enhancements.