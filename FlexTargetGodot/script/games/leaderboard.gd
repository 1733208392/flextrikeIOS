extends CanvasLayer

signal leaderboard_loaded(is_new: bool)
signal replay_pressed

var http_service: Node
var leaderboard_data: Array = []
var current_score: int = 0
var highlight_index: int = -1
var is_new_file: bool = false

func _ready():
	http_service = get_node("/root/HttpService")
	
	# Connect to remote control for back/home button
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Leaderboard] Connected to MenuController back_pressed signal")
	else:
		print("[Leaderboard] MenuController autoload not found!")

	# Set translated UI title label if present
	var title_label = $Control/Panel/VBoxContainer/TitleLabel
	if title_label:
		title_label.text = tr("leaderboard")

	# UI buttons
	var back_btn = $Control/HBoxContainer/Back
	var replay_btn = $Control/HBoxContainer/Replay

	# Set translated button texts
	if back_btn:
		back_btn.text = tr("back_button")
	if replay_btn:
		replay_btn.text = tr("restart")

	# Default focus: give Replay focus
	if replay_btn:
		replay_btn.grab_focus()

	# Remote control navigation: claim focus so we receive navigate_claimed
	remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.claim_focus("leaderboard")
		# Connect claimed navigation and enter to local handlers
		if not remote_control.is_connected("navigate_claimed", Callable(self, "_on_navigate_claimed")):
			remote_control.connect("navigate_claimed", Callable(self, "_on_navigate_claimed"))
		if not remote_control.is_connected("enter_pressed", Callable(self, "_on_enter_pressed")):
			remote_control.connect("enter_pressed", Callable(self, "_on_enter_pressed"))


func _on_navigate_claimed(owner_name: String, direction: String) -> void:
	if owner_name != "leaderboard":
		return
	# Only left/right toggle between Back and Replay
	if direction == "left" or direction == "right":
		var back_btn = $Control/HBoxContainer/Back
		var replay_btn = $Control/HBoxContainer/Replay
		if back_btn and replay_btn:
			if back_btn.has_focus():
				replay_btn.grab_focus()
			else:
				back_btn.grab_focus()
		# Play cursor sound if available
		var rc = get_node_or_null("/root/MenuController")
		if rc:
			rc.play_cursor_sound()

func _on_enter_pressed() -> void:
	var back_btn = $Control/HBoxContainer/Back
	var replay_btn = $Control/HBoxContainer/Replay
	if back_btn and back_btn.has_focus():
		_return_to_menu()
	elif replay_btn and replay_btn.has_focus():
		# Emit a replay signal for the caller to handle restart logic
		emit_signal("replay_pressed")

func _exit_tree() -> void:
	# Release claimed focus and disconnect signals
	var rc = get_node_or_null("/root/MenuController")
	if rc:
		rc.release_focus("leaderboard")
		var nav_callable = Callable(self, "_on_navigate_claimed")
		var enter_callable = Callable(self, "_on_enter_pressed")
		var back_callable = Callable(self, "_on_remote_back_pressed")
		if rc.is_connected("navigate_claimed", nav_callable):
			rc.disconnect("navigate_claimed", nav_callable)
		if rc.is_connected("enter_pressed", enter_callable):
			rc.disconnect("enter_pressed", enter_callable)
		if rc.is_connected("back_pressed", back_callable):
			rc.disconnect("back_pressed", back_callable)

	
func load_leaderboard(score_to_add: int = -1):
	is_new_file = false  # Reset flag
	if http_service:
		current_score = score_to_add  # Store the score to add if file doesn't exist
		http_service.load_game(Callable(self, "_on_leaderboard_loaded"), "fruitblast_leaderboard")
		await get_tree().create_timer(0.1).timeout  # Wait a bit for the request
	else:
		print("HttpService not found")

func _on_leaderboard_loaded(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		print("[Leaderboard] Raw response body: ", body_str)
		var json_result = JSON.parse_string(body_str)
		if json_result != null:
			var response_data = json_result
			print("[Leaderboard] Parsed response: ", response_data)
			var code = response_data.get("code", -1)
			var msg = response_data.get("msg", "Unknown error")
			var data = response_data.get("data", {})
			print("[Leaderboard] Code: ", code, ", Msg: ", msg, ", Data: ", data)
			
			if code == 0:
				# Success - get the leaderboard content
				print("[Leaderboard] Data type: ", typeof(data), ", Data value: ", data)
				if typeof(data) == TYPE_STRING:
					# Data is a JSON string, parse it
					var parsed_data = JSON.parse_string(data)
					if parsed_data != null:
						if typeof(parsed_data) == TYPE_DICTIONARY:
							leaderboard_data = parsed_data.get("content", [])
						elif typeof(parsed_data) == TYPE_ARRAY:
							# Data is the leaderboard array directly
							leaderboard_data = parsed_data
						else:
							leaderboard_data = []
					else:
						leaderboard_data = []
				else:
					# Data is already a dictionary
					leaderboard_data = data.get("content", [])
				if typeof(leaderboard_data) != TYPE_ARRAY:
					leaderboard_data = []
			else:
				# Error - likely file doesn't exist, create it with current score as 1st place
				print("[Leaderboard] Load failed with code ", code, ": ", msg, " - Creating new leaderboard file with current score")
				is_new_file = true
				leaderboard_data = [{"total_score": current_score}]
				
				# Create the file with the current score
				if http_service:
					var leaderboard_json = JSON.stringify(leaderboard_data)
					http_service.save_game(Callable(self, "_on_leaderboard_created"), "fruitblast_leaderboard", leaderboard_json)
				else:
					print("[Leaderboard] HttpService not found, cannot create leaderboard")
				return
		else:
			print("[Leaderboard] Failed to parse JSON response: ", body_str)
			leaderboard_data = []
	else:
		print("[Leaderboard] HTTP request failed - Result: ", result, ", Response Code: ", response_code)
		leaderboard_data = []
	
	# Ensure it's an array of dicts with total_score
	for i in range(leaderboard_data.size()):
		if typeof(leaderboard_data[i]) != TYPE_DICTIONARY or not leaderboard_data[i].has("total_score"):
			leaderboard_data[i] = {"total_score": 0}
	
	# Sort by total_score descending
	leaderboard_data.sort_custom(func(a, b): return a["total_score"] > b["total_score"])
	
	# Keep only top 10
	if leaderboard_data.size() > 10:
		leaderboard_data.resize(10)
	
	emit_signal("leaderboard_loaded", false)

func update_leaderboard_with_score(score: int):
	current_score = score
	highlight_index = -1
	
	# Check if score qualifies for top 10
	var inserted = false
	for i in range(leaderboard_data.size()):
		if score > leaderboard_data[i]["total_score"]:
			leaderboard_data.insert(i, {"total_score": score})
			highlight_index = i
			inserted = true
			break
	
	if not inserted and leaderboard_data.size() < 10:
		leaderboard_data.append({"total_score": score})
		highlight_index = leaderboard_data.size() - 1
		inserted = true
	
	if inserted:
		# Keep only top 10
		if leaderboard_data.size() > 10:
			leaderboard_data.resize(10)
		
		# Save updated leaderboard
		if http_service:
			var leaderboard_json = JSON.stringify(leaderboard_data)
			http_service.save_game(Callable(self, "_on_leaderboard_saved"), "fruitblast_leaderboard", leaderboard_json)
		else:
			print("HttpService not found")
	
	display_leaderboard()

func _on_leaderboard_saved(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("Leaderboard saved successfully")
	else:
		print("Failed to save leaderboard")

func _on_leaderboard_created(result, response_code, _headers, _body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		print("[Leaderboard] New leaderboard file created successfully")
		if is_new_file:
			# For new files, the current score is already in 1st place
			highlight_index = 0
			display_leaderboard()
		emit_signal("leaderboard_loaded", is_new_file)
	else:
		print("[Leaderboard] Failed to create leaderboard file")
		# Still emit signal with empty leaderboard
		emit_signal("leaderboard_loaded", false)

func display_leaderboard():
	var scores_container = $Control/Panel/VBoxContainer/ScoresContainer
	var score_labels = scores_container.get_children()
	
	for i in range(score_labels.size()):
		if i < leaderboard_data.size():
			var score = int(leaderboard_data[i]["total_score"])
			score_labels[i].text = str(i + 1) + ". " + str(score)
			if i == highlight_index:
				score_labels[i].add_theme_color_override("font_color", Color.YELLOW)
			else:
				score_labels[i].remove_theme_color_override("font_color")
		else:
			score_labels[i].text = str(i + 1) + ". --"
			score_labels[i].remove_theme_color_override("font_color")
	
	$Control/Panel/VBoxContainer/YourScoreLabel.text = tr("your_score") + str(current_score)

func _on_remote_back_pressed():
	"""Handle back/home directive from remote control to return to menu"""
	print("[Leaderboard] Remote back/home pressed - returning to menu...")
	_return_to_menu()

func _return_to_menu():
	print("[Leaderboard] Returning to menu scene")
	var tree = get_tree()
	if tree:
		var error = tree.change_scene_to_file("res://scene/games/menu/menu.tscn")
		if error != OK:
			print("[Leaderboard] Failed to change scene: ", error)
		else:
			print("[Leaderboard] Scene change initiated")
	else:
		print("[Leaderboard] Cannot change scene - scene tree is null")
