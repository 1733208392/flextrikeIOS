# Functional Test Plan - FlexTarget Project

## 1. Overview
This Functional Test Plan (FTP) describes the testing approach for the FlexTarget application on both iOS and Android platforms. The focus is on validating the application's features against user requirements and ensuring a consistent experience across different devices and target hardware.

## 2. Test Objectives
- Confirm all user-facing features operate according to specifications.
- Ensure the user interface (UI) is intuitive, responsive, and handles errors gracefully.
- Validate that the hardware-software interaction (BLE) performs reliably from a user perspective.
- Verify localization and accessibility across supported languages.

---

## 3. Core Features & Test Scenarios

### 3.1 User Authentication & Profile
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-AUTH-01 | Login (Valid) | Enter valid credentials and tap Login. | User is redirected to the main dashboard; token is saved. |
| FUNC-AUTH-02 | Login (Invalid) | Enter wrong password or non-existent email. | Appropriate error message is displayed (e.g., "Invalid credentials"). |
| FUNC-AUTH-03 | Auto-Login | Relaunch the app after a successful login. | App opens directly to the dashboard without asking for credentials. |
| FUNC-AUTH-04 | Logout | Tap Logout in settings. | Session is cleared; user is returned to the Login screen. |

### 3.2 BLE Device Management
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-BLE-01 | Scanning | Pull to refresh or tap Scan in BLE view. | Nearby Smart targets are discovered and listed with signal strength. |
| FUNC-BLE-02 | Connection | Tap a discovered device to connect. | Connection status changes to "Connected"; LED on target may flash (if implemented). |
| FUNC-BLE-03 | Reconnection | Disable and re-enable Bluetooth on the phone. | App attempts to automatically reconnect to the last used target. |
| FUNC-BLE-04 | Error Handling | Attempt connection when hardware netlink is disabled. | System alerts user: "netlink is not enabled" as per protocol response. |

### 3.3 Drill Management & Execution
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-DRL-01 | Drill Selection | Browse and select a drill (e.g., "IDPA Standard"). | Drill details and setup options are displayed correctly. |
| FUNC-DRL-02 | Parameters Setup | Modify drill time, target count, or scoring mode. | Changes are reflected in the UI and transmitted to the target. |
| FUNC-DRL-03 | Start Drill | Press "Start" button. | Countdown timer begins; "Standby... Beep" audio triggers. |
| FUNC-DRL-04 | Shot Reception | Fire a laser shot at the smart target. | The shot is instantly displayed on the phone screen with scoring info. |
| FUNC-DRL-05 | End Drill | Complete the drill duration or hit all targets. | Summary screen appears showing hits, misses, split times, and total score. |

### 3.4 History & Analytics
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-HIST-01 | Record Viewing | Navigate to the History tab. | List of previous sessions is displayed chronologically. |
| FUNC-HIST-02 | Detailed View | Tap a specific session in the history list. | Detailed shot map and performance metrics are shown. |
| FUNC-HIST-03 | Data Persistence | Perform a drill while offline, then close the app. | Result is saved locally and remains available on next launch. |

### 3.5 Competition & Leaderboard
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-COMP-01 | View Leaderboard | Open the Competition tab. | Global or event-specific rankings are fetched and displayed. |
| FUNC-COMP-02 | Submit Result | Finish a sanctioned drill and tap "Submit to Leaderboard". | Result is uploaded; success message is shown; ranking updates. |

### 3.6 Profile & Athlete Management
| Test ID | Scenario | Description | Expected Result |
| :--- | :--- | :--- | :--- |
| FUNC-PROF-01 | Edit Profile | Change username or avatar in User Profile view. | Changes are saved and reflected across the app. |
| FUNC-PROF-02 | Athlete List | (If applicable) Add multiple athletes to a single device. | Multiple athlete profiles are managed within the app. |

---

## 4. UI/UX & Non-Functional Testing

### 4.1 Visual & Theme
- **Dark Mode**: All screens must adhere to the design theme (Black background, red accents) as defined in `flextargetApp.swift`.
- **Responsive Layout**: UI elements should adapt to different screen sizes (iPhone SE to iPad, various Android aspect ratios).

### 4.2 Multi-language Support
- Verify following localizations:
    - English (en)
    - Chinese (zh-Hans, zh-Hant)
    - German (de)
    - Spanish (es)
    - Japanese (ja)

### 4.3 Connectivity Edge Cases
- **Out of Range**: Walk away from the target until disconnected; verify "Device Disconnected" alert.
- **Low Battery**: Handle hardware low-battery notifications gracefully.

---

## 5. Test Environment
- **Hardware**: iOS Devices (iOS 15+), Android Devices (API 24+), ET02 Smart Target, Laser Trainer.
- **Mocking**: For automated functional tests, use the Simulator/Emulator flags to simulate BLE messages.

## 6. Acceptance Criteria
- 100% of Critical paths (FUNC-AUTH-01, FUNC-BLE-02, FUNC-DRL-03) must pass.
- No "High" severity UI glitches.
- Localization is complete for all primary user flows.
