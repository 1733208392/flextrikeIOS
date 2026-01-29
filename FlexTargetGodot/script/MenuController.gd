extends Node

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

# Global Menu Controller Singleton
# Handles remote control directives from WebSocketListener
# Emits signals that scenes can connect to for menu control

signal navigate(direction: String)
signal navigate_claimed(owner: String, direction: String)
signal enter_pressed
signal back_pressed
signal homepage_pressed
signal volume_up_requested
signal volume_down_requested
signal power_off_requested
signal menu_control(directive: String)  # For compatibility with onscreen keyboard

var http_service = null
var cursor_sound: AudioStream = load("res://audio/Cursor.ogg")
var _focus_owner: String = ""

func claim_focus(_owner: String) -> void:
	_focus_owner = _owner

func release_focus(_owner: String) -> void:
	if _focus_owner == _owner:
		_focus_owner = ""

func get_focus_owner() -> String:
	return _focus_owner

func _ready():
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		# print("[MenuController] Connected to WebSocketListener.menu_control signal")
	else:
		# print("[MenuController] WebSocketListener singleton not found!")
		pass
	
	# Get HttpService reference
	http_service = get_node_or_null("/root/HttpService")
	if not http_service:
		# print("[MenuController] HttpService singleton not found!")
		pass

func _on_menu_control(directive: String):
	# print("[MenuController] Received directive: ", directive)
	
	# Emit the menu_control signal for compatibility with onscreen keyboard
	menu_control.emit(directive)
	
	match directive:
		"up", "down", "left", "right":
			# If an owner has claimed focus, emit claimed navigate only to that owner
			if _focus_owner != "":
				navigate_claimed.emit(_focus_owner, directive)
			else:
				navigate.emit(directive)
		"enter":
			enter_pressed.emit()
		"back":
			back_pressed.emit()
		"homepage":
			homepage_pressed.emit()
		"volume_up":
			volume_up_requested.emit()
			_handle_volume_up()
		"volume_down":
			volume_down_requested.emit()
			_handle_volume_down()
		"power":
			power_off_requested.emit()
			_handle_power_off()
		_:
			# print("[MenuController] Unknown directive: ", directive)
			pass

func _handle_volume_up():
	if http_service:
		# print("[MenuController] Sending volume up HTTP request...")
		http_service.volume_up(func(result, response_code, headers, body):
			_on_volume_response("up", result, response_code, headers, body)
		)
	else:
		# print("[MenuController] HttpService not available for volume up")
		pass

func _handle_volume_down():
	if http_service:
		# print("[MenuController] Sending volume down HTTP request...")
		http_service.volume_down(func(result, response_code, headers, body):
			_on_volume_response("down", result, response_code, headers, body)
		)
	else:
		# print("[MenuController] HttpService not available for volume down")
		pass

func _handle_power_off():
	# Show power off dialog instead of calling HTTP shutdown
	var parent = get_parent()
	if parent and parent.has_method("power_off"):
		parent.power_off()
	else:
		if not DEBUG_DISABLED:
			print("[MenuController] Parent doesn't have power_off method")

func _on_volume_response(_direction: String, _result, _response_code, _headers, _body):
	var _body_str = _body.get_string_from_utf8()
	# print("[MenuController] Volume ", _direction, " HTTP response:", _result, _response_code, _body_str)

func _on_shutdown_response(_result, _response_code, _headers, _body):
	var _body_str = _body.get_string_from_utf8()
	# print("[MenuController] Shutdown HTTP response:", _result, response_code, body_str)

func play_cursor_sound():
	"""Play cursor sound effect for menu navigation at fixed volume"""
	if not cursor_sound:
		if not DEBUG_DISABLED:
			print("[MenuController] Cursor sound not loaded")
		return
	
	# Create audio player with fixed volume
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = cursor_sound
	audio_player.volume_db = 0  # Full volume
	
	add_child(audio_player)
	audio_player.play()
	# Clean up audio player after sound finishes
	audio_player.finished.connect(func(): audio_player.queue_free())
