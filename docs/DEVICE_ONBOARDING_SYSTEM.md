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

### Pre-Launch Detection: Auto-Netlink Ready State

**New Feature (v2.1+):** Devices previously marked as `first_run_complete = true` now automatically detect their WiFi status during app startup and conditionally start the netlink service without showing onboarding.

1. **Splash Loading Enhanced Checks**
   - After settings load, if `first_run_complete = true`:
     - Fetches current `netlink_status` from device
     - Checks for `wifi_status = true` AND valid `wifi_ip` (not empty/0.0.0.0)
   
2. **Three Possible Paths:**
   - **Path A (Auto-Netlink Ready):** WiFi connected + valid IP → Automatically start netlink procedure → `option.tscn`
   - **Path B (WiFi Reconnect):** No WiFi but first_run_complete → Broadcast provision_status:incomplete → `wifi_networks.tscn`
   - **Path C (Fresh Setup):** first_run_complete = false → Standard onboarding → `onboarding.tscn`

### Phase 1: Device Discovery & Introduction

1. **Device Broadcasts Status** (Onboarding Flow)
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

#### Auto-Netlink Setup (Two Scenarios)

**Scenario A: Triggered from WiFi Scene** (when enabled via `wifi_connection` command)
   - User successfully connects to WiFi on `wifi_networks.tscn`
   - System detects valid IP address
   - Automatically configures and starts netlink service
   - Transitions to `option.tscn`

**Scenario B: Auto-Start on Launch** (NEW - for already provisioned devices)
   - Device detected as `first_run_complete = true` with active WiFi
   - Splash loading automatically initiates netlink config
   - No user intervention required if WiFi still connected
   - Transitions directly to `option.tscn`

**Netlink Service Configuration** (Both Scenarios)
   - Configures netlink service (channel 17, device "01", mode "master")
   - 1.5-second delay before starting service (for service stabilization)
   - Graceful fallback to `option.tscn` on config/start failure

**Status Verification**
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

**Files:** `splash_loading.gd`, `onboarding.gd`, `WebSocketListener.gd`, `wifi_networks.gd`

**Key Features:**
- Scene-based UI flow management
- WebSocket command routing
- HTTP service integration
- Auto-netlink configuration
- Enhanced splash loading with provision status detection

**Splash Loading Enhancement (splash_loading.gd):**
```gdscript
# After settings load, if first_run_complete:
func _check_wifi_and_auto_netlink():
    # Fetch netlink_status to check WiFi connectivity
    HttpService.netlink_status(Callable(self, "_on_netlink_status_check_response"))

func _on_netlink_status_check_response(result, response_code, _headers, body):
    # Parse wifi_status and wifi_ip from response
    if wifi_status and ip_valid:
        # WiFi connected: start auto-netlink
        GlobalData.auto_netlink_enabled = true
        _start_auto_netlink()
    else:
        # WiFi not connected: broadcast provision_status and go to wifi_networks
        _start_provision_status_broadcast()
        get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")
```

**WebSocket Provision Step Handling (WebSocketListener.gd):**
```gdscript
# Provision step handling
if content.has("provision_step"):
    var step = content["provision_step"]
    if step == "wifi_connection":
        GlobalData.auto_netlink_enabled = true
        get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")
```

**Auto-Netlink Procedure (splash_loading.gd & wifi_networks.gd - Consistent):**
```gdscript
func _start_auto_netlink():
    # Step 1: Configure netlink service
    HttpService.netlink_config(Callable(self, "_on_auto_netlink_config_response"), 
                              17, "01", "master")

func _on_auto_netlink_config_response(result, response_code, _headers, _body):
    # Step 2: Wait 1.5 seconds for stabilization
    auto_netlink_timer = Timer.new()
    auto_netlink_timer.wait_time = 1.5
    add_child(auto_netlink_timer)
    auto_netlink_timer.timeout.connect(Callable(self, "_on_auto_netlink_delay_timeout"))
    auto_netlink_timer.start()

func _on_auto_netlink_delay_timeout():
    # Step 3: Start netlink service
    HttpService.netlink_start(Callable(self, "_on_auto_netlink_start_response"))

func _on_auto_netlink_start_response(result, response_code, _headers, _body):
    # Transition to option.tscn regardless of success/failure
    get_tree().change_scene_to_file("res://scene/option/option.tscn")
```

## Technical Specifications

### Timing & Timeouts

| Operation | Timeout | Purpose |
|-----------|---------|---------|
| App Loading | 20 seconds | Maximum time for auto-netlink procedures (extended from 10s) |
| Network Scan | 20 seconds | WiFi network discovery |
| IP Polling | 30 seconds | Wait for IP address assignment |
| Verification | 5-second intervals | Status confirmation |
| Provision Status Broadcast | 5-second intervals | Device availability announcement |
| Auto-Netlink Delay | 1.5 seconds | Service startup stabilization |
| WiFi Status Check | On-demand | Performed at app startup for auto-netlink detection |

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

## Enhancements in v2.1

### Auto-Netlink Ready State

**New Capability:** Devices marked as `first_run_complete = true` now support automatic netlink initialization on app startup if WiFi is already connected.

**Benefits:**
- Faster app launch for previously configured devices
- Seamless reconnection without user intervention
- Maintains device provisioning even after app restarts
- Fallback to WiFi reconnection if connection is lost

**Implementation Details:**
- Splash loading timeout extended from 10s to 20s to accommodate netlink procedures
- New provision status broadcast when first_run_complete but WiFi disconnected
- Identical auto-netlink callbacks in both splash_loading.gd and wifi_networks.gd for consistency
- Graceful error handling with transition to option.tscn on failure

**User Experience:**
- Previously provisioned device with WiFi: Automatic netlink start (no user action)
- Previously provisioned device without WiFi: Shows WiFi selection screen with provision_status broadcast
- New device: Standard onboarding flow unchanged

## Conclusion

The Device Onboarding system provides a robust, user-friendly solution for initial smart target device setup. Its cross-platform consistency, comprehensive error handling, and intuitive user experience make it production-ready for large-scale deployment.

With v2.1 enhancements, the system now intelligently detects device provisioning state and WiFi connectivity at startup, enabling automatic netlink initialization for previously configured devices while maintaining seamless WiFi reconnection capabilities.

The system's modular architecture and well-defined message protocols ensure maintainability and extensibility for future enhancements.


App loads → splash_loading
    ↓
Settings load complete
    ↓
Check: first_run_complete?
    ├─ NO → onboarding.tscn (unchanged)
    │
    └─ YES → Fetch netlink_status
        ├─ WiFi connected + valid IP?
        │   ├─ YES → Start auto-netlink
        │   │         ├─ netlink_config
        │   │         ├─ wait 1.5s
        │   │         ├─ netlink_start
        │   │         └─ option.tscn
        │   │
        │   └─ NO → Broadcast provision_status:incomplete
        │           └─ wifi_networks.tscn (user selects WiFi)
        │
        └─ Request fails → main_menu.tscn (fallback)