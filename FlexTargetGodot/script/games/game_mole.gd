extends Node2D

@onready var pop_timer: Timer = $PopTimer

const MAG_SIZE := 10
const PASS_HIT_RATE := 0.7
const MAX_BUNNY_HITS_ALLOWED := 1
const BASE_MOLE_SCORE := 10
const BUNNY_PENALTY := 10
const COMBO_BONUS_STEP := 5
const COIN_SCORE := 50
const COIN_SPAWN_CHANCE := 0.35
const COIN_HEAD_OFFSET := Vector2(0, -140)

var moles = []
var bunnies = []
var targets = []
var spawn_positions: Array[Vector2] = []
var level = 1  # For now, level 1
var score: int = 0
var level_start_score: int = 0  # Track score at the start of each level
var coins_collected: int = 0  # Track coins collected in current level
var top_bar: Node = null
var coin_scene = preload("res://scene/games/wack-a-mole/coin-animate-hole.tscn")
var current_coin: Node = null
var coin_timer: Timer = null
var remote_control: Node
var previous_emit_click_for_ui := false  # Track previous UI click injection state
var ws_listener: Node = null

var shots_fired: int = 0
var total_hits: int = 0
var bunny_hits: int = 0
var last_shot_ms: int = -1000
var last_shot_pos: Vector2 = Vector2.ZERO
var combo_streak: int = 0
var active_combo_label: Label = null

# Level timing variables
var level_duration: float = 30.0  # 30 seconds per level
var level_timer: Timer = null
var time_elapsed: float = 0.0
var level_complete: bool = false

# Mole tracking for level completion
var total_moles_appeared: int = 0  # Track how many moles have appeared
var moles_hit: int = 0  # Track how many moles have been hit
var hit_threshold: float = 0.6  # 60% threshold for level completion

# Base timing values for difficulty scaling
var base_pop_interval_min: float = 1.5  # Pop a mole every 1.5-2.5 seconds
var base_pop_interval_max: float = 2.5
var base_mole_stay_out: float = 5.0  # Each mole stays out for 5 seconds
var difficulty_multiplier: float = 1.0  # Starts at 1.0, reduces by 20% each level

func _ready() -> void:
	var viewport_size = get_viewport_rect().size
	var cols = 3
	var rows = 3
	moles = []
	bunnies = []
	targets = []
	spawn_positions = []
	for child in get_children():
		if child is Area2D and child.name.begins_with("Mole"):
			moles.append(child)
		elif child is Area2D and child.name.begins_with("Bunny"):
			bunnies.append(child)

	for target in moles:
		target.visible = false
		if target.has_method("go_in"):
			target.go_in()
	for target in bunnies:
		target.visible = false
		if target.has_method("go_in"):
			target.go_in()
	
	targets = moles.duplicate()
	targets.append_array(bunnies)
	
	var margin_left = 30	
	var margin_right = 30
	var margin_top = 150
	var margin_bottom = 150
	
	var grid_width = viewport_size.x - margin_left - margin_right
	var grid_height = viewport_size.y - margin_top - margin_bottom
	
	var cell_width = grid_width / cols
	var cell_height = grid_height / rows
	for row in range(rows):
		for col in range(cols):
			var base_x = margin_left + col * cell_width
			var base_y = margin_top + row * cell_height
			var random_offset_x = randf_range(-cell_width * 0.1, cell_width * 0.1)
			var random_offset_y = randf_range(-cell_height * 0.4, cell_height * 0.4)
			var x = base_x + cell_width * 0.5 + random_offset_x
			var y = base_y + cell_height * 0.5 + random_offset_y
			spawn_positions.append(Vector2(x, y))
	
	pop_timer.timeout.connect(_on_pop_timer_timeout)
	
	# Get top bar reference (it's a child of this scene)
	if has_node("TopBarMole"):
		top_bar = get_node("TopBarMole")
		print("Top bar found: ", top_bar.name)
		if top_bar.has_method("update_score"):
			top_bar.update_score(0)
		if top_bar.has_method("update_ammo_progress"):
			top_bar.update_ammo_progress(shots_fired, MAG_SIZE)
	else:
		print("Warning: TopBarMole not found as child of GameMole!")
	
	# Connect to all moles' hit signals
	# Scoring is handled centrally from bullet hit classification.
	
	# Track score at the start of level 1
	level_start_score = 0
	
	# Start level 1: start interval-based pop timer
	_start_pop_timer()
	
	# Enable input processing
	set_process_input(true)
	
	# Hide global status bar when playing the game
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.hide()
		print("[GameMole] Global status bar hidden")
	else:
		print("[GameMole] Global status bar not found")
	
	# Get MenuController
	remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.back_pressed.connect(_on_back_pressed)
		if remote_control.has_signal("homepage_pressed"):
			remote_control.homepage_pressed.connect(_on_homepage_pressed)
			print("[GameMole] Connected to MenuController homepage_pressed signal")
		print("[GameMole] Connected to MenuController signals")
	else:
		print("[GameMole] MenuController not found")
	
	# Disable UI click injection for game_mole (so shooting works normally)
	ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		previous_emit_click_for_ui = ws_listener.get_emit_click_for_ui()
		ws_listener.set_emit_click_for_ui(false)
		if not ws_listener.bullet_hit.is_connected(_on_bullet_fired):
			ws_listener.bullet_hit.connect(_on_bullet_fired)
		print("[GameMole] Disabled UI click injection, previous state was: ", previous_emit_click_for_ui)
	else:
		print("[GameMole] WebSocketListener not found for UI click injection")

func _start_pop_timer() -> void:
	"""Start the pop timer with interval-based mole spawning"""
	pop_timer.wait_time = randf_range(base_pop_interval_min * difficulty_multiplier, base_pop_interval_max * difficulty_multiplier)
	pop_timer.start()

func pop_next() -> void:
	"""Pop a random available target (mole or bunny)."""
	if _should_fail_due_to_mole_overload():
		_finish_level(false)
		return

	var available_targets = targets.filter(func(t): return t.has_method("is_in") and t.is_in())
	if available_targets.size() > 0:
		var target = available_targets[randi() % available_targets.size()]
		var spawn_index = _pick_free_spawn_index()
		if spawn_index == -1:
			print("[GameMole] No free spawn cell available, skipping spawn for ", target.name)
			return
		target.set_meta("spawn_grid_index", spawn_index)
		target.position = spawn_positions[spawn_index]
		var visible_time = base_mole_stay_out * difficulty_multiplier
		if target.has_method("start_appearance"):
			target.start_appearance(visible_time)
		else:
			target.go_out()
		_spawn_coin_on_target(target)
		if target in moles:
			total_moles_appeared += 1
		print("Target appeared: ", target.name, " | Moles appeared: ", total_moles_appeared, " Hit: ", moles_hit)
		if _should_fail_due_to_mole_overload():
			_finish_level(false)
			return

func _on_pop_timer_timeout() -> void:
	"""Timer ticks at fixed interval regardless of mole state"""
	pop_next()
	
	# Reschedule the next pop at the interval
	pop_timer.wait_time = randf_range(base_pop_interval_min * difficulty_multiplier, base_pop_interval_max * difficulty_multiplier)
	pop_timer.start()

func _on_coin_timer_timeout() -> void:
	"""Spawn a random coin every 5-10 seconds"""
	# Remove existing coin if any
	_clear_current_coin()
	
	# Randomly pick a mole to replace with coin
	if moles.size() > 0:
		var random_mole = moles[randi() % moles.size()]
		var coin = coin_scene.instantiate()
		coin.global_position = random_mole.global_position
		coin.coin_hit.connect(_on_coin_hit)
		add_child(coin)
		current_coin = coin
		print("Coin spawned at position: ", coin.global_position)
	
	# Restart timer
	coin_timer.wait_time = randf_range(5.0, 10.0)
	coin_timer.start()

func _on_coin_hit() -> void:
	"""Called when coin is hit"""
	score += COIN_SCORE
	coins_collected += 1  # Increment coins collected counter
	print("Coin collected! Score increased by 50 to: ", score, " | Total coins: ", coins_collected)
	
	# Create and spawn score label animation at coin position
	if current_coin:
		var score_label = preload("res://scene/games/wack-a-mole/score_label.tscn").instantiate()
		score_label.global_position = current_coin.global_position
		score_label.display_score(COIN_SCORE)
		add_child(score_label)
	
	# Clear current coin reference (it will be queue_freed by coin_hole script)
	current_coin = null
	
	# Update top bar if found
	if top_bar and top_bar.has_method("update_score"):
		top_bar.update_score(score)
	
	# Increment star count
	if top_bar and top_bar.has_method("increment_stars"):
		top_bar.increment_stars()

func _spawn_coin_on_target(target: Node) -> void:
	if current_coin and is_instance_valid(current_coin):
		return
	if randf() > COIN_SPAWN_CHANCE:
		return
	if not target or not target.visible:
		return

	var coin = coin_scene.instantiate()
	coin.global_position = target.global_position + COIN_HEAD_OFFSET
	coin.coin_hit.connect(_on_coin_hit)
	add_child(coin)
	current_coin = coin
	print("[GameMole] Coin spawned on target: ", target.name, " at ", coin.global_position)

func _clear_current_coin() -> void:
	if current_coin and is_instance_valid(current_coin):
		current_coin.queue_free()
	current_coin = null

func _on_bullet_fired(_hit_pos: Vector2, _a: int = 0, _t: int = 0) -> void:
	_register_shot(_hit_pos)

func _register_shot(hit_pos: Vector2) -> void:
	# Deduplicate events coming from multiple input paths in the same instant.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - last_shot_ms <= 60 and hit_pos.distance_to(last_shot_pos) <= 12.0:
		return
	last_shot_ms = now_ms
	last_shot_pos = hit_pos

	if level_complete:
		return
	if shots_fired >= MAG_SIZE:
		return

	shots_fired += 1
	if top_bar and top_bar.has_method("update_ammo_progress"):
		top_bar.update_ammo_progress(shots_fired, MAG_SIZE)

	var coin_hit_type = _classify_coin_hit(hit_pos)
	if coin_hit_type == "coin":
		score += COIN_SCORE
		total_hits += 1
		coins_collected += 1
		print("[GameMole] Coin hit | score=", score, " coins=", coins_collected)
		if top_bar and top_bar.has_method("update_score"):
			top_bar.update_score(score)
		if shots_fired >= MAG_SIZE:
			_finish_level(true)
		return

	var hit_type = _classify_target_hit(hit_pos)
	if hit_type == "mole":
		moles_hit += 1
		total_hits += 1
		combo_streak += 1
		var combo_bonus = max(0, combo_streak - 1) * COMBO_BONUS_STEP
		var shot_points = BASE_MOLE_SCORE + combo_bonus
		score += shot_points
		_show_combo_feedback()
		print("[GameMole] Mole hit | combo=", combo_streak, " +", shot_points, " score=", score)
	elif hit_type == "bunny":
		bunny_hits += 1
		total_hits += 1
		score -= BUNNY_PENALTY
		combo_streak = 0
		print("[GameMole] Bunny hit | bunny_hits=", bunny_hits, " score=", score)
		if bunny_hits >= 2:
			_finish_level(false)
			return
	else:
		combo_streak = 0
		print("[GameMole] Shot missed | combo reset")

	if top_bar and top_bar.has_method("update_score"):
		top_bar.update_score(score)

	if shots_fired >= MAG_SIZE:
		_finish_level(true)

func _classify_target_hit(hit_pos: Vector2) -> String:
	for target in targets:
		if not target.visible:
			continue
		if not target.has_method("is_hittable") or not target.is_hittable():
			continue
		if _point_hits_target(target, hit_pos):
			if target.name.begins_with("Mole"):
				return "mole"
			if target.name.begins_with("Bunny"):
				return "bunny"
	return ""

func _classify_coin_hit(hit_pos: Vector2) -> String:
	if not current_coin or not is_instance_valid(current_coin):
		return ""
	if not current_coin.visible:
		return ""

	var shape = current_coin.get_node_or_null("CollisionShape2D")
	if not shape or not shape.shape:
		return ""

	var local_hit_pos = current_coin.to_local(hit_pos)
	if shape.shape is CircleShape2D:
		var circle = shape.shape as CircleShape2D
		if local_hit_pos.length() <= circle.radius:
			return "coin"
	return ""

func _point_hits_target(target: Area2D, hit_pos: Vector2) -> bool:
	var shape = target.get_node_or_null("CollisionShape2D")
	if not shape or not shape.shape:
		return target.global_position.distance_to(hit_pos) <= 80.0

	var local_hit_pos = target.to_local(hit_pos)
	if shape.shape is CircleShape2D:
		var circle = shape.shape as CircleShape2D
		return local_hit_pos.length() <= circle.radius

	return target.global_position.distance_to(hit_pos) <= 80.0

func _count_visible_moles() -> int:
	var visible_moles: int = 0
	for mole in moles:
		if mole.visible:
			visible_moles += 1
	return visible_moles

func _count_visible_idle_moles() -> int:
	var visible_idle_moles: int = 0
	for mole in moles:
		if not mole.visible:
			continue
		if mole.has_method("is_idle_visible") and mole.is_idle_visible():
			visible_idle_moles += 1
	return visible_idle_moles

func _get_occupied_spawn_indices() -> Array[int]:
	var occupied: Array[int] = []
	for target in targets:
		if not target.visible:
			continue
		if not target.has_meta("spawn_grid_index"):
			continue
		var spawn_index = int(target.get_meta("spawn_grid_index"))
		if spawn_index >= 0 and spawn_index < spawn_positions.size() and not occupied.has(spawn_index):
			occupied.append(spawn_index)
	return occupied

func _pick_free_spawn_index() -> int:
	if spawn_positions.is_empty():
		return -1

	var occupied := _get_occupied_spawn_indices()
	var free_indices: Array[int] = []
	for i in range(spawn_positions.size()):
		if not occupied.has(i):
			free_indices.append(i)

	if free_indices.is_empty():
		return -1

	return free_indices[randi() % free_indices.size()]

func _should_fail_due_to_mole_overload() -> bool:
	return _count_visible_moles() >= 3 and _count_visible_idle_moles() >= 3

func _get_failure_reason_text() -> String:
	if bunny_hits >= 2:
		return tr("bunny_hit_twice")
	if _should_fail_due_to_mole_overload():
		return tr("too_many_idle_moles")
	return ""

func _check_overload_failure_after_idle() -> void:
	if not level_complete and _should_fail_due_to_mole_overload():
		_finish_level(false)

func _finish_level(passed_override: bool = true) -> void:
	"""Called when level time expires"""
	if level_complete:
		return
	
	level_complete = true
	pop_timer.stop()
	if active_combo_label and is_instance_valid(active_combo_label):
		active_combo_label.queue_free()
	active_combo_label = null
	
	# Calculate shot hit percentage
	var hit_percentage: float = 0.0
	if shots_fired > 0:
		hit_percentage = float(moles_hit) / float(shots_fired)
	
	var level_passed: bool = passed_override and hit_percentage >= PASS_HIT_RATE and bunny_hits <= MAX_BUNNY_HITS_ALLOWED
	var stars_earned: int = _calculate_stars(hit_percentage)
	
	print("Level Complete! Final Score: ", score)
	print("Mole hits: ", moles_hit, " / ", shots_fired)
	print("Bunny hits: ", bunny_hits)
	print("Hit percentage: ", hit_percentage * 100, "%")
	print("Level passed: ", level_passed, " | Stars: ", stars_earned)
	
	# Show the level complete screen
	var mole_level_complete_scene = preload("res://scene/games/wack-a-mole/mole_level_complete.tscn").instantiate()
	get_tree().root.add_child(mole_level_complete_scene)
	
	# Call show_level_complete with the stats including pass/fail status
	if mole_level_complete_scene.has_method("show_level_complete"):
		var bonus = 0
		if level_passed:
			bonus = 150  # Bonus for passing level
		var failure_reason = ""
		if not level_passed:
			failure_reason = _get_failure_reason_text()
		
		# Pass the actual coins collected (not calculated from score)
		mole_level_complete_scene.show_level_complete(level, score, coins_collected, bonus, stars_earned, level_passed, moles_hit, shots_fired, bunny_hits, failure_reason)
		print("Mole level complete scene shown with level: ", level, " total_score: ", score, " coins: ", coins_collected, " passed: ", level_passed)
	else:
		print("Warning: show_level_complete method not found on mole_level_complete_scene")

func _start_next_level() -> void:
	"""Start the next level with increased difficulty (20% faster)"""
	# Increment level
	level += 1
	
	# Apply difficulty multiplier: reduce by 20% each level
	difficulty_multiplier *= 0.8
	
	# Reset level state
	level_complete = false
	time_elapsed = 0.0
	total_moles_appeared = 0
	moles_hit = 0
	total_hits = 0
	bunny_hits = 0
	shots_fired = 0
	coins_collected = 0  # Reset coins for new level
	level_start_score = score  # Save current score as the start of this level
	_clear_current_coin()
	_reset_combo_state()
	
	# Update top bar with new level number
	if top_bar and top_bar.has_method("update_level"):
		top_bar.update_level(level)
	
	print("Starting Level ", level, " with difficulty multiplier: ", difficulty_multiplier)
	
	# Reset all targets to in position
	for target in targets:
		target.go_in()
	
	if top_bar and top_bar.has_method("update_ammo_progress"):
		top_bar.update_ammo_progress(shots_fired, MAG_SIZE)
	
	# Start popping moles with new difficulty on fixed interval
	_start_pop_timer()

func _restart_current_level() -> void:
	"""Restart the current level without incrementing level counter"""
	print("Restarting Level ", level)
	
	# Reset level state
	level_complete = false
	time_elapsed = 0.0
	total_moles_appeared = 0
	moles_hit = 0
	total_hits = 0
	bunny_hits = 0
	shots_fired = 0
	coins_collected = 0  # Reset coins for level restart
	level_start_score = score  # Save current score as the start of this level
	_clear_current_coin()
	_reset_combo_state()
	
	# Reset all targets to in position
	for target in targets:
		target.go_in()
	
	if top_bar and top_bar.has_method("update_ammo_progress"):
		top_bar.update_ammo_progress(shots_fired, MAG_SIZE)
	
	# Start popping moles with same difficulty on fixed interval
	_start_pop_timer()

func _calculate_stars(hit_percentage: float) -> int:
	"""Calculate stars earned based on hit percentage"""
	if hit_percentage >= 0.9:  # 90% or more
		return 3
	elif hit_percentage >= 0.75:  # 75% or more
		return 2
	elif hit_percentage >= PASS_HIT_RATE:  # 70% or more (passed)
		return 1
	else:  # Less than 60% (failed)
		return 0

func _reset_combo_state() -> void:
	combo_streak = 0
	if active_combo_label and is_instance_valid(active_combo_label):
		active_combo_label.queue_free()
	active_combo_label = null

func _show_combo_feedback() -> void:
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

func _input(event: InputEvent):
	if not level_complete and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_register_shot(event.position)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_BACK or event.keycode == KEY_HOME:
			_return_to_menu()

func _on_back_pressed():
	print("[GameMole] Back pressed")
	_return_to_menu()

func _on_homepage_pressed():
	print("[GameMole] Homepage pressed")
	_return_to_menu()

func _return_to_menu():
	print("[GameMole] Returning to menu scene")
	# Show global status bar when leaving the game
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.show()
		print("[GameMole] Global status bar shown")
	var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
	if error != OK:
		print("[GameMole] Failed to change scene: ", error)
	else:
		print("[GameMole] Scene change initiated")

func _exit_tree():
	# Restore UI click injection state when exiting game_mole
	ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if ws_listener.bullet_hit.is_connected(_on_bullet_fired):
			ws_listener.bullet_hit.disconnect(_on_bullet_fired)
		ws_listener.set_emit_click_for_ui(previous_emit_click_for_ui)
		print("[GameMole] Restored UI click injection to: ", previous_emit_click_for_ui)
