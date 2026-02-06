extends CanvasLayer

@onready var back_button = $Control/VBoxContainer/Panel/PanelContent/ButtonsContainer/BackButton
@onready var next_button = $Control/VBoxContainer/Panel/PanelContent/ButtonsContainer/NextButton
@onready var level_label = $Control/VBoxContainer/Panel/PanelContent/LevelLabel
@onready var score_value = $Control/VBoxContainer/Panel/PanelContent/ScoreValue
@onready var best_score_value = $Control/VBoxContainer/Panel/PanelContent/BestScoreValue
@onready var status_label = $Control/VBoxContainer/Panel/PanelContent/LevelLabel2
@onready var audio_player = $Control/AudioStreamPlayer2D

var current_level: int = 1
var current_score: int = 0
var is_passed: bool = true
var http_service: Node
var best_score: int = 0

func _ready():
	http_service = get_node("/root/HttpService")
	# Connect button signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	print("[LevelComplete] Connected button signals")
	
	# Set focus to next button by default
	if next_button:
		next_button.grab_focus()
	
	# Enable input processing for navigation
	set_process_input(true)
	
	# Connect to remote control
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_enter_pressed)
		remote_control.back_pressed.connect(_on_back_pressed)
		print("[LevelComplete] Connected to MenuController")
	else:
		print("[LevelComplete] MenuController autoload not found!")
	
	print("[LevelComplete] Scene ready")

func show_level_complete(level: int, score: int, passed: bool = true):
	"""Show the level complete screen with the given data"""
	current_level = level
	current_score = score
	is_passed = passed
	
	# Load best score from leaderboard
	load_best_score()
	
	# Update labels
	if level_label:
		level_label.text = "Level %03d" % level
	if score_value:
		score_value.text = str(score)
	if status_label:
		status_label.text = "CLEARED" if passed else "FAILED"
	
	# Update buttons based on passed status
	if next_button:
		if passed:
			next_button.text = "NEXT"
			next_button.icon = preload("res://asset/next-icon.png")
			next_button.pressed.connect(_on_next_pressed)
		else:
			next_button.text = "REPY"
			next_button.icon = preload("res://asset/restart-icon.png")
			next_button.pressed.connect(_on_restart_pressed)
	
	# Show the panel
	visible = true
	set_process_input(true)
	
	# Ensure next button has focus
	if next_button:
		next_button.grab_focus()
	
	# Play victory sound
	if audio_player:
		audio_player.play()
	
	print("[LevelComplete] Showing level %d with score %d, passed %s" % [level, score, str(passed)])

func load_best_score():
	"""Load the best score from the leaderboard"""
	if http_service:
		http_service.load_game(Callable(self, "_on_best_score_loaded"), "fruitblast_leaderboard")

func _on_best_score_loaded(result, response_code, _headers, body):
	"""Handle the leaderboard load response to extract best score"""
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json_result = JSON.parse_string(body_str)
		if json_result != null:
			var response_data = json_result
			var code = response_data.get("code", -1)
			if code == 0:
				var data = response_data.get("data", {})
				var leaderboard_data = []
				if typeof(data) == TYPE_STRING:
					var parsed_data = JSON.parse_string(data)
					if parsed_data != null:
						if typeof(parsed_data) == TYPE_DICTIONARY:
							leaderboard_data = parsed_data.get("content", [])
						elif typeof(parsed_data) == TYPE_ARRAY:
							leaderboard_data = parsed_data
				else:
					leaderboard_data = data.get("content", [])
				
				best_score = 0
				if typeof(leaderboard_data) == TYPE_ARRAY:
					for entry in leaderboard_data:
						if typeof(entry) == TYPE_DICTIONARY and entry.has("total_score"):
							best_score = max(best_score, int(entry["total_score"]))
			else:
				best_score = 0
		else:
			best_score = 0
	else:
		best_score = 0
	
	# Update the best score display
	if best_score_value:
		best_score_value.text = "BEST " + str(best_score)
	
	print("[LevelComplete] Best score loaded: %d" % best_score)

func _on_enter_pressed():
	"""Handle enter directive from remote control"""
	print("[LevelComplete] Remote enter pressed")
	if not next_button or not back_button:
		return
	if next_button.has_focus():
		if is_passed:
			_on_next_pressed()
		else:
			_on_restart_pressed()
	elif back_button.has_focus():
		_on_back_pressed()

func _on_remote_navigate(direction: String):
	"""Handle navigation directives from remote control"""
	print("[LevelComplete] Remote navigate: ", direction)
	if not next_button or not back_button:
		return
	if direction == "left":
		if next_button.has_focus():
			back_button.grab_focus()
		else:
			next_button.grab_focus()
	elif direction == "right":
		if back_button.has_focus():
			next_button.grab_focus()
		else:
			back_button.grab_focus()

func _input(event):
	"""Handle left/right navigation between buttons"""
	if not next_button or not back_button:
		return
	if event.is_action_pressed("ui_left"):
		print("[LevelComplete] UI left pressed")
		if next_button.has_focus():
			back_button.grab_focus()
		else:
			next_button.grab_focus()
	elif event.is_action_pressed("ui_right"):
		print("[LevelComplete] UI right pressed")
		if back_button.has_focus():
			next_button.grab_focus()
		else:
			back_button.grab_focus()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			print("[LevelComplete] Keyboard back pressed")
			_on_back_pressed()

func _on_back_pressed():
	"""Return to menu when back is pressed"""
	print("[LevelComplete] Back button pressed - returning to menu")
	hide_level_complete()
	if get_tree():
		var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
		if error != OK:
			print("[LevelComplete] Failed to change scene: ", error)
	
	# Clean up this level complete screen
	queue_free()

func _on_next_pressed():
	"""Continue to next level when next is pressed"""
	print("[LevelComplete] Next button pressed - starting next level")
	hide_level_complete()
	
	# Get reference to game node - walk up the tree to find it
	var game_node = get_parent()
	while game_node and not game_node.has_meta("is_game_scene"):
		game_node = game_node.get_parent()
	
	if game_node and game_node.has_meta("is_game_scene"):
		var next_level = current_level + 1
		game_node.current_level = next_level
		game_node.velocity_bonus = (next_level - 1) * 0.5  # +0.5 per level
		game_node.spawn_speed_multiplier = pow(1.3, next_level - 1)  # 30% faster per level
		game_node.score_target = round((120 * pow(1.3, next_level - 1)) / 10) * 10  # 30% more coins per level, rounded to 10s
		game_node.score = 0
		game_node.fruits_spawned = 0
		print("[LevelComplete] Updated game to level %d with velocity bonus %.1f and spawn multiplier %.2f" % [next_level, game_node.velocity_bonus, game_node.spawn_speed_multiplier])
		print("[LevelComplete] Game node found: %s" % game_node.name)
		
		# Update the level display in status bar
		if game_node.has_method("update_level_display"):
			game_node.update_level_display()
		
		# Reset game state
		if game_node.has_method("restart_level"):
			print("[LevelComplete] Calling restart_level() on game node")
			game_node.restart_level()
		else:
			print("[LevelComplete] Game doesn't have restart_level method, reloading scene")
			if get_tree():
				var error = get_tree().reload_current_scene()
				if error != OK:
					print("[LevelComplete] Failed to reload scene: ", error)
	else:
		print("[LevelComplete] Could not find game node after walking parent tree")
		print("[LevelComplete] Reloading scene as fallback")
		if get_tree():
			var error = get_tree().change_scene_to_file("res://scene/games/game.tscn")
			if error != OK:
				print("[LevelComplete] Failed to change scene: ", error)
	
	# Clean up this level complete screen
	queue_free()

func _on_restart_pressed():
	"""Restart the current level when restart is pressed"""
	print("[LevelComplete] Restart button pressed - restarting current level")
	hide_level_complete()
	
	# Get reference to game node - walk up the tree to find it
	var game_node = get_parent()
	while game_node and not game_node.has_meta("is_game_scene"):
		game_node = game_node.get_parent()
	
	if game_node and game_node.has_meta("is_game_scene"):
		var restart_level = current_level
		game_node.current_level = restart_level
		game_node.velocity_bonus = (restart_level - 1) * 0.5  # +0.5 per level
		game_node.spawn_speed_multiplier = pow(1.3, restart_level - 1)  # 30% faster per level
		game_node.score_target = round((120 * pow(1.3, restart_level - 1)) / 10) * 10  # 30% more coins per level, rounded to 10s
		game_node.score = 0
		game_node.fruits_spawned = 0
		print("[LevelComplete] Restarted game to level %d with velocity bonus %.1f and spawn multiplier %.2f" % [restart_level, game_node.velocity_bonus, game_node.spawn_speed_multiplier])
		print("[LevelComplete] Game node found: %s" % game_node.name)
		
		# Update the level display in status bar
		if game_node.has_method("update_level_display"):
			game_node.update_level_display()
		
		# Reset game state
		if game_node.has_method("restart_level"):
			print("[LevelComplete] Calling restart_level() on game node")
			game_node.restart_level()
		else:
			print("[LevelComplete] Game doesn't have restart_level method, reloading scene")
			if get_tree():
				var error = get_tree().reload_current_scene()
				if error != OK:
					print("[LevelComplete] Failed to reload scene: ", error)
	else:
		print("[LevelComplete] Could not find game node after walking parent tree")
		print("[LevelComplete] Reloading scene as fallback")
		if get_tree():
			var error = get_tree().change_scene_to_file("res://scene/games/game.tscn")
			if error != OK:
				print("[LevelComplete] Failed to change scene: ", error)
	
	# Clean up this level complete screen
	queue_free()

func hide_level_complete():
	"""Hide the level complete screen"""
	visible = false
	set_process_input(false)
	
	# Disconnect button signals
	if next_button:
		next_button.pressed.disconnect(_on_next_pressed if is_passed else _on_restart_pressed)
	
	# Disconnect from remote control signals
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.disconnect(_on_remote_navigate)
		remote_control.enter_pressed.disconnect(_on_enter_pressed)
		remote_control.back_pressed.disconnect(_on_back_pressed)
		print("[LevelComplete] Disconnected from MenuController signals")
