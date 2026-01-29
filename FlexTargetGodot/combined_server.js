// Combined Server: HttpServerSim + BLE_WS_SIM
// Merges HTTP server for game data and netlink operations with WebSocket/BLE proxy for Godot-Mobile App communication
//
// TEST SCENARIOS:
// - To test netlink_status failure response, change TEST_SCENARIO_NETLINK_STATUS to 'failure'
//   Response will have code: 1 (error) instead of code: 0 (success)
//   This tests error handling when the netlink service cannot retrieve status

const http = require('http');
const fs = require('fs');
const url = require('url');
const bleno = require('@abandonware/bleno');
const WebSocket = require('ws');

// Netlink state variables (shared between HTTP and WS/BLE)
let netlinkStarted = true;
let netlinkChannel = 0;
let netlinkWorkMode = "master";
let netlinkDeviceName = "01";
let netlinkBluetoothName = "Kai’s MacBook Pro";
let netlinkWifiIp = "192.168.1.100"; // Mock IP for simulation

// BLE Configuration
const SERVICE_UUID = '0000ffc9-0000-1000-8000-00805f9b34fb';
const NOTIFY_CHARACTERISTIC_UUID = '0000ffe1-0000-1000-8000-00805f9b34fb';
const WRITE_CHARACTERISTIC_UUID = '0000ffe2-0000-1000-8000-00805f9b34fb';

// BLE Advertising Configuration
const BLE_DEVICE_NAME = 'BLE-SIM';
const ADVERTISING_INTERVAL_MS = 10000; // Re-advertise every 10 seconds

// WebSocket Configuration
const WS_PATH = '/websocket';

// Embedded System State (for /system/embedded/status endpoint)
let embeddedSystemState = {
  heartbeat: Math.floor(Date.now() / 1000), // Last heartbeat timestamp
  threshold: 1000, // Sensor threshold value
  temperature: 28, // Temperature in Celsius
  version: "v1.0.0" // Hardware version
};

// Test scenario configuration
// Set this to 'failure' to simulate netlink_status request failure (code: 1)
// Set to 'success' for normal operation
let TEST_SCENARIO_NETLINK_STATUS = 'success'; // Options: 'success' | 'failure'

// Global state management for WS/BLE
let mobileAppBLEClient = null;
let godotWSClient = null;
const connectedGodotClients = new Set();

// Drill timing
let drillStartTime = null; // Timestamp when drill started (for bullet t values)
let gameStartTime = null; // Timestamp when game started (for bullet t values)

// Function to get current drill time in milliseconds
function getCurrentDrillTime() {
  if (drillStartTime === null) {
    return 0; // Default if no drill started
  }
  return Date.now() - drillStartTime;
}

// Function to get current game time in milliseconds
function getCurrentGameTime() {
  if (gameStartTime === null) {
    return 0; // Default if no game started
  }
  return Date.now() - gameStartTime;
}

console.log('[CombinedServer] Starting Combined HTTP/WebSocket/BLE Proxy Simulation...');
console.log('[CombinedServer] HTTP server on port 80, WebSocket on path /websocket, BLE advertising service UUID:', SERVICE_UUID);

// ============================================================================
// HTTP SERVER (for game data and netlink operations)
// ============================================================================

const httpServer = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  
  // Log all incoming requests
  console.log(`[HttpServer] ${new Date().toISOString()} - ${req.method} ${pathname}`);

  if (pathname === '/game/save' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { data_id, content, namespace = 'default' } = data;

        if (!data_id || !content) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing data_id or content" }));
          return;
        }

        const fileName = `${data_id}.json`;
        
        // Debug logging for all files
        console.log(`[HttpServer] Saving file: ${fileName}`);
        console.log(`[HttpServer] Content to save: ${content}`);
        
        // Try to parse and log JSON content for debugging
        try {
          const parsedContent = JSON.parse(content);
          console.log(`[HttpServer] Parsed ${data_id} content:`, parsedContent);
          
          // Special handling for settings file
          if (data_id === 'settings') {
            console.log(`[HttpServer] Settings drill_sequence: ${parsedContent.drill_sequence}`);
            console.log(`[HttpServer] Settings language: ${parsedContent.language}`);
          }
        } catch (e) {
          console.log(`[HttpServer] Failed to parse ${data_id} content as JSON for debugging: ${e.message}`);
          console.log(`[HttpServer] Content appears to be non-JSON data`);
        }
        
        fs.writeFile(fileName, content, 'utf8', (err) => {
          if (err) {
            console.error('Error saving file:', err);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "Failed to save file" }));
          } else {
            console.log(`[HttpServer] Successfully saved: ${fileName}`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, msg: "" }));
          }
        });
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/game/load' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { data_id, namespace = 'default' } = data;

        if (!data_id) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing data_id" }));
          return;
        }

        const fileName = `${data_id}.json`;
        
        // Debug logging for all files
        console.log(`[HttpServer] Loading file: ${fileName}`);
        
        fs.readFile(fileName, 'utf8', (err, content) => {
          if (err) {
            console.error('Error loading file:', err);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: {}, msg: "OK" }));
          } else {
            console.log(`[HttpServer] Successfully loaded: ${fileName}`);
            console.log(`[HttpServer] Loaded content: ${content}`);
            
            // Try to parse and log JSON content for debugging
            try {
              const parsedContent = JSON.parse(content);
              console.log(`[HttpServer] Parsed ${data_id} content:`, parsedContent);
              
              // Special handling for settings file
              if (data_id === 'settings') {
                console.log(`[HttpServer] Loaded settings drill_sequence: ${parsedContent.drill_sequence}`);
                console.log(`[HttpServer] Loaded settings language: ${parsedContent.language}`);
              }
            } catch (e) {
              console.log(`[HttpServer] Failed to parse ${data_id} content as JSON for debugging: ${e.message}`);
              console.log(`[HttpServer] Content appears to be non-JSON data`);
            }
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 0, data: content }));
          }
        });
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/game/start' && req.method === 'POST') {
    // 开始游戏 - Start game
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { mode, count, duration } = data;

        // Validate required mode parameter
        if (!mode) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing required parameter: mode" }));
          return;
        }

        // Validate mode values
        const validModes = ['free', 'counter', 'timer'];
        if (!validModes.includes(mode)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid mode. Must be one of: free, counter, timer" }));
          return;
        }

        // Validate count parameter for counter mode
        if (mode === 'counter') {
          if (count === undefined || count === null) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "Missing required parameter: count (required for counter mode)" }));
            return;
          }
          if (!Number.isInteger(count) || count <= 0) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "count must be a positive integer" }));
            return;
          }
        }

        // Validate duration parameter for timer mode
        if (mode === 'timer') {
          if (duration === undefined || duration === null) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "Missing required parameter: duration (required for timer mode)" }));
            return;
          }
          if (!Number.isInteger(duration) || duration <= 0) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ code: 1, msg: "duration must be a positive integer (seconds)" }));
            return;
          }
        }

        // Log the game start
        console.log(`[HttpServer] Game started with mode: ${mode}`);
        if (mode === 'counter') {
          console.log(`[HttpServer] Target shot count: ${count}`);
        } else if (mode === 'timer') {
          console.log(`[HttpServer] Game duration: ${duration} seconds`);
        }

        // Set game start time for bullet timing
        gameStartTime = Date.now();

        // TODO: Store game state and implement game logic
        // For now, just acknowledge the game start

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          code: 0, 
          msg: "Game started successfully",
          data: {
            mode: mode,
            count: mode === 'counter' ? count : null,
            duration: mode === 'timer' ? duration : null,
            start_time: new Date().toISOString()
          }
        }));

      } catch (error) {
        console.log(`[HttpServer] /game/start - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });
  } else if (pathname === '/netlink/wifi/scan' && req.method === 'POST') {
    const ssidList = ["cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G", "cjyw", "cjyw2", "cjyw5G"];
    console.log(`[HttpServer] Starting WiFi scan simulation (15s delay)...`);
    // Simulate 15 second delay for WiFi scanning
    setTimeout(() => {
      console.log(`[HttpServer] WiFi scan completed`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ code: 0, msg: "", data: { ssid_list: ssidList } }));
    }, 5000);
  } else if (pathname === '/netlink/wifi/connect' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const requestData = JSON.parse(body);

        // Accept both simple payload and legacy wrapped payload
        let ssid = null;
        let password = null;

        if (requestData && typeof requestData === 'object') {
          if (requestData.ssid && requestData.password) {
            ssid = requestData.ssid;
            password = requestData.password;
          } else if (requestData.type === 'netlink' && requestData.action === 'forward' && requestData.content) {
            try {
              const parsedContent = JSON.parse(requestData.content);
              ssid = parsedContent.ssid;
              password = parsedContent.password;
            } catch (e) {
              // content was not valid JSON
              ssid = null;
              password = null;
            }
          }
        }

        if (!ssid || !password) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: 'Missing ssid or password' }));
          return;
        }

        // Simulate WiFi connection with 10 second delay
        console.log(`[HttpServer] Connecting to WiFi: SSID=${ssid} (10s delay)...`);
        setTimeout(() => {
          console.log(`[HttpServer] WiFi connection completed for SSID=${ssid}`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 0, data: {}, msg: '' }));
        }, 5000);
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: 'Invalid JSON' }));
      }
    });
  } else if (pathname === '/netlink/config' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const { channel, work_mode, device_name } = data;

        // Validate channel: must be int between 1 and 254
        if (typeof channel !== 'number' || !Number.isInteger(channel) || channel < 1 || channel > 254) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid channel: must be integer between 1 and 254" }));
          return;
        }

        // Validate work_mode: must be "master" or "slave"
        if (typeof work_mode !== 'string' || (work_mode !== 'master' && work_mode !== 'slave')) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid work_mode: must be 'master' or 'slave'" }));
          return;
        }

        // Validate device_name: must be string
        if (typeof device_name !== 'string') {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid device_name: must be string" }));
          return;
        }

        // Simulate configuration with 10 second delay
        console.log(`[HttpServer] Starting netlink configuration: channel=${channel}, work_mode=${work_mode}, device_name=${device_name} (10s delay)...`);
        
        setTimeout(() => {
          // Store the configuration
          netlinkChannel = channel;
          netlinkWorkMode = work_mode;
          netlinkDeviceName = device_name;
          netlinkBluetoothName = netlinkBluetoothName;
          
          console.log(`[HttpServer] Netlink configuration completed`);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 0, msg: "Configuration successful" }));
        }, 5000);
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/netlink/start' && req.method === 'POST') {
    // Start netlink service
    netlinkStarted = true;
    console.log(`[HttpServer] Netlink service started`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ code: 0, msg: "" }));
  } else if (pathname === '/netlink/stop' && req.method === 'POST') {
    // Stop netlink service
    netlinkStarted = false;
    console.log(`[HttpServer] Netlink service stopped`);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ code: 0, msg: "" }));
  } else if (pathname === '/netlink/status' && req.method === 'POST') {
    // Get netlink service status
    console.log(`[HttpServer] Netlink status requested`);
    
    // Test scenario: simulate failure response
    if (TEST_SCENARIO_NETLINK_STATUS === 'failure') {
      console.log(`[HttpServer] TEST SCENARIO: Responding with failure (code: 1)`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        code: 0,
        msg: "",
        data: {
          wifi_ip: netlinkWifiIp,
          wifi_status: false,
          channel: 0,
          work_mode: null,
          device_name: null,
          bluetooth_name: netlinkBluetoothName,
          started: false
        }
      }));
      return;
    }
    
    // Normal success response
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "",
      data: {
        wifi_ip: netlinkWifiIp,
        wifi_status: true,
        channel: netlinkChannel,
        work_mode: netlinkWorkMode,
        device_name: netlinkDeviceName,
        bluetooth_name: netlinkBluetoothName,
        started: netlinkStarted
      }
    }));
    
  } else if (pathname === '/netlink/forward-data' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const content = JSON.parse(body);

        if (!content) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing content" }));
          return;
        }

        // Use the parsed content directly as envelope, change action and ensure device/type
        const envelope = content;
        envelope.action = 'forward'; // Change action for BLE compatibility
        envelope.device = netlinkDeviceName; // Ensure device is the server's device name
        envelope.type = 'netlink'; // Ensure type is set

        console.log(`[HttpServer] Forwarding data to BLE:`, envelope);

        // Split message into chunks and send via BLE
        sendMessageInChunks(envelope);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: "" }));
      } catch (error) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON" }));
      }
    });
  } else if (pathname === '/system/embedded/status' && req.method === 'POST') {
    // Query embedded system status
    // Update heartbeat to current timestamp
    embeddedSystemState.heartbeat = Math.floor(Date.now() / 1000);
    
    console.log(`[HttpServer] /system/embedded/status called`);
    console.log(`[HttpServer] Embedded system state:`, embeddedSystemState);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "Success",
      data: {
        heartbeat: embeddedSystemState.heartbeat,
        threshold: embeddedSystemState.threshold,
        temperature: embeddedSystemState.temperature,
        version: embeddedSystemState.version
      }
    }));
  } else if (pathname === '/system/embedded/threshold' && req.method === 'POST') {
    // Set sensor threshold
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const value = data.value;

        // Validate that value is provided
        if (value === undefined || value === null) {
          console.log(`[HttpServer] /system/embedded/threshold - Missing 'value' parameter`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing 'value' parameter" }));
          return;
        }

        // Validate that value is a number and within range (700-2000)
        const numValue = parseInt(value);
        if (isNaN(numValue)) {
          console.log(`[HttpServer] /system/embedded/threshold - Invalid value type: ${value}`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid value type (must be integer)" }));
          return;
        }

        if (numValue < 700 || numValue > 2000) {
          console.log(`[HttpServer] /system/embedded/threshold - Value out of range: ${numValue} (must be 700-2000)`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Value must be between 700 and 2000" }));
          return;
        }

        // Update threshold value
        embeddedSystemState.threshold = numValue;
        console.log(`[HttpServer] /system/embedded/threshold set to: ${numValue}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: "Threshold set successfully" }));
      } catch (error) {
        console.log(`[HttpServer] /system/embedded/threshold - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/config/netlink-mode' && req.method === 'POST') {
    // Test endpoint: dynamically change netlink work mode
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const workMode = data.work_mode;

        // Validate that work_mode is provided
        if (workMode === undefined || workMode === null) {
          console.log(`[TestEndpoint] /test/config/netlink-mode - Missing 'work_mode' parameter`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing 'work_mode' parameter" }));
          return;
        }

        // Validate that work_mode is either 'master' or 'slave'
        if (workMode !== 'master' && workMode !== 'slave') {
          console.log(`[TestEndpoint] /test/config/netlink-mode - Invalid work_mode: ${workMode}`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "work_mode must be 'master' or 'slave'" }));
          return;
        }

        // Update netlink work mode
        netlinkWorkMode = workMode;
        console.log(`[TestEndpoint] Netlink work_mode changed to: ${workMode}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 0, msg: `Work mode set to '${workMode}'` }));
      } catch (error) {
        console.log(`[TestEndpoint] /test/config/netlink-mode - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/config/netlink-status-scenario' && req.method === 'POST') {
    // Test endpoint: dynamically change test scenario for netlink status
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const scenario = data.scenario;

        // Validate that scenario is provided
        if (scenario === undefined || scenario === null) {
          console.log(`[TestEndpoint] /test/config/netlink-status-scenario - Missing 'scenario' parameter`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing 'scenario' parameter" }));
          return;
        }

        // Validate that scenario is either 'success' or 'failure'
        if (scenario !== 'success' && scenario !== 'failure') {
          console.log(`[TestEndpoint] /test/config/netlink-status-scenario - Invalid scenario: ${scenario}`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "scenario must be 'success' or 'failure'" }));
          return;
        }

        // Update test scenario
        TEST_SCENARIO_NETLINK_STATUS = scenario;
        console.log(`[TestEndpoint] TEST_SCENARIO_NETLINK_STATUS changed to: ${scenario}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          code: 0, 
          msg: `Test scenario set to '${scenario}'`,
          current_scenario: TEST_SCENARIO_NETLINK_STATUS
        }));
      } catch (error) {
        console.log(`[TestEndpoint] /test/config/netlink-status-scenario - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/config/netlink-started' && req.method === 'POST') {
    // Test endpoint: dynamically change netlink started state
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const started = data.started;

        // Validate that started is provided
        if (started === undefined || started === null) {
          console.log(`[TestEndpoint] /test/config/netlink-started - Missing 'started' parameter`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Missing 'started' parameter" }));
          return;
        }

        // Validate that started is a boolean
        if (typeof started !== 'boolean') {
          console.log(`[TestEndpoint] /test/config/netlink-started - Invalid started type: ${typeof started}`);
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "started must be a boolean (true or false)" }));
          return;
        }

        // Update netlink started state
        netlinkStarted = started;
        console.log(`[TestEndpoint] Netlink started state changed to: ${started}`);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          code: 0, 
          msg: `Netlink started set to ${started}`,
          current_started: netlinkStarted
        }));
      } catch (error) {
        console.log(`[TestEndpoint] /test/config/netlink-started - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/query/netlink-status' && req.method === 'POST') {
    // Test endpoint: query current netlink status
    console.log(`[TestEndpoint] /test/query/netlink-status called`);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      code: 0,
      msg: "Current netlink status",
      data: {
        wifi_ip: netlinkWifiIp,
        wifi_status: true,
        channel: netlinkChannel,
        work_mode: netlinkWorkMode,
        device_name: netlinkDeviceName,
        bluetooth_name: netlinkBluetoothName,
        started: netlinkStarted
      }
    }));

  // ============================================================================
  // TEST ENDPOINTS - Simulate netlink commands for unit testing drills_network scene
  // ============================================================================
  // These endpoints simulate the mobile app sending BLE messages:
  //   Body: {"action":"netlink_forward","content":{...},"dest":"A"}
  //   Server forwards: { type: 'netlink', data: content } to Godot
  //
  // Usage:
  //   curl -X POST http://localhost/test/ble/animation_config -H "Content-Type: application/json" \
  //     -d '{"action":"netlink_forward","content":{"command":"animation_config","target_id":"ipsc_mini","action":"run_through","duration":5},"dest":"A"}'
  //
  //   curl -X POST http://localhost/test/ble/ready -H "Content-Type: application/json" \
  //     -d '{"action":"netlink_forward","content":{"command":"ready","isFirst":false,"isLast":true,"targetType":"ipsc","timeout":30,"delay":5},"dest":"A"}'
  //
  //   curl -X POST http://localhost/test/ble/start -H "Content-Type: application/json" \
  //     -d '{"action":"netlink_forward","content":{"command":"start","repeat":1},"dest":"A"}'
  //
  //   curl -X POST http://localhost/test/ble/end -H "Content-Type: application/json" \
  //     -d '{"action":"netlink_forward","content":{"command":"end"},"dest":"A"}'
  //
  // Test Scenarios:
  //   1. First target only:      isFirst=true,  isLast=false
  //   2. Middle target:          isFirst=false, isLast=false
  //   3. Last target (not first): isFirst=false, isLast=true
  //   4. Single target:          isFirst=true,  isLast=true
  // ============================================================================

  } else if (pathname === '/test/ble/ready' && req.method === 'POST') {
    // Simulate BLE ready command from mobile app
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsedData = JSON.parse(body);
        
        // Copy BLE forwarding logic: check for netlink_forward and content
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log(`[TestEndpoint] Simulating BLE ready command:`, parsedData.content);
          
          // Send { type: 'netlink', data: content } to Godot
          const message = {
            type: 'netlink',
            action:'netlink_forward',
            dest: '01',
            data: parsedData.content,
          };
          
          // Broadcast to all connected Godot WebSocket clients
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(message));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Netlink ready sent to ${sentCount} Godot client(s)`);
          
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            code: 0, 
            msg: `BLE ready command sent to ${sentCount} client(s)`,
            sent: message
          }));
        } else {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid message format: expected action='netlink_forward' and content" }));
        }
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/ready - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/ble/start' && req.method === 'POST') {
    // Simulate BLE start command from mobile app
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsedData = JSON.parse(body);
        
        // Copy BLE forwarding logic: check for netlink_forward and content
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log(`[TestEndpoint] Simulating BLE start command:`, parsedData.content);
          
          // Set drill start time for bullet timing
          drillStartTime = Date.now();
          
          // Send { type: 'netlink', data: content } to Godot
          const message = {
            type: 'netlink',
            data: parsedData.content
          };
          
          // Broadcast to all connected Godot WebSocket clients
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(message));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Netlink start sent to ${sentCount} Godot client(s)`);
          
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            code: 0, 
            msg: `BLE start command sent to ${sentCount} client(s)`,
            sent: message
          }));
        } else {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid message format: expected action='netlink_forward' and content" }));
        }
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/start - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/ble/end' && req.method === 'POST') {
    // Simulate BLE end command from mobile app
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsedData = JSON.parse(body);
        
        // Copy BLE forwarding logic: check for netlink_forward and content
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log(`[TestEndpoint] Simulating BLE end command:`, parsedData.content);
          
          // Check for end command to reset drill timing
          if (parsedData.content.command === 'end') {
            console.log('[TestEndpoint] End command received, resetting drill start time');
            drillStartTime = null;
          }
          
          // Send { type: 'netlink', data: content } to Godot
          const message = {
            type: 'netlink',
            data: parsedData.content
          };
          
          // Broadcast to all connected Godot WebSocket clients
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(message));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Netlink end sent to ${sentCount} Godot client(s)`);
          
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            code: 0, 
            msg: `BLE end command sent to ${sentCount} client(s)`,
            sent: message
          }));
        } else {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid message format: expected action='netlink_forward' and content" }));
        }
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/end - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/ble/animation_config' && req.method === 'POST') {
    // Simulate BLE animation_config command from mobile app
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsedData = JSON.parse(body);
        
        // Copy BLE forwarding logic: check for netlink_forward and content
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log(`[TestEndpoint] Simulating BLE animation_config command:`, parsedData.content);
          
          // Send { type: 'netlink', data: content } to Godot
          const message = {
            type: 'netlink',
            data: parsedData.content
          };
          
          // Broadcast to all connected Godot WebSocket clients
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(message));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Netlink animation_config sent to ${sentCount} Godot client(s)`);
          
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            code: 0, 
            msg: `BLE animation_config command sent to ${sentCount} client(s)`,
            sent: message
          }));
        } else {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ code: 1, msg: "Invalid message format: expected action='netlink_forward' and content" }));
        }
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/animation_config - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/ble/sequence' && req.method === 'POST') {
    // Simulate BLE sequence: ready -> animation_config -> start
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const parsedData = body ? JSON.parse(body) : {};
        
        // Default animation config if not provided
        const animationConfig = parsedData.animation_config || {
          command: 'animation_config',
          action: 'swing_left',
          duration: 5};
        
        console.log(`[TestEndpoint] Starting BLE sequence: animation_config -> ready -> start -> end`);
        
        // Send animation_config after 1 second
        setTimeout(() => {
          const animationMessage = {
            type: 'netlink',
            data: animationConfig
          };
          
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(animationMessage));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Sequence step 1: Animation config sent to ${sentCount} Godot client(s):`, animationMessage);
        }, 1000);
        
        // Send ready command after 2 seconds
        setTimeout(() => {
          const readyMessage = {
            type: 'netlink',
            action: 'netlink_forward',
            dest: '01',
            data: {
              command: 'ready',
              isFirst: true,
              isLast: true,
              targetType: 'ipsc',
              timeout: 30,
              delay: 5,
              mode: 'CQB'
            }
          };
          
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(readyMessage));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Sequence step 2: Ready sent to ${sentCount} Godot client(s)`);
        }, 5000);
        
        // Send start command after 10 seconds
        setTimeout(() => {
          // Set drill start time for bullet timing
          drillStartTime = Date.now();
          
          const startMessage = {
            type: 'netlink',
            data: {
              command: 'start',
              repeat: 1
            }
          };
          
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(startMessage));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Sequence step 3: Start sent to ${sentCount} Godot client(s)`);
        }, 10000);
        
        // Send end command after 4 seconds
        setTimeout(() => {
          // Reset drill start time for end command
          drillStartTime = null;
          
          const endMessage = {
            type: 'netlink',
            data: {
              command: 'end'
            }
          };
          
          let sentCount = 0;
          connectedGodotClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify(endMessage));
              sentCount++;
            }
          });
          
          console.log(`[TestEndpoint] Sequence step 4: End sent to ${sentCount} Godot client(s)`);
        }, 20000);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          code: 0, 
          msg: 'BLE sequence started: animation_config (1s) -> ready (2s) -> start (10s) -> end (20s)',
          sequence: ['animation_config', 'ready', 'start', 'end'],
          animation_config: animationConfig
        }));
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/sequence - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });

  } else if (pathname === '/test/ble/shot' && req.method === 'POST') {
    // Simulate a bullet hit for testing target interactions
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const content = body ? JSON.parse(body) : {};
        const x = content.x !== undefined ? content.x : 960;  // Default center X
        const y = content.y !== undefined ? content.y : 540;  // Default center Y
        
        console.log(`[TestEndpoint] Simulating shot at (${x}, ${y})`);
        
        // Create shot message matching the format expected by WebSocketListener
        const shotMessage = {
          type: 'shot',
          x: x,
          y: y
        };
        
        // Broadcast to all connected Godot WebSocket clients
        let sentCount = 0;
        connectedGodotClients.forEach(client => {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(shotMessage));
            sentCount++;
          }
        });
        
        console.log(`[TestEndpoint] Shot sent to ${sentCount} Godot client(s)`);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          code: 0, 
          msg: `Shot sent to ${sentCount} client(s)`,
          sent: shotMessage
        }));
      } catch (error) {
        console.log(`[TestEndpoint] /test/ble/shot - JSON parse error: ${error.message}`);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ code: 1, msg: "Invalid JSON format" }));
      }
    });
  } else if (pathname === '/test/multi-target/acks' && req.method === 'POST') {
    // ============================================================================
    // TEST ENDPOINT: Multi-Target Acks Only (8 targets)
    // ============================================================================
    // Sends acknowledgments only to 8 targets (1 master + 7 slaves)
    //
    // Usage:
    //   curl -X POST http://localhost/test/multi-target/acks
    //
    // This endpoint:
    // - Sends ack:ready for each of 8 targets at staggered intervals
    // ============================================================================
    
    console.log(`[TestEndpoint] Multi-Target Acks: Received request`);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      code: 0, 
      msg: 'Sending acks to 8 targets'
    }));
    
    // Send ack:ready for each target
    for (let i = 1; i <= 8; i++) {
      (function(index) {
        const targetName = String(index).padStart(2, '0');
        
        // Send ack:ready at staggered intervals
        setTimeout(() => {
          const ackMessage = {
            action: 'forward',
            type: 'netlink',
            device: targetName,
            content: {
              ack: 'ready'
            }
          };
          
          forwardToMobileApp(ackMessage);
          console.log(`[TestEndpoint] Multi-Target Acks: Sent ack:ready for target ${targetName}`);
        }, index * 500);
      })(i);
    }

  } else if (pathname === '/test/multi-target/shots' && req.method === 'POST') {
    // ============================================================================
    // TEST ENDPOINT: Multi-Target Shots Only (8 targets)
    // ============================================================================
    // Sends shot data only to 8 targets (1 master + 7 slaves)
    //
    // Usage:
    //   curl -X POST http://localhost/test/multi-target/shots
    //
    // This endpoint:
    // - Sends 2 shots (AZone + BZone) for each of 8 targets at staggered intervals
    // ============================================================================
    
    console.log(`[TestEndpoint] Multi-Target Shots: Received request`);
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      code: 0, 
      msg: 'Sending shots to 8 targets'
    }));
    
    // Send shots for each target
    for (let i = 1; i <= 8; i++) {
      (function(index) {
        const targetName = String(index).padStart(2, '0');
        
        // Send first shot with delay
        setTimeout(() => {
          const shotData1 = {
            cmd: 'shot',
            ha: 'AZone',
            hp: {
              x: '360.0',
              y: '452.5'
            },
            rep: 1,
            std: '0.00',
            tt: 'ipsc',
            td: '0.18'
          };
          
          const shot1Message = {
            device: targetName,
            action: 'forward',
            type: 'netlink',
            content: shotData1
          };
          
          forwardToMobileApp(shot1Message);
          console.log(`[TestEndpoint] Multi-Target Shots: Sent shot 1 (AZone) for target ${targetName}`);
        }, (index * 1000) + 200);
        
        // Send second shot with even longer delay
        setTimeout(() => {
          const shotData2 = {
            cmd: 'shot',
            ha: 'AZone',
            hp: {
              x: '375.0',
              y: '465.0'
            },
            rep: 1,
            std: '0.00',
            tt: 'ipsc',
            td: '0.25'
          };
          
          const shot2Message = {
            device: targetName,
            action: 'forward',
            type: 'netlink',
            content: shotData2
          };
          
          forwardToMobileApp(shot2Message);
          console.log(`[TestEndpoint] Multi-Target Shots: Sent shot 2 (BZone) for target ${targetName}`);
        }, (index * 1000) + 300);
      })(i);
    }

  } else {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
    });
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ code: 0, msg: "" }));
    });
  }
});

// ============================================================================
// WEBSOCKET SERVER (for Godot Game communication)
// ============================================================================

const wss = new WebSocket.Server({ server: httpServer, path: WS_PATH });

// Shot data simulation (from Low Level HW to Godot)
const randomDataOptions = [
  { t: 630, x: 100, y: 200, a: 1069 },
  { t: 630, x: 40, y: 300, a: 1069 },
  { t: 630, x: 250, y: 300, a: 1069 },
  { t: 630, x: 250, y: 250, a: 1069 },
  { t: 630, x: 200, y: 300, a: 1069 },
  { t: 630, x: 200, y: 200, a: 1069 },
  { t: 630, x: 200, y: 100, a: 1069 },
  { t: 630, x: 170, y: 200, a: 1069 },
  { t: 630, x: 134, y: 238.2, a: 1069 }
];

// Bullet variance for realistic simulation
const BULLET_VARIANCE = {
  maxX: 10.0,
  maxY: 10.0,
};

function addBulletVariance(bulletData) {
  const variedBullet = { ...bulletData };
  const u1 = Math.random();
  const u2 = Math.random();
  const z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  const z1 = Math.sqrt(-2 * Math.log(u1)) * Math.sin(2 * Math.PI * u2);
  
  variedBullet.x = Math.round((bulletData.x + (z0 * BULLET_VARIANCE.maxX * 0.33)) * 10) / 10;
  variedBullet.y = Math.round((bulletData.y + (z1 * BULLET_VARIANCE.maxY * 0.33)) * 10) / 10;
  
  return variedBullet;
}

// WebSocket server event handlers
wss.on('listening', () => {
  console.log(`[CombinedServer] WebSocket server listening on path ${WS_PATH}`);
});

wss.on('connection', (ws) => {
  console.log('[CombinedServer] Godot client connected via WebSocket');
  connectedGodotClients.add(ws);
  godotWSClient = ws; // Keep reference to latest client

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log('[CombinedServer] Received from Godot:', data);
      
      // Handle netlink forward messages from Godot to Mobile App
      if (data.type === 'netlink' && data.action === 'forward') {
        console.log('[CombinedServer] Forwarding netlink forward message from Godot to Mobile App');
        forwardToMobileApp(data);
      } else {
        // Forward other messages from Godot to Mobile App via BLE
        forwardToMobileApp(data);
      }
    } catch (error) {
      console.log('[CombinedServer] Invalid JSON from Godot:', error.message);
    }
  });

  ws.on('close', () => {
    console.log('[CombinedServer] Godot client disconnected');
    connectedGodotClients.delete(ws);
    if (godotWSClient === ws) {
      godotWSClient = null;
    }
  });
});

// Add keyboard input for remote control directives (only if we have a controlling terminal)
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');

  // Debounce mechanism for Enter key to prevent double firing
  let lastEnterTime = 0;
  const ENTER_DEBOUNCE_MS = 50; // 50ms debounce

  // Burst mode configuration
  let burstMode = false;
  let burstInterval = null;
  const BURST_RATE_MS = 50; // 50ms = 20 bullets per second (1000ms / 20)

  process.stdin.on('data', (key) => {
    const keyStr = key.toString();
  let directive = null;

  // Map keys to directives (from original WebSocket server)
  if (keyStr === 'B' || keyStr === 'b') { // B - Send volley of bullets near bottom of scene (268x476.4, bottom-left origin)
    if (connectedGodotClients.size > 0) {
      // Target scene dimensions: width=268, height=476.4 (origin: bottom-left so y=0 is bottom)
      const SCENE_W = 268;
      const SCENE_H = 476.4;

      // Volley configuration (bottom area: small y values near 0)
      const volleyCount = 6; // number of bullets in volley
      const minY = 0;       // bottommost
      const maxY = 60;      // up to 60 units above bottom

      const bullets = [];
      for (let i = 0; i < volleyCount; i++) {
        // evenly space across width with small random jitter
        const slotCenterX = Math.round(((i + 0.5) / volleyCount) * SCENE_W);
        const x = Math.round(slotCenterX + (Math.random() - 0.5) * 8); // small jitter for narrow scene
        // since origin is bottom-left, pick y between minY..maxY
        const y = Math.round(minY + Math.random() * (maxY - minY));

        const baseBullet = { t: getCurrentGameTime(), x: x, y: y, a: 1069 };
        bullets.push(addBulletVariance(baseBullet));
      }

      const bulletMessage = { type: 'data', data: bullets };
      sendToGodot(bulletMessage);
      console.log('[CombinedServer] Bottom-left volley sent via keyboard - bullets:', bullets.length);
    }
    return;
  } else if (keyStr === 'C' || keyStr === 'c') { // C - Send center screen bullet
    if (connectedGodotClients.size > 0) {
      const centerBullet = { t: getCurrentGameTime(), x: 134, y: 238.2, a: 1069 };
      const bulletMessage = {
        type: 'data',
        data: [centerBullet]
      };
      sendToGodot(bulletMessage);
      console.log('[CombinedServer] Center bullet sent via keyboard');
    }
    return;
  } else if (keyStr === 'F' || keyStr === 'f') { // F - toggle burst mode (20 bullets/second)
    if (burstMode) {
      // Stop burst mode
      if (burstInterval) {
        clearInterval(burstInterval);
        burstInterval = null;
      }
      burstMode = false;
      console.log('[CombinedServer] Burst mode stopped');
    } else {
      // Start burst mode
      burstMode = true;
      burstInterval = setInterval(() => {
        if (connectedGodotClients.size > 0) {
          // Generate random bullet with dynamic timing
          const randomData = randomDataOptions[Math.floor(Math.random() * randomDataOptions.length)];
          const dynamicBullet = { ...randomData, t: getCurrentGameTime() };
          const variedData = addBulletVariance(dynamicBullet);
          const randomDataPayload = {
            type: 'data',
            data: [variedData]
          };
          sendToGodot(randomDataPayload);
        }
      }, BURST_RATE_MS);
      console.log(`[CombinedServer] Burst mode started - firing at 20 bullets/second (${BURST_RATE_MS}ms intervals)`);
    }
    return; // Don't send control message
  } else if (keyStr === '\u001B[A') { // Arrow Up
    directive = 'up';
  } else if (keyStr === '\u001B[B') { // Arrow Down
    directive = 'down';
  } else if (keyStr === '\u001B[C') { // Arrow Right
    directive = 'right';
  } else if (keyStr === '\u001B[D') { // Arrow Left
    directive = 'left';
  } else if (keyStr === '\r') { // Enter
    // Debounce Enter key to prevent double firing
    const now = Date.now();
    if (now - lastEnterTime > ENTER_DEBOUNCE_MS) {
      directive = 'enter';
      lastEnterTime = now;
    } else {
      return; // Skip duplicate Enter within debounce period
    }
  } else if (keyStr === 'H' || keyStr === 'h') { // H - homepage
    directive = 'homepage';
  } else if (keyStr === 'K' || keyStr === 'k') { // K - back
    directive = 'back';
  } else if (keyStr === 'M' || keyStr === 'm') { // M - compose
    directive = 'compose';
  } else if (keyStr === 'V' || keyStr === 'v') { // V - volume_up
    directive = 'volume_up';
  } else if (keyStr === 'D' || keyStr === 'd') { // D - volume_down
    directive = 'volume_down';
  } else if (keyStr === 'P' || keyStr === 'p') { // P - power
    directive = 'power';
  } else if (keyStr === '\u0003') { // Ctrl+C
    process.exit();
  }

  if (directive) {
    const controlMessage = { type: 'control', directive };
    sendToGodot(controlMessage);
    console.log(`[CombinedServer] Sent control directive: ${directive}`);
  }
  });
}

// Function to send data to Godot clients
function sendToGodot(data) {
  const message = JSON.stringify(data);
  connectedGodotClients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
      console.log('[CombinedServer] Sent to Godot:', message);
    }
  });
}

// ============================================================================
// BLE PERIPHERAL (for Mobile App communication)
// ============================================================================

// BLE Notify Characteristic (Mobile App reads data)
class NotifyCharacteristic extends bleno.Characteristic {
  constructor() {
    super({
      uuid: NOTIFY_CHARACTERISTIC_UUID,
      properties: ['read', 'notify'],
      value: null
    });

    this._value = Buffer.from(JSON.stringify({ type: 'ready' }));
    this._updateValueCallback = null;
  }

  onReadRequest(offset, callback) {
    console.log('[CombinedServer] Mobile App read request on notify characteristic');
    callback(bleno.Characteristic.RESULT_SUCCESS, this._value);
  }

  onSubscribe(maxValueSize, updateValueCallback) {
    console.log('[CombinedServer] Mobile App subscribed to BLE notifications');
    this._updateValueCallback = updateValueCallback;
    mobileAppBLEClient = this;
  }

  onUnsubscribe() {
    console.log('[CombinedServer] Mobile App unsubscribed from BLE notifications');
    this._updateValueCallback = null;
    mobileAppBLEClient = null;
  }

  // Method to send data to Mobile App
  sendToMobileApp(data) {
    if (this._updateValueCallback) {
      this._value = Buffer.from(JSON.stringify(data) + "\r\n");
      this._updateValueCallback(this._value);
      console.log('[CombinedServer] Sent to Mobile App via BLE:', JSON.stringify(data));
    }
  }
}

// BLE Write Characteristic (Mobile App sends data)
class WriteCharacteristic extends bleno.Characteristic {
  constructor(notifyCharacteristic) {
    super({
      uuid: WRITE_CHARACTERISTIC_UUID,
      properties: ['write'],
      value: null
    });
    this.notifyCharacteristic = notifyCharacteristic;
    this.messageBuffer = ''; // Buffer for accumulating split message packets
  }

  onWriteRequest(data, offset, withoutResponse, callback) {
    const receivedData = data.toString('utf8');
    
    // Accumulate data in buffer
    this.messageBuffer += receivedData;
    
    console.log('[CombinedServer] BLE data received, buffer now:', this.messageBuffer);
    
    // Check if we have a complete message (ends with \r\n)
    if (this.messageBuffer.endsWith('\r\n')) {
      // Remove the \r\n terminator and process the complete message
      const completeMessage = this.messageBuffer.slice(0, -2);
      
      console.log('[CombinedServer] ===========================================');
      console.log('[CombinedServer] COMPLETE BLE MESSAGE RECEIVED');
      console.log('[CombinedServer] Raw data:', completeMessage);
      console.log('[CombinedServer] ===========================================');

      try {
        const parsedData = JSON.parse(completeMessage);
        console.log('[CombinedServer] Parsed BLE message:');
        console.log(JSON.stringify(parsedData, null, 2));
        console.log('[CombinedServer] ===========================================');
        
        // Handle netlink forward messages from Mobile App to Godot
        if (parsedData.action === 'netlink_forward' && parsedData.content) {
          console.log('[CombinedServer] Forwarding netlink message from Mobile App to Godot');
          
          // Check for end command to reset drill timing
          if (parsedData.content.command === 'end') {
            console.log('[CombinedServer] End command received, resetting drill start time');
            drillStartTime = null;
          }
          
          sendToGodot({ type: 'netlink', data: parsedData.content });
        }
        
        // Handle specific commands
        if (parsedData.action === 'netlink_query_device_list') {
          console.log('[CombinedServer] Processing query_device_list from Mobile App');
          const response = {
            type: 'netlink',
            action: 'device_list',
            data: [
              { mode: 'master', name: '01' }
            ]
          };
          
          // Send response back to Mobile App
          if (this.notifyCharacteristic) {
            this.notifyCharacteristic.sendToMobileApp(response);
            console.log('[CombinedServer] Sent device_list response to Mobile App with 8 devices');
          } else {
            console.log('[CombinedServer] Cannot send device_list response: notify characteristic not available');
          }
        }

      } catch (error) {
        console.log('[CombinedServer] ERROR: Failed to parse BLE data from Mobile App:', error.message);
        console.log('[CombinedServer] Raw data was:', completeMessage);
        console.log('[CombinedServer] ===========================================');
      }
      
      // Clear the buffer after processing
      this.messageBuffer = '';
    } else {
      console.log('[CombinedServer] Waiting for more data to complete message...');
    }

    callback(bleno.Characteristic.RESULT_SUCCESS);
  }
}

// Function to split message into chunks and send via BLE
function sendMessageInChunks(data) {
  if (!mobileAppBLEClient || !mobileAppBLEClient._updateValueCallback) {
    console.log('[CombinedServer] No Mobile App connected via BLE to forward message');
    return;
  }

  const jsonString = JSON.stringify(data);
  const maxChunkSize = 100;
  const chunks = [];
  
  // Split the message into chunks of max 100 bytes
  for (let i = 0; i < jsonString.length; i += maxChunkSize) {
    chunks.push(jsonString.slice(i, i + maxChunkSize));
  }
  
  console.log(`[CombinedServer] Splitting message into ${chunks.length} chunks`);
  
  // Send all chunks with delay to ensure proper ordering
  chunks.forEach((chunk, index) => {
    setTimeout(() => {
      const isLastChunk = index === chunks.length - 1;
      const chunkToSend = isLastChunk ? chunk + '\r\n' : chunk;
      
      const buffer = Buffer.from(chunkToSend);
      mobileAppBLEClient._updateValueCallback(buffer);
      
      console.log(`[CombinedServer] Sent chunk ${index + 1}/${chunks.length} (${buffer.length} bytes)${isLastChunk ? ' [END]' : ''}: ${chunkToSend}`);
    }, index * 50); // 50ms delay between chunks
  });
}

// Function to forward data from Godot to Mobile App
function forwardToMobileApp(data) {
  if (mobileAppBLEClient) {
    mobileAppBLEClient.sendToMobileApp(data);
  } else {
    console.log('[CombinedServer] No Mobile App connected via BLE to forward message');
  }
}

// Create BLE service
const notifyCharacteristic = new NotifyCharacteristic();
const writeCharacteristic = new WriteCharacteristic(notifyCharacteristic);

const bleService = new bleno.PrimaryService({
  uuid: SERVICE_UUID,
  characteristics: [
    notifyCharacteristic,
    writeCharacteristic
  ]
});

// BLE advertising management
let advertisingInterval = null;

function startActiveAdvertising() {
  //console.log('[CombinedServer] Starting active advertising with service UUID:', SERVICE_UUID);
  
  // Start advertising with service UUID prominently featured
  bleno.startAdvertising(BLE_DEVICE_NAME, [SERVICE_UUID], (error) => {
    if (error) {
      console.error('[CombinedServer] Advertising error:', error);
    } else {
      console.log('[CombinedServer] Successfully advertising service UUID:', SERVICE_UUID);
    }
  });
  
  // Set up periodic re-advertising to ensure visibility
  if (advertisingInterval) {
    clearInterval(advertisingInterval);
  }
  
  advertisingInterval = setInterval(() => {
    if (bleno.state === 'poweredOn') {
      //console.log('[CombinedServer] Re-advertising service UUID:', SERVICE_UUID);
      bleno.startAdvertising(BLE_DEVICE_NAME, [SERVICE_UUID]);
    }
  }, ADVERTISING_INTERVAL_MS);
}

function stopActiveAdvertising() {
  console.log('[CombinedServer] Stopping active advertising');
  
  if (advertisingInterval) {
    clearInterval(advertisingInterval);
    advertisingInterval = null;
  }
  
  bleno.stopAdvertising();
}

// BLE event handlers
bleno.on('stateChange', (state) => {
  console.log('[CombinedServer] BLE state change:', state);

  if (state === 'poweredOn') {
    startActiveAdvertising();
  } else {
    stopActiveAdvertising();
  }
});

bleno.on('advertisingStart', (error) => {
  console.log('[CombinedServer] BLE advertising started:', error ? error : 'success');
  
  if (!error) {
    bleno.setServices([bleService], (error) => {
      if (error) {
        console.error('[CombinedServer] Error setting services:', error);
      } else {
        console.log('[CombinedServer] BLE services set successfully');
        console.log('[CombinedServer] Service UUID actively advertised:', SERVICE_UUID);
      }
    });
  }
});

bleno.on('advertisingStop', () => {
  console.log('[CombinedServer] Advertising stopped');
});

bleno.on('accept', (clientAddress) => {
  console.log('[CombinedServer] Mobile App connected via BLE:', clientAddress);
  // Continue advertising even when connected to remain discoverable
  console.log('[CombinedServer] Maintaining advertising for discoverability');
});

bleno.on('disconnect', (clientAddress) => {
  console.log('[CombinedServer] Mobile App disconnected from BLE:', clientAddress);
  // Ensure we restart advertising after disconnect
  if (bleno.state === 'poweredOn') {
    setTimeout(() => {
      startActiveAdvertising();
    }, 1000);
  }
});

// ============================================================================
// STARTUP
// ============================================================================

httpServer.listen(80, () => {
  console.log('[CombinedServer] HTTP server listening on port 80');
});

console.log('[CombinedServer] Configuration:');
console.log('[CombinedServer] - HTTP Server Port: 80');
console.log('[CombinedServer] - WebSocket Server Path:', WS_PATH);
console.log('[CombinedServer] - BLE Device Name:', BLE_DEVICE_NAME);
console.log('[CombinedServer] - BLE Service UUID (Actively Advertised):', SERVICE_UUID);
console.log('[CombinedServer] - BLE Notify Characteristic UUID:', NOTIFY_CHARACTERISTIC_UUID);
console.log('[CombinedServer] - BLE Write Characteristic UUID:', WRITE_CHARACTERISTIC_UUID);
console.log('[CombinedServer] - Advertising Interval:', ADVERTISING_INTERVAL_MS + 'ms');
console.log('[CombinedServer] ');
console.log('[CombinedServer] Proxy Functions:');
console.log('[CombinedServer] 1. Low Level HW → WebSocket → Godot Game');
console.log('[CombinedServer] 2. Mobile App → BLE → WebSocket → Godot Game');
console.log('[CombinedServer] 3. Godot Game → WebSocket → BLE → Mobile App');
console.log('[CombinedServer] 4. HTTP API for game data save/load and netlink operations');
console.log('[CombinedServer] ');
console.log('[CombinedServer] BLE Advertising Features:');
console.log('[CombinedServer] - Service UUID actively advertised before and during connections');
console.log('[CombinedServer] - Periodic re-advertising for maximum discoverability');
console.log('[CombinedServer] - Automatic restart of advertising after disconnection');
console.log('[CombinedServer] ');
console.log('[CombinedServer] Keyboard Controls:');
console.log('[CombinedServer]   B - Send single random bullet');
console.log('[CombinedServer]   C - Send center screen bullet'); 
console.log('[CombinedServer]   F - Toggle burst mode (20 bullets/second)');
console.log('[CombinedServer]   Arrow keys - Send directional commands');
console.log('[CombinedServer]   Enter - Send enter command');
console.log('[CombinedServer]   H - Homepage command');
console.log('[CombinedServer]   V - Volume up command');
console.log('[CombinedServer]   D - Volume down command');
console.log('[CombinedServer]   P - Power command');
console.log('[CombinedServer]   Ctrl+C - Exit');
console.log('[CombinedServer] ');
console.log('[CombinedServer] Test Endpoints:');
console.log('[CombinedServer]   /test/multi-target/start - Multi-target simulation (8 targets)');
console.log('[CombinedServer]     Usage: POST with {"action":"netlink_forward","content":{"command":"ready"},"dest":"A"}');
console.log('[CombinedServer]     - Sends device_list with 8 targets (01 master, 02-08 slaves)');
console.log('[CombinedServer]     - Sends ack:ready for each target');
console.log('[CombinedServer]     - Sends 2 shots data for each target');
console.log('[CombinedServer]     - Responds ack:end when receives end command');
console.log('[CombinedServer]   /test/multi-target/acks - Send acks only to 8 targets');
console.log('[CombinedServer]     Usage: POST (no body required)');
console.log('[CombinedServer]     - Sends ack:ready for each of 8 targets');
console.log('[CombinedServer]   /test/multi-target/shots - Send shots only to 8 targets');
console.log('[CombinedServer]     Usage: POST (no body required)');
console.log('[CombinedServer]     - Sends 2 shots (AZone + BZone) for each of 8 targets');
console.log('[CombinedServer]   /test/ble/animation_config - Send animation_config command');
console.log('[CombinedServer]     Usage: POST with {"action":"netlink_forward","content":{"command":"animation_config","target_id":"ipsc_mini","action":"run_through","duration":5}}');
console.log('[CombinedServer]     - Sends animation configuration to Godot');
console.log('[CombinedServer]   /test/ble/ready - Send ready command');
console.log('[CombinedServer]     Usage: POST with {"action":"netlink_forward","content":{"command":"ready","isFirst":true,"isLast":true,"targetType":"ipsc","timeout":30,"delay":5}}');
console.log('[CombinedServer]     - Sends ready command to prepare targets');
console.log('[CombinedServer]   /test/ble/start - Send start command');
console.log('[CombinedServer]     Usage: POST with {"action":"netlink_forward","content":{"command":"start","repeat":1}}');
console.log('[CombinedServer]     - Sends start command to begin drill and sets timing reference');
console.log('[CombinedServer]   /test/ble/end - Send end command');
console.log('[CombinedServer]     Usage: POST with {"action":"netlink_forward","content":{"command":"end"}}');
console.log('[CombinedServer]     - Sends end command to stop drill and resets timing');
console.log('[CombinedServer]   /test/ble/sequence - Send ready -> animation_config -> start sequence');
console.log('[CombinedServer]     Usage: POST (optional body with animation_config)');
console.log('[CombinedServer]     - Sends ready command after 1s');
console.log('[CombinedServer]     - Sends animation_config after 2s (default: run_through for ipsc_mini)');
console.log('[CombinedServer]     - Sends start command after 3s');