extends Node

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production
const VERSION = "1.0.1"  # Software version for BLE query response
const OTA_USERAPP_DIR = "/srv/www/userapp"  # Directory for OTA mode and file downloads
#const OTA_USERAPP_DIR = "/Users/kai/otatest"  # Directory for OTA mode and file downloads

# Global data storage for sharing information between scenes
var upper_level_scene: String = "res://scene/drills.tscn"
var settings_dict: Dictionary = {}
var selected_drill_data: Dictionary = {}  # Store selected drill data for replay
var latest_performance_data: Dictionary = {}  # Store latest performance data for fallback
var netlink_status: Dictionary = {}  # Store last known netlink status from server
var ble_ready_content: Dictionary = {}  # Store BLE ready command content for passing between scenes
var game_mode: String = "ipsc"  # Store current game mode (ipsc, idpa, cqb)
var sub_menu_config: Dictionary = {
	"title": "Stage Options",
	"items": [
		{
			"text": "ipsc",
			"action": "http_call",
			"http_call": "start_game",
			"success_scene": "res://scene/intro/intro.tscn"
		},
		{
			"text": "back_to_main",
			"action": "back_to_main"
		}
	]
}

# Track which scene we're returning from for focus management
var return_source: String = ""

# Flag to indicate if we're coming from IDPA history (affects file loading in drill_replay)
var is_idpa_history: bool = false

# Store the selected variant (IPSC or IDPA)
var selected_variant: String = "IPSC"

# Flag to focus network button when returning to options
var last_focused_networking_button: Node = null

# Timer for periodic netlink status updates
var netlink_timer: Timer = null
const NETLINK_UPDATE_INTERVAL = 60.0  # Request every 60 seconds

# OTA mode tracking
var ota_mode: bool = false  # True if system is in OTA mode (can write to /srv/www/userapp)
var current_upgrade_version: String = ""  # Version being downloaded during OTA upgrade

# Signal emitted when settings are successfully loaded
signal settings_loaded
signal netlink_status_loaded

func _ready():
	# print("GlobalData singleton initialized")
	_detect_ota_mode()
	load_settings_from_http()

func _detect_ota_mode():
	"""Check if system is in OTA mode by testing if OTA_USERAPP_DIR is writable"""
	var test_file_path = OTA_USERAPP_DIR + "/.ota_test"
	var test_file = FileAccess.open(test_file_path, FileAccess.WRITE)
	if test_file:
		# Successfully opened for writing, system is in OTA mode
		ota_mode = true
		test_file.close()
		# Clean up test file
		DirAccess.remove_absolute(test_file_path)
		if not DEBUG_DISABLED:
			print("[GlobalData] OTA mode detected: system is writable")
	else:
		ota_mode = false
		if not DEBUG_DISABLED:
			print("[GlobalData] OTA mode not detected: system is read-only")

func _setup_netlink_timer():
	"""Setup periodic netlink status updates (called after first successful response)"""
	if netlink_timer:
		return  # Timer already started
	netlink_timer = Timer.new()
	add_child(netlink_timer)
	netlink_timer.wait_time = NETLINK_UPDATE_INTERVAL
	netlink_timer.timeout.connect(_on_netlink_timer_timeout)
	netlink_timer.start()
	# print("GlobalData: Netlink status timer started with interval: ", NETLINK_UPDATE_INTERVAL)

func _on_netlink_timer_timeout():
	"""Periodic callback to request netlink status"""
	HttpService.netlink_status(Callable(self, "update_netlink_status_from_response"))
	# print("GlobalData: Periodic netlink status request sent")

func load_settings_from_http():
	# print("GlobalData: Requesting settings from HttpService...")
	HttpService.load_game(Callable(self, "_on_settings_loaded"), "settings")

func _on_settings_loaded(_result, response_code, _headers, body):
	# print("GlobalData: HTTP response received - Code: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		# print("GlobalData: Parsed JSON: ", json)
		if json and json.has("data"):
			var data = json["data"]
			# print("GlobalData: Parsed content JSON: ", content_json)
			if data:
				if typeof(data) == TYPE_STRING:
					var parsed = JSON.parse_string(data)
					if parsed:
						settings_dict = parsed
					else:
						settings_dict = {}
				else:
					settings_dict = data
				# Ensure max_index is always an integer
				if settings_dict.has("max_index"):
					settings_dict["max_index"] = int(settings_dict["max_index"])
				# Ensure channel is always an integer
				if settings_dict.has("channel"):
					settings_dict["channel"] = int(settings_dict["channel"])
			# Ensure new auto restart fields have defaults
			if not settings_dict.has("auto_restart"):
				settings_dict["auto_restart"] = false
			if not settings_dict.has("auto_restart_pause_time"):
				settings_dict["auto_restart_pause_time"] = 5
			# Ensure SFX volume has default
			if not settings_dict.has("sfx_volume"):
				settings_dict["sfx_volume"] = 5
			# print("GlobalData: Settings loaded into dictionary: ", settings_dict)
				# print("GlobalData: drill_sequence value: ", settings_dict.get("drill_sequence", "NOT_FOUND"))
				# print("GlobalData: Settings keys: ", settings_dict.keys())
				# Emit signal to notify that settings are loaded
				settings_loaded.emit()
			else:
				# print("GlobalData: Failed to parse settings content")
				# Emit signal even on failure so app doesn't hang
				settings_loaded.emit()
		else:
			# print("GlobalData: No data field in response")
			# Emit signal even on failure so app doesn't hang
			settings_loaded.emit()
	else:
		# print("GlobalData: Failed to load settings, response code: ", response_code)
		# Emit signal even on failure so app doesn't hang
		settings_loaded.emit()

func update_netlink_status_from_response(_result, response_code, _headers, body):
	# print("GlobalData: Received netlink_status response - Code:", response_code)
	if response_code == 200 and _result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		# print("GlobalData: netlink_status body: ", body_str)
		# Try to parse top-level response then data
		var json = JSON.parse_string(body_str)
		if json:
			# Check for error code in response
			if json.has("code") and json["code"] != 0:
				# Server returned an error code (not 0 = success)
				var _error_msg = json.get("msg", "Unknown error")
				# print("GlobalData: netlink_status request failed with error code: ", json["code"], " - ", _error_msg)
				# Clear netlink_status and emit signal (listeners will see it's empty)
				netlink_status = {}
				netlink_status_loaded.emit()
				# Still start the timer so we retry periodically
				_setup_netlink_timer()
				return
			
			# Check for data field (success case)
			if json.has("data"):
				# 'data' may already be a dictionary encoded as object or a JSON string
				var data_field = json["data"]
				if typeof(data_field) == TYPE_STRING:
					var parsed = JSON.parse_string(data_field)
					if parsed:
						netlink_status = parsed
					else:
						netlink_status = {}
				else:
					netlink_status = data_field
				
				# Ensure channel is always an integer if present
				if netlink_status.has("channel"):
					netlink_status["channel"] = int(netlink_status["channel"])
				# print("GlobalData: netlink_status updated: ", netlink_status)
				# Emit signal to notify listeners that netlink status is available
				netlink_status_loaded.emit()
				# Start periodic timer on first successful response
				_setup_netlink_timer()
			else:
				# print("GlobalData: netlink_status response missing data field or failed to parse")
				netlink_status = {}
				netlink_status_loaded.emit()
				_setup_netlink_timer()
		else:
			# print("GlobalData: Failed to parse netlink_status JSON response")
			netlink_status = {}
			netlink_status_loaded.emit()
			_setup_netlink_timer()
	else:
		# print("GlobalData: netlink_status request failed or non-200 code: ", response_code)
		netlink_status = {}
		netlink_status_loaded.emit()
		_setup_netlink_timer()

func _exit_tree():
	"""Cleanup timer when GlobalData is removed"""
	if netlink_timer:
		netlink_timer.queue_free()
		netlink_timer = null
