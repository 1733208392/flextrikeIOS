extends Control

@onready var save_button = $VBoxContainer/SaveButton
@onready var load_button = $VBoxContainer/LoadButton
@onready var save_leaderboard_button = $VBoxContainer/SaveLeaderBoardButton
@onready var load_leaderboard_button = $VBoxContainer/LoadLeaderBoardButton
@onready var response_text = $VBoxContainer/ResponseText

var current_focused_button = 0  # 0 for save, 1 for load, 2 for save leaderboard, 3 for load leaderboard

func _ready():
	# Connect buttons
	if save_button:
		save_button.focus_mode = Control.FOCUS_ALL
	if load_button:
		load_button.focus_mode = Control.FOCUS_ALL
	if save_leaderboard_button:
		save_leaderboard_button.focus_mode = Control.FOCUS_ALL
	if load_leaderboard_button:
		load_leaderboard_button.focus_mode = Control.FOCUS_ALL
	
	# Set initial focus
	set_focus_to_button(0)
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		print("[TestHttp] Connected to WebSocketListener")
	else:
		print("[TestHttp] WebSocketListener not found")

func set_focus_to_button(index: int):
	current_focused_button = index
	if index == 0 and save_button:
		save_button.grab_focus()
	elif index == 1 and load_button:
		load_button.grab_focus()
	elif index == 2 and save_leaderboard_button:
		save_leaderboard_button.grab_focus()
	elif index == 3 and load_leaderboard_button:
		load_leaderboard_button.grab_focus()

func _on_menu_control(directive: String):
	print("[TestHttp] Received directive: ", directive)
	match directive:
		"up", "down":
			toggle_focus()
		"enter":
			perform_action()
		_:
			print("[TestHttp] Unknown directive: ", directive)

func toggle_focus():
	current_focused_button = (current_focused_button + 1) % 4
	set_focus_to_button(current_focused_button)

func perform_action():
	if current_focused_button == 0:
		save_settings()
	elif current_focused_button == 1:
		load_settings()
	elif current_focused_button == 2:
		save_leaderboard_index()
	elif current_focused_button == 3:
		load_leaderboard_index()

func save_settings():
	var file = FileAccess.open("res://asset/settings.json", FileAccess.READ)
	if not file:
		response_text.text = "Failed to open settings.json"
		return
	
	var content = file.get_as_text()
	file.close()
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending save request..."
		http_service.save_game(_on_save_response, "settings", content)
	else:
		response_text.text = "HttpService not found"

func _on_save_response(result, response_code, headers, body):
	var body_text = body.get_string_from_utf8()
	var response_str = "=== SAVE SETTINGS RESPONSE ===\n"
	response_str += "Result: %d\n" % result
	response_str += "Response Code: %d\n" % response_code
	response_str += "Body:\n%s" % body_text
	response_text.text = response_str
	print("[TestHttp] Save response: ", response_str)

func load_settings():
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending load request..."
		http_service.load_game(_on_load_response, "settings")
	else:
		response_text.text = "HttpService not found"

func _on_load_response(result, response_code, headers, body):
	var body_text = body.get_string_from_utf8()
	var response_str = "=== LOAD SETTINGS RESPONSE ===\n"
	response_str += "Result: %d\n" % result
	response_str += "Response Code: %d\n" % response_code
	response_str += "Body:\n%s" % body_text
	response_text.text = response_str
	print("[TestHttp] Load response: ", response_str)

func save_leaderboard_index():
	var file = FileAccess.open("res://HttpServerSim/leader_board_index.json", FileAccess.READ)
	if not file:
		response_text.text = "Failed to open leader_board_index.json"
		return
	
	var content = file.get_as_text()
	file.close()
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending save leaderboard request..."
		http_service.save_game(_on_save_leaderboard_response, "leader_board_index", content)
	else:
		response_text.text = "HttpService not found"

func _on_save_leaderboard_response(result, response_code, headers, body):
	var body_text = body.get_string_from_utf8()
	var response_str = "=== SAVE LEADERBOARD RESPONSE ===\n"
	response_str += "Result: %d\n" % result
	response_str += "Response Code: %d\n" % response_code
	response_str += "Body:\n%s" % body_text
	response_text.text = response_str
	print("[TestHttp] Save leaderboard response: ", response_str)

func load_leaderboard_index():
	var http_service = get_node("/root/HttpService")
	if http_service:
		response_text.text = "Sending load leaderboard request..."
		http_service.load_game(_on_load_leaderboard_response, "leader_board_index")
	else:
		response_text.text = "HttpService not found"

func _on_load_leaderboard_response(result, response_code, headers, body):
	var body_text = body.get_string_from_utf8()
	var response_str = "=== LOAD LEADERBOARD RESPONSE ===\n"
	response_str += "Result: %d\n" % result
	response_str += "Response Code: %d\n" % response_code
	response_str += "Body:\n%s" % body_text
	response_text.text = response_str
	print("[TestHttp] Load leaderboard response: ", response_str)
