extends CanvasLayer

@onready var back_button = $Control/VBoxContainer/Panel/PanelContent/ButtonsContainer/BackButton
@onready var next_button = $Control/VBoxContainer/Panel/PanelContent/ButtonsContainer/NextButton
@onready var level_label = $Control/VBoxContainer/Panel/PanelContent/LevelLabel
@onready var score_value = $Control/VBoxContainer/Panel/PanelContent/ScoreContainer/ScoreValue
@onready var star1 = $Control/VBoxContainer/Panel/PanelContent/StarsContainer/Star1
@onready var star2 = $Control/VBoxContainer/Panel/PanelContent/StarsContainer/Star2
@onready var star3 = $Control/VBoxContainer/Panel/PanelContent/StarsContainer/Star3
@onready var coin_particles = $Control/CoinParticles

var current_level: int = 1
var current_score: int = 0
var stars_earned: int = 3  # Default to 3 stars
var victory_sound = preload("res://audio/victory-chime.mp3")

func _ready():
	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	print("[LevelComplete] Connected button signals")
	
	# Set focus to next button by default
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
	
	if coin_particles:
		coin_particles.emitting = true
	
	print("[LevelComplete] Scene ready")

func show_level_complete(level: int, score: int, stars: int = 3):
	"""Show the level complete screen with the given data"""
	current_level = level
	current_score = score
	stars_earned = clamp(stars, 0, 3)
	
	# Update labels
	level_label.text = "Level %03d" % level
	score_value.text = str(score)
	
	# Update stars display
	_update_stars_display()
	
	# Show the panel
	visible = true
	set_process_input(true)
	
	# Ensure next button has focus
	next_button.grab_focus()
	
	# Ensure particles are visible and start emitting
	if coin_particles:
		coin_particles.restart()
		coin_particles.emitting = true
	
	print("[LevelComplete] Showing level %d with score %d and %d stars" % [level, score, stars])

func _update_stars_display():
	"""Update the star display based on stars_earned"""
	# Fade out stars that weren't earned
	var tween = create_tween()
	tween.set_parallel(true)
	
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
	print("[LevelComplete] Remote enter pressed")
	if next_button.has_focus():
		_on_next_pressed()
	elif back_button.has_focus():
		_on_back_pressed()

func _on_remote_navigate(direction: String):
	"""Handle navigation directives from remote control"""
	print("[LevelComplete] Remote navigate: ", direction)
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
		print("[LevelComplete] Disconnected from MenuController signals")
