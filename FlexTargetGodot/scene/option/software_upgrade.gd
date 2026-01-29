extends Control

const DEBUG_DISABLED = false

@onready var title_label = $TitleLabel
@onready var status_label = $VBoxContainer/StatusLabel
@onready var version_label = $VBoxContainer/VersionLabel
@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var wifi_status_label = $VBoxContainer/WiFiStatusLabel
@onready var retry_button = $VBoxContainer/RetryButton
@onready var back_button = $VBoxContainer/BackButton

var ws_listener
var http_service
var global_data

var downloading: bool = false
var upgrade_failed: bool = false

# OTA upgrade parameters (set via set_upgrade_parameters before triggering download)
var pending_upgrade_address: String = ""
var pending_upgrade_checksum: String = ""
var pending_upgrade_version: String = "unknown"

# Timer for sending periodic ready notifications to mobile app
var ready_notification_timer: Timer = null

# Button navigation
var buttons: Array = []
var focused_index: int = 1  # Default to back button

func _ready():
	ws_listener = get_node_or_null("/root/WebSocketListener")
	http_service = get_node_or_null("/root/HttpService")
	global_data = get_node_or_null("/root/GlobalData")
	
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Scene initialized")
	
	# Set up UI
	title_label.text = tr("software_upgrade")
	
	# Connect button signals
	retry_button.pressed.connect(_on_retry_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	# Set up button navigation array
	buttons = [retry_button, back_button]
	
	# Connect to menu control directives from WebSocketListener
	if ws_listener:
		if ws_listener.has_signal("menu_control"):
			ws_listener.menu_control.connect(_on_menu_control)
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Connected to WebSocketListener.menu_control signal")
		else:
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] WebSocketListener has no menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] WebSocketListener not found")
	
	# Connect to download progress signal from SignalBus
	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if signal_bus.has_signal("download_progress"):
			signal_bus.download_progress.connect(_on_download_progress)
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Connected to SignalBus.download_progress signal")
		else:
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] SignalBus has no download_progress signal")
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] SignalBus not found")
	
	# Fetch latest WiFi status from server before displaying
	if http_service:
		http_service.netlink_status(Callable(self, "_on_netlink_status_response"))
	else:
		# If no http_service, just update with current data
		_update_wifi_status()
	
	# Show initial status
	status_label.text = tr("waiting_upgrade_command")
	retry_button.visible = false
	progress_bar.visible = false
	version_label.text = ""
	
	# Send initial notification to mobile app that device is in OTA mode and ready to download
	_send_ready_notification()
	
	# Start a timer to send ready notification every 5 seconds until download starts
	_start_ready_notification_timer()
	
	# Connect to OTA upgrade request signal from SignalBus
	if signal_bus:
		signal_bus.ota_upgrade_requested.connect(_on_ota_upgrade_requested)
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Connected to SignalBus.ota_upgrade_requested signal")

func _exit_tree():
	"""Clean up when scene is closed"""
	_stop_ready_notification_timer()
	if ready_notification_timer:
		ready_notification_timer.queue_free()

func _on_netlink_status_response(_result, response_code, _headers, body):
	"""Handle netlink status response and update WiFi display"""
	if response_code == 200 and _result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json and json.has("data"):
			var data_field = json["data"]
			if typeof(data_field) == TYPE_STRING:
				var parsed = JSON.parse_string(data_field)
				if parsed:
					if global_data:
						global_data.netlink_status = parsed
						if not DEBUG_DISABLED:
							print("[SoftwareUpgrade] Updated netlink_status from server: ", parsed)
			else:
				if global_data:
					global_data.netlink_status = data_field
					if not DEBUG_DISABLED:
						print("[SoftwareUpgrade] Updated netlink_status from server: ", data_field)
	
	# Update WiFi status display with latest data
	_update_wifi_status()

func _update_wifi_status():
	"""Update WiFi status display"""
	var is_wifi_connected = false
	var wifi_ip = ""
	
	if global_data and global_data.netlink_status.has("wifi_status"):
		is_wifi_connected = global_data.netlink_status["wifi_status"]
		# Also check for valid IP address
		if is_wifi_connected and global_data.netlink_status.has("wifi_ip"):
			wifi_ip = global_data.netlink_status["wifi_ip"]
			# Verify it's not empty
			if wifi_ip == "":
				is_wifi_connected = false
	
	if is_wifi_connected and wifi_ip != "":
		wifi_status_label.text = tr("wifi_connected") % wifi_ip
		wifi_status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		wifi_status_label.text = tr("wifi_not_connected")
		wifi_status_label.add_theme_color_override("font_color", Color.RED)
	
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] WiFi status updated: ", wifi_status_label.text)

func _on_menu_control(directive: String):
	"""Handle remote controller directives for button navigation"""
	if downloading:
		# Disable navigation during download
		return
	
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Received menu_control directive: ", directive)
	
	match directive:
		"up":
			# Move focus up (towards retry button)
			focused_index = (focused_index - 1) % buttons.size()
			_update_button_focus()
			var menu_controller = get_node_or_null("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			# Move focus down (towards back button)
			focused_index = (focused_index + 1) % buttons.size()
			_update_button_focus()
			var menu_controller = get_node_or_null("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			# Activate focused button
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Activating button at index: ", focused_index)
			buttons[focused_index].pressed.emit()
			var menu_controller = get_node_or_null("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		_:
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Unknown directive: ", directive)

func _update_button_focus():
	"""Update button focus to the currently selected index"""
	buttons[focused_index].grab_focus()
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Focused index: ", focused_index, " Button: ", buttons[focused_index].name)

func _on_download_progress(progress: float):
	"""Handle download progress updates from HttpService"""
	if not downloading:
		return
	
	progress_bar.value = progress
	
	if not DEBUG_DISABLED and int(progress) % 10 == 0 and progress > 0:
		print("[SoftwareUpgrade] Download progress: %.1f%%" % progress)

func _on_retry_pressed():
	"""Retry the upgrade"""
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Retry button pressed")
	
	# Check WiFi status first
	_update_wifi_status()
	
	if global_data and global_data.netlink_status.has("wifi_status"):
		if not global_data.netlink_status["wifi_status"]:
			status_label.text = tr("wifi_not_connected_error")
			status_label.add_theme_color_override("font_color", Color.RED)
			return
	
	# Reset UI
	upgrade_failed = false
	status_label.text = tr("waiting_upgrade_command")
	status_label.add_theme_color_override("font_color", Color.WHITE)
	retry_button.visible = false
	version_label.text = ""

func _on_back_pressed():
	"""Go back to options menu"""
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Back button pressed")
	
	if downloading:
		# Show warning if download is in progress
		status_label.text = tr("download_in_progress")
		return
	
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/option.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Warning: Node not in tree, cannot change scene")

func set_upgrade_parameters(address: String, checksum: String, version: String):
	"""Set OTA upgrade parameters (called from WebSocketListener)"""
	pending_upgrade_address = address
	pending_upgrade_checksum = checksum
	pending_upgrade_version = version
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Set pending upgrade parameters for version: ", version)

func _send_ready_notification():
	"""Send ready_to_download notification to mobile app"""
	if http_service:
		var ready_notification = {"notification": "ready_to_download"}
		http_service.forward_data_to_app(func(_result, _response_code, _headers, _body):
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Sent OTA ready_to_download notification to mobile app")
		, ready_notification)
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] HttpService not available to send OTA ready_to_download notification")

func _start_ready_notification_timer():
	"""Start timer to send ready notifications every 5 seconds"""
	if ready_notification_timer == null:
		ready_notification_timer = Timer.new()
		ready_notification_timer.wait_time = 5.0
		ready_notification_timer.timeout.connect(_on_ready_notification_timeout)
		add_child(ready_notification_timer)
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Started ready notification timer (5 second interval)")
	
	if not ready_notification_timer.is_stopped():
		ready_notification_timer.stop()
	ready_notification_timer.start()

func _stop_ready_notification_timer():
	"""Stop the ready notification timer"""
	if ready_notification_timer and not ready_notification_timer.is_stopped():
		ready_notification_timer.stop()
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Stopped ready notification timer")

func _on_ready_notification_timeout():
	"""Called when ready notification timer fires"""
	if not downloading and not upgrade_failed:
		_send_ready_notification()
	else:
		# Stop timer if download has started or failed
		_stop_ready_notification_timer()

func _on_ota_upgrade_requested(address: String, checksum: String, version: String):
	"""Handle OTA upgrade request signal from SignalBus"""
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Received OTA upgrade request via signal")
	
	if downloading:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Upgrade already in progress, ignoring duplicate request")
		return
		
	# Immediately stop timer to prevent further ready notifications
	_stop_ready_notification_timer()
	
	# Start the upgrade
	start_upgrade(address, checksum, version)

func start_upgrade(address: String, checksum: String, version: String):
	"""Start the OTA upgrade download process"""
	if downloading:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] start_upgrade called but already downloading. Skipping.")
		return

	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Starting OTA upgrade - Version: ", version, ", Address: ", address)
	
	if not address or not checksum:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Invalid upgrade parameters")
		_send_download_failure()
		return
	
	# Check if OTA mode is enabled
	if not (global_data and global_data.ota_mode):
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] OTA mode is not enabled")
		_send_download_failure()
		return
	
	# Update UI to indicate download starting
	downloading = true
	upgrade_failed = false
	if global_data:
		global_data.current_upgrade_version = version
	
	# Stop sending ready notifications since download is starting
	_stop_ready_notification_timer()
	
	status_label.text = tr("downloading_software")
	version_label.text = tr("version") + version
	progress_bar.visible = true
	progress_bar.value = 0
	retry_button.visible = false
	
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] OTA upgrade initiated for version: ", version)
	
	# Initiate download with version parameter using HttpService
	if http_service:
		http_service.download_and_verify(address, checksum, version, Callable(self, "_on_download_complete"))
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] HttpService not found")
		_send_download_failure()

func _on_download_complete(success: bool, version: String):
	"""Callback for OTA download completion"""
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Download complete - Success: ", success, ", Version: ", version)
	
	if success:
		# Perform cleanup before sending notification
		_cleanup_download_resources()
		
		# Send success notification to mobile app only after cleanup is complete
		if http_service:
			var content = {
				"notification": "download_complete",
				"version": version
			}
			http_service.forward_data_to_app(func(_result, _response_code, _headers, _body):
				if not DEBUG_DISABLED:
					print("[SoftwareUpgrade] Download complete notification sent to mobile app")
			, content)
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Sent download_complete notification with version: ", version)
			
			status_label.text = tr("upgrade_success")
			status_label.add_theme_color_override("font_color", Color.GREEN)
			progress_bar.value = 100
		else:
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] HttpService not available to send completion notification")
			_send_download_failure()
	else:
		_send_download_failure()

func _cleanup_download_resources():
	"""Clean up and release resources used during download"""
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Starting cleanup of download resources...")
	
	# Clear pending parameters to prevent accidental reuse
	pending_upgrade_address = ""
	pending_upgrade_checksum = ""
	pending_upgrade_version = "unknown"
	
	# Reset status flags
	downloading = false
	
	# Force garbage collection to ensure file handles and memory are released
	# This is a hint to the engine to clean up orphaned HTTPRequest nodes or buffers
	# GC.collect() is not available in GDScript 2.0 directly like this, but we can ensure
	# all local references are cleared.
	
	if not DEBUG_DISABLED:
		print("[SoftwareUpgrade] Cleanup of download resources completed")

func _send_download_failure():
	"""Send download failure notification to mobile app"""
	# Perform cleanup even on failure
	_cleanup_download_resources()
	
	downloading = false
	upgrade_failed = true
	
	if http_service:
		var content = {
			"notification": "download_failure"
		}
		http_service.forward_data_to_app(func(_result, _response_code, _headers, _body):
			if not DEBUG_DISABLED:
				print("[SoftwareUpgrade] Download failure notification sent to mobile app")
		, content)
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] Sent download_failure notification")
	else:
		if not DEBUG_DISABLED:
			print("[SoftwareUpgrade] HttpService not available to send failure notification")
	
	status_label.text = tr("upgrade_failed")
	status_label.add_theme_color_override("font_color", Color.RED)
	progress_bar.visible = false
	retry_button.visible = true
