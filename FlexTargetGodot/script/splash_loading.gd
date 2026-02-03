extends Control

const DEBUG_DISABLED = true

# @onready var loading_label = $VBoxContainer/LoadingLabel
# @onready var logo_container = $VBoxContainer/LogoContainer

var dots_count = 0
var loading_timer: Timer
var timeout_timer: Timer
var max_loading_time = 20.0  # Maximum 20 seconds loading time (for auto-netlink procedure)

# Auto-netlink variables
var auto_netlink_timer: Timer
var auto_netlink_in_progress = false
var netlink_status_response: Dictionary = {}

# Shader effect variables
var effect_rect: ColorRect
var effect_material: ShaderMaterial
var progress = 0.0

func _ready():	
	# Setup loading animation
	setup_loading_animation()
	
	# Setup timeout fallback
	setup_timeout_fallback()
	
	# Setup shader effect
	#setup_shader_effect()
	
	# Connect to GlobalData settings loaded signal
	var global_data = get_node("/root/GlobalData")
	if global_data:
		# Check if settings are already loaded
		if global_data.settings_dict.size() > 0:
			if not DEBUG_DISABLED:
				print("[Splash] Settings already loaded, proceeding to main menu")
			proceed_to_main_menu()  # Commented for testing
		else:
			# Wait for settings to load
			global_data.settings_loaded.connect(_on_settings_loaded)
	else:
		if not DEBUG_DISABLED:
			print("[Splash] GlobalData not found, proceeding anyway")
		proceed_to_main_menu()  # Commented for testing

func _process(delta):
	if effect_material:
		progress = fmod(progress + delta * 0.5, 1.0)
		effect_material.set_shader_parameter("progress", progress)

func setup_loading_animation():
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.5
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	loading_timer.autostart = true
	add_child(loading_timer)
	
	# Initial text
	#loading_label.text = tr("loading")

func setup_timeout_fallback():
	timeout_timer = Timer.new()
	timeout_timer.wait_time = max_loading_time
	timeout_timer.timeout.connect(_on_timeout)
	timeout_timer.one_shot = true
	timeout_timer.autostart = true
	add_child(timeout_timer)

func _on_loading_timer_timeout():
	dots_count = (dots_count + 1) % 4
	var dots = ""
	for i in range(dots_count):
		dots += "."
	#loading_label.text = tr("loading") + dots

func _on_settings_loaded():
	if not DEBUG_DISABLED:
		print("[Splash] Settings loaded signal received, proceeding to main menu")
	proceed_to_main_menu()  # Commented for testing

func _on_timeout():
	if not DEBUG_DISABLED:
		print("[Splash] Loading timeout reached, proceeding to main menu anyway")
	#loading_label.text = tr("timeout_loading")
	await get_tree().create_timer(1.0).timeout
	proceed_to_main_menu()

# =============================================================================
# AUTO-NETLINK PROCEDURES
# =============================================================================

func _start_auto_netlink():
	"""
	Start auto netlink config and start procedure.
	Transitions to option.tscn on success/failure/timeout.
	"""
	if auto_netlink_in_progress:
		return
	
	auto_netlink_in_progress = true
	if not DEBUG_DISABLED:
		print("[Splash] Starting auto netlink config")
	
	# Config with channel 17, work_mode "master", device_name "01"
	HttpService.netlink_config(Callable(self, "_on_auto_netlink_config_response"), 17, "01", "master")

func _on_auto_netlink_config_response(result, response_code, _headers, _body):
	"""
	Handle auto netlink config response
	"""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[Splash] Auto netlink config successful, starting delay timer")
		# Start 1.5 second delay timer before starting netlink
		auto_netlink_timer = Timer.new()
		auto_netlink_timer.wait_time = 1.5
		auto_netlink_timer.one_shot = true
		auto_netlink_timer.timeout.connect(Callable(self, "_on_auto_netlink_delay_timeout"))
		add_child(auto_netlink_timer)
		auto_netlink_timer.start()
	else:
		if not DEBUG_DISABLED:
			print("[Splash] Auto netlink config failed: ", result, " code: ", response_code)
		# Config failed, reset flag and transition to option.tscn
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.auto_netlink_enabled = false
		auto_netlink_in_progress = false
		_transition_to_option()

func _on_auto_netlink_delay_timeout():
	"""
	Handle auto netlink delay timeout, start netlink
	"""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	if not DEBUG_DISABLED:
		print("[Splash] Auto netlink delay timeout, starting netlink")
	HttpService.netlink_start(Callable(self, "_on_auto_netlink_start_response"))

func _on_auto_netlink_start_response(result, response_code, _headers, _body):
	"""
	Handle auto netlink start response
	"""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not DEBUG_DISABLED:
			print("[Splash] Auto netlink start successful")
	else:
		if not DEBUG_DISABLED:
			print("[Splash] Auto netlink start failed: ", result, " code: ", response_code)
	
	# Reset flag and clear auto_netlink_enabled regardless of success
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.auto_netlink_enabled = false
	auto_netlink_in_progress = false
	
	# Auto procedure complete, transition to option.tscn
	_transition_to_option()

func _transition_to_option():
	"""
	Transition to main_menu.tscn
	"""
	if not DEBUG_DISABLED:
		print("[Splash] Transitioning to main_menu.tscn")
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")  # Commented for testing

# =============================================================================
# PROVISION STATUS BROADCAST
# =============================================================================

func _start_provision_status_broadcast():
	"""
	Start broadcasting provision_status:incomplete (when WiFi not connected but first_run_complete).
	This will be handled by a timer that broadcasts every 5 seconds.
	"""
	if not DEBUG_DISABLED:
		print("[Splash] Starting provision_status broadcast")
	
	# Broadcast immediately
	_broadcast_provision_status()
	
	# Create timer to broadcast every 5 seconds (will be stopped when scene changes)
	var forward_timer = Timer.new()
	forward_timer.wait_time = 5.0
	forward_timer.timeout.connect(Callable(self, "_broadcast_provision_status"))
	add_child(forward_timer)
	forward_timer.start()

func _broadcast_provision_status():
	"""
	Broadcast provision_status: incomplete to mobile app
	"""
	var content = {
		"provision_status": "incomplete"
	}
	HttpService.forward_data(Callable(), content)
	if not DEBUG_DISABLED:
		print("[Splash] Sent provision_status: incomplete")

func proceed_to_main_menu():
	# Stop timers
	if loading_timer:
		loading_timer.queue_free()
	if timeout_timer:
		timeout_timer.queue_free()
	
	# Check if first run is complete
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.get("first_run_complete", false):
		# First run is complete, check if WiFi is already connected
		if not DEBUG_DISABLED:
			print("[Splash] First run complete, checking WiFi status")
		_check_wifi_and_auto_netlink()
		return
	
	# First run not complete, proceed to onboarding
	if not DEBUG_DISABLED:
		print("[Splash] First run not complete, transitioning to onboarding")
	get_tree().change_scene_to_file("res://scene/onboarding.tscn")  # Commented for testing

func _check_wifi_and_auto_netlink():
	"""
	Check if WiFi is connected via netlink_status.
	If connected: start auto-netlink procedure
	If not connected: broadcast provision_status:incomplete and go to wifi_networks
	"""
	if not DEBUG_DISABLED:
		print("[Splash] Fetching netlink_status to check WiFi connection")
	HttpService.netlink_status(Callable(self, "_on_netlink_status_check_response"))

func _on_netlink_status_check_response(result, response_code, _headers, body):
	"""
	Handle netlink_status response to determine next action
	"""
	if not is_instance_valid(self) or not is_inside_tree():
		return
	
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[Splash] GlobalData not found, transitioning to main menu")
		get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")  # Commented for testing
		return
	
	# Parse netlink status response
	var wifi_status = false
	var wifi_ip = ""
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		if json:
			var data = null
			if json.has("data"):
				var data_field = json["data"]
				if typeof(data_field) == TYPE_STRING:
					data = JSON.parse_string(data_field)
				else:
					data = data_field
			else:
				data = json
			
			if data and typeof(data) == TYPE_DICTIONARY:
				wifi_status = data.get("wifi_status", false)
				wifi_ip = data.get("wifi_ip", "")
				netlink_status_response = data
				if not DEBUG_DISABLED:
					print("[Splash] Netlink status - wifi_status: ", wifi_status, ", wifi_ip: ", wifi_ip)
	
	# Check if WiFi is connected and IP is valid
	var ip_valid = wifi_ip and wifi_ip != "" and wifi_ip != "0.0.0.0"
	
	if wifi_status and ip_valid:
		# WiFi is connected, start auto-netlink
		if not DEBUG_DISABLED:
			print("[Splash] WiFi connected with valid IP: ", wifi_ip, ", starting auto-netlink")
		global_data.auto_netlink_enabled = true
		_start_auto_netlink()
	else:
		# WiFi not connected, show provision_status incomplete and go to wifi_networks
		if not DEBUG_DISABLED:
			print("[Splash] WiFi not connected (status: ", wifi_status, ", IP valid: ", ip_valid, "), transitioning to wifi_networks with provision broadcast")
		global_data.auto_netlink_enabled = false
		_start_provision_status_broadcast()
		get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")  # Commented for testing
