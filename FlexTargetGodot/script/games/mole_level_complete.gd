extends CanvasLayer

var back_button: Button
var next_button: Button
var replay_button: Button
@onready var level_label = $Control/VBoxContainer/HeaderCircle/CircleContent/LevelLabel
@onready var level_number = $Control/VBoxContainer/HeaderCircle/CircleContent/LevelNumber
@onready var score_label = $Control/VBoxContainer/Content/PanelContent/ScoreContainer/ScoreLabel
@onready var score_value = $Control/VBoxContainer/Content/PanelContent/ScoreContainer/ScoreValue
@onready var coin_label = $Control/VBoxContainer/Content/PanelContent/CoinContainer/CoinLabel
@onready var coin_value = $Control/VBoxContainer/Content/PanelContent/CoinContainer/CoinValue
@onready var bonus_label = $Control/VBoxContainer/Content/PanelContent/BonusContainer/BonusLabel
@onready var star1 = $Control/VBoxContainer/HeaderCircle/StarsContainer/Star1
@onready var star2 = $Control/VBoxContainer/HeaderCircle/StarsContainer/Star2
@onready var star3 = $Control/VBoxContainer/HeaderCircle/StarsContainer/Star3
@onready var coin_particles = $Control/CoinParticles
@onready var cleared_label = $Control/VBoxContainer/Content/PanelContent/ClearedLabel
@onready var audio_player = $Control/AudioStreamPlayer2D

var bonus_value: Label = null  # Optional - may not exist in scene

var current_level: int = 1
var current_score: int = 0
var current_coins: int = 0
var current_bonus: int = 0
var stars_earned: int = 3  # Default to 3 stars
var level_passed: bool = true  # Track if level was passed or failed
var victory_sound = preload("res://audio/victory-chime.mp3")
var game_node: Node = null  # Reference to the GameMole node

func _ready():
	# Debug: Print the scene tree
	print_tree_pretty()
	
	# Get button references using get_node_or_null with correct paths
	back_button = get_node_or_null("Control/VBoxContainer/Content/PanelContent/ButtonsContainer/BackButton")
	next_button = get_node_or_null("Control/VBoxContainer/Content/PanelContent/ButtonsContainer/NextButton")
	replay_button = get_node_or_null("Control/VBoxContainer/Content/PanelContent/ButtonsContainer/ReplayButton")
	
	# Debug: Print button references
	print("Back button: ", back_button)
	print("Next button: ", next_button)
	print("Replay button: ", replay_button)
	
	# Connect button signals
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("[MoleLevelComplete] Connected back_button")
	else:
		print("[MoleLevelComplete] Back button not found")
	
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
		print("[MoleLevelComplete] Connected next_button")
	else:
		print("[MoleLevelComplete] Next button not found")
	
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
		print("[MoleLevelComplete] Connected replay_button")
	else:
		print("[MoleLevelComplete] Replay button not found")
	
	print("[MoleLevelComplete] Connected button signals")
	
	# Set focus to next button by default (if it exists)
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
		print("[MoleLevelComplete] Connected to MenuController")
	else:
		print("[MoleLevelComplete] MenuController autoload not found!")
	
	if coin_particles:
		coin_particles.emitting = true
	
	# Translate static labels
	if level_label:
		level_label.text = tr("level_label")
	if score_label:
		score_label.text = tr("score")
	if coin_label:
		coin_label.text = tr("coin_label")
	if bonus_label:
		bonus_label.text = tr("bonus_label")
	if back_button:
		back_button.text = tr("back_button")
	if next_button:
		next_button.text = tr("next")
	if replay_button:
		replay_button.text = tr("replay_button")
	
	print("[MoleLevelComplete] Scene ready")

func show_level_complete(level: int, score: int, coins: int = 0, bonus: int = 0, stars: int = 3, passed: bool = true):
	"""Show the level complete screen with the given data"""
	current_level = level
	current_score = score
	current_coins = coins
	current_bonus = bonus
	stars_earned = clamp(stars, 0, 3)
	level_passed = passed
	
	# Store reference to the GameMole node for later use
	game_node = get_tree().root.get_node("GameMole")
	
	# Update labels
	level_number.text = "%03d" % level
	score_value.text = str(score)
	coin_value.text = str(coins)
	
	# Update bonus if the node exists
	if bonus_value:
		bonus_value.text = str(bonus)
	
	# Update cleared label and buttons based on pass/fail
	if level_passed:
		cleared_label.text = tr("level_cleared")
		next_button.visible = true
		replay_button.visible = false
		next_button.grab_focus()
		
		# Show particles and play sound for passed level
		if coin_particles:
			coin_particles.restart()
			coin_particles.emitting = true
		if audio_player:
			audio_player.play()
	else:
		cleared_label.text = tr("level_failed")
		next_button.visible = false
		replay_button.visible = true
		replay_button.grab_focus()
		
		# Hide particles and stop sound for failed level
		if coin_particles:
			coin_particles.emitting = false
		if audio_player:
			audio_player.stop()
	
	# Update stars display
	_update_stars_display()
	
	# Show the panel
	visible = true
	set_process_input(true)
	
	print("[MoleLevelComplete] Showing level %d with score %d, coins %d, bonus %d and %d stars (passed: %s)" % [level, score, coins, bonus, stars, level_passed])

func _update_stars_display():
	"""Update the star display based on stars_earned"""
	# Fade out stars that weren't earned
	if stars_earned >= 1:
		star1.modulate.a = 1.0
	else:
		star1.modulate.a = 0.3
	
	if stars_earned >= 2:
		star2.modulate.a = 1.0
	else:
		star2.modulate.a = 0.3
	
	if stars_earned >= 3:
		star3.modulate.a = 1.0
	else:
		star3.modulate.a = 0.3

func _on_enter_pressed():
	"""Handle enter directive from remote control"""
	print("[MoleLevelComplete] Remote enter pressed")
	# Prioritize the button that currently has focus. Support replay_button when shown.
	if next_button and next_button.has_focus():
		_on_next_pressed()
	elif replay_button and replay_button.has_focus():
		_on_replay_pressed()
	elif back_button and back_button.has_focus():
		_on_back_pressed()

func _on_remote_navigate(direction: String):
	"""Handle navigation directives from remote control"""
	print("[MoleLevelComplete] Remote navigate: ", direction)
	# Determine the secondary button shown to the right of Back:
	var secondary_button: Button = null
	if next_button and next_button.visible:
		secondary_button = next_button
	elif replay_button and replay_button.visible:
		secondary_button = replay_button

	if direction == "left":
		# Move focus left: if currently on secondary -> go to back, else go to secondary
		if secondary_button and secondary_button.has_focus():
			if back_button:
				back_button.grab_focus()
		else:
			if secondary_button:
				secondary_button.grab_focus()
			elif back_button:
				back_button.grab_focus()
	elif direction == "right":
		# Move focus right: if currently on back -> go to secondary, else go to back
		if back_button and back_button.has_focus():
			if secondary_button:
				secondary_button.grab_focus()
		else:
			if back_button:
				back_button.grab_focus()
			elif secondary_button:
				secondary_button.grab_focus()

func _input(event):
	"""Handle left/right navigation between buttons"""
	if event.is_action_pressed("ui_left"):
		print("[MoleLevelComplete] UI left pressed")
		# Mirror remote navigation logic for keyboard/gamepad arrows
		var secondary_button: Button = null
		if next_button and next_button.visible:
			secondary_button = next_button
		elif replay_button and replay_button.visible:
			secondary_button = replay_button

		if secondary_button and secondary_button.has_focus():
			if back_button:
				back_button.grab_focus()
		else:
			if secondary_button:
				secondary_button.grab_focus()
			elif back_button:
				back_button.grab_focus()
	elif event.is_action_pressed("ui_right"):
		print("[MoleLevelComplete] UI right pressed")
		var secondary_button_r: Button = null
		if next_button and next_button.visible:
			secondary_button_r = next_button
		elif replay_button and replay_button.visible:
			secondary_button_r = replay_button

		if back_button and back_button.has_focus():
			if secondary_button_r:
				secondary_button_r.grab_focus()
		else:
			if back_button:
				back_button.grab_focus()
			elif secondary_button_r:
				secondary_button_r.grab_focus()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			print("[MoleLevelComplete] Keyboard back pressed")
			_on_back_pressed()

func _on_back_pressed():
	"""Return to menu when back is pressed"""
	print("[MoleLevelComplete] Back button pressed - returning to menu")
	hide_level_complete()
	if get_tree():
		var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
		if error != OK:
			print("[MoleLevelComplete] Failed to change scene: ", error)
	
	# Clean up this level complete screen
	queue_free()

func _on_next_pressed():
	"""Continue to next level when next is pressed"""
	print("[MoleLevelComplete] Next button pressed - starting next level")
	hide_level_complete()
	
	if game_node and game_node.has_method("_start_next_level"):
		print("[MoleLevelComplete] Calling _start_next_level() on game node")
		game_node._start_next_level()
	else:
		print("[MoleLevelComplete] Game node not found or doesn't have _start_next_level method")
	
	# Clean up this level complete screen
	queue_free()

func _on_replay_pressed():
	"""Replay the current level when replay is pressed"""
	print("[MoleLevelComplete] Replay button pressed - restarting level")
	hide_level_complete()
	
	# Restart the current level without reloading the scene
	if game_node and game_node.has_method("_restart_current_level"):
		print("[MoleLevelComplete] Calling _restart_current_level() on game node")
		game_node._restart_current_level()
	else:
		print("[MoleLevelComplete] Game node not found or doesn't have _restart_current_level method, reloading scene as fallback")
		if get_tree():
			var error = get_tree().reload_current_scene()
			if error != OK:
				print("[MoleLevelComplete] Failed to reload scene: ", error)
	
	# Clean up this level complete screen
	queue_free()

func hide_level_complete():
	"""Hide the level complete screen"""
	visible = false
	set_process_input(false)
	if coin_particles:
		coin_particles.emitting = false
	
	# Disconnect from remote control signals
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.disconnect(_on_remote_navigate)
		remote_control.enter_pressed.disconnect(_on_enter_pressed)
		remote_control.back_pressed.disconnect(_on_back_pressed)
		print("[MoleLevelComplete] Disconnected from MenuController signals")
