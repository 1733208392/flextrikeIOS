extends Control

# Preload the scenes for the drill sequence
@export var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@export var ipsc_mini_black_1_scene: PackedScene = preload("res://scene/ipsc_mini_black_1.tscn")
@export var ipsc_mini_black_2_scene: PackedScene = preload("res://scene/ipsc_mini_black_2.tscn")
@export var hostage_scene: PackedScene = preload("res://scene/targets/hostage.tscn")
@export var two_poppers_scene: PackedScene = preload("res://scene/targets/2poppers_simple.tscn")
@export var three_paddles_scene: PackedScene = preload("res://scene/targets/3paddles_simple.tscn")
@export var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")
@export var footsteps_scene: PackedScene = preload("res://scene/footsteps.tscn")

# Drill sequence and progress tracking
#var base_target_sequence: Array[String] = ["ipsc_mini","ipsc_mini_black_1", "ipsc_mini_black_2", "hostage", "2poppers", "3paddles", "ipsc_mini_rotate"]
var base_target_sequence: Array[String] = ["ipsc_mini_rotate"]

var target_sequence: Array[String] = []  # This will hold the actual sequence (potentially randomized)
var current_target_index: int = 0
var current_target_instance: Node = null
var footsteps_instance: Node = null  # Reference to the footsteps transition scene
var total_drill_score: int = 0
var drill_completed: bool = false
var bullets_allowed: bool = false  # Track if bullet spawning is allowed
var rotating_target_hits: int = 0  # Track hits on the rotating target

# Randomization settings
# When enabled, target sequence will be randomized at the start of each drill
# This adds unpredictability while maintaining the same target types and counts
@export var randomize_sequence: bool = true  # Enable/disable sequence randomization

# Elapsed time tracking
var elapsed_seconds: float = 0.0
var drill_start_time: float = 0.0

# Timeout functionality
var timeout_timer: Timer = null
var timeout_seconds: float = 40.0
var drill_timed_out: bool = false
var timeout_beep_player: AudioStreamPlayer = null
var last_beep_second: int = -1  # Track last second we beeped

# Node references
@onready var center_container = $CenterContainer
@onready var drill_timer = $DrillUI/DrillTimer
@onready var footsteps_node = $Footsteps

# Performance tracking
signal target_hit(target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float)
signal drills_finished

# Performance optimization
const DEBUG_DISABLED = true  # Set to false for production release

# UI update signals
signal ui_timer_update(elapsed_seconds: float)
signal ui_target_title_update(target_index: int, total_targets: int)
signal ui_fastest_time_update(fastest_time: float)
signal ui_show_completion(final_time: float, fastest_time: float, final_score: int)
signal ui_show_completion_with_timeout(final_time: float, fastest_time: float, final_score: int, timed_out: bool, show_hit_factor: bool)
signal ui_hide_completion()
signal ui_show_shot_timer()
signal ui_hide_shot_timer()
signal ui_score_update(score: int)
signal ui_progress_update(targets_completed: int)
signal ui_timeout_warning(remaining_seconds: float)

@onready var performance_tracker = preload("res://script/performance_tracker.gd").new()

func _ready():
	"""Initialize the drill with the first target"""
	# Set initial randomization based on current drill sequence setting
	var current_sequence = "Fixed"  # Default
	
	# Fallback: Try to load from GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("drill_sequence"):
		current_sequence = global_data.settings_dict.get("drill_sequence", "Fixed")
		if not DEBUG_DISABLED:
			print("[Drills] Loaded drill sequence from GlobalData: ", current_sequence)
			print("[Drills] Full GlobalData.settings_dict: ", global_data.settings_dict)
	else:
		if not DEBUG_DISABLED:
			print("[Drills] No drill sequence setting found, using default Fixed")
			if global_data:
				print("[Drills] GlobalData exists but no drill_sequence key. Available keys: ", global_data.settings_dict.keys())
			else:
				print("[Drills] GlobalData is null")
	
	randomize_sequence = (current_sequence == "Random")
	if not DEBUG_DISABLED:
		print("[Drills] Initial randomization setting: ", randomize_sequence, " (from sequence: ", current_sequence, ")")
	
	# Initialize the target sequence (randomized or not)
	initialize_target_sequence()
	
	if not DEBUG_DISABLED:
		print("=== STARTING DRILL ===")
	emit_signal("ui_progress_update", 0)  # Initialize progress bar
	
	# Clear any existing targets in the center container
	clear_current_target()
	
	# Ensure the center container doesn't block mouse input
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect shot timer signals via DrillUI
	var drill_ui = $DrillUI
	if drill_ui:
		var shot_timer_overlay = drill_ui.get_node("ShotTimerOverlay")
		if shot_timer_overlay:
			shot_timer_overlay.timer_ready.connect(_on_shot_timer_ready)
			shot_timer_overlay.timer_reset.connect(_on_shot_timer_reset)
	
	# Connect drill timer signal
	drill_timer.timeout.connect(_on_drill_timer_timeout)
	
	# Create and setup timeout timer
	timeout_timer = Timer.new()
	timeout_timer.wait_time = timeout_seconds
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout_timer_timeout)
	add_child(timeout_timer)
	
	# Create and setup timeout beep audio player
	timeout_beep_player = AudioStreamPlayer.new()
	timeout_beep_player.stream = preload("res://audio/synthetic-shot-timer.wav")
	timeout_beep_player.volume_db = 0.0
	add_child(timeout_beep_player)
	
	# Instantiate and add performance tracker
	add_child(performance_tracker)
	target_hit.connect(performance_tracker._on_target_hit)
	drills_finished.connect(performance_tracker._on_drills_finished)
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[Drills] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Drills] WebSocketListener singleton not found!")
	
	# Hide status bar for drills
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = false
		if not DEBUG_DISABLED:
			print("[Drills] Hidden status bar: ", status_bar.name)
	
	# Show shot timer overlay before starting drill
	show_shot_timer()

func show_shot_timer():
	"""Show the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== SHOWING SHOT TIMER OVERLAY ===")
	emit_signal("ui_show_shot_timer")
	
	# Disable bullet spawning during shot timer
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# No target should be visible during shot timer phase
	clear_current_target()

func hide_shot_timer():
	"""Hide the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== HIDING SHOT TIMER OVERLAY ===")
	emit_signal("ui_hide_shot_timer")

func set_target_drill_active(target: Node, active: bool):
	"""Set the drill_active flag on a target"""
	if target and target.has_method("set"):
		target.set("drill_active", active)
		if not DEBUG_DISABLED:
			print("Set drill_active to ", active, " on target: ", target.name)
	else:
		if not DEBUG_DISABLED:
			print("WARNING: Could not set drill_active on target - has_method('set') returned false")

func _on_shot_timer_ready(delay: float):
	"""Handle when shot timer beep occurs - start the drill"""
	if not DEBUG_DISABLED:
		print("=== SHOT TIMER READY - STARTING DRILL === Delay: ", delay, " seconds")
	
	# Pass the delay to performance tracker
	performance_tracker.set_shot_timer_delay(delay)
	
	# Wait for the beep to finish and "Ready" text to disappear
	await get_tree().create_timer(0.5).timeout
	# Start the drill timer
	start_drill_timer()
	# Now spawn the first target directly (no footsteps at the beginning)
	await spawn_next_target()
	# Hide the shot timer overlay after target is spawned
	hide_shot_timer()
	# Activate drill on the spawned target
	if current_target_instance:
		set_target_drill_active(current_target_instance, true)

func _on_shot_timer_reset():
	"""Handle when shot timer is reset"""
	if not DEBUG_DISABLED:
		print("=== SHOT TIMER RESET ===")
	# Could add additional logic here if needed

func _on_drill_timer_timeout():
	"""Handle drill timer timeout - update elapsed time display"""
	elapsed_seconds += 0.1
	emit_signal("ui_timer_update", elapsed_seconds)
	
	# Check for timeout warning (5 seconds left)
	var remaining_time = timeout_seconds - elapsed_seconds
	if remaining_time <= 5.0 and remaining_time > 0.0:
		emit_signal("ui_timeout_warning", remaining_time)
		
		# Play beep for each remaining second during countdown
		var current_second = int(ceil(remaining_time))
		if current_second != last_beep_second and current_second <= 5:
			last_beep_second = current_second
			if timeout_beep_player:
				timeout_beep_player.play()
				if not DEBUG_DISABLED:
					print("=== TIMEOUT BEEP - %d seconds remaining ===" % current_second)

func start_drill_timer():
	"""Start the drill elapsed time timer"""
	elapsed_seconds = 0.0
	drill_start_time = Time.get_unix_time_from_system()
	drill_timed_out = false
	last_beep_second = -1  # Reset beep tracking
	emit_signal("ui_timer_update", elapsed_seconds)
	drill_timer.start()
	
	# Start the timeout timer
	timeout_timer.start()
	
	# Reset performance tracker timing for accurate first shot measurement
	performance_tracker.reset_shot_timer()
	
	# Reset fastest time for the new drill
	performance_tracker.reset_fastest_time()
	emit_signal("ui_fastest_time_update", 999.0)  # Reset to show "--"
	
	if not DEBUG_DISABLED:
		print("=== DRILL TIMER STARTED ===")
		print("=== TIMEOUT TIMER STARTED (40 seconds) ===")

func _on_timeout_timer_timeout():
	"""Handle timeout when 30 seconds have elapsed"""
	if not DEBUG_DISABLED:
		print("=== DRILL TIMEOUT! ===")
	drill_timed_out = true
	complete_drill_with_timeout()

func randomize_target_sequence():
	"""Randomize the target sequence using Fisher-Yates shuffle algorithm"""
	# Start with a copy of the base sequence
	target_sequence = base_target_sequence.duplicate()
	
	# Fisher-Yates shuffle for true randomness
	for i in range(target_sequence.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = target_sequence[i]
		target_sequence[i] = target_sequence[j]
		target_sequence[j] = temp
	
	if not DEBUG_DISABLED:
		print("=== TARGET SEQUENCE RANDOMIZED ===")
		print("Original: ", base_target_sequence)
		print("Randomized: ", target_sequence)

func toggle_randomization():
	"""Toggle sequence randomization on/off"""
	randomize_sequence = !randomize_sequence
	# Re-initialize sequence with new setting
	initialize_target_sequence()
	
	if not DEBUG_DISABLED:
		print("=== RANDOMIZATION TOGGLED ===")
		print("Randomization now: ", "ENABLED" if randomize_sequence else "DISABLED")
		print("Current sequence: ", target_sequence)

func set_randomization(enabled: bool):
	"""Set randomization state and reinitialize sequence"""
	randomize_sequence = enabled
	initialize_target_sequence()
	
	if not DEBUG_DISABLED:
		print("=== RANDOMIZATION SET TO: ", "ENABLED" if enabled else "DISABLED", " ===")
		print("Current sequence: ", target_sequence)

func initialize_target_sequence():
	"""Initialize the target sequence based on randomization setting"""
	if randomize_sequence:
		randomize_target_sequence()
	else:
		# Use fixed sequence
		target_sequence = base_target_sequence.duplicate()
		if not DEBUG_DISABLED:
			print("=== TARGET SEQUENCE INITIALIZED (FIXED) ===")
			print("Sequence: ", target_sequence)

func find_option_node(node: Node) -> Node:
	"""Recursively search for an option node in the scene tree"""
	if node.name == "Option" or node.get_script() and str(node.get_script()).contains("option.gd"):
		return node
	
	for child in node.get_children():
		var result = find_option_node(child)
		if result:
			return result
	
	return null

func stop_drill_timer():
	"""Stop the drill elapsed time timer"""
	drill_timer.stop()
	timeout_timer.stop()
	if not DEBUG_DISABLED:
		print("=== DRILL TIMER STOPPED ===")
		print("=== TIMEOUT TIMER STOPPED ===")

func _process(_delta):
	"""Main process loop - UI updates are handled by drill_ui.gd"""
	pass

func update_target_title():
	"""Update the target title based on the current target number"""
	emit_signal("ui_target_title_update", current_target_index, target_sequence.size())
	if not DEBUG_DISABLED:
		print("Updated title to: Target ", current_target_index + 1, "/", target_sequence.size())

func spawn_next_target():
	"""Spawn the next target in the sequence"""
	if current_target_index >= target_sequence.size():
		complete_drill()
		return
	
	var target_type = target_sequence[current_target_index]
	if not DEBUG_DISABLED:
		print("=== SPAWNING TARGET: ", target_type, " (", current_target_index + 1, "/", target_sequence.size(), ") ===")
	
	# Clear any existing target
	clear_current_target()
	
	# Hide footsteps when target appears
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation when hiding
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
	
	# Create the new target based on type
	match target_type:
		"ipsc_mini":
			spawn_ipsc_mini()
		"ipsc_mini_black_1":
			spawn_ipsc_mini_black_1()
		"ipsc_mini_black_2":
			spawn_ipsc_mini_black_2()
		"hostage":
			await spawn_hostage()
		"2poppers":
			spawn_2poppers_simple()
		"3paddles":
			spawn_3paddles()
		"ipsc_mini_rotate":
			await spawn_ipsc_mini_rotate()
		_:
			if not DEBUG_DISABLED:
				print("ERROR: Unknown target type: ", target_type)
			return
	
	# Update the title
	update_target_title()
	
	# Connect signals for the new target
	connect_target_signals()
	
	# Activate drill on the spawned target
	if current_target_instance:
		set_target_drill_active(current_target_instance, true)
	
	# Re-enable bullet spawning after target is fully ready
	await get_tree().process_frame  # Ensure target is fully initialized
	bullets_allowed = true
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
	if not DEBUG_DISABLED:
		print("Bullet spawning re-enabled for new target: ", target_type)

func clear_current_target():
	"""Remove the current target from the scene"""
	# Deactivate the current target before clearing it
	if current_target_instance:
		set_target_drill_active(current_target_instance, false)
	
	for child in center_container.get_children():
		center_container.remove_child(child)
		child.queue_free()
	
	current_target_instance = null

func spawn_ipsc_mini():
	"""Spawn an IPSC mini target"""
	var target = ipsc_mini_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("IPSC Mini target spawned")

func spawn_ipsc_mini_black_1():
	"""Spawn an IPSC mini black 1 target"""
	var target = ipsc_mini_black_1_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("IPSC Mini Black 1 target spawned")

func spawn_ipsc_mini_black_2():
	"""Spawn an IPSC mini black 2 target"""
	var target = ipsc_mini_black_2_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("IPSC Mini Black 2 target spawned")

func spawn_hostage():
	"""Spawn a hostage target"""
	if not DEBUG_DISABLED:
		print("=== SPAWNING HOSTAGE TARGET ===")
	var target = hostage_scene.instantiate()
	center_container.add_child(target)
	
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("Hostage target spawned successfully")
		print("Hostage target has target_hit signal: ", target.has_signal("target_hit"))
		print("Hostage target has target_disappeared signal: ", target.has_signal("target_disappeared"))
	
	# Wait for the target to be fully ready before proceeding
	await get_tree().process_frame

func spawn_2poppers_simple():
	"""Spawn a 2poppers_simple composite target with WebSocket integration"""
	var target = two_poppers_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("2poppers_simple target spawned with WebSocket integration")

func spawn_2poppers():
	"""Legacy function - redirects to spawn_2poppers_simple()"""
	spawn_2poppers_simple()

func spawn_3paddles():
	"""Spawn a 3paddles composite target"""
	var target = three_paddles_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	if not DEBUG_DISABLED:
		print("3paddles target spawned")

func spawn_ipsc_mini_rotate():
	"""Spawn an IPSC mini rotating target"""
	var target = ipsc_mini_rotate_scene.instantiate()
	center_container.add_child(target)
	current_target_instance = target
	
	target.position = Vector2(-200, 200)
	
	# Reset rotating target hit counter
	rotating_target_hits = 0
	if not DEBUG_DISABLED:
		print("Rotating target hit counter reset to 0")
	
	# Wait for the node to be fully added to the scene
	await get_tree().process_frame
	
	if not DEBUG_DISABLED:
		print("IPSC Mini Rotate target spawned and positioned")

func spawn_footsteps():
	"""Spawn the footsteps transition scene"""
	if footsteps_instance:
		# Remove existing footsteps if any
		if footsteps_instance.get_parent():
			footsteps_instance.get_parent().remove_child(footsteps_instance)
		footsteps_instance.queue_free()
	
	footsteps_instance = footsteps_scene.instantiate()
	center_container.add_child(footsteps_instance)
	current_target_instance = footsteps_instance
	
	if not DEBUG_DISABLED:
		print("Footsteps transition scene spawned")

func connect_footsteps_signals():
	"""Connect signals for footsteps transition scene"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING FOOTSTEPS SIGNALS ===")
	
	# Footsteps is a transition scene, so we'll auto-advance after the animation completes
	# Get the animation player and connect to animation_finished signal
	if footsteps_node:
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			# Disconnect any existing connections first
			if animation_player.animation_finished.is_connected(_on_footsteps_animation_finished):
				animation_player.animation_finished.disconnect(_on_footsteps_animation_finished)
			
			# Connect the signal
			animation_player.animation_finished.connect(_on_footsteps_animation_finished)
			if not DEBUG_DISABLED:
				print("Connected to footsteps animation_finished signal")
		else:
			if not DEBUG_DISABLED:
				print("ERROR: AnimationPlayer not found in footsteps node")
	else:
		if not DEBUG_DISABLED:
			print("ERROR: Footsteps node not available for signal connection")

func show_footsteps_transition():
	"""Show footsteps as a transition between targets"""
	if not DEBUG_DISABLED:
		print("=== SHOWING FOOTSTEPS TRANSITION ===")
	
	# Clear current target
	clear_current_target()
	
	# Show the footsteps node and start animation
	if footsteps_node:
		footsteps_node.visible = true
		current_target_instance = footsteps_node
		
		# Reset the sprite region to initial state for animation
		var sprite = footsteps_node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.region_rect = Rect2(0, 0, 0, 300)  # Reset to initial state
		
		# Reset animation to beginning and play
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()  # Stop any current animation
			animation_player.play("footstep_reveal")  # Start from beginning
			if not DEBUG_DISABLED:
				print("Started footsteps animation")
		
		# Connect to footsteps animation completion to advance to next target
		connect_footsteps_signals()
		
		if not DEBUG_DISABLED:
			print("Footsteps transition shown")
	else:
		if not DEBUG_DISABLED:
			print("ERROR: Footsteps node not found!")

func _on_footsteps_animation_finished(_anim_name: String):
	"""Handle footsteps animation completion - auto-advance to next target"""
	if not DEBUG_DISABLED:
		print("=== FOOTSTEPS ANIMATION FINISHED ===")
		print("Animation name: ", _anim_name)
	
	# Hide footsteps immediately when animation finishes
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
		if not DEBUG_DISABLED:
			print("Footsteps hidden after animation completion")
	
	# Proceed to spawn the next actual target
	await spawn_next_target()

func hide_footsteps():
	"""Hide the footsteps transition scene"""
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation when hiding
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
		if not DEBUG_DISABLED:
			print("Footsteps transition scene hidden")

func show_footsteps():
	"""Show the footsteps transition scene"""
	if footsteps_node:
		footsteps_node.visible = true
		if not DEBUG_DISABLED:
			print("Footsteps transition scene shown")

func connect_target_signals():
	"""Connect to the current target's signals"""
	if not current_target_instance:
		if not DEBUG_DISABLED:
			print("WARNING: No current target instance to connect signals")
		return
	
	# Check bounds before accessing target_sequence
	if current_target_index >= target_sequence.size():
		if not DEBUG_DISABLED:
			print("WARNING: current_target_index out of bounds in connect_target_signals")
			print("Index: ", current_target_index, " Size: ", target_sequence.size())
		return
	
	var current_target_type = target_sequence[current_target_index]
	
	# Handle composite targets that contain child targets
	match current_target_type:
		"2poppers":
			connect_2poppers_signals()
		"3paddles":
			connect_paddle_signals()
		"ipsc_mini_rotate":
			connect_ipsc_mini_rotate_signals()
		_:
			connect_simple_target_signals()

func connect_simple_target_signals():
	"""Connect signals for simple targets (ipsc_mini, hostage, popper, paddle)"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING SIMPLE TARGET SIGNALS ===")
		print("Target instance: ", current_target_instance)
	if current_target_instance:
		if not DEBUG_DISABLED:
			print("Target name: ", current_target_instance.name)
			if current_target_index < target_sequence.size():
				print("Target type: ", target_sequence[current_target_index])
			else:
				print("Target type: INDEX OUT OF BOUNDS (", current_target_index, ")")
	else:
		if not DEBUG_DISABLED:
			print("Target name: None")
	
	if current_target_instance.has_signal("target_hit"):
		# Disconnect any existing connections
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		
		# Connect the signal
		current_target_instance.target_hit.connect(_on_target_hit)
		if not DEBUG_DISABLED:
			print("Connected to target_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("WARNING: target_hit signal not found!")
	
	# Connect to disappear signal if available
	if current_target_instance.has_signal("target_disappeared"):
		if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
			current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
		current_target_instance.target_disappeared.connect(_on_target_disappeared)
		if not DEBUG_DISABLED:
			print("Connected to target_disappeared signal")
	else:
		if not DEBUG_DISABLED:
			print("WARNING: target_disappeared signal not found!")
	
	if not DEBUG_DISABLED:
		print("=== SIGNAL CONNECTION COMPLETE ===")

func _on_target_disappeared(target_id: String = ""):
	"""Handle when a target has completed its disappear animation"""
	# Check bounds before accessing target_sequence
	if current_target_index >= target_sequence.size():
		if not DEBUG_DISABLED:
			print("=== TARGET DISAPPEARED - INDEX OUT OF BOUNDS ===")
			print("Target index: ", current_target_index)
			print("Target sequence size: ", target_sequence.size())
			print("Drill should already be completed, ignoring target_disappeared signal")
		return
	
	var current_target_type = target_sequence[current_target_index]
	if not DEBUG_DISABLED:
		print("=== TARGET DISAPPEARED ===")
		print("Target type: ", current_target_type)
		print("Target ID: ", target_id)
		print("Target index: ", current_target_index)
		print("Moving to next target...")
	
	# Disable bullet spawning during target transition
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	if not DEBUG_DISABLED:
		print("Bullet spawning disabled during target transition")
	
	current_target_index += 1
	
	# Update progress bar - current_target_index now represents completed targets
	emit_signal("ui_progress_update", current_target_index)
	
	# Check if there are more targets - if so, show footsteps transition first
	if current_target_index < target_sequence.size():
		if not DEBUG_DISABLED:
			print("More targets remaining - showing footsteps transition")
		show_footsteps_transition()
	else:
		if not DEBUG_DISABLED:
			print("No more targets - proceeding to completion")
		spawn_next_target()

func connect_ipsc_mini_rotate_signals():
	"""Connect signals for ipsc_mini_rotate target (has child ipsc_mini)"""
	var ipsc_mini = current_target_instance.get_node("RotationCenter/IPSCMini")
	if ipsc_mini and ipsc_mini.has_signal("target_hit"):
		if ipsc_mini.target_hit.is_connected(_on_target_hit):
			ipsc_mini.target_hit.disconnect(_on_target_hit)
		ipsc_mini.target_hit.connect(_on_target_hit)
		if not DEBUG_DISABLED:
			print("Connected to ipsc_mini_rotate signals")
		
		# DO NOT connect target_disappeared signal for rotating targets
		# Rotating targets handle their own completion logic in _on_target_hit
		# Connecting target_disappeared would cause double incrementation of current_target_index
		if not DEBUG_DISABLED:
			print("Skipping target_disappeared connection for rotating target (handled manually)")

func connect_paddle_signals():
	"""Connect signals for paddle targets (3paddles composite target)"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING TO 3PADDLES SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		if not DEBUG_DISABLED:
			print("Connected to 3paddles target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			if not DEBUG_DISABLED:
				print("Connected to 3paddles target_disappeared signal")
	else:
		if not DEBUG_DISABLED:
			print("WARNING: 3paddles target doesn't have expected signals!")

func connect_2poppers_signals():
	"""Connect signals for popper targets (2poppers composite target)"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING TO 2POPPERS SIGNALS ===")
	if current_target_instance and current_target_instance.has_signal("target_hit"):
		if current_target_instance.target_hit.is_connected(_on_target_hit):
			current_target_instance.target_hit.disconnect(_on_target_hit)
		current_target_instance.target_hit.connect(_on_target_hit)
		if not DEBUG_DISABLED:
			print("Connected to 2poppers target_hit signal")
		
		# Connect disappear signal
		if current_target_instance.has_signal("target_disappeared"):
			if current_target_instance.target_disappeared.is_connected(_on_target_disappeared):
				current_target_instance.target_disappeared.disconnect(_on_target_disappeared)
			current_target_instance.target_disappeared.connect(_on_target_disappeared)
			if not DEBUG_DISABLED:
				print("Connected to 2poppers target_disappeared signal")
	else:
		if not DEBUG_DISABLED:
			print("WARNING: 2poppers target doesn't have expected signals!")

func _on_target_hit(param1, param2 = null, param3 = null, param4 = null):
	"""Handle when a target is hit - supports both simple targets and composite targets"""
	# Check bounds before accessing target_sequence
	if current_target_index >= target_sequence.size():
		if not DEBUG_DISABLED:
			print("WARNING: target hit but current_target_index out of bounds")
			print("Index: ", current_target_index, " Size: ", target_sequence.size())
		return
	
	var current_target_type = target_sequence[current_target_index]
	var hit_area = ""
	var hit_position = Vector2.ZERO
	
	# Handle different signal signatures
	if current_target_type == "3paddles":
		# 3paddles sends: paddle_id, zone, points, hit_position
		var paddle_id = param1
		var zone = str(param2)
		var actual_points = param3
		hit_position = param4
		hit_area = "Paddle"
		if not DEBUG_DISABLED:
			print("Target hit: ", current_target_type, " paddle: ", paddle_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += int(actual_points)
	elif current_target_type == "2poppers":
		# 2poppers sends: popper_id, zone, points, hit_position
		var popper_id = param1
		var zone = str(param2)
		var actual_points = param3
		hit_position = param4
		
		if popper_id == "miss":
			hit_area = "Miss"
			if not DEBUG_DISABLED:
				print("Target miss: ", current_target_type, " - bullet missed both poppers at ", hit_position)
		else:
			hit_area = "Popper"
			if not DEBUG_DISABLED:
				print("Target hit: ", current_target_type, " popper: ", popper_id, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		
		total_drill_score += int(actual_points)
	else:
		# Simple targets send: zone, points, hit_position
		var zone = param1
		var actual_points = param2
		hit_position = param3
		hit_area = zone
		
		# Filter out paddle hits
		if zone == "Paddle":
			if not DEBUG_DISABLED:
				print("Ignoring paddle hit in simple target")
			return
		
		if not DEBUG_DISABLED:
			print("Target hit: ", current_target_type, " in zone: ", zone, " for ", actual_points, " points at ", hit_position)
		total_drill_score += int(actual_points)
	
	if not DEBUG_DISABLED:
		print("Total drill score: ", total_drill_score)
	emit_signal("ui_score_update", total_drill_score)
	
	# Get rotation angle for rotating targets
	var rotation_angle = 0.0
	if current_target_type == "ipsc_mini_rotate" and current_target_instance:
		var rotation_center = current_target_instance.get_node("RotationCenter")
		if rotation_center:
			rotation_angle = rotation_center.rotation
			if not DEBUG_DISABLED:
				print("Rotating target hit at rotation angle: ", rotation_angle, " radians (", rad_to_deg(rotation_angle), " degrees)")
	
	# Emit the enhanced target_hit signal for performance tracking
	emit_signal("target_hit", current_target_type, hit_position, hit_area, rotation_angle)
	
	# Special handling for rotating target - only count valid target hits (not misses or barrel hits)
	if current_target_type == "ipsc_mini_rotate":
		# Check if this is a valid target hit (not a miss or barrel_miss)
		var zone = hit_area  # hit_area was set above to the zone value
		var actual_points = param2 if current_target_type != "3paddles" else param3
		
		if zone != "miss" and zone != "barrel_miss" and actual_points > 0:
			rotating_target_hits += 1
			if not DEBUG_DISABLED:
				print("Rotating target VALID hit count: ", rotating_target_hits, " (zone: ", zone, ", points: ", actual_points, ")")
		else:
			if not DEBUG_DISABLED:
				print("Rotating target miss/barrel hit - not counted (zone: ", zone, ", points: ", actual_points, ")")
		
		# Check if we've reached 2 VALID hits on the rotating target
		if rotating_target_hits >= 2:
			if not DEBUG_DISABLED:
				print("2 VALID hits on rotating target reached! Moving to next target.")
			
			# Reset the counter for potential future rotating targets
			rotating_target_hits = 0
			
			# Check if this is the last target in the sequence
			if current_target_index >= target_sequence.size() - 1:
				# This is the last target - complete the drill
				current_target_index += 1  # Mark this target as completed
				emit_signal("ui_progress_update", current_target_index)
				complete_drill()
				if not DEBUG_DISABLED:
					print("Rotating target was the last target - drill completed!")
			else:
				# Not the last target - proceed to next target normally
				current_target_index += 1
				emit_signal("ui_progress_update", current_target_index)
				spawn_next_target()
				if not DEBUG_DISABLED:
					print("Rotating target completed - moving to next target in sequence")
			
			# Don't continue processing this hit since we're transitioning
			return
	
	# Update the fastest interval display
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_fastest_time_update", fastest_time)

func complete_drill():
	"""Complete the drill sequence and show completion overlay"""
	if not DEBUG_DISABLED:
		print("=== DRILL COMPLETED! ===")
		print("Final score: ", total_drill_score)
		print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	
	# Stop the drill timer
	stop_drill_timer()
	
	# Hide the shot timer since drill is complete
	hide_shot_timer()
	
	# Temporarily disable bullet spawning to freeze gameplay
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# Show the completion overlay
	var fastest_time = performance_tracker.get_fastest_time_diff()
	if drill_timed_out:
		emit_signal("ui_show_completion_with_timeout", elapsed_seconds, fastest_time, total_drill_score, true, false)
	else:
		emit_signal("ui_show_completion", elapsed_seconds, fastest_time, total_drill_score)
	
	# Set the total elapsed time in performance tracker before finishing
	performance_tracker.set_total_elapsed_time(elapsed_seconds)
	
	# Wait a moment to ensure the overlay is visible before enabling bullets
	await get_tree().create_timer(0.1).timeout
	
	# Re-enable bullet spawning for overlay interactions
	bullets_allowed = true  # Enable local bullets flag for overlay interactions
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("=== BULLETS RE-ENABLED FOR COMPLETION OVERLAY ===")
			print("bullets_allowed: ", bullets_allowed)
			print("WebSocket bullet_spawning_enabled: ", ws_listener.bullet_spawning_enabled)
	
	# Only emit drills finished signal if not timed out (to save performance data)
	if not drill_timed_out:
		emit_signal("drills_finished")
	
	# Check for auto restart setting
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("auto_restart") and global_data.settings_dict.get("auto_restart", false):
		var pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if not DEBUG_DISABLED:
			print("=== AUTO RESTART ENABLED - RESTARTING DRILL ===")
			print("Auto restart pause time: ", pause_time, " seconds")
		
		# Start countdown display on the restart button
		var drill_ui = get_node_or_null("DrillUI")
		if drill_ui:
			var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
			if drill_complete_overlay and drill_complete_overlay.has_method("start_countdown"):
				drill_complete_overlay.start_countdown(pause_time)
		
		# Wait for the configured pause time to let the completion overlay be visible
		await get_tree().create_timer(pause_time).timeout
		# Restart the drill after the pause
		restart_drill()
		return
	
	# Clear the current target to prevent further interactions
	clear_current_target()
	
	# Hide footsteps when drill completes
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
		if not DEBUG_DISABLED:
			print("Footsteps hidden on drill completion")
	
	# Reset tracking variables for next run - but keep UI state for display
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	rotating_target_hits = 0
	
	# DON'T reset progress bar, timer, or fastest time - keep them displayed
	# elapsed_seconds = 0.0  # Keep final time displayed
	# emit_signal("ui_timer_update", elapsed_seconds)
	# emit_signal("ui_progress_update", 0)  # Keep progress at 100%
	
	# Reset performance tracker for next drill - but don't update UI
	performance_tracker.reset_fastest_time()
	# emit_signal("ui_fastest_time_update", 999.0)  # Don't reset UI display

func complete_drill_with_timeout():
	"""Complete the drill due to timeout - don't save performance data"""
	if not DEBUG_DISABLED:
		print("=== DRILL TIMED OUT! ===")
		print("Final score: ", total_drill_score)
		print("Targets completed: ", current_target_index, "/", target_sequence.size())
	drill_completed = true
	drill_timed_out = true
	
	# Stop the drill timer
	stop_drill_timer()
	
	# Hide the shot timer since drill is complete
	hide_shot_timer()
	
	# Temporarily disable bullet spawning to freeze gameplay
	bullets_allowed = false
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
	
	# Show the completion overlay with timeout indication
	var fastest_time = performance_tracker.get_fastest_time_diff()
	emit_signal("ui_show_completion_with_timeout", elapsed_seconds, fastest_time, total_drill_score, true, false)
	
	# DON'T set total elapsed time in performance tracker - we're not saving timeout data
	# performance_tracker.set_total_elapsed_time(elapsed_seconds)
	
	# Wait a moment to ensure the overlay is visible before enabling bullets
	await get_tree().create_timer(0.1).timeout
	
	# Re-enable bullet spawning for overlay interactions
	bullets_allowed = true  # Enable local bullets flag for overlay interactions
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("=== BULLETS RE-ENABLED FOR COMPLETION OVERLAY (TIMEOUT) ===")
			print("bullets_allowed: ", bullets_allowed)
			print("WebSocket bullet_spawning_enabled: ", ws_listener.bullet_spawning_enabled)
	
	# DON'T emit drills_finished signal - this prevents performance data saving
	# emit_signal("drills_finished")
	
	# Check for auto restart setting
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("auto_restart") and global_data.settings_dict.get("auto_restart", false):
		var pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if not DEBUG_DISABLED:
			print("=== AUTO RESTART ENABLED - RESTARTING DRILL AFTER TIMEOUT ===")
			print("Auto restart pause time: ", pause_time, " seconds")
		
		# Start countdown display on the restart button
		var drill_ui = get_node_or_null("DrillUI")
		if drill_ui:
			var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
			if drill_complete_overlay and drill_complete_overlay.has_method("start_countdown"):
				drill_complete_overlay.start_countdown(pause_time)
		
		# Wait for the configured pause time to let the completion overlay be visible
		await get_tree().create_timer(pause_time).timeout
		# Restart the drill after the pause
		restart_drill()
		return
	
	# Clear the current target to prevent further interactions
	clear_current_target()
	
	# Hide footsteps when drill times out
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
		if not DEBUG_DISABLED:
			print("Footsteps hidden on drill timeout")
	
	# Reset tracking variables for next run - but keep UI state for display
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	rotating_target_hits = 0
	
	# Reset performance tracker for next drill without saving data
	performance_tracker.reset_fastest_time()

func restart_drill():
	"""Restart the drill from the beginning"""
	if not DEBUG_DISABLED:
		print("=== RESTARTING DRILL ===")
	
	# Hide the completion overlay if it's visible
	emit_signal("ui_hide_completion")
	
	# Reset all tracking variables
	current_target_index = 0
	total_drill_score = 0
	drill_completed = false
	drill_timed_out = false
	rotating_target_hits = 0
	last_beep_second = -1  # Reset beep tracking
	
	# Stop any running timers
	if timeout_timer.is_stopped() == false:
		timeout_timer.stop()
	
	# Re-initialize target sequence (this will re-randomize if enabled)
	initialize_target_sequence()
	
	# NOW reset all UI displays when restarting
	emit_signal("ui_progress_update", 0)  # Reset progress bar
	elapsed_seconds = 0.0
	emit_signal("ui_timer_update", elapsed_seconds)  # Reset timer display
	emit_signal("ui_score_update", 0)  # Reset score display
	
	# Reset performance tracker and UI
	performance_tracker.reset_fastest_time()
	performance_tracker.reset_shot_timer()
	emit_signal("ui_fastest_time_update", 999.0)  # Reset to show "--"
	
	# Clear the current target
	clear_current_target()
	
	# Hide footsteps when restarting drill
	if footsteps_node:
		footsteps_node.visible = false
		# Stop animation
		var animation_player = footsteps_node.get_node_or_null("AnimationPlayer")
		if animation_player:
			animation_player.stop()
		if not DEBUG_DISABLED:
			print("Footsteps hidden on drill restart")
	
	# Show shot timer overlay again (which will spawn inactive target)
	show_shot_timer()
	
	if not DEBUG_DISABLED:
		print("Drill restarted!")
		print("New target sequence: ", target_sequence)

func is_bullet_spawning_allowed() -> bool:
	"""Check if bullet spawning is currently allowed"""
	return bullets_allowed

func get_drills_manager():
	"""Return reference to this drills manager for targets to use"""
	return self

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Drills] Received menu_control signal with directive: ", directive)
	
	# Check if drill complete overlay is visible and should handle navigation
	var drill_ui = get_node_or_null("DrillUI")
	var drill_complete_overlay = null
	if drill_ui:
		drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
	
	# Forward navigation commands to drill_complete_overlay if it's visible
	if drill_complete_overlay and drill_complete_overlay.visible and directive in ["up", "down", "enter"]:
		if not DEBUG_DISABLED:
			print("[Drills] Forwarding navigation directive to drill_complete_overlay: ", directive)
			print("[Drills] drill_complete_overlay script: ", drill_complete_overlay.get_script())
			print("[Drills] drill_complete_overlay has method: ", drill_complete_overlay.has_method("_on_websocket_menu_control"))
		
		if drill_complete_overlay.has_method("_on_websocket_menu_control"):
			drill_complete_overlay._on_websocket_menu_control(directive)
		else:
			# Fallback: Call the navigation methods directly if the main method is missing
			if not DEBUG_DISABLED:
				print("[Drills] Using fallback navigation methods")
			match directive:
				"up":
					if drill_complete_overlay.has_method("_navigate_up"):
						drill_complete_overlay._navigate_up()
					else:
						if not DEBUG_DISABLED:
							print("[Drills] _navigate_up method not found")
						_manual_navigate_up(drill_complete_overlay)
				"down":
					if drill_complete_overlay.has_method("_navigate_down"):
						drill_complete_overlay._navigate_down()
					else:
						if not DEBUG_DISABLED:
							print("[Drills] _navigate_down method not found")
						_manual_navigate_down(drill_complete_overlay)
				"enter":
					if drill_complete_overlay.has_method("_activate_focused_button"):
						drill_complete_overlay._activate_focused_button()
					else:
						if not DEBUG_DISABLED:
							print("[Drills] _activate_focused_button method not found")
						# Manual button activation
						_manual_button_activation(drill_complete_overlay)
		var menu_controller = get_node("/root/MenuController")
		if menu_controller:
			menu_controller.play_cursor_sound()
		return
	
	# Handle drills manager specific commands
	match directive:
		"volume_up":
			if not DEBUG_DISABLED:
				print("[Drills] Volume up")
			volume_up()
		"volume_down":
			if not DEBUG_DISABLED:
				print("[Drills] Volume down")
			volume_down()
		"power":
			if not DEBUG_DISABLED:
				print("[Drills] Power off")
			power_off()
		"back":
			if not DEBUG_DISABLED:
				print("[Drills] back - navigating to sub menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "drills"
				if not DEBUG_DISABLED:
					print("[Drills] Set return_source to drills")
			
			# Show status bar when exiting drills
			if get_tree():
				var status_bars = get_tree().get_nodes_in_group("status_bar")
				for status_bar in status_bars:
					status_bar.visible = true
					if not DEBUG_DISABLED:
						print("[Drills] Shown status bar: ", status_bar.name)
			
				get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")
		"homepage":
			if not DEBUG_DISABLED:
				print("[Drills] homepage - navigating to main menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "drills"
				if not DEBUG_DISABLED:
					print("[Drills] Set return_source to drills")
			
			# Show status bar when exiting drills
			if get_tree():
				var status_bars = get_tree().get_nodes_in_group("status_bar")
				for status_bar in status_bars:
					status_bar.visible = true
					if not DEBUG_DISABLED:
						print("[Drills] Shown status bar: ", status_bar.name)
			
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		_:
			if not DEBUG_DISABLED:
				print("[Drills] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Drills] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		if not DEBUG_DISABLED:
			print("[Drills] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Drills] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		if not DEBUG_DISABLED:
			print("[Drills] HttpService singleton not found!")

func _on_volume_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Drills] Volume HTTP response:", result, response_code, body_str)

func power_off():
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.set_alert_text(tr("power_off_alert"))
	add_child(dialog)

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func _manual_button_activation(overlay):
	"""Manually activate the focused button when script methods are not available"""
	if not DEBUG_DISABLED:
		print("[Drills] Attempting manual button activation")
	
	# Try to find the focused button in the overlay
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	# Check which button has focus using the viewport
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == restart_button:
		if not DEBUG_DISABLED:
			print("[Drills] Manually activating restart button")
		_manual_restart_drill()
	elif focused_control == replay_button:
		if not DEBUG_DISABLED:
			print("[Drills] Manually activating replay button")
		_manual_go_to_replay()
	else:
		# Default to restart if no focus
		if not DEBUG_DISABLED:
			print("[Drills] No button focused, defaulting to restart")
		_manual_restart_drill()

func _manual_restart_drill():
	"""Manually restart the drill when script methods are not available"""
	if not DEBUG_DISABLED:
		print("[Drills] Manual restart drill")
	
	# Hide the completion overlay
	var drill_ui = get_node_or_null("DrillUI")
	if drill_ui:
		var drill_complete_overlay = drill_ui.get_node_or_null("drill_complete_overlay")
		if drill_complete_overlay:
			drill_complete_overlay.visible = false
	
	# Restart the drill
	restart_drill()

func _manual_go_to_replay():
	"""Manually navigate to replay scene when script methods are not available"""
	if not DEBUG_DISABLED:
		print("[Drills] Manual navigation to drill replay")
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _manual_navigate_up(overlay):
	"""Manually navigate up between buttons"""
	if not DEBUG_DISABLED:
		print("[Drills] Manual navigate up")
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == replay_button and restart_button:
		restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Drills] Focused restart button")
	elif restart_button:
		restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Drills] Default focus to restart button")

func _manual_navigate_down(overlay):
	"""Manually navigate down between buttons"""
	if not DEBUG_DISABLED:
		print("[Drills] Manual navigate down")
	var restart_button = overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	var focused_control = get_viewport().gui_get_focus_owner()
	
	if focused_control == restart_button and replay_button:
		replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Drills] Focused replay button")
	elif restart_button:
		restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Drills] Default focus to restart button")
