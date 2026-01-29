extends Area2D

var last_click_frame = -1
var is_fallen = false
var initial_position: Vector2  # Store the paddle's starting position
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

# Paddle identification
var paddle_id: String = ""  # Unique identifier for this paddle

# Bullet spawning
const BulletScene = preload("res://scene/bullet.tscn")
const ScoreUtils = preload("res://script/score_utils.gd")
var debug_markers = true  # Set to false to disable debug markers

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var last_smoke_time: float = 0.0
var last_impact_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var smoke_cooldown: float = 0.08  # 80ms minimum between smoke effects
var impact_cooldown: float = 0.06  # 60ms minimum between impact effects
var max_concurrent_sounds: int = 1  # Maximum number of concurrent sound effects
var active_sounds: int = 0

# Performance optimization
const DEBUG_DISABLED = false  # Set to true for verbose debugging

# Scoring system
var total_score: int = 0
signal target_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared(paddle_id: String)

func _ready():
	# Store the initial position for relative animation
	initial_position = position
	print("[paddle %s] Initial position stored: %s" % [paddle_id, initial_position])
	
	# Ensure input is enabled for mouse clicks
	input_pickable = true
	print("[paddle %s] Input pickable enabled" % paddle_id)
	
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
	# Set default paddle ID if not already set
	if paddle_id == "":
		paddle_id = name  # Use node name as default ID
	
	# Create unique material instance to prevent shared shader parameters
	# This ensures each paddle has its own shader state
	if sprite.material:
		sprite.material = sprite.material.duplicate()
		print("[paddle %s] Created unique shader material instance" % paddle_id)
		
		# Create unique animation with correct starting position
		create_relative_animation()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[paddle %s] Connected to WebSocketListener bullet_hit signal" % paddle_id)
	else:
		print("[paddle %s] WebSocketListener singleton not found!" % paddle_id)
	
	# Set up collision detection for bullets
	# NOTE: Collision detection is now obsolete due to WebSocket fast path
	# collision_layer = 7  # Target layer
	# collision_mask = 0   # Don't detect other targets
	
	# Debug: Test if shader material is working
	test_shader_material()

func set_paddle_id(id: String):
	"""Set the unique identifier for this paddle"""
	paddle_id = id
	print("Paddle ID set to: %s" % paddle_id)

func is_paddle_fallen() -> bool:
	return is_fallen

func create_relative_animation():
	"""Create a unique animation that starts from the paddle's actual position"""
	if not animation_player:
		print("WARNING: Paddle %s: No AnimationPlayer found" % paddle_id)
		return
	
	if not animation_player.has_animation("fall_down"):
		print("WARNING: Paddle %s: Animation 'fall_down' not found" % paddle_id)
		return
	
	# Get the original animation
	var original_animation = animation_player.get_animation("fall_down")
	if not original_animation:
		print("ERROR: Paddle %s: Could not get 'fall_down' animation" % paddle_id)
		return
	
	# Create a duplicate animation
	var new_animation = original_animation.duplicate()
	
	# Find and update the position track
	for i in range(new_animation.get_track_count()):
		var track_path = new_animation.track_get_path(i)
		
		# Look for the position track
		if str(track_path) == ".:position":
			print("Paddle %s: Updating position track %d" % [paddle_id, i])
			
			# Get the original end position offset (0, 120)
			var original_keys = new_animation.track_get_key_value(i, 1)  # Get the end position
			var fall_offset = original_keys  # This should be Vector2(0, 120)
			
			# Calculate new positions relative to initial position
			var start_pos = initial_position
			var end_pos = initial_position + fall_offset
			
			print("Paddle %s: Position animation - Start: %s, End: %s" % [paddle_id, start_pos, end_pos])
			
			# Update the track keys
			new_animation.track_set_key_value(i, 0, start_pos)  # Start position
			new_animation.track_set_key_value(i, 1, end_pos)    # End position
			
			break
	
	# Create a new animation library with our updated animation
	var new_library = AnimationLibrary.new()
	new_library.add_animation("fall_down", new_animation)
	
	# Replace the animation library
	animation_player.remove_animation_library("")
	animation_player.add_animation_library("", new_library)
	
	print("Paddle %s: Created relative animation starting from %s" % [paddle_id, initial_position])

func _input(event):
	# Debug: Press SPACE to test shader effects manually
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("SPACE pressed - testing shader")
			test_shader_effects()
		elif event.keycode == KEY_R:
			print("R pressed - resetting paddle")
			reset_paddle()
		elif event.keycode == KEY_D:
			debug_markers = !debug_markers
			print("Debug markers ", "enabled" if debug_markers else "disabled")

func test_shader_material():
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		print("Paddle %s: Shader material found! Resource ID: %s" % [paddle_id, shader_material.get_instance_id()])
		print("Paddle %s: Shader: %s" % [paddle_id, shader_material.shader])
		print("Paddle %s: Fall progress: %s" % [paddle_id, shader_material.get_shader_parameter("fall_progress")])
	else:
		print("ERROR: Paddle %s: No shader material found on sprite!" % paddle_id)

func _on_input_event(_viewport, event, shape_idx):
	# Check for left mouse button click and if paddle hasn't fallen yet
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_fallen:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the mouse position and convert to world coordinates (accounting for Camera2D)
		var mouse_screen_pos = event.global_position
		var camera = get_viewport().get_camera_2d()
		var mouse_world_pos: Vector2
		
		if camera:
			# Convert screen position to world position using camera transformation
			mouse_world_pos = camera.get_global_mouse_position()
			print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", mouse_world_pos)
		else:
			# Fallback if no camera
			mouse_world_pos = mouse_screen_pos
			print("No camera found, using screen position: ", mouse_world_pos)
		
		# Spawn bullet at correct world position
		spawn_bullet_at_position(mouse_world_pos)
		
		# Determine which area was clicked based on shape_idx
		match shape_idx:
			0:  # CircleArea (index 0) - Main target hit
				print("Paddle %s circle area hit! Starting fall animation..." % paddle_id)
				var points = ScoreUtils.new().get_points_for_hit_area("CircleArea", 5)
				total_score += points
				target_hit.emit(paddle_id, "CircleArea", points, event.position)
				trigger_fall_animation()
			1:  # StandArea (index 1) 
				print("Paddle %s stand area hit!" % paddle_id)
				var points = ScoreUtils.new().get_points_for_hit_area("StandArea", 0)
				total_score += points
				target_hit.emit(paddle_id, "StandArea", points, event.position)
				# Debug: Test shader manually
				test_shader_effects()
			_:
				print("Paddle %s hit!" % paddle_id)
				var points = ScoreUtils.new().get_points_for_hit_area("GeneralHit", 1)  # Default points for general hit
				total_score += points
				target_hit.emit(paddle_id, "GeneralHit", points, event.position)

func spawn_bullet_at_position(world_pos: Vector2):
	print("PADDLE: Spawning bullet at world position: ", world_pos)
	
	if BulletScene:
		var bullet = BulletScene.instantiate()
		print("PADDLE: Bullet instantiated: ", bullet)
		
		# Find the top-level scene node to add bullet effects
		# This ensures effects don't get rotated with rotating targets
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
			print("PADDLE: Bullet added to scene root: ", scene_root.name)
		else:
			# Fallback to immediate parent if scene_root not found
			get_parent().add_child(bullet)
			print("PADDLE: Bullet added to parent (fallback)")
		
		# Use the new set_spawn_position method to ensure proper positioning
		bullet.set_spawn_position(world_pos)
		
		print("PADDLE: Bullet spawned and position set to: ", world_pos)
	else:
		print("PADDLE ERROR: BulletScene is null!")

func is_point_in_circle_area(point: Vector2) -> bool:
	var circle_area = get_node("CircleArea")
	if circle_area and circle_area is CollisionShape2D:
		var shape = circle_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(circle_area.position)
			var result = distance <= shape.radius
			if not DEBUG_DISABLED:
				print("[paddle %s] Circle area check: point=%s, circle_pos=%s, distance=%s, radius=%s, result=%s" % 
					[paddle_id, point, circle_area.position, distance, shape.radius, result])
			return result
		else:
			if not DEBUG_DISABLED:
				print("[paddle %s] CircleArea shape is not CircleShape2D: %s" % [paddle_id, shape])
	else:
		if not DEBUG_DISABLED:
			print("[paddle %s] CircleArea node not found or not CollisionShape2D: %s" % [paddle_id, circle_area])
	return false

func is_point_in_stand_area(point: Vector2) -> bool:
	var stand_area = get_node("StandArea")
	if stand_area and stand_area is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, stand_area.polygon)
	return false

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	print("Paddle %s score reset to 0" % paddle_id)

func create_debug_marker(world_pos: Vector2):
	# Create a small visual marker to show where the click was detected
	var marker = ColorRect.new()
	marker.size = Vector2(10, 10)
	marker.color = Color.RED
	marker.global_position = world_pos - Vector2(5, 5)  # Center the marker
	get_parent().add_child(marker)
	
	# Remove marker after 1 second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): marker.queue_free(); timer.queue_free())
	get_parent().add_child(timer)
	timer.start()
	
	print("Debug marker created at: ", world_pos)

func test_shader_effects():
	print("Testing shader effects manually...")
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		# Manually set shader parameters to test
		shader_material.set_shader_parameter("fall_progress", 0.5)
		shader_material.set_shader_parameter("rotation_angle", 45.0)
		shader_material.set_shader_parameter("perspective_strength", 2.0)
		print("Shader parameters set for testing")
	else:
		print("ERROR: Cannot test - no shader material!")

func trigger_fall_animation():
	if is_fallen:
		print("Paddle %s already fallen, ignoring trigger" % paddle_id)
		return
		
	print("=== TRIGGERING FALL ANIMATION FOR PADDLE %s ===" % paddle_id)
	is_fallen = true
	
	# Debug: Check if we have the material
	var shader_material = sprite.material as ShaderMaterial
	if not shader_material:
		print("ERROR: Paddle %s: No shader material found!" % paddle_id)
		return
	
	print("Paddle %s: Shader material found, setting parameters... (Resource ID: %s)" % [paddle_id, shader_material.get_instance_id()])
	
	# Add some randomization to the fall
	var random_rotation = randf_range(-120.0, 120.0)
	var blur_intensity = randf_range(0.03, 0.06)
	var motion_dir = Vector2(randf_range(-0.4, 0.4), 1.0).normalized()
	var perspective = randf_range(1.2, 2.0)
	
	print("Setting rotation_angle to: ", random_rotation)
	shader_material.set_shader_parameter("rotation_angle", random_rotation)
	
	print("Setting motion_blur_intensity to: ", blur_intensity)
	shader_material.set_shader_parameter("motion_blur_intensity", blur_intensity)
	
	print("Setting motion_direction to: ", motion_dir)
	shader_material.set_shader_parameter("motion_direction", motion_dir)
	
	print("Setting perspective_strength to: ", perspective)
	shader_material.set_shader_parameter("perspective_strength", perspective)
	
	# Play the fall animation
	if not animation_player:
		print("ERROR: No AnimationPlayer found!")
		return
		
	if not animation_player.has_animation("fall_down"):
		print("ERROR: Animation 'fall_down' not found!")
		return
	
	print("Starting animation 'fall_down'...")
	animation_player.play("fall_down")
	
	# Connect to animation finished signal to handle cleanup
	if not animation_player.animation_finished.is_connected(_on_fall_animation_finished):
		animation_player.animation_finished.connect(_on_fall_animation_finished)
	
	print("=== FALL ANIMATION TRIGGERED FOR PADDLE %s ===" % paddle_id)

func _on_fall_animation_finished(anim_name: StringName):
	if anim_name == "fall_down":
		print("Paddle %s fall animation completed!" % paddle_id)
		# Emit signal to notify that the paddle has disappeared
		emit_signal("target_disappeared", paddle_id)
		# For now, just disable further interactions
		input_pickable = false
		
		# Emit signal to notify the drills system that the target has disappeared
		target_disappeared.emit(paddle_id)
		print("target_disappeared signal emitted for paddle %s" % paddle_id)

# Optional: Function to reset the paddle (for testing or game restart)
func reset_paddle():
	is_fallen = false
	input_pickable = true
	position = initial_position  # Reset to initial position, not (0,0)
	# Re-enable collision area if it was disabled by a hit in another scene
	var circle_area = get_node_or_null("CircleArea")
	if circle_area and circle_area is CollisionShape2D:
		circle_area.disabled = false
		if not DEBUG_DISABLED:
			print("[paddle %s] CircleArea collision re-enabled" % paddle_id)
	# Ensure the paddle sprite and node are visible after reset
	visible = true
	sprite.visible = true
	
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fall_progress", 0.0)
		shader_material.set_shader_parameter("rotation_angle", 0.0)
		print("Paddle %s: Shader parameters reset (Resource ID: %s)" % [paddle_id, shader_material.get_instance_id()])
	else:
		print("WARNING: Paddle %s: No shader material to reset!" % paddle_id)
	
	if animation_player:
		animation_player.stop()
		if animation_player.has_animation("fall_down"):
			animation_player.seek(0.0, true)  # Seek to start without playing
		if not DEBUG_DISABLED:
			print("[paddle %s] AnimationPlayer reset" % paddle_id)
	
	print("Paddle %s reset to initial position %s" % [paddle_id, initial_position])
	
	print("Paddle %s reset" % paddle_id)

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[paddle %s] WebSocket bullet spawning disabled during shot timer" % paddle_id)
		return
	
	print("[paddle %s] Received bullet hit at position: %s" % [paddle_id, pos])
	
	# FAST PATH: Direct processing for WebSocket hits
	
	handle_websocket_bullet_hit_fast(pos, t)

func handle_websocket_bullet_hit_fast(world_pos: Vector2, t: int = 0):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	if not DEBUG_DISABLED:
		print("[paddle %s] FAST PATH: Processing WebSocket bullet hit at: %s" % [paddle_id, world_pos])
	
	# Don't process if paddle has already fallen
	if is_fallen:
		if not DEBUG_DISABLED:
			print("[paddle %s] Paddle already fallen - ignoring WebSocket hit" % paddle_id)
		return
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	if not DEBUG_DISABLED:
		print("[paddle %s] World pos: %s -> Local pos: %s" % [paddle_id, world_pos, local_pos])
	
	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	var should_fall = false
	
	# Check which zone was hit (highest score first)
	if is_point_in_circle_area(local_pos):
		zone_hit = "CircleArea"
		points = ScoreUtils.new().get_points_for_hit_area("CircleArea", 5)
		is_target_hit = true
		should_fall = true
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Circle area hit - 5 points!" % paddle_id)
	elif is_point_in_stand_area(local_pos):
		zone_hit = "StandArea"
		points = ScoreUtils.new().get_points_for_hit_area("StandArea", 0)
		is_target_hit = true
		should_fall = false
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Stand area hit - 0 points (no fall)" % paddle_id)
	else:
		zone_hit = "miss"
		points = 0
		is_target_hit = false
		should_fall = false
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Bullet missed target" % paddle_id)
	
	# 2. NO BULLET HOLES: Paddle is steel target, doesn't create bullet holes
	
	# 3. ALWAYS: Spawn bullet effects (impact/sound) for target hits
	if is_target_hit:
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Bullet effects spawned for target hit" % paddle_id)
	else:
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: No effects - bullet missed target" % paddle_id)
	
	# 4. Update score and emit signal only for target hits
	if is_target_hit:
		total_score += points
		target_hit.emit(paddle_id, zone_hit, points, world_pos, t)
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Emitted target_hit: zone=%s, points=%d, total_score=%d" % [paddle_id, zone_hit, points, total_score])
	
	# 5. Trigger fall animation if needed (only for hits that should cause falling)
	if should_fall:
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Triggering fall animation..." % paddle_id)
		trigger_fall_animation()
	elif zone_hit == "StandArea":
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Stand hit - testing shader effects only" % paddle_id)
		test_shader_effects()
	else:
		if not DEBUG_DISABLED:
			print("[paddle %s] FAST: Miss - no animation triggered" % paddle_id)

func spawn_bullet_effects_at_position(world_pos: Vector2, is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	if not DEBUG_DISABLED:
		print("[paddle %s] Spawning bullet effects at: %s (Target hit: %s)" % [paddle_id, world_pos, is_target_hit])
	
	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Load the effect scenes directly
	# var bullet_smoke_scene = preload("res://scene/bullet_smoke.tscn")
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")
	
	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()
	
	# Throttled smoke effect - DISABLED for performance optimization
	# Smoke is the most expensive effect (GPUParticles2D) and not essential for gameplay
	if false:  # Completely disabled
		pass
	else:
		if not DEBUG_DISABLED:
			print("[paddle %s] Smoke effect disabled for performance optimization" % paddle_id)
	
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above other elements
		impact.z_index = 15
		last_impact_time = time_stamp
		if not DEBUG_DISABLED:
			print("[paddle %s] Impact effect spawned at: %s with z_index: 15" % [paddle_id, world_pos])
	elif (time_stamp - last_impact_time) < impact_cooldown:
		if not DEBUG_DISABLED:
			print("[paddle %s] Impact effect throttled (too fast)" % paddle_id)
	
	# Throttled sound effect - ALWAYS play (for both hits and misses)
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		if not DEBUG_DISABLED:
			print("[paddle %s] Sound effect throttled (too fast - %ss since last)" % [paddle_id, current_time - last_sound_time])
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		if not DEBUG_DISABLED:
			print("[paddle %s] Sound effect throttled (too many concurrent sounds: %d/%d)" % [paddle_id, active_sounds, max_concurrent_sounds])
		return
	
	# Load the metal impact sound for steel targets
	var impact_sound = preload("res://audio/metal_hit.WAV")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Update throttling state
		last_sound_time = current_time
		active_sounds += 1
		
		# Clean up audio player after sound finishes and decrease active count
		audio_player.finished.connect(func(): 
			active_sounds -= 1
			audio_player.queue_free()
			if not DEBUG_DISABLED:
				print("[paddle %s] Sound finished, active sounds: %d" % [paddle_id, active_sounds])
		)
		if not DEBUG_DISABLED:
			print("[paddle %s] Steel impact sound played at: %s (Active sounds: %d)" % [paddle_id, world_pos, active_sounds])
	else:
		print("[paddle %s] No impact sound found!" % paddle_id)  # Keep this as it indicates an error

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play steel impact sound effect at specific position (legacy - non-throttled)"""
	# Load the metal impact sound for steel targets
	var impact_sound = preload("res://audio/metal_hit.WAV")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		print("[paddle %s] Steel impact sound played at: %s" % [paddle_id, world_pos])
	else:
		print("[paddle %s] No impact sound found!" % paddle_id)
