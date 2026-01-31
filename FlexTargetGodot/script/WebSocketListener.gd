extends Node

const DEBUG_DISABLED = true
#const WEBSOCKET_URL = "ws://127.0.0.1/websocket"
const WEBSOCKET_URL = "ws://192.168.0.122/websocket"

signal data_received(data)
signal bullet_hit(pos: Vector2, a: int, t: int)
signal menu_control(directive: String)
signal ble_ready_command(content: Dictionary)
signal ble_start_command(content: Dictionary)
signal ble_end_command(content: Dictionary)
signal animation_config(action: String, duration: float)
signal target_name_received(target_name: String)

var socket: WebSocketPeer
var bullet_spawning_enabled: bool = true
var prev_socket_state: int = -1
var global_data: Node

# Message rate limiting for performance optimization
var last_message_time: float = 0.0
var message_cooldown: float = 0.010  # Reduced to 10ms for better responsiveness
var max_messages_per_frame: int = 20  # Increased from 2 to 20 to handle backlogs and prevent lag
var processed_this_frame: int = 0

# Enhanced timing tracking for better shot spacing
var last_shot_processing_time: float = 0.0
var minimum_shot_spacing: float = 0.015  # 15ms minimum between individual shots

# Queue management for clearing pending signals
var pending_bullet_hits: Array[Vector2] = []  # Track pending bullet hit signals

# Directive throttling to prevent duplicates from long press or hardware congestion
var directive_cooldown: float = 0.1  # 100ms cooldown between identical directives
var last_directive_times: Dictionary = {}

func _ready():
	socket = WebSocketPeer.new()
	#var err = socket.connect_to_url("ws://127.0.0.1/websocket")
	var err = socket.connect_to_url(WEBSOCKET_URL)
	if err != OK:
		if not DEBUG_DISABLED:
			print("Unable to connect")
		set_process(false)
	else:
		# Set highest priority for WebSocket processing to ensure immediate message handling
		set_process_priority(100)  # Higher priority than default (0)
		if not DEBUG_DISABLED:
			print("[WebSocket] Process priority set to maximum for immediate message processing")

	# Reconnect timer for retrying closed connections
	var reconnect_timer = Timer.new()
	reconnect_timer.set_name("WebSocketReconnectTimer")
	reconnect_timer.one_shot = true
	reconnect_timer.wait_time = 2.0 # seconds; initial retry delay
	reconnect_timer.connect("timeout", Callable(self, "_on_reconnect_timer_timeout"))
	add_child(reconnect_timer)

	# Connect watchdog timer: ensures a connect attempt actually reaches OPEN within a short timeout
	var connect_watchdog = Timer.new()
	connect_watchdog.set_name("WebSocketConnectWatchdog")
	connect_watchdog.one_shot = true
	connect_watchdog.wait_time = 3.0 # seconds; watchdog timeout for connect attempts
	connect_watchdog.connect("timeout", Callable(self, "_on_connect_watchdog_timeout"))
	add_child(connect_watchdog)

	global_data = get_node("/root/GlobalData")

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()

	# Detect state transitions and only announce real OPEN events
	if state != prev_socket_state:
		# When transitioning to OPEN, reset reconnect backoff/timers
		if state == WebSocketPeer.STATE_OPEN:
			var open_msg = "WebSocket connection opened"
			if not DEBUG_DISABLED:
				print(open_msg)

			# Reset timing trackers and reconnect timer backoff on real open
			last_message_time = Time.get_ticks_msec() / 1000.0
			last_shot_processing_time = 0.0
			var rt = get_node_or_null("WebSocketReconnectTimer")
			if rt:
				rt.wait_time = 2.0

			# Stop the connect watchdog if it is running
			var wd = get_node_or_null("WebSocketConnectWatchdog")
			if wd and wd.is_stopped() == false:
				wd.stop()

		prev_socket_state = state
	
	# Reset per-frame message counter
	processed_this_frame = 0
	
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() and processed_this_frame < max_messages_per_frame:
			var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
			
			var packet = socket.get_packet()
			var message = packet.get_string_from_utf8()
			data_received.emit(message)
			_process_websocket_json(message)
			
			last_message_time = time_stamp
			processed_this_frame += 1
			
		if socket.get_available_packet_count() > 0:
			if not DEBUG_DISABLED:
				print("[WebSocket] Rate limiting: ", socket.get_available_packet_count(), " messages queued for next frame")
			
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		var close_msg = "WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1]
		if not DEBUG_DISABLED:
			print(close_msg)

		# Attempt immediate reconnect and schedule retries
		_attempt_reconnect()
		set_process(false) # Stop processing until reconnect attempt

# Parse JSON and emit bullet_hit for each (x, y)
func _process_websocket_json(json_string):
	# print("[WebSocket] Processing JSON: ", json_string)
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		if not DEBUG_DISABLED:
			print("[WebSocket] Error parsing JSON: ", json_string)
		return
	
	var parsed = json.get_data()
	# Handle telemetry data
	if parsed and parsed.has("type") and parsed["type"] == "telemetry" and parsed.has("data"):
		var telemetry = parsed["data"]
		var telemetry_str = JSON.stringify(telemetry)
		if not DEBUG_DISABLED:
			print("[WebSocket] Telemetry received: ", telemetry_str)
		return
	
	# print("[WebSocket] Parsed data: ", parsed)
	# Handle control directive
	if parsed and parsed.has("type") and parsed["type"] == "control" and parsed.has("directive"):
		var directive = parsed["directive"]
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Throttle duplicate directives to prevent issues from long press or hardware congestion
		if last_directive_times.has(directive):
			var time_diff = current_time - last_directive_times[directive]
			if time_diff < directive_cooldown:
				if not DEBUG_DISABLED:
					print("[WebSocket] Throttling duplicate directive: ", directive, " (", time_diff, "s since last)")
				return
		
		last_directive_times[directive] = current_time
		
		if not DEBUG_DISABLED:
			print("[WebSocket] Emitting menu_control with directive: ", directive)
		menu_control.emit(directive)
		return
	
	# Handle BLE forwarded / netlink commands
	if parsed and (parsed.get("type") in ["netlink", "forward"] or parsed.get("action") == "forward"):
		var data_key = "data" if parsed.get("type") == "netlink" else "content"
		if parsed.has(data_key):
			_handle_ble_forwarded_command(parsed[data_key])
			return
	
	# Handle bullet hit data
	if parsed and parsed.has("data"):
		# print("[WebSocket] Found data array with ", parsed["data"].size(), " entries")
		for entry in parsed["data"]:
			var x = entry.get("x", null)
			var y = entry.get("y", null)
			var a = entry.get("a", null)
			var t = entry.get("t", null)
			if x != null and y != null:
				# Apply additional shot spacing to prevent burst processing
				var current_shot_time = Time.get_ticks_msec() / 1000.0
				if (current_shot_time - last_shot_processing_time) < minimum_shot_spacing:
					if not DEBUG_DISABLED:
						print("[WebSocket] Shot spacing too fast (", current_shot_time - last_shot_processing_time, "s), delaying processing")
					# Skip this shot to maintain minimum spacing
					continue
				
				last_shot_processing_time = current_shot_time
				
				# Transform pos from WebSocket (268x476.4, origin bottom-left) to game (720x1280, origin top-left)
				var ws_width = 268.0
				var ws_height = 476.4
				var game_width = 720.0
				var game_height = 1280.0
				# Flip y and scale
				var x_new = x * (game_width / ws_width)
				var y_new = game_height - (y * (game_height / ws_height))
				var transformed_pos = Vector2(x_new, y_new)
				
				if bullet_spawning_enabled:
					# Emit immediately when enabled
					if not DEBUG_DISABLED: print("[WebSocket] Raw position: Vector2(", x, ", ", y, ") -> Transformed: ", transformed_pos)
					# Emit bullet_hit signal with additional data (a and t)
					if a != null and t != null:
						bullet_hit.emit(transformed_pos, a, t)
						# bullet_hit.emit(transformed_pos)						
				else:
					# When disabled, don't add to pending queue - just ignore
					pass
					if not DEBUG_DISABLED: print("[WebSocket] Bullet spawning disabled, ignoring hit at: Vector2(", x, ", ", y, ")")
			else:
				if not DEBUG_DISABLED:
					print("[WebSocket] Entry missing x or y: ", entry)

func _handle_ble_forwarded_command(parsed):
	"""Handle BLE forwarded commands"""
	var _sb = get_node_or_null("/root/SignalBus")
	var gd = get_node_or_null("/root/GlobalData")
	
	# The new format has data directly as the command content, no dest/content wrapper
	var content = parsed
	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded command content: ", content)

	# Handle start_game_upgrade action - forward to software_upgrade scene
	if content.get("action") == "start_game_upgrade":
		# Check if OTA mode is enabled
		if gd and gd.ota_mode:
			var address = content.get("address", "")
			var checksum = content.get("checksum", "")
			var version = content.get("version", "unknown")
			if address and checksum:
				if not DEBUG_DISABLED:
					print("[WebSocket] OTA upgrade initiated for version: ", version)
				# Transition to software upgrade scene and set parameters
				_trigger_software_upgrade(address, checksum, version)
			else:
				if not DEBUG_DISABLED:
					print("[WebSocket] OTA upgrade missing address or checksum")
		else:
			if not DEBUG_DISABLED:
				print("[WebSocket] OTA upgrade attempted but OTA mode is not enabled")
		return

	var content_str = JSON.stringify(content)
	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded: ", content_str)

	#     let content: [String: Any] = [
	#     "command": "ready"/"start",
	#     "delay": delay,
	#     "targetType": target.targetType ?? "",
	#     "timeout": target.timeout,
	#     "countedShots": target.countedShots]

	# Determine command type from content. Common keys: 'command', 'cmd', or 'type'
	var command = null

	command = content.get("command", null)

	if not DEBUG_DISABLED:
		print("[WebSocket] BLE forwarded command determined command: ", command)

	# Emit the appropriate signal based on the command value
	match command:
		"ready":
			if not DEBUG_DISABLED: print("[WebSocket] Emitting ble_ready_command signal with content: ", content)
			ble_ready_command.emit(content)
		"start":
			if not DEBUG_DISABLED: print("[WebSocket] Emitting ble_start_command signal with content: ", content)
			ble_start_command.emit(content)
		"end":
			if not DEBUG_DISABLED: print("[WebSocket] Emitting ble_end_command signal with content: ", content)
			ble_end_command.emit(content)
		"animation_config":
			if not DEBUG_DISABLED: print("[WebSocket] Handling animation_config command with content: ", content)
			_handle_animation_config(content)
		"query_version":
			if not DEBUG_DISABLED: print("[WebSocket] Handling query_version command")
			_handle_query_version()
		_:
			if not DEBUG_DISABLED:
				print("[WebSocket] BLE forwarded command unknown or unsupported command: ", command)

	# Handle WiFi password from mobile app
	if content.has("ssid") and content.has("password"):
		var sb = get_node_or_null("/root/SignalBus")
		if sb:
			sb.emit_wifi_password_received(content["ssid"], content["password"])
		return

	# Handle target name from mobile app
	if content.has("target_name"):
		var target_name = content["target_name"]
		if not DEBUG_DISABLED:
			print("[WebSocket] Emitting target_name_received signal with name: ", target_name)
		target_name_received.emit(target_name)
		return

func _handle_animation_config(parsed):
	"""Handle animation configuration commands from mobile app"""
	var _sb = get_node_or_null("/root/SignalBus")
	
	# Extract action and duration from the parsed message
	var action = parsed.get("action", "")
	var duration = parsed.get("duration", 3.0)
	
	if not DEBUG_DISABLED:
		print("[WebSocket] Animation config received - action: ", action, ", duration: ", duration)
	
	# Validate the data
	if action == "":
		if not DEBUG_DISABLED:
			print("[WebSocket] Animation config missing action")
		return
	
	var content_str = JSON.stringify({"action": action, "duration": duration})
	if not DEBUG_DISABLED:
		print("[WebSocket] Animation config: ", content_str)
	
	# Emit the animation config signal
	if not DEBUG_DISABLED:
		print("[WebSocket] Emitting animation_config signal - action: ", action, ", duration: ", duration)
	animation_config.emit(action, duration)

func _handle_query_version():
	"""Handle query_version command - return the VERSION constant from GlobalData"""
	var gd = get_node_or_null("/root/GlobalData")
	if not gd:
		if not DEBUG_DISABLED:
			print("[WebSocket] GlobalData not found for query_version")
		return
	
	var version = gd.VERSION
	var response_content = {"version": version}
	
	if not DEBUG_DISABLED:
		print("[WebSocket] Responding to query_version with version: ", version)
	
	# Forward the response to the app using HttpService
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.forward_data_to_app(func(_result, _response_code, _headers, _body):
			if not DEBUG_DISABLED:
				print("[WebSocket] Version query response sent to mobile app")
		, response_content)
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] HttpService not found for query_version response")
func clear_queued_signals():
	"""Clear all queued WebSocket packets and pending bullet hit signals"""
	if not DEBUG_DISABLED:
		print("[WebSocket] Clearing queued signals and packets")
	
	# Clear all pending WebSocket packets
	var cleared_packets = 0
	while socket.get_available_packet_count() > 0:
		socket.get_packet()  # Consume and discard the packet
		cleared_packets += 1
	
	if cleared_packets > 0:
		if not DEBUG_DISABLED:
			print("[WebSocket] Cleared ", cleared_packets, " queued WebSocket packets")
	
	# Clear pending bullet hit signals
	var cleared_signals = pending_bullet_hits.size()
	pending_bullet_hits.clear()
	
	if cleared_signals > 0:
		if not DEBUG_DISABLED: print("[WebSocket] Cleared ", cleared_signals, " pending bullet hit signals")
	
	# Reset rate limiting timer to prevent immediate flood when re-enabled
	last_message_time = Time.get_ticks_msec() / 1000.0
	
	# Reset shot processing timer for clean restart
	last_shot_processing_time = 0.0

func send_netlink_forward(device: String, content_val: Dictionary) -> int:
	"""Helper to send a netlink forward message over the websocket socket.
	Returns OK on success, or the error code otherwise."""
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var ack_message = {
			"type": "netlink",
			"action": "forward",
			"device": device,
			"content": content_val
		}
		var json_string = JSON.stringify(ack_message)
		var err = socket.send_text(json_string)
		if err != OK:
			if not DEBUG_DISABLED:
				print("[WebSocket] send_netlink_forward failed: ", err)
			return err
		if not DEBUG_DISABLED:
			print("[WebSocket] send_netlink_forward sent: ", json_string)
		return OK
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] send_netlink_forward: socket not available or not open")
		return ERR_UNAVAILABLE

func set_bullet_spawning_enabled(enabled: bool):
	"""Set bullet spawning enabled state and clear queues when disabled"""
	var previous_state = bullet_spawning_enabled
	bullet_spawning_enabled = enabled
	
	if not DEBUG_DISABLED:
		print("[WebSocket] Bullet spawning enabled changed from ", previous_state, " to ", enabled)
	
	# Clear queues when disabling bullet spawning
	if not enabled and previous_state:
		clear_queued_signals()

func get_bullet_spawning_enabled() -> bool:
	"""Get current bullet spawning enabled state"""
	return bullet_spawning_enabled

func _attempt_reconnect() -> void:
	"""Try to reopen the websocket connection immediately. If it fails, schedule the reconnect timer."""
	if not DEBUG_DISABLED:
		print("[WebSocket] Attempting reconnect...")

		# Try to create a fresh WebSocketPeer and initiate connection
		var new_socket = WebSocketPeer.new()
		var err = new_socket.connect_to_url(WEBSOCKET_URL)

		# If connect_to_url returns OK it means the connection process started successfully
		if err == OK:
			socket = new_socket
			# Enable processing so poll() can drive the connection state machine
			set_process(true)
			if not DEBUG_DISABLED:
				print("[WebSocket] Reconnect attempt started (connection in progress)")

			# Start the connect watchdog to ensure the connect finishes in a timely manner
			var watchdog = get_node_or_null("WebSocketConnectWatchdog")
			if watchdog:
				watchdog.start()
			return

		# If connect_to_url returned an error, schedule retry with backoff
		var timer = get_node_or_null("WebSocketReconnectTimer")
		if timer:
			var next = clamp(timer.wait_time * 2.0, 2.0, 60.0)
			timer.wait_time = next
			if not DEBUG_DISABLED:
				print("[WebSocket] Reconnect attempt failed to start (err=", err, ") - scheduling retry in ", timer.wait_time, "s")
			timer.start()


func _on_reconnect_timer_timeout() -> void:
	"""Handler called when reconnect timer fires; attempt reconnect."""
	_attempt_reconnect()


func _on_connect_watchdog_timeout() -> void:
	"""Called when a connect attempt didn't reach OPEN within the watchdog timeout.
	Schedules backoff retry and emits onboard debug info."""
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		# Connection succeeded just before watchdog fired; nothing to do
		if not DEBUG_DISABLED:
			print("[WebSocket] Connect watchdog fired but socket already OPEN")
		return

	# Not open: schedule backoff retry
	var timer = get_node_or_null("WebSocketReconnectTimer")
	if timer:
		var next = clamp(timer.wait_time * 2.0, 2.0, 60.0)
		timer.wait_time = next
		if not DEBUG_DISABLED:
			print("[WebSocket] Connect watchdog timeout - scheduling retry in ", timer.wait_time, "s")
		timer.start()

func _trigger_software_upgrade(address: String, checksum: String, version: String) -> void:
	"""Trigger the software upgrade scene and pass download parameters"""
	if not DEBUG_DISABLED:
		print("[WebSocket] Triggering software upgrade signal with version: ", version)
	
	# Emit signal via SignalBus for current or future software_upgrade node
	var sb = get_node_or_null("/root/SignalBus")
	if sb:
		sb.emit_ota_upgrade_requested(address, checksum, version)
	else:
		if not DEBUG_DISABLED:
			print("[WebSocket] SignalBus not found to emit ota_upgrade_requested")


func _on_download_complete(_success: bool, _version: String):
	"""DEPRECATED: OTA download logic moved to software_upgrade scene"""
	if not DEBUG_DISABLED:
		print("[WebSocket] _on_download_complete is deprecated - OTA logic moved to software_upgrade scene")
