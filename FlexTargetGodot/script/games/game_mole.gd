extends Node2D

@onready var pop_timer: Timer = $PopTimer

var moles = []
var level = 1  # For now, level 1
var score: int = 0
var level_start_score: int = 0  # Track score at the start of each level
var coins_collected: int = 0  # Track coins collected in current level
var top_bar: Node = null
var coin_scene = preload("res://scene/games/wack-a-mole/coin-animate-hole.tscn")
var current_coin: Node = null
var coin_timer: Timer = null
var remote_control: Node

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
	var rows = 4
	moles = []
	for child in get_children():
		if child is Area2D:
			moles.append(child)
	
	var margin_left = 30	
	var margin_right = 30
	var margin_top = 150
	var margin_bottom = 150
	
	var grid_width = viewport_size.x - margin_left - margin_right
	var grid_height = viewport_size.y - margin_top - margin_bottom
	
	for i in range(moles.size()):
		var row = i / cols
		var col = i % cols
		var cell_width = grid_width / cols
		var cell_height = grid_height / rows
		var base_x = margin_left + col * cell_width
		var base_y = margin_top + row * cell_height
		var random_offset_x = randf_range(-cell_width * 0.1, cell_width * 0.1)
		var random_offset_y = randf_range(-cell_height * 0.4, cell_height * 0.4)
		var x = base_x + cell_width * 0.5 + random_offset_x
		var y = base_y + cell_height * 0.5 + random_offset_y
		moles[i].position = Vector2(x, y)
	
	pop_timer.timeout.connect(_on_pop_timer_timeout)
	
	# Get top bar reference (it's a child of this scene)
	if has_node("TopBarMole"):
		top_bar = get_node("TopBarMole")
		print("Top bar found: ", top_bar.name)
		if top_bar.has_method("update_score"):
			top_bar.update_score(0)
	else:
		print("Warning: TopBarMole not found as child of GameMole!")
	
	# Start level timer (30 seconds)
	level_timer = Timer.new()
	add_child(level_timer)
	level_timer.wait_time = 0.1  # Update progress every 0.1 seconds
	level_timer.timeout.connect(_on_level_timer_timeout)
	level_timer.start()
	time_elapsed = 0.0
	
	# Connect to all moles' hit signals
	for mole in moles:
		mole.mole_hit.connect(_on_mole_hit)
	
	# Track score at the start of level 1
	level_start_score = 0
	
	# Start level 1: start interval-based pop timer
	_start_pop_timer()
	
	# Start coin spawn timer
	coin_timer = Timer.new()
	add_child(coin_timer)
	coin_timer.wait_time = randf_range(5.0, 10.0)
	coin_timer.timeout.connect(_on_coin_timer_timeout)
	coin_timer.start()
	
	# Enable input processing
	set_process_input(true)
	
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

	# Notify backend that a game session is starting via HttpService autoload (if present)
	if has_node("/root/HttpService"):
		var http_service = get_node("/root/HttpService")
		if http_service and http_service.has_method("start_game"):
			var _callback = func(_result, response_code, _headers, _body):
				print("[GameMole] HttpService.start_game response - Code: ", response_code)
			http_service.start_game(_callback)
			print("[GameMole] Called HttpService.start_game()")
		else:
			print("[GameMole] HttpService does not have start_game method")
	else:
		print("[GameMole] HttpService autoload not found")

func _start_pop_timer() -> void:
	"""Start the pop timer with interval-based mole spawning"""
	pop_timer.wait_time = randf_range(base_pop_interval_min * difficulty_multiplier, base_pop_interval_max * difficulty_multiplier)
	pop_timer.start()

func pop_next() -> void:
	"""Pop a random available mole (only if one is in)"""
	var available_moles = moles.filter(func(m): return m.is_in())
	if available_moles.size() > 0:
		var mole = available_moles[randi() % available_moles.size()]
		mole.go_out()
		total_moles_appeared += 1  # Track that a mole has appeared
		print("Mole appeared! Total appeared: ", total_moles_appeared, " Hit: ", moles_hit)
		
		# Schedule go_in after adjusted time (reduced by 20% each level)
		var go_in_wait_time = base_mole_stay_out * difficulty_multiplier
		var go_in_timer = Timer.new()
		add_child(go_in_timer)
		go_in_timer.wait_time = go_in_wait_time
		go_in_timer.one_shot = true
		go_in_timer.timeout.connect(func(): mole.go_in(); go_in_timer.queue_free())
		go_in_timer.start()

func _on_pop_timer_timeout() -> void:
	"""Timer ticks at fixed interval regardless of mole state"""
	pop_next()
	
	# Reschedule the next pop at the interval
	pop_timer.wait_time = randf_range(base_pop_interval_min * difficulty_multiplier, base_pop_interval_max * difficulty_multiplier)
	pop_timer.start()

func _on_mole_hit(hit_pos: Vector2, score_gained: int) -> void:
	"""Called when a mole is hit"""
	moles_hit += 1  # Track hit count
	score += score_gained
	print("Score increased to: ", score, " | Moles hit: ", moles_hit, " / ", total_moles_appeared)
	
	# Create and spawn score label animation
	var score_label = preload("res://scene/games/wack-a-mole/score_label.tscn").instantiate()
	score_label.global_position = hit_pos
	score_label.display_score(score_gained)
	add_child(score_label)
	
	# Update top bar if found
	if top_bar and top_bar.has_method("update_score"):
		top_bar.update_score(score)
		print("Top bar updated with score: ", score)
	else:
		print("Warning: Could not update top bar")

func _on_coin_timer_timeout() -> void:
	"""Spawn a random coin every 5-10 seconds"""
	# Remove existing coin if any
	if current_coin:
		current_coin.queue_free()
		current_coin = null
	
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
	score += 150
	coins_collected += 1  # Increment coins collected counter
	print("Coin collected! Score increased by 150 to: ", score, " | Total coins: ", coins_collected)
	
	# Create and spawn score label animation at coin position
	if current_coin:
		var score_label = preload("res://scene/games/wack-a-mole/score_label.tscn").instantiate()
		score_label.global_position = current_coin.global_position
		score_label.display_score(150)
		add_child(score_label)
	
	# Clear current coin reference (it will be queue_freed by coin_hole script)
	current_coin = null
	
	# Update top bar if found
	if top_bar and top_bar.has_method("update_score"):
		top_bar.update_score(score)
	
	# Increment star count
	if top_bar and top_bar.has_method("increment_stars"):
		top_bar.increment_stars()

func _on_level_timer_timeout() -> void:
	"""Called every 0.1 seconds to update level progress"""
	if level_complete:
		return
	
	time_elapsed += 0.1
	
	# Update progress bar in top bar
	if top_bar and top_bar.has_method("update_time_progress"):
		var progress = time_elapsed / level_duration
		top_bar.update_time_progress(progress)
	
	# Check if level is complete (30 seconds elapsed)
	if time_elapsed >= level_duration:
		_end_level()

func _end_level() -> void:
	"""Called when level time expires"""
	if level_complete:
		return
	
	level_complete = true
	level_timer.stop()
	pop_timer.stop()
	if coin_timer:
		coin_timer.stop()
	
	# Calculate hit percentage
	var hit_percentage: float = 0.0
	if total_moles_appeared > 0:
		hit_percentage = float(moles_hit) / float(total_moles_appeared)
	
	var level_passed: bool = hit_percentage >= hit_threshold
	var stars_earned: int = _calculate_stars(hit_percentage)
	
	print("Level Complete! Final Score: ", score)
	print("Moles hit: ", moles_hit, " / ", total_moles_appeared)
	print("Hit percentage: ", hit_percentage * 100, "%")
	print("Level passed: ", level_passed, " | Stars: ", stars_earned)
	
	# Show the level complete screen
	var mole_level_complete_scene = preload("res://scene/games/wack-a-mole/mole_level_complete.tscn").instantiate()
	get_tree().root.add_child(mole_level_complete_scene)
	
	# Call show_level_complete with the stats including pass/fail status
	if mole_level_complete_scene.has_method("show_level_complete"):
		# Calculate score earned in THIS level (not cumulative)
		var level_score = score - level_start_score
		var bonus = 0
		if level_passed:
			bonus = 150  # Bonus for passing level
		
		# Pass the actual coins collected (not calculated from score)
		mole_level_complete_scene.show_level_complete(level, level_score, coins_collected, bonus, stars_earned, level_passed)
		print("Mole level complete scene shown with level: ", level, " level_score: ", level_score, " coins: ", coins_collected, " passed: ", level_passed)
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
	coins_collected = 0  # Reset coins for new level
	level_start_score = score  # Save current score as the start of this level
	
	# Update top bar with new level number
	if top_bar and top_bar.has_method("update_level"):
		top_bar.update_level(level)
	
	print("Starting Level ", level, " with difficulty multiplier: ", difficulty_multiplier)
	
	# Reset all moles to in position
	for mole in moles:
		mole.go_in()
	
	# Restart level timer
	level_timer.start()
	time_elapsed = 0.0
	
	# Restart coin timer
	if coin_timer:
		coin_timer.wait_time = randf_range(5.0, 10.0)
		coin_timer.start()
	
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
	coins_collected = 0  # Reset coins for level restart
	level_start_score = score  # Save current score as the start of this level
	
	# Reset all moles to in position
	for mole in moles:
		mole.go_in()
	
	# Restart level timer
	level_timer.start()
	time_elapsed = 0.0
	
	# Restart coin timer
	if coin_timer:
		coin_timer.wait_time = randf_range(5.0, 10.0)
		coin_timer.start()
	
	# Start popping moles with same difficulty on fixed interval
	_start_pop_timer()

func _calculate_stars(hit_percentage: float) -> int:
	"""Calculate stars earned based on hit percentage"""
	if hit_percentage >= 0.9:  # 90% or more
		return 3
	elif hit_percentage >= 0.75:  # 75% or more
		return 2
	elif hit_percentage >= hit_threshold:  # 60% or more (passed)
		return 1
	else:  # Less than 60% (failed)
		return 0

func _input(event):
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
	var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
	if error != OK:
		print("[GameMole] Failed to change scene: ", error)
	else:
		print("[GameMole] Scene change initiated")
