extends Area2D

var last_click_frame = -1
var is_fallen = false
var initial_position: Vector2  # Store the popper's starting position
@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

# Popper identification
var popper_id: String = ""  # Unique identifier for this popper

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const ScoreUtils = preload("res://script/score_utils.gd")

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var last_smoke_time: float = 0.0
var last_impact_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var smoke_cooldown: float = 0.08  # 80ms minimum between smoke effects
var impact_cooldown: float = 0.06  # 60ms minimum between impact effects
var max_concurrent_sounds: int = 1  # Maximum number of concurrent sound effects
var active_sounds: int = 0

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared

func _ready():
	# Store the initial position for relative animation
	initial_position = position
	print("[popper %s] Initial position stored: %s" % [popper_id, initial_position])
	
	# Set default popper ID if not already set
	if popper_id == "":
		popper_id = name  # Use node name as default ID
	
	# Connect the input_event signal to handle mouse clicks
	input_event.connect(_on_input_event)
	
	# Create unique material instance to prevent shared shader parameters
	# This ensures each popper has its own shader state
	if sprite.material:
		sprite.material = sprite.material.duplicate()
		print("[popper %s] Created unique shader material instance" % popper_id)
		
		# Create unique animation with correct starting position
		create_relative_animation()
	
		# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[popper %s] Connected to WebSocketListener bullet_hit signal" % popper_id)
	else:
		print("[popper %s] WebSocketListener singleton not found!" % popper_id)
	
	
	# Set up collision detection for bullets
	# NOTE: Collision detection is now obsolete due to WebSocket fast path
	# collision_layer = 7  # Target layer
	# collision_mask = 0   # Don't detect other targets
	
	# Debug: Test if shader material is working
	test_shader_material()

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if bullet spawning is enabled
		var ws_listener = get_node_or_null("/root/WebSocketListener")
		if ws_listener and not ws_listener.bullet_spawning_enabled:
			print("[popper] Bullet spawning disabled during shot timer")
			return
			
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)
	
	# Debug: Press T to test popper shader effects manually
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			print("T pressed - testing popper shader")
			test_shader_effects()
		elif event.keycode == KEY_Y:
			print("Y pressed - resetting popper")
			reset_popper()

func test_shader_material():
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		print("Popper shader material found!")
		print("Shader: ", shader_material.shader)
		print("Fall progress: ", shader_material.get_shader_parameter("fall_progress"))
	else:
		print("ERROR: No shader material found on popper sprite!")

func create_relative_animation():
	"""Create a unique animation that starts from the popper's actual position"""
	if not animation_player:
		print("WARNING: Popper %s: No AnimationPlayer found" % popper_id)
		return
	
	if not animation_player.has_animation("fall_down"):
		print("WARNING: Popper %s: Animation 'fall_down' not found" % popper_id)
		return
	
	# Get the original animation
	var original_animation = animation_player.get_animation("fall_down")
	if not original_animation:
		print("ERROR: Popper %s: Could not get 'fall_down' animation" % popper_id)
		return
	
	# Create a duplicate animation
	var new_animation = original_animation.duplicate()
	
	# Find and update the position track
	for i in range(new_animation.get_track_count()):
		var track_path = new_animation.track_get_path(i)
		
		# Look for the position track
		if str(track_path) == ".:position":
			print("Popper %s: Updating position track %d" % [popper_id, i])
			
			# Get the original end position offset (0, 0) - poppers typically don't move position much
			var original_keys = new_animation.track_get_key_value(i, 1)  # Get the end position
			var fall_offset = original_keys  # This should be Vector2(0, 0) or similar for poppers
			
			# Calculate new positions relative to initial position
			var start_pos = initial_position
			var end_pos = initial_position + fall_offset
			
			print("Popper %s: Position animation - Start: %s, End: %s" % [popper_id, start_pos, end_pos])
			
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
	
	print("Popper %s: Created relative animation starting from %s" % [popper_id, initial_position])

func _on_input_event(_viewport, event, shape_idx):
	# Check for left mouse button click and if popper hasn't fallen yet
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_fallen:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the click position in local coordinates
		var _local_pos = to_local(event.position)
		
		# Determine which area was clicked based on shape_idx and emit signal
		var zone_hit = ""
		var points = 0
		
		match shape_idx:
			0:  # StandArea (index 0)
				zone_hit = "StandArea"
				points = ScoreUtils.new().get_points_for_hit_area("StandArea", 0)
				print("Popper stand hit! Starting fall animation...")
				trigger_fall_animation()
			1:  # BodyArea (index 1) - Main scoring hit
				zone_hit = "BodyArea"
				points = ScoreUtils.new().get_points_for_hit_area("BodyArea", 2)
				print("Popper body hit! Starting fall animation...")
				trigger_fall_animation()
			2:  # NeckArea (index 2) - Medium scoring hit
				zone_hit = "NeckArea"
				points = ScoreUtils.new().get_points_for_hit_area("NeckArea", 3)
				print("Popper neck hit! Starting fall animation...")
				trigger_fall_animation()
			3:  # HeadArea (index 3) - High scoring hit
				zone_hit = "HeadArea"
				points = ScoreUtils.new().get_points_for_hit_area("HeadArea", 5)
				print("Popper head hit! Starting fall animation...")
				trigger_fall_animation()
			_:
				zone_hit = "unknown"
				points = 0
				print("Popper hit!")
		
		# Emit the target_hit signal for mouse clicks only if it's a valid hit (including stand hits with 0 points)
		if zone_hit != "" and zone_hit != "unknown":
			total_score += points
			target_hit.emit(zone_hit, points, event.position)
			print("Mouse click target_hit emitted: ", zone_hit, " for ", points, " points at ", event.position)
		else:
			print("Mouse click missed - no target_hit signal emitted")

func test_shader_effects():
	print("Testing popper shader effects manually...")
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		# Manually set shader parameters to test
		shader_material.set_shader_parameter("fall_progress", 0.5)
		shader_material.set_shader_parameter("rotation_angle", 45.0)
		shader_material.set_shader_parameter("perspective_strength", 2.0)
		print("Popper shader parameters set for testing")
	else:
		print("ERROR: Cannot test - no shader material!")

func trigger_fall_animation():
	if is_fallen:
		print("Popper already fallen, ignoring trigger")
		return
		
	print("=== TRIGGERING POPPER FALL ANIMATION ===")
	is_fallen = true
	
	# Debug: Check if we have the material
	var shader_material = sprite.material as ShaderMaterial
	if not shader_material:
		print("ERROR: No popper shader material found!")
		return
	
	print("Popper shader material found, setting parameters...")
	
	# Add some randomization to the fall - different from paddle
	var random_rotation = randf_range(-150.0, 150.0)  # More dramatic for popper
	var blur_intensity = randf_range(0.035, 0.065)    # Slightly stronger blur
	var motion_dir = Vector2(randf_range(-0.3, 0.3), 1.0).normalized()
	var perspective = randf_range(1.3, 2.2)           # Stronger perspective
	
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
	
	print("Starting popper animation 'fall_down'...")
	animation_player.play("fall_down")
	
	# Connect to animation finished signal to handle cleanup
	if not animation_player.animation_finished.is_connected(_on_fall_animation_finished):
		animation_player.animation_finished.connect(_on_fall_animation_finished)
	
	print("=== POPPER FALL ANIMATION TRIGGERED ===")

func _on_fall_animation_finished(anim_name: StringName):
	if anim_name == "fall_down":
		print("Popper fall animation completed!")
		# Optional: Add scoring, sound effects, or remove the popper
		# For now, just disable further interactions
		input_pickable = false
		
		# Emit signal to notify the drills system that the target has disappeared
		target_disappeared.emit()
		print("target_disappeared signal emitted")

# Optional: Function to reset the popper (for testing or game restart)
func reset_popper():
	is_fallen = false
	input_pickable = true
	position = Vector2(245, 407)  # Original position
	
	var shader_material = sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("fall_progress", 0.0)
		shader_material.set_shader_parameter("rotation_angle", 0.0)
	
	if animation_player:
		animation_player.stop()
		animation_player.seek(0.0)

func spawn_bullet_at_position(world_pos: Vector2):
	print("Spawning bullet at world position: ", world_pos)
	
	if BulletScene:
		var bullet = BulletScene.instantiate()
		
		# Find the top-level scene node to add bullet effects
		# This ensures effects don't get rotated with rotating targets
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
		else:
			# Fallback to immediate parent if scene_root not found
			get_parent().add_child(bullet)
		
		# Use the new set_spawn_position method to ensure proper positioning
		bullet.set_spawn_position(world_pos)
		
		print("Bullet spawned and position set to: ", world_pos)

func handle_bullet_collision(bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this target"""
	# NOTE: This collision handling is now obsolete due to WebSocket fast path
	# WebSocket hits use handle_websocket_bullet_hit_fast() instead
	
	print("Bullet collision detected at position: ", bullet_position)
	
	# If popper has already fallen, ignore further collisions
	if is_fallen:
		print("Popper already fallen, ignoring collision")
		return "already_fallen"
	
	# Convert bullet world position to local coordinates
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var points = 0
	var should_fall = false
	var score_util = ScoreUtils.new()
	
	# Check which collision area the bullet hit by testing point in shapes
	# We need to check each collision shape manually since we can't get shape_idx from collision
	if is_point_in_head_area(local_pos):
		zone_hit = "HeadArea"
		points = score_util.get_points_for_hit_area("HeadArea", 5)
		should_fall = true
		print("COLLISION: Popper head hit by bullet - %d points!" % points)
	elif is_point_in_neck_area(local_pos):
		zone_hit = "NeckArea"
		points = score_util.get_points_for_hit_area("NeckArea", 3)
		should_fall = true
		print("[popper %s] FAST: Neck hit - %d points!" % [popper_id, points])
	elif is_point_in_body_area(local_pos):
		zone_hit = "BodyArea"
		points = score_util.get_points_for_hit_area("BodyArea", 2)
		should_fall = true
		print("[popper %s] FAST: Body hit - %d points!" % [popper_id, points])
	elif is_point_in_stand_area(local_pos):
		zone_hit = "StandArea"
		points = score_util.get_points_for_hit_area("StandArea", 0)
		should_fall = true
		print("[popper %s] FAST: Stand hit - %d points (will fall)" % [popper_id, points])
	else:
		print("COLLISION: Bullet missed - no target_hit signal emitted")
		return zone_hit
	
	if should_fall:
		trigger_fall_animation()
	
	return zone_hit

func is_point_in_head_area(point: Vector2) -> bool:
	var head_area = get_node("HeadArea")
	if head_area and head_area is CollisionShape2D:
		var shape = head_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(head_area.position)
			return distance <= shape.radius
	return false

func is_point_in_neck_area(point: Vector2) -> bool:
	var neck_area = get_node("NeckArea")
	if neck_area and neck_area is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(point, neck_area.polygon)
	return false

func is_point_in_body_area(point: Vector2) -> bool:
	var body_area = get_node("BodyArea")
	if body_area and body_area is CollisionShape2D:
		var shape = body_area.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(body_area.position)
			return distance <= shape.radius
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
	print("Score reset to 0")

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[popper %s] WebSocket bullet spawning disabled during shot timer" % popper_id)
		return
	
	print("[popper %s] Received bullet hit at position: %s" % [popper_id, pos])
	
	# FAST PATH: Direct processing for WebSocket hits
	handle_websocket_bullet_hit_fast(pos, t)

func handle_websocket_bullet_hit_fast(world_pos: Vector2, t: int = 0):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	print("[popper %s] FAST PATH: Processing WebSocket bullet hit at: %s" % [popper_id, world_pos])
	
	# Don't process if popper has already fallen
	if is_fallen:
		print("[popper %s] Popper already fallen - ignoring WebSocket hit" % popper_id)
		return
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	print("[popper %s] World pos: %s -> Local pos: %s" % [popper_id, world_pos, local_pos])
	
	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	var should_fall = false
	var score_util = ScoreUtils.new()
	
	if is_point_in_head_area(local_pos):
		zone_hit = "HeadArea"
		points = score_util.get_points_for_hit_area("HeadArea", 5)
		is_target_hit = true
		should_fall = true
		print("[popper %s] FAST: Head hit - %d points!" % [popper_id, points])
	elif is_point_in_neck_area(local_pos):
		zone_hit = "NeckArea"
		points = score_util.get_points_for_hit_area("NeckArea", 3)
		is_target_hit = true
		should_fall = true
		print("[popper %s] FAST: Neck hit - %d points!" % [popper_id, points])
	elif is_point_in_body_area(local_pos):
		zone_hit = "BodyArea"
		points = score_util.get_points_for_hit_area("BodyArea", 2)
		is_target_hit = true
		should_fall = true
		print("[popper %s] FAST: Body hit - %d points!" % [popper_id, points])
	elif is_point_in_stand_area(local_pos):
		zone_hit = "StandArea"
		points = score_util.get_points_for_hit_area("StandArea", 0)
		is_target_hit = true
		should_fall = true
		print("[popper %s] FAST: Stand hit - %d points (will fall)" % [popper_id, points])
	else:
		zone_hit = "miss"
		points = 0
		is_target_hit = false
		should_fall = false
		print("[popper %s] FAST: Bullet missed target" % popper_id)
	
	# 2. NO BULLET HOLES: Popper is steel target, doesn't create bullet holes
	
	# 3. ALWAYS: Spawn bullet effects (impact/sound) for target hits
	if is_target_hit:
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
		print("[popper %s] FAST: Bullet effects spawned for target hit" % popper_id)
	else:
		print("[popper %s] FAST: No effects - bullet missed target" % popper_id)
	
	# 4. Update score and emit signal ONLY for actual hits
	if is_target_hit:
		total_score += points
		target_hit.emit(zone_hit, points, world_pos, t)
		print("[popper %s] FAST: Target hit! Total score: %d" % [popper_id, total_score])
	else:
		print("[popper %s] FAST: Bullet missed - no target_hit signal emitted" % popper_id)
	
	# 5. Trigger fall animation if needed (for all hits that should cause falling)
	if should_fall:
		print("[popper %s] FAST: Triggering fall animation..." % popper_id)
		trigger_fall_animation()
	else:
		print("[popper %s] FAST: Miss - no animation triggered" % popper_id)

func spawn_bullet_effects_at_position(world_pos: Vector2, is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	print("[popper %s] Spawning bullet effects at: %s (Target hit: %s)" % [popper_id, world_pos, is_target_hit])
	
	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Load the effect scenes directly
	var _bullet_smoke_scene = preload("res://scene/bullet_smoke.tscn")
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")
	
	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()
	
	# Throttled smoke effect - DISABLED for performance optimization
	# Smoke is the most expensive effect (GPUParticles2D) and not essential for gameplay
	if false:  # Completely disabled
		pass
	else:
		print("[popper %s] Smoke effect disabled for performance optimization" % popper_id)
	
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above other elements
		impact.z_index = 15
		last_impact_time = time_stamp
		print("[popper %s] Impact effect spawned at: %s with z_index: 15" % [popper_id, world_pos])
	elif (time_stamp - last_impact_time) < impact_cooldown:
		print("[popper %s] Impact effect throttled (too fast)" % popper_id)
	
	# Throttled sound effect - only plays for hits since this function is only called for hits
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		print("[popper %s] Sound effect throttled (too fast - %ss since last)" % [popper_id, current_time - last_sound_time])
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		print("[popper %s] Sound effect throttled (too many concurrent sounds: %d/%d)" % [popper_id, active_sounds, max_concurrent_sounds])
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
			print("[popper %s] Sound finished, active sounds: %d" % [popper_id, active_sounds])
		)
		print("[popper %s] Steel impact sound played at: %s (Active sounds: %d)" % [popper_id, world_pos, active_sounds])
	else:
		print("[popper %s] No impact sound found!" % popper_id)

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
		print("[popper %s] Steel impact sound played at: %s" % [popper_id, world_pos])
	else:
		print("[popper %s] No impact sound found!" % popper_id)
