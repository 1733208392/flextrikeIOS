extends Control

# References to networking buttons
var wifi_button = null
var network_button = null
var start_netlink_button = null
var networking_buttons = []

# References to networking info labels
var content1_label = null
var content2_label = null
var content3_label = null
var content4_label = null
var content5_label = null
var content6_label = null

# References to networking title labels
var title1_label = null
var title2_label = null
var title3_label = null
var title4_label = null
var title5_label = null
var title6_label = null

# Networking configuration state
var current_netlink_config = null
var is_configuring_netlink = false
var is_stopping_netlink = false
var is_netlink_started = false

# Status label and update timers
var statusLabel = null
var update_timer = null
var stop_timer = null
var updating_text = ""
var updating_dots = 0

func _ready():
	"""Initialize networking tab"""
	# Find nodes using get_node() from parent scene since script is added as child
	var parent = get_parent()
	if parent:
		wifi_button = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/WifiButton")
		network_button = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/NetworkButton")
		start_netlink_button = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/ButtonRow/StartNetlinkButton")
		
		content1_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Content1")
		content2_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Content2")
		content3_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Content3")
		content4_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Content4")
		content5_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Content5")
		content6_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row6/Content6")
		
		title1_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row1/Title1")
		title2_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row2/Title2")
		title3_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row3/Title3")
		title4_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row4/Title4")
		title5_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row5/Title5")
		title6_label = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/Row6/Title6")
	
		statusLabel = parent.get_node("VBoxContainer/MarginContainer/tab_container/Networking/MarginContainer/NetworkContainer/NetworkInfo/StatusLabel")
	if title1_label:
		title1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title2_label:
		title2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title3_label:
		title3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title4_label:
		title4_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title5_label:
		title5_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if title6_label:
		title6_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Initialize networking buttons array (wifi, network, start_netlink)
	networking_buttons = []
	if wifi_button:
		networking_buttons.append(wifi_button)
	if network_button:
		networking_buttons.append(network_button)
	if start_netlink_button:
		networking_buttons.append(start_netlink_button)

	# Initialize status update timers
	update_timer = Timer.new()
	add_child(update_timer)
	update_timer.wait_time = 0.5
	update_timer.timeout.connect(_on_update_timer_timeout)
	
	stop_timer = Timer.new()
	add_child(stop_timer)
	stop_timer.wait_time = 2.0
	stop_timer.one_shot = true
	stop_timer.timeout.connect(_on_stop_timer_timeout)

	# Set updating text with translation
	updating_text = tr("netlink_status_updating")

	# Connect wifi button pressed to open overlay
	if wifi_button:
		wifi_button.pressed.connect(_on_wifi_pressed)
	
	# Connect network button pressed
	if network_button:
		network_button.pressed.connect(_on_network_pressed)
		network_button.disabled = false  # Ensure it's enabled
	
	# Connect start netlink button pressed
	if start_netlink_button:
		start_netlink_button.pressed.connect(_on_start_netlink_pressed)
		start_netlink_button.disabled = true  # Initially disabled
	
	# Request initial netlink status
	_request_netlink_status()

func _populate_networking_fields(data: Dictionary):
	"""Populate networking UI labels with data from netlink_status"""
	# Map expected fields from netlink_status -> UI labels
	# Content1: bluetooth_name, Content2: device_name, Content3: channel, Content4: wifi_ip, Content5: work_mode
	if content1_label:
		content1_label.text = str(data.get("bluetooth_name", ""))
	if content2_label:
		content2_label.text = str(data.get("device_name", ""))
	if content3_label:
		var channel_value = int(data.get("channel", 0))
		if channel_value > 10:
			channel_value = 1
		content3_label.text = str(channel_value)
	if content4_label:
		content4_label.text = str(data.get("wifi_ip", ""))
	if content5_label:
		var work_mode = str(data.get("work_mode", "")).to_lower()
		if work_mode == "master":
			content5_label.text = tr("work_mode_master")
		elif work_mode == "slave":
			content5_label.text = tr("work_mode_slave")
		else:
			content5_label.text = work_mode
	if content6_label:
		var started = data.get("started", false)
		if started:
			content6_label.text = tr("started")
		else:
			content6_label.text = tr("stopped")
		is_netlink_started = started
		_update_start_button_text(started)
		# Emit signal_bus.network_started if started
		if started:
			var signal_bus = get_node_or_null("/root/SignalBus")
			if signal_bus and signal_bus.has_signal("network_started"):
				signal_bus.network_started.emit()
		else:
			var signal_bus = get_node_or_null("/root/SignalBus")
			if signal_bus and signal_bus.has_signal("network_stopped"):
				signal_bus.network_stopped.emit()

func _update_start_button_text(started: bool):
	"""Update the start/stop button text based on netlink status"""
	if start_netlink_button:
		if started:
			start_netlink_button.text = tr("stop_netlink")
		else:
			start_netlink_button.text = tr("start_netlink")

func _request_netlink_status():
	"""Request netlink status from HTTP service"""
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] About to call http_service.netlink_status")
		http_service.netlink_status(Callable(self, "_on_netlink_status_response"))
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Called http_service.netlink_status successfully")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] HttpService singleton not found; cannot request netlink status")

func _on_netlink_status_response(result, response_code, _headers, body):
	"""Handle netlink_status HTTP response"""
	if not GlobalDebug.DEBUG_DISABLED:
		print("[NetworkingTab] Received netlink_status HTTP response - Code:", response_code)
	if response_code == 200 and result == HTTPRequest.RESULT_SUCCESS:
		var body_str = body.get_string_from_utf8()
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] netlink_status body: ", body_str)
		
		# Parse the response
		var json = JSON.parse_string(body_str)
		if json:
			var parsed_data = null
			
			# Try different response formats
			if json.has("data"):
				# Format: {"data": "..."} or {"data": {...}}
				var data_field = json["data"]
				if typeof(data_field) == TYPE_STRING:
					parsed_data = JSON.parse_string(data_field)
				else:
					parsed_data = data_field
				if not GlobalDebug.DEBUG_DISABLED:
					print("[NetworkingTab] Parsed data from 'data' field")
			else:
				# Direct format: {...}
				parsed_data = json
				if not GlobalDebug.DEBUG_DISABLED:
					print("[NetworkingTab] Parsed data directly from response")
			
			if parsed_data and typeof(parsed_data) == TYPE_DICTIONARY:
				if not GlobalDebug.DEBUG_DISABLED:
					print("[NetworkingTab] Parsed netlink_status data: ", parsed_data)
				# Populate UI directly with parsed data
				_populate_networking_fields(parsed_data)
				# Store the config data
				current_netlink_config = parsed_data
				# Enable start netlink button if config is valid
				_check_and_enable_start_button(parsed_data)
				
				# If status shows netlink is started, update GlobalData
				if parsed_data.get("started", false):
					var global_data = get_node_or_null("/root/GlobalData")
					if global_data:
						global_data.netlink_status["started"] = true
						# Emit the signal to notify other components
						if global_data.has_method("netlink_status_loaded"):
							global_data.netlink_status_loaded.emit()
			else:
				if not GlobalDebug.DEBUG_DISABLED:
					print("[NetworkingTab] Failed to parse netlink_status data - parsed_data: ", parsed_data, " type: ", typeof(parsed_data))
		else:
			if not GlobalDebug.DEBUG_DISABLED:
				print("[NetworkingTab] Failed to parse JSON response: ", body_str)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] netlink_status request failed with code:", response_code)
		# Disable start button if request failed
		if start_netlink_button:
			start_netlink_button.disabled = true

func get_networking_buttons() -> Array:
	"""Get array of networking buttons for navigation"""
	return networking_buttons

func navigate_network_buttons(direction: String):
	"""Navigate between networking buttons"""
	if networking_buttons.is_empty():
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] No networking buttons available")
		return

	var current_index = -1
	for i in range(networking_buttons.size()):
		if networking_buttons[i] and networking_buttons[i].has_focus():
			current_index = i
			break

	if current_index == -1:
		networking_buttons[0].grab_focus()
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Focus set to first networking button")
		return

	var target_index = current_index
	if direction == "up":
		target_index = (target_index - 1 + networking_buttons.size()) % networking_buttons.size()
	else:
		target_index = (target_index + 1) % networking_buttons.size()

	if networking_buttons[target_index]:
		networking_buttons[target_index].grab_focus()
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Networking focus moved to ", networking_buttons[target_index].name)

func press_focused_button():
	"""Handle button press for currently focused networking button"""
	for button in networking_buttons:
		if button and button.has_focus():
			if button == wifi_button:
				_on_wifi_pressed()
			elif button == network_button:
				_on_network_pressed()
			elif button == start_netlink_button:
				_on_start_netlink_pressed()
			return

func set_focus_to_first_button():
	"""Set focus to first networking button"""
	if not networking_buttons.is_empty() and networking_buttons[0]:
		networking_buttons[0].grab_focus()
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Focus set to first networking button")

func set_focus_to_network_button():
	"""Set focus to network button (second button)"""
	if networking_buttons.size() > 1 and networking_buttons[1]:
		networking_buttons[1].grab_focus()
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Focus set to network button")

func _on_wifi_pressed():
	"""Handle WiFi button pressed"""
	_show_wifi_networks()

func _show_wifi_networks():
	"""Navigate to WiFi networks scene"""
	if not is_inside_tree():
		print("[NetworkingTab] Cannot change scene, node not inside tree")
		return
	print("[NetworkingTab] Switching to WiFi networks scene")
	get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")

func _on_network_pressed():
	"""Handle Network button pressed"""
	get_tree().change_scene_to_file("res://scene/networking_config.tscn")

func _check_and_enable_start_button(config: Dictionary):
	"""Check if netlink config is valid and enable start button accordingly"""
	if not start_netlink_button:
		return
	
	# Check if required fields are present and not empty
	var required_fields = ["bluetooth_name", "device_name", "channel", "wifi_ip", "work_mode"]
	var is_valid = true
	for field in required_fields:
		if not config.has(field) or str(config[field]).strip_edges().is_empty():
			is_valid = false
			break
	
	if is_valid:
		start_netlink_button.disabled = false
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] StartNetlinkButton enabled - valid config found")
	else:
		start_netlink_button.disabled = true
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] StartNetlinkButton disabled - invalid config")

func _on_start_netlink_pressed():
	"""Handle Start/Stop Netlink button pressed"""
	# Start status update animation
	if statusLabel:
		statusLabel.text = updating_text
		updating_dots = 0
		if update_timer:
			update_timer.stop()
			update_timer.start()
		if stop_timer:
			stop_timer.stop()
			stop_timer.start()
	
	if not current_netlink_config or is_configuring_netlink or is_stopping_netlink:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Cannot toggle netlink - no config or operation in progress")
		return
	
	var http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] HttpService not found, cannot toggle netlink")
		return
	
	if is_netlink_started:
		# Stop netlink
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Stopping netlink...")
		http_service.netlink_stop(Callable(self, "_on_netlink_stop_callback"))
	else:
		# Start netlink
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Starting netlink...")
		_do_netlink_start()

func _do_netlink_start():
	"""Start netlink with current configuration"""
	if not GlobalDebug.DEBUG_DISABLED:
		print("[NetworkingTab] Starting netlink...")
	
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.netlink_start(Callable(self, "_on_netlink_start_callback"))

func _on_netlink_stop_callback(result, response_code, _headers, _body):
	"""Handle netlink stop response for toggle"""
	is_stopping_netlink = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink stop successful")
		
		# Re-request netlink status to update the UI
		_request_netlink_status()
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink stop failed - Result: ", result, ", Code: ", response_code)

func _on_netlink_stop_for_start_callback(result, response_code, _headers, _body):
	"""Handle netlink stop response when stopping before starting"""
	is_stopping_netlink = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink stop successful, proceeding to start...")
		
		# Update GlobalData to mark netlink as stopped
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.netlink_status["started"] = false
		
		# Now start netlink
		_do_netlink_start()
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink stop failed - Result: ", result, ", Code: ", response_code)

func _on_netlink_start_callback(result, response_code, _headers, _body):
	"""Handle netlink start response"""
	is_configuring_netlink = false
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink start successful")
		
		# Re-request netlink status to update the UI
		_request_netlink_status()
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[NetworkingTab] Netlink start failed - Result: ", result, ", Code: ", response_code)

func update_ui_texts():
	"""Update networking tab UI text labels with translated strings"""
	# Networking tab labels
	if title1_label:
		title1_label.text = tr("bluetooth_name")
	if title2_label:
		title2_label.text = tr("device_name")
	if title3_label:
		title3_label.text = tr("network_channel")
	if title4_label:
		title4_label.text = tr("ip_address")
	if title5_label:
		title5_label.text = tr("working_mode")
	if title6_label:
		title6_label.text = tr("netlink_status")
	if wifi_button:
		wifi_button.text = tr("wifi_configure")
	if network_button:
		network_button.text = tr("network_configure")
	if start_netlink_button:
		_update_start_button_text(is_netlink_started)

	# Update updating text with current translation
	updating_text = tr("netlink_status_updating")

func _on_update_timer_timeout():
	"""Handle update timer timeout for animated dots"""
	updating_dots = (updating_dots + 1) % 4
	var dots = ""
	for i in range(updating_dots):
		dots += "."
	if statusLabel:
		statusLabel.text = updating_text + dots

func _on_stop_timer_timeout():
	"""Handle stop timer timeout to clear status label"""
	if update_timer:
		update_timer.stop()
	if statusLabel:
		statusLabel.text = ""
