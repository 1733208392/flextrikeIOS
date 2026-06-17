extends Node2D

enum GameState { SETTINGS, COUNTDOWN, RUNNING, PAUSED, GAME_OVER }

var current_state = GameState.RUNNING
var current_level: int = 1  # Track current level
var velocity_bonus: float = 0.0  # Velocity bonus per level (+0.5 per level)
var spawn_speed_multiplier: float = 1.0  # Spawn speed multiplier (30% faster per level)
const MAG_SIZE := 10
const PASS_SCORE_THRESHOLD := 70
const PASS_ACCURACY_THRESHOLD := 0.7
const BASE_HIT_SCORE := 10
const COMBO_BONUS_STEP := 5
const LEVEL_FALL_SPEED_MULTIPLIER := 1.15

var watermelon_whole_scene = preload("res://scene/games/watermelon.tscn")
var banana_whole_scene = preload("res://scene/games/banana.tscn")
var avocado_whole_scene = preload("res://scene/games/avocado.tscn")
var tomato_whole_scene = preload("res://scene/games/tomato.tscn")
var lemon_whole_scene = preload("res://scene/games/lemon.tscn")
var pineapple_whole_scene = preload("res://scene/games/pineapple.tscn")
var pear_whole_scene = preload("res://scene/games/pear.tscn")
var bullet_impact_scene = preload("res://scene/games/bullet_impact.tscn")
var bomb_scene = preload("res://scene/games/bomb.tscn")
var level_complete_scene = preload("res://scene/games/level_complete.tscn")
var http_service: Node
var spawn_timer = 0.0
var spawn_interval = 2.0  # Base spawn interval (gets divided by spawn_speed_multiplier)
var fruit_scenes = []  # Array to hold all fruit scenes
var fruits_spawned: int = 0  # Track how many fruits have been spawned
var bomb_spawn_interval: int = randi_range(5, 7)  # Spawn bomb every 5-7 fruits
const MAX_FALLING_OBJECTS = 10
var truck_node: Node2D
var truck_crashed: bool = false
var game_over: bool = false
var level_resolved: bool = false
var level_label: Label
var top_score_label: Label
var ammo_icons: Array[TextureRect] = []
var ui_score: int = 0
var score: int = 0  # Compatibility with level_complete.gd
var score_target: int = PASS_SCORE_THRESHOLD  # Compatibility with level_complete.gd
var shots_fired: int = 0
var shots_hit: int = 0
var shots_missed: int = 0
var combo_streak: int = 0
var ws_listener: Node = null
var previous_emit_click_for_ui := false
var active_combo_label: Label = null

func _ready():
	# Mark this as the game scene for level progression
	set_meta("is_game_scene", true)
	
	# Enable input processing
	set_process_input(true)
	
	ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		previous_emit_click_for_ui = ws_listener.get_emit_click_for_ui()
		ws_listener.set_emit_click_for_ui(false)
		ws_listener.bullet_hit.connect(_on_bullet_fired)
		print("[Game] Disabled UI click injection for fruitninja, previous state was: ", previous_emit_click_for_ui)
	else:
		print("[Game] WARNING: WebSocketListener not found, shot tracking disabled")
	
	# Get http service for leaderboard
	http_service = get_node("/root/HttpService")
	
	# Hide the global status bar for fruit ninja game
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.visible = false
	
	# Load language setting from GlobalData (like option.gd does)
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[Game] Loaded language from GlobalData: ", language)
	else:
		print("[Game] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
	
	# Initialize fruit scenes array
	fruit_scenes = [watermelon_whole_scene, banana_whole_scene, avocado_whole_scene, tomato_whole_scene, lemon_whole_scene, pineapple_whole_scene, pear_whole_scene]
	
	# Filter out any null scenes (in case preload failed)
	fruit_scenes = fruit_scenes.filter(func(scene): return scene != null)
	
	if fruit_scenes.is_empty():
		print("ERROR: No fruit scenes loaded! Check that the scene files exist at res://scene/games/")
		return

	# Initialize top status bar references and defaults
	_init_top_bar_ui()
	
	# Get truck node and connect to its signals
	truck_node = get_node_or_null("Truck")
	if truck_node:
		truck_node.truck_crashed.connect(_on_truck_crashed)
		print("[Game] Connected to truck signals")
		_sync_top_bar_ui()
		
	else:
		print("[Game] WARNING: Truck node not found!")
	
	# Connect to remote control directives
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		print("[Game] Connected to MenuController signals")
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
	# Don't spawn fruits if game is over
	if game_over:
		_sync_top_bar_ui()
		return
	
	_sync_top_bar_ui()

	# Spawn a new fruit at intervals, faster on higher levels.
	spawn_timer += delta
	if spawn_timer >= (spawn_interval / max(spawn_speed_multiplier, 0.001)):
		spawn_random_fruit()
		spawn_timer = 0.0

func _init_top_bar_ui():
	var top_bar = get_node_or_null("StatusBar/TopBar")
	if not top_bar:
		print("[Game] WARNING: StatusBar/TopBar not found")
		return

	level_label = top_bar.get_node_or_null("Level")
	top_score_label = top_bar.get_node_or_null("Score")
	ammo_icons.clear()
	for i in range(1, MAG_SIZE + 1):
		var ammo_icon = top_bar.get_node_or_null("AmmoContainer/Bullet%d" % i)
		if ammo_icon and ammo_icon is TextureRect:
			ammo_icons.append(ammo_icon)

	if level_label:
		level_label.text = "LEVEL " + str(current_level)
	if top_score_label:
		top_score_label.text = str(ui_score)
	_update_ammo_display()

func _sync_top_bar_ui():
	if top_score_label:
		top_score_label.text = str(ui_score)

	_update_ammo_display()

func _update_ammo_display():
	for i in range(ammo_icons.size()):
		var ammo_icon = ammo_icons[i]
		if ammo_icon:
			ammo_icon.visible = i < max(0, MAG_SIZE - shots_fired)

func _on_bullet_fired(hit_pos: Vector2, _a: int = 0, _t: int = 0):
	if game_over or level_resolved or truck_crashed:
		return
	if shots_fired >= MAG_SIZE:
		return

	shots_fired += 1
	var hit_type = _classify_hit_type(hit_pos)
	if hit_type != "":
		shots_hit += 1
		combo_streak += 1
		var combo_bonus = max(0, combo_streak - 1) * COMBO_BONUS_STEP
		var shot_points = BASE_HIT_SCORE + combo_bonus
		ui_score += shot_points
		score = ui_score
		_show_combo_feedback()
		print("[Game] Shot hit ", hit_type, " | combo=", combo_streak, " +", shot_points, " score=", ui_score)
	else:
		shots_missed += 1
		combo_streak = 0
		print("[Game] Shot missed | fired=", shots_fired, " miss=", shots_missed)

	_sync_top_bar_ui()

	if shots_fired >= MAG_SIZE:
		_finish_magazine_round()

func _classify_hit_type(hit_pos: Vector2) -> String:
	# Prefer bomb classification if overlapping with fruit at the same point.
	for child in get_children():
		if not (child is RigidBody2D) or child.get_parent() != self:
			continue
		if child.is_queued_for_deletion():
			continue
		if (child.get("is_bomb") == true or child.name.begins_with("Bomb")) and _point_hits_body(child, hit_pos):
			return "bomb"

	for child in get_children():
		if not (child is RigidBody2D) or child.get_parent() != self:
			continue
		if child.is_queued_for_deletion():
			continue
		if child.get("is_fruit") == true and _point_hits_body(child, hit_pos):
			return "fruit"

	return ""

func _point_hits_body(body: RigidBody2D, hit_pos: Vector2) -> bool:
	var shape_node: CollisionShape2D = null
	for child in body.get_children():
		if child is CollisionShape2D:
			shape_node = child
			break

	if not shape_node or not shape_node.shape:
		# Fallback when no collision shape is found.
		return body.global_position.distance_to(hit_pos) <= 60.0

	var local_hit_pos = body.to_local(hit_pos)
	var shape = shape_node.shape

	if shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		var half_height = capsule.height / 2.0
		var clamped_y = clamp(local_hit_pos.y, -half_height + capsule.radius, half_height - capsule.radius)
		var axis_point = Vector2(0, clamped_y)
		return local_hit_pos.distance_to(axis_point) <= capsule.radius
	elif shape is CircleShape2D:
		var circle = shape as CircleShape2D
		return local_hit_pos.length() <= circle.radius
	elif shape is RectangleShape2D:
		var rect = shape as RectangleShape2D
		var half_size = rect.size / 2.0
		return abs(local_hit_pos.x) <= half_size.x and abs(local_hit_pos.y) <= half_size.y

	# Generic fallback for unsupported shapes.
	return body.global_position.distance_to(hit_pos) <= 60.0

func _finish_magazine_round():
	if level_resolved:
		return

	level_resolved = true
	game_over = true
	_freeze_all_physics_bodies()

	var accuracy = float(shots_hit) / float(max(1, shots_fired))
	var passed = accuracy >= PASS_ACCURACY_THRESHOLD and not truck_crashed

	print("[Game] Magazine complete | score=", ui_score, " accuracy=", accuracy, " truck_crashed=", truck_crashed, " passed=", passed)

	var level_complete = level_complete_scene.instantiate()
	add_child(level_complete)
	level_complete.show_level_complete(current_level, ui_score, passed, accuracy, shots_hit, shots_fired)

func _show_combo_feedback():
	if combo_streak < 2:
		return

	if active_combo_label and is_instance_valid(active_combo_label):
		active_combo_label.queue_free()

	active_combo_label = Label.new()
	active_combo_label.text = "X%d" % combo_streak
	active_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active_combo_label.add_theme_font_size_override("font_size", 54)
	active_combo_label.add_theme_color_override("font_outline_color", Color(0.55, 0.05, 0.05, 1.0))
	active_combo_label.add_theme_constant_override("outline_size", 8)
	active_combo_label.modulate = Color(1.0, 0.95, 0.25, 1.0)
	active_combo_label.position = Vector2(280, 130)
	active_combo_label.size = Vector2(120, 80)
	active_combo_label.z_index = 100
	active_combo_label.scale = Vector2(0.6, 0.6)
	add_child(active_combo_label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(active_combo_label, "position:y", 58.0, 0.55)
	tween.tween_property(active_combo_label, "modulate", Color(1.0, 0.25, 0.15, 0.0), 0.55)
	tween.tween_property(active_combo_label, "scale", Vector2(1.75, 1.75), 0.18)
	tween.chain().tween_property(active_combo_label, "scale", Vector2(1.2, 1.2), 0.18)
	tween.finished.connect(func():
		if active_combo_label and is_instance_valid(active_combo_label):
			active_combo_label.queue_free()
		active_combo_label = null
	)

func _input(event):
	# Handle mouse click to simulate bullet hit
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		# Emit bullet_hit signal to all fruits
		if WebSocketListener:
			WebSocketListener.bullet_hit.emit(click_pos, 0, 0)
		print("Mouse click at: ", click_pos)
	
	# Handle keyboard input for back
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACK or event.keycode == KEY_HOME:
			_return_to_menu()

func _trigger_level_complete():
	"""Trigger level complete when truck survives"""
	print("[Game] Level Complete!")
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
				anim_player.play("moving")
	
	# Show the new level complete screen
	var level_complete = level_complete_scene.instantiate()
	add_child(level_complete)
	
	# Show level complete with current level and passed=true
	level_complete.show_level_complete(current_level, ui_score, true, float(shots_hit) / float(max(1, shots_fired)), shots_hit, shots_fired)
	
	# Freeze all dropping fruits and bombs
	for child in get_children():
		if child is RigidBody2D and (child.get("is_fruit") == true or child.name.begins_with("Bomb")):
			child.freeze = true
			child.linear_velocity = Vector2.ZERO
			child.angular_velocity = 0.0

func update_level_display():
	"""Update the level label in the status bar"""
	if level_label:
		level_label.text = "Level " + str(current_level)

func spawn_random_fruit():
	"""Spawn a random fruit from the array"""
	if fruit_scenes.is_empty():
		print("ERROR: fruit_scenes is empty, cannot spawn fruit")
		return

	if _count_active_falling_objects() >= MAX_FALLING_OBJECTS:
		print("[Game] Falling object limit reached (", MAX_FALLING_OBJECTS, "), skipping fruit spawn")
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
	var velocity_magnitude = 50.0 * pow(LEVEL_FALL_SPEED_MULTIPLIER, current_level - 1)
	fruit.linear_velocity = Vector2(sin(random_angle) * velocity_magnitude, cos(random_angle) * velocity_magnitude)
	print("Spawned new random fruit from the sky - Level: ", current_level, " Fall speed: ", velocity_magnitude)

func spawn_bomb():
	"""Spawn a bomb that falls from the sky"""
	if _count_active_falling_objects() >= MAX_FALLING_OBJECTS:
		print("[Game] Falling object limit reached (", MAX_FALLING_OBJECTS, "), skipping bomb spawn")
		return

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
		var velocity_magnitude = 50.0 * pow(LEVEL_FALL_SPEED_MULTIPLIER, current_level - 1)
		bomb.linear_velocity = Vector2(sin(random_angle) * velocity_magnitude, cos(random_angle) * velocity_magnitude)
		print("Bomb velocity set: ", bomb.linear_velocity, " - Level: ", current_level, " Fall speed: ", velocity_magnitude)
	else:
		print("ERROR: Bomb is not a RigidBody2D!")
	
	print("Spawned bomb from the sky at z_index=10")

func _count_active_falling_objects() -> int:
	"""Count the fruit and bomb instances currently falling in this scene"""
	var active_objects = 0
	for child in get_children():
		if child is RigidBody2D and child.get_parent() == self:
			if child.get("is_fruit") == true or child.get("is_bomb") == true or child.name.begins_with("Bomb"):
				active_objects += 1
	return active_objects


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
	fruits_spawned = 0
	truck_crashed = false
	game_over = false
	level_resolved = false
	spawn_timer = 0.0
	shots_fired = 0
	shots_hit = 0
	shots_missed = 0
	combo_streak = 0
	if active_combo_label and is_instance_valid(active_combo_label):
		active_combo_label.queue_free()
	active_combo_label = null
	
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
	
	# Spawn first fruit
	spawn_random_fruit()
	_sync_top_bar_ui()
	
	print("[Game] Level restarted successfully")

func _on_truck_crashed():
	"""Handle truck crashed signal - trigger game over with failed level complete screen"""
	if level_resolved:
		return

	print("[Game] Received truck_crashed signal")
	level_resolved = true
	truck_crashed = true
	game_over = true
	
	# Freeze all dropping fruits and bombs
	_freeze_all_physics_bodies()
	
	# Show level complete screen with failure
	var level_complete = level_complete_scene.instantiate()
	add_child(level_complete)
	level_complete.show_level_complete(current_level, ui_score, false, float(shots_hit) / float(max(1, shots_fired)), shots_hit, shots_fired)



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
	"""Set game over flag and show level complete screen with failure"""
	if level_resolved:
		return

	print("Game Over!")

	# Freeze all floating fruits immediately
	for fruit in get_children():
		if fruit.get("is_fruit") == true:
			if fruit is RigidBody2D:
				fruit.freeze = true
				fruit.linear_velocity = Vector2.ZERO
				fruit.angular_velocity = 0
	
	# Set game over flag
	level_resolved = true
	game_over = true
	
	# Show level complete screen with failure
	var level_complete = level_complete_scene.instantiate()
	add_child(level_complete)
	level_complete.show_level_complete(current_level, ui_score, false, float(shots_hit) / float(max(1, shots_fired)), shots_hit, shots_fired)

func _exit_tree():
	# Show the global status bar back when leaving the game
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.visible = true

	if ws_listener and ws_listener.bullet_hit.is_connected(_on_bullet_fired):
		ws_listener.bullet_hit.disconnect(_on_bullet_fired)
	if ws_listener:
		ws_listener.set_emit_click_for_ui(previous_emit_click_for_ui)
