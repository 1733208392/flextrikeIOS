extends Node2D

enum GameState { RUNNING, PAUSED }

var current_state = GameState.RUNNING
var current_level: int = 1  # Track current level
var velocity_bonus: float = 0.0  # Velocity bonus per level (+0.5 per level)
var spawn_speed_multiplier: float = 1.0  # Spawn speed multiplier (30% faster per level)

var watermelon_whole_scene = preload("res://scene/games/watermelon.tscn")
var banana_whole_scene = preload("res://scene/games/banana.tscn")
var avocado_whole_scene = preload("res://scene/games/avocado.tscn")
var tomato_whole_scene = preload("res://scene/games/tomato.tscn")
var lemon_whole_scene = preload("res://scene/games/lemon.tscn")
var pineapple_whole_scene = preload("res://scene/games/pineapple.tscn")
var pear_whole_scene = preload("res://scene/games/pear.tscn")
var bullet_impact_scene = preload("res://scene/games/bullet_impact.tscn")
var coin_anim_scene = preload("res://scene/games/coin_anim.tscn")
var bomb_scene = preload("res://scene/games/bomb.tscn")
var coin_collection_sound = preload("res://audio/SE-Collision_08C.ogg")
var leaderboard_scene = preload("res://scene/games/leaderboard.tscn")
var spawn_timer = 0.0
var spawn_interval = 2.0  # Base spawn interval (gets divided by spawn_speed_multiplier)
var fruit_scenes = []  # Array to hold all fruit scenes
var fruits_spawned: int = 0  # Track how many fruits have been spawned
var bomb_spawn_interval: int = randi_range(5, 7)  # Spawn bomb every 5-7 fruits
var truck_node: Node2D
var truck_health: int = 100
var truck_crashed: bool = false
var game_over: bool = false
var score: int = 0
var total_score: int = 0
var score_label: Label
var level_label: Label
var progress_bar: ProgressBar
var coin_icon_position: Vector2
var fruits_in_trunk: int = 0
var truck_full: bool = false
var max_fruits_in_trunk: int = 10
var counted_fruits: Dictionary = {}  # Track fruits that have been counted to avoid duplicates
var pause_overlay: CanvasLayer
var score_target: int = 120  # Base target score for level 1 (increases 30% per level)

func _ready():
	# Mark this as the game scene for level progression
	set_meta("is_game_scene", true)
	
	# Enable input processing
	set_process_input(true)
	
	# Load language setting from GlobalData (like option.gd does)
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[Game] Loaded language from GlobalData: ", language)
	else:
		print("[Game] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
	
	# Set score target based on current level (30% increase per level, rounded to nearest 10)
	var base_target = 120 * pow(1.3, current_level - 1)
	score_target = round(base_target / 10) * 10
	
	# Initialize fruit scenes array
	fruit_scenes = [watermelon_whole_scene, banana_whole_scene, avocado_whole_scene, tomato_whole_scene, lemon_whole_scene, pineapple_whole_scene, pear_whole_scene]
	
	# Filter out any null scenes (in case preload failed)
	fruit_scenes = fruit_scenes.filter(func(scene): return scene != null)
	
	if fruit_scenes.is_empty():
		print("ERROR: No fruit scenes loaded! Check that the scene files exist at res://scene/games/")
		return

	# Get game over panel and hide it initially
	var game_over_panel = get_node("GameOverLayer/GameOverPanel")
	if game_over_panel:
		game_over_panel.hide()

	# Get score label and coin icon position
	var top_bar = get_node("StatusBar/TopBar")
	score_label = top_bar.get_node("Score")
	level_label = top_bar.get_node("Level")
	level_label.text = "Level " + str(current_level)
	progress_bar = top_bar.get_node("ProgressBar")
	progress_bar.max_value = score_target
	progress_bar.value = score
	var coin_icon = top_bar.get_node("CoinIcon")
	coin_icon_position = coin_icon.global_position
	
	# Get truck node and connect to its signals
	truck_node = get_node_or_null("Truck")
	if truck_node:
		truck_node.truck_crashed.connect(_on_truck_crashed)
		print("[Game] Connected to truck signals")
		
	else:
		print("[Game] WARNING: Truck node not found!")
	
	# Call start_game on HttpService when game starts
	HttpService.start_game(func(result, response_code, _headers, _body):
		print("Game started - Result: ", result, ", Response Code: ", response_code)
	)
	
	# Get pause overlay
	pause_overlay = get_node_or_null("PauseOverlay")
	if not pause_overlay:
		print("[Game] Warning: PauseOverlay not found!")
	else:
		pause_overlay.visible = false
		var play_button = pause_overlay.get_node("Control/PlayButton")
		if play_button:
			play_button.connect("pressed", _resume_game)
	
	# Connect to remote control directives
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		print("[Game] Connected to MenuController signals")
		remote_control.enter_pressed.connect(_on_enter_pressed)
		remote_control.back_pressed.connect(_on_remote_back_pressed)
	else:
		print("[Game] MenuController autoload not found!")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
	TranslationServer.set_locale(locale)

	# Spawn the first fruit immediately
	spawn_random_fruit()

func _process(delta):
	# Don't spawn fruits if game is over, truck is full, or game is paused
	if game_over or truck_full or current_state == GameState.PAUSED:
		return
	
	# Spawn a new fruit at intervals (faster with higher spawn_speed_multiplier)
	spawn_timer += delta
	if spawn_timer >= (spawn_interval / spawn_speed_multiplier):
		spawn_random_fruit()
		spawn_timer = 0.0

func _input(event):
	# Handle mouse click to simulate bullet hit
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		# Emit bullet_hit signal to all fruits
		if WebSocketListener:
			WebSocketListener.bullet_hit.emit(click_pos, 0, 0)
		print("Mouse click at: ", click_pos)
	
	# Handle keyboard input for pause/resume and back
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			if current_state == GameState.RUNNING:
				_pause_game()
			elif current_state == GameState.PAUSED:
				_resume_game()
		elif event.keycode == KEY_BACK or event.keycode == KEY_HOME:
			_return_to_menu()

# Collision detection now handled by truck - this function is no longer used
# func _on_count_rect_collision(body: Node2D):
# 	"""Handle collision between fruit (RigidBody2D) and count rect - award 3x score"""
# 	if body.get("is_fruit") == true:
# 		# Check if this fruit has already been counted
# 		if counted_fruits.has(body):
# 			return
# 		
# 		counted_fruits[body] = true
# 		_award_triple_score(body.global_position)
# 		_add_fruit_to_trunk(body)

func _award_triple_score(from_position: Vector2):
	"""Award 3x score with 3 coin animations"""
	var points = 30  # 3x the normal 10 points
	score += points
	total_score += points
	
	# Update the score label
	score_label.text = str(total_score)
	
	# Update progress bar
	if progress_bar:
		progress_bar.value = score
	
	# Create 3 coin animations
	for i in range(3):
		# Stagger the animations slightly
		await get_tree().create_timer(i * 0.1).timeout
		_create_coin_animation(from_position, coin_icon_position)

func _trigger_level_complete():
	"""Trigger level complete when score reaches target"""
	print("[Game] Level Complete! Score: ", score)
	game_over = true
	
	# Play truck run animation and background animation
	_play_truck_run_animation()

func _play_truck_run_animation():
	"""Play winning animation when level is complete"""
	# Queue free all floating fruits and bombs (not in trunk)
	for fruit in get_children():
		if fruit.get("is_fruit") == true or fruit.get("is_bomb") == true:
			if fruit is RigidBody2D:
				# Only queue free if not a child of truck (floating fruits/bombs)
				if fruit.get_parent() == self:
					fruit.queue_free()

	# Play truck run animation on level completion
	truck_node.run()
	
	# Play background moving animation
	var background = get_node_or_null("Background")
	if background:
		var sprite = background.get_node_or_null("Sprite2D")
		if sprite:
			var anim_player = sprite.get_node_or_null("AnimationPlayer")
			if anim_player:
				anim_player.play("moving")	# Show the new level complete screen
	var level_complete_scene = preload("res://scene/games/level_complete.tscn")
	var level_complete = level_complete_scene.instantiate()
	add_child(level_complete)
	
	# Show level complete with current level, current score, and 3 stars
	level_complete.show_level_complete(current_level, score, 3)
	
	# Freeze all dropping fruits and bombs
	for child in get_children():
		if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
			child.freeze = true
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0

func add_score(points: int, from_position: Vector2):
	"""Animate coins flying to the coin icon and add score"""
	score += points
	total_score += points
	
	# Update the score label
	score_label.text = str(total_score)
	
	# Update progress bar
	if progress_bar:
		progress_bar.value = score
	
	# Spawn animated coin that flies to the icon
	_create_coin_animation(from_position, coin_icon_position)
	
	# Check if score reaches target
	if score >= score_target and not game_over:
		_trigger_level_complete()

func update_level_display():
	"""Update the level label in the status bar"""
	if level_label:
		level_label.text = "Level " + str(current_level)
	if progress_bar:
		progress_bar.max_value = score_target
		progress_bar.value = score

func _create_coin_animation(start_pos: Vector2, end_pos: Vector2):
	"""Create an animated coin that flies from start to end position"""
	var coin = coin_anim_scene.instantiate()
	
	# Add coin to the GameOverLayer (UI space) instead of game scene (world space)
	var game_over_layer = get_node("GameOverLayer")
	game_over_layer.add_child(coin)
	
	# Convert world position to screen position for the start position
	var camera = get_node_or_null("Camera2D")
	if camera:
		# Get viewport and convert world position to screen coordinates
		var viewport = get_viewport()
		var canvas_transform = viewport.get_canvas_transform()
		var screen_start_pos = canvas_transform * start_pos
		coin.global_position = screen_start_pos
	else:
		# No camera, use position directly
		coin.global_position = start_pos
	
	# Play coin collection sound from the coin instance
	var audio_player = coin.get_node_or_null("AudioStreamPlayer2D")
	if audio_player:
		audio_player.play()
	
	# Tween animation - coins fly to the coin icon
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(coin, "global_position", end_pos, 0.6)
	tween.parallel().tween_property(coin, "scale", Vector2(0.3, 0.3), 0.6)
	tween.tween_callback(coin.queue_free)

func spawn_random_fruit():
	"""Spawn a random fruit from the array"""
	if fruit_scenes.is_empty():
		print("ERROR: fruit_scenes is empty, cannot spawn fruit")
		return
	
	# Track spawn count and spawn bomb if needed
	fruits_spawned += 1
	print("Fruit spawn count: ", fruits_spawned, " / ", bomb_spawn_interval)
	if fruits_spawned >= bomb_spawn_interval:
		spawn_bomb()
		fruits_spawned = 0
		bomb_spawn_interval = randi_range(5, 7)  # Reset to next random interval
		return  # Don't spawn fruit this time, spawn bomb instead
	
	var random_index = randi() % fruit_scenes.size()
	var fruit_scene = fruit_scenes[random_index]
	var fruit = fruit_scene.instantiate()
	add_child(fruit)
	# Position fruit at random horizontal position at the top of the screen
	var viewport_size = get_viewport_rect().size
	var random_x = randf_range(100, viewport_size.x - 100)
	fruit.global_position = Vector2(random_x, -50)
	# Give fruit downward velocity with random horizontal drift
	# Spawn from -60° to 60°, but exclude -30° to 30°
	var random_angle: float
	if randf() < 0.5:
		# Left side: -60° to -30°
		random_angle = randf_range(-PI/3, -PI/6)
	else:
		# Right side: 30° to 60°
		random_angle = randf_range(PI/6, PI/3)
	var velocity_magnitude = 50 + velocity_bonus  # Add velocity bonus per level
	fruit.linear_velocity = Vector2(sin(random_angle) * velocity_magnitude, cos(random_angle) * velocity_magnitude)
	print("Spawned new random fruit from the sky - Level: ", current_level, " Velocity Bonus: ", velocity_bonus)

func spawn_bomb():
	"""Spawn a bomb that falls from the sky"""
	print("Spawning bomb! (fruits_spawned=", fruits_spawned, ")")
	var bomb = bomb_scene.instantiate()
	add_child(bomb)
	
	# Ensure bomb is in front of background (higher z-index)
	bomb.z_index = 10
	
	# Position bomb at random horizontal position at the top of the screen
	var viewport_size = get_viewport_rect().size
	var random_x = randf_range(100, viewport_size.x - 100)
	bomb.global_position = Vector2(random_x, -50)
	print("Bomb position: ", bomb.global_position)
	
	# Bomb is now a RigidBody2D, set velocity directly
	if bomb is RigidBody2D:
		var random_angle = randf_range(-PI/4, PI/4)
		var velocity_magnitude = 50 + velocity_bonus  # Add velocity bonus per level
		bomb.linear_velocity = Vector2(sin(random_angle) * velocity_magnitude, cos(random_angle) * velocity_magnitude)
		print("Bomb velocity set: ", bomb.linear_velocity, " - Level: ", current_level, " Velocity Bonus: ", velocity_bonus)
	else:
		print("ERROR: Bomb is not a RigidBody2D!")
	
	print("Spawned bomb from the sky at z_index=10")

func _on_enter_pressed():
	# Don't handle pause/resume if level complete screen is visible
	var level_complete = get_node_or_null("LevelCompletePanel")
	if level_complete and level_complete.visible:
		return
		
	if current_state == GameState.RUNNING:
		_pause_game()
	elif current_state == GameState.PAUSED:
		_resume_game()

func _pause_game():
	if pause_overlay:
		pause_overlay.visible = true
	current_state = GameState.PAUSED
	
	# Freeze all existing fruits and bombs
	for child in get_children():
		if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
			child.freeze = true
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0
	
	print("[Game] Game paused")

func _resume_game():
	if pause_overlay:
		pause_overlay.visible = false
	current_state = GameState.RUNNING
	
	# Unfreeze all existing fruits and bombs only if game is not over
	if not game_over:
		for child in get_children():
			if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
				child.freeze = false
				# Don't restore gravity_scale here - fruits should have their original gravity
	
	print("[Game] Game resumed")

func _on_remote_back_pressed():
	"""Handle back/home directive from remote control to return to menu"""
	print("Remote back/home pressed - returning to menu...")
	_return_to_menu()

func _return_to_menu():
	print("[Game] Returning to menu scene")
	var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
	if error != OK:
		print("[Game] Failed to change scene: ", error)
	else:
		print("[Game] Scene change initiated")

func restart_level():
	"""Restart the current level with reset game state"""
	print("[Game] Restarting level %d with velocity bonus %.1f and spawn multiplier %.2f" % [current_level, velocity_bonus, spawn_speed_multiplier])
	
	# Reset game state
	score = 0
	fruits_spawned = 0
	truck_crashed = false
	game_over = false
	truck_full = false
	fruits_in_trunk = 0
	counted_fruits.clear()
	spawn_timer = 0.0
	
	# Update score label
	if score_label:
		score_label.text = str(total_score)
	
	# Update progress bar
	if progress_bar:
		progress_bar.value = score
	
	# Reset truck health
	truck_node.current_health = truck_node.max_health
	truck_node.update_health_bar()
	
	# Reset truck to idle animation
	if truck_node.animated_sprite:
		truck_node.animated_sprite.play("idle")
	
	# Reset background to idle state
	var background = get_node_or_null("Background")
	if background:
		var sprite = background.get_node_or_null("Sprite2D")
		if sprite:
			var anim_player = sprite.get_node_or_null("AnimationPlayer")
			if anim_player:
				anim_player.play("RESET")
	
	# Queue free all floating fruits and bombs
	for fruit in get_children():
		if fruit.get("is_fruit") == true or fruit.name.begins_with("Bomb"):
			if fruit is RigidBody2D and fruit.get_parent() == self:
				fruit.queue_free()
	
	# Reset game state
	current_state = GameState.RUNNING
	
	# Ensure pause overlay is hidden
	if pause_overlay:
		pause_overlay.visible = false
	
	# Spawn first fruit
	spawn_random_fruit()
	
	print("[Game] Level restarted successfully")

func _on_truck_crashed():
	"""Handle truck crashed signal - trigger game over"""
	print("[Game] Received truck_crashed signal")
	truck_crashed = true
	game_over = true
	
	# Freeze all dropping fruits and bombs
	_freeze_all_physics_bodies()
	
	# Show leaderboard
	_show_leaderboard()

func _show_leaderboard():
	"""Load and display the leaderboard"""
	var leaderboard = leaderboard_scene.instantiate()
	add_child(leaderboard)
	leaderboard.connect("leaderboard_loaded", Callable(self, "_on_leaderboard_loaded").bind(leaderboard))
	# Connect replay action from leaderboard to default restart (reload main game scene)
	if not leaderboard.is_connected("replay_pressed", Callable(self, "_on_leaderboard_replay_pressed")):
		leaderboard.connect("replay_pressed", Callable(self, "_on_leaderboard_replay_pressed"))
	leaderboard.load_leaderboard(total_score)

func _on_leaderboard_loaded(is_new: bool, leaderboard: CanvasLayer):
	"""Callback when leaderboard is loaded"""
	if not is_new:
		leaderboard.update_leaderboard_with_score(total_score)

func _on_leaderboard_replay_pressed() -> void:
	"""Default handler for leaderboard replay: reload the main game scene file"""
	print("[Game] Leaderboard requested replay - restarting level in-place")
	# Remove leaderboard overlay if present
	var lb = get_node_or_null("Leaderboard")
	if lb:
		lb.queue_free()

	# Call restart_level to reset game state without reloading the scene
	restart_level()

func _play_lightning_effect():
	"""Play a lightning bolt animation across the sky"""
	var lightning = ColorRect.new()
	lightning.name = "Lightning"
	lightning.color = Color.WHITE
	lightning.color.a = 0.0
	
	# Add to a high layer so it appears on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(lightning)
	
	# Set lightning to cover the entire screen
	var viewport_size = get_viewport_rect().size
	lightning.position = Vector2.ZERO
	lightning.size = viewport_size
	
	# Quick flash effect - blink multiple times
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	# Lightning flashes (quick blinks)
	for i in range(3):
		tween.tween_property(lightning, "color:a", 0.6, 0.05)  # Flash on
		tween.tween_property(lightning, "color:a", 0.0, 0.05)  # Flash off
		if i < 2:
			tween.tween_callback(func(): await get_tree().create_timer(0.1).timeout)
	
	# Cleanup
	tween.tween_callback(lightning.queue_free)

func _shake_camera(intensity: float = 10.0, duration: float = 0.5):
	"""Shake the camera with specified intensity and duration"""
	print("_shake_camera called! Intensity: ", intensity, ", Duration: ", duration)
	var camera = get_node_or_null("Camera2D")
	if not camera:
		print("ERROR: Camera2D not found!")
		return
	print("Camera found: ", camera)
	
	var original_offset = camera.offset
	var shake_timer = 0.0
	
	# Create a tween for smooth shake reduction over time
	while shake_timer < duration:
		var shake_amount = intensity * (1.0 - shake_timer / duration)  # Reduce shake over time
		camera.offset = original_offset + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_timer += get_process_delta_time()
		await get_tree().process_frame
	
	# Reset camera to original position
	camera.offset = original_offset
	print("Camera shake complete")

func _freeze_all_physics_bodies():
	"""Recursively freeze all RigidBody2D fruits and bombs in the scene"""
	for child in get_children():
		if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0
			child.gravity_scale = 0.0  # Disable gravity
			child.freeze = true
			print("[Game] Froze: ", child.name)
		# Also check children of the truck (fruits in trunk)
		elif child.name == "Truck":
			_freeze_truck_contents(child)

func _freeze_truck_contents(truck: Node):
	"""Recursively freeze all physics bodies inside the truck"""
	for child in truck.get_children():
		if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0
			child.gravity_scale = 0.0  # Disable gravity
			child.freeze = true
			print("[Game] Froze truck content: ", child.name)
		else:
			# Recursively check deeper children
			_freeze_truck_contents(child)

func _trigger_game_over():
	"""Set game over flag and show game over panel"""
	print("Game Over!")

	# Freeze all floating fruits immediately
	for fruit in get_children():
		if fruit.get("is_fruit") == true:
			if fruit is RigidBody2D:
				fruit.freeze = true
				fruit.linear_velocity = Vector2.ZERO
				fruit.angular_velocity = 0
	
	# Set game over flag
	game_over = true
	
	# Show leaderboard
	_show_leaderboard()
