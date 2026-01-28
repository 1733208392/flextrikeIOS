extends Area2D

var last_click_frame = -1

# Animation state tracking
var is_disappearing: bool = false

# Shot tracking for disappearing animation - only valid target hits count
var shot_count: int = 0
@export var max_shots: int = 2  # Exported so scenes can override in the editor; default 2

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")
const ScoreUtils = preload("res://script/score_utils.gd")

# Bullet hole system - GPU instanced rendering for performance
var bullet_hole_multimeshes: Array[MultiMeshInstance2D] = []
var bullet_hole_textures: Array[Texture2D] = []
var max_instances_per_texture: int = 32  # Maximum bullet holes per texture type
var active_instances: Dictionary = {}  # Track active instance counts per texture

# Legacy pool variables (kept for compatibility but not used)
var bullet_hole_pool: Array[Node] = []
var available_holes: Array[Node] = []
var pool_size: int = 8
var max_pool_size: int = 16
var active_bullet_holes: Array[Node] = []

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var last_smoke_time: float = 0.0
var last_impact_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var smoke_cooldown: float = 0.08  # 80ms minimum between smoke effects
var impact_cooldown: float = 0.06  # 60ms minimum between impact effects
var max_concurrent_sounds: int = 1  # Maximum number of concurrent sound effects
var active_sounds: int = 0
var impact_sound_res: AudioStream = null
var sound_player_pool: Array = []
var sound_pool_size: int = 4  # number of pooled AudioStreamPlayer2D

# Performance optimization
const DEBUG_DISABLED = true

# Performance optimization for rotating targets
var rotation_cache_angle: float = 0.0
var rotation_cache_time: float = 0.0
var rotation_cache_duration: float = 0.1  # Cache rotation for 100ms

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

# Bullet activity monitoring for animation pausing
var bullet_activity_count: int = 0
var activity_threshold: int = 3  # Pause rotation if 3+ bullets in flight
var activity_cooldown_timer: float = 0.0
var activity_cooldown_duration: float = 1.0  # Resume after 1 second of low activity
var animation_paused: bool = false

# Scoring system
var total_score: int = 0
var drill_active: bool = false  # Flag to ignore shots before drill starts
signal target_hit(zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared

func _ready():
	
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()

	# Initialize pooled audio players to reduce sound latency
	_init_sound_pool()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)

	# If loaded by drills_network (networked drills loader), set max_shots high for testing
	var drills_network = get_node_or_null("/root/drills_network")
	if drills_network:
		max_shots = 1000

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	return false

func spawn_bullet_at_position(world_pos: Vector2):
	
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

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	is_disappearing = true
	
	# Get the AnimationPlayer
	var animation_player = get_node("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
		# Play the disappear animation
		animation_player.play("disappear")
func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	
	# Disable collision detection completely
	# NOTE: Collision detection was already obsolete due to WebSocket fast path
	# set_collision_layer(0)
	# set_collision_mask(0)
	
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()
	
	# Keep the disappearing state active to prevent any further interactions
	# is_disappearing remains true

func reset_target():
	"""Reset the target to its original state (useful for restarting)"""
	# Reset animation state
	is_disappearing = false
	
	# Reset shot count
	shot_count = 0
	
	# Reset visual properties
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	
	# Re-enable collision detection
	# NOTE: Collision detection disabled as it's obsolete due to WebSocket fast path
	# collision_layer = 7
	# collision_mask = 0
	
	# Reset score
	reset_score()
	
	# Reset bullet hole pool - hide all active holes
	reset_bullet_hole_pool()
	

func reset_bullet_hole_pool():
	"""Reset all bullet hole instances by hiding them"""
	
	# Reset all MultiMesh visible instance counts
	for texture_index in range(bullet_hole_multimeshes.size()):
		var multimesh_instance = bullet_hole_multimeshes[texture_index]
		if multimesh_instance and multimesh_instance.multimesh:
			multimesh_instance.multimesh.visible_instance_count = 0
		active_instances[texture_index] = 0
	

func initialize_bullet_hole_pool():
	"""Initialize GPU-instanced bullet hole rendering system"""
	
	# Clear any existing multimeshes
	for multimesh in bullet_hole_multimeshes:
		if is_instance_valid(multimesh):
			multimesh.queue_free()
	bullet_hole_multimeshes.clear()
	bullet_hole_textures.clear()
	active_instances.clear()
	
	# Load bullet hole textures
	load_bullet_hole_textures()
	
	# Create a MultiMesh instance for each texture
	for i in range(bullet_hole_textures.size()):
		var multimesh_instance = MultiMeshInstance2D.new()
		add_child(multimesh_instance)
		multimesh_instance.z_index = 0
		
		# Create and configure the MultiMesh
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.instance_count = max_instances_per_texture
		multimesh.visible_instance_count = 0
		
		# Create mesh for this texture
		var mesh = create_bullet_hole_mesh(bullet_hole_textures[i])
		multimesh.mesh = mesh
		# Assign the mesh to the multimesh and ensure the instance uses the mesh material
		multimesh_instance.multimesh = multimesh
		# MultiMeshInstance2D may not automatically use the Mesh.material; set material_override
		if mesh and mesh.material:
			# Try assigning to the instance material property (some Godot versions use 'material')
			# This avoids assigning to non-existent 'material_override'
			# Safely check for a 'material' property before assigning
			var has_material_prop := false
			for prop in multimesh_instance.get_property_list():
				if prop.name == "material":
					has_material_prop = true
					break
			if has_material_prop:
				multimesh_instance.material = mesh.material
				# If it's a ShaderMaterial, ensure the texture uniform is set on the instance material
				if multimesh_instance.material is ShaderMaterial:
					multimesh_instance.material.set_shader_parameter("texture_albedo", bullet_hole_textures[i])
				elif mesh.material is ShaderMaterial:
					# As a fallback, ensure mesh material shader parameter is set (already done in creation)
					mesh.material.set_shader_parameter("texture_albedo", bullet_hole_textures[i])
			# Additionally, some engine versions expose a 'texture' property on MultiMeshInstance2D
			# Try to set it if present so the renderer has the texture bound
			for p in multimesh_instance.get_property_list():
				if p.name == "texture":
					multimesh_instance.set("texture", bullet_hole_textures[i])
					break
			# else: fallback to mesh.material (already set) and let engine handle it
		bullet_hole_multimeshes.append(multimesh_instance)
		active_instances[i] = 0  # Track active instances for this texture

func load_bullet_hole_textures():
	"""Load all bullet hole textures"""
	bullet_hole_textures = [
		load("res://asset/bullet_hole1.png"),
		load("res://asset/bullet_hole2.png"),
		load("res://asset/bullet_hole3.png"),
		load("res://asset/bullet_hole4.png"),
		load("res://asset/bullet_hole5.png"),
		load("res://asset/bullet_hole6.png")
	]
	
	# Verify all textures loaded
	for i in range(bullet_hole_textures.size()):
		if not bullet_hole_textures[i]:
			print("ERROR: Failed to load bullet hole texture ", i + 1)

func create_bullet_hole_mesh(texture: Texture2D) -> QuadMesh:
	"""Create a quad mesh for the bullet hole texture"""
	var mesh = QuadMesh.new()
	mesh.size = texture.get_size()
	
	# Create shader material with texture
	var shader_material = ShaderMaterial.new()
	var shader = load("res://shader/bullet_hole_instanced.gdshader")
	if shader:
		shader_material.shader = shader
		shader_material.set_shader_parameter("texture_albedo", texture)
	
	mesh.material = shader_material
	return mesh

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using GPU instancing"""
	
	# Select random texture index
	var texture_index = randi() % bullet_hole_textures.size()
	
	# Get the corresponding MultiMesh instance
	if texture_index >= bullet_hole_multimeshes.size():
		return  # Safety check
	
	var multimesh_instance = bullet_hole_multimeshes[texture_index]
	var multimesh = multimesh_instance.multimesh
	
	# Check if we have room for another instance
	var current_count = active_instances[texture_index]
	if current_count >= max_instances_per_texture:
		return  # Pool exhausted for this texture
	
	# Reuse a preallocated Transform2D to avoid per-shot allocations and improve speed.
	# We keep no rotation here (rotation code was commented-out) and apply a uniform scale.
	var t = _reusable_transform
	var scale_factor = randf_range(0.6, 0.8)
	# Set axes for uniform scale (no rotation)
	t.x = Vector2(scale_factor, 0.0)
	t.y = Vector2(0.0, scale_factor)
	t.origin = local_position

	# Set the instance transform (the MultiMesh copies the transform internally)
	multimesh.set_instance_transform_2d(current_count, t)
	
	# Update visibility count
	multimesh.visible_instance_count = current_count + 1
	active_instances[texture_index] = current_count + 1
		
func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	
	# Ignore shots if drill is not active yet
	if not drill_active:
		return
	
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		return
	
	# Check if this target is part of a rotating scene (ipsc_mini_rotate)
	# Use optimized rotation-aware processing instead of bullet spawning
	var parent_node = get_parent()
	while parent_node:
		if parent_node.name.contains("IPSCMiniRotate") or parent_node.name.contains("RotationCenter"):
			# Use optimized direct hit processing for rotating targets
			handle_websocket_bullet_hit_rotating(pos, t)
			return
		parent_node = parent_node.get_parent()
	
	# FAST PATH: Direct bullet hole spawning for WebSocket hits (non-rotating targets only)
	handle_websocket_bullet_hit_fast(pos, t)

# FAST PATH: Direct bullet hole spawning for WebSocket hits (non-rotating targets only)
func handle_websocket_bullet_hit_fast(world_pos: Vector2, t: int = 0):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	
	# Don't process if target is disappearing
	if is_disappearing:
		return
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	
	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	
	# Check which zone was hit (highest score first)
	if is_point_in_zone("AZone", local_pos):
		zone_hit = "AZone"
		points = ScoreUtils.new().get_points_for_hit_area("AZone", 5)
		is_target_hit = true
	elif is_point_in_zone("CZone", local_pos):
		zone_hit = "CZone"
		points = ScoreUtils.new().get_points_for_hit_area("CZone", 3)
		is_target_hit = true
	elif is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
		is_target_hit = true
	else:
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", 0)
		is_target_hit = false
	
	# 2. CONDITIONAL: Only spawn bullet hole and impact sound if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
		var time_stamp = Time.get_ticks_msec() / 1000.0
		play_impact_sound_at_position_throttled(world_pos, time_stamp)
	# 3. ALWAYS: Spawn bullet effects (impact/sound) but skip smoke for misses
	else:
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
	
	# 4. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos, t)
	
	# 5. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1	
		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()

func spawn_bullet_effects_at_position(world_pos: Vector2, is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	
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
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above bullet holes
		impact.z_index = 15
		last_impact_time = time_stamp
	# Throttled sound effect - only plays for hits since this function is only called for hits
	play_impact_sound_at_position_throttled(world_pos, time_stamp)


func _init_sound_pool():
	"""Pre-create AudioStreamPlayer2D nodes to avoid allocation and node overhead on each sound."""
	impact_sound_res = preload("res://audio/paper_hit.ogg")
	# Clamp pool size to configured max_concurrent_sounds if present
	if max_concurrent_sounds > 0:
		sound_pool_size = max_concurrent_sounds
	# Clear any existing
	for p in sound_player_pool:
		if is_instance_valid(p):
			p.queue_free()
	sound_player_pool.clear()

	var scene_root = get_tree().current_scene if get_tree() else self
	for i in range(sound_pool_size):
		var player = AudioStreamPlayer2D.new()
		player.stream = impact_sound_res
		player.volume_db = -5
		player.bus = "Master"
		# Connect finished to a bound callback so we know which player finished
		player.finished.connect(Callable(self, "_on_sound_finished").bind(player))
		# Parent to scene root so global_position works
		scene_root.add_child(player)
		sound_player_pool.append(player)

	# Pre-warm decoders: play and stop quietly so decoder is ready on first real play
	for p in sound_player_pool:
		var prev_vol = p.volume_db
		p.volume_db = -80
		p.play()
		p.stop()
		p.volume_db = prev_vol


func _on_sound_finished(_player: AudioStreamPlayer2D) -> void:
	# Called when a pooled player finishes playing
	# Keep active_sounds in sync with actual players as a fallback
	active_sounds = _count_playing_sounds()


func _get_free_sound_player() -> AudioStreamPlayer2D:
	# Return a free (not playing) player or reuse the oldest one
	for p in sound_player_pool:
		if not p.playing:
			return p

	# None free: reuse first one (stop then return). Stopping ensures the stream restarts immediately.
	var p = sound_player_pool[0]
	if p.playing:
		p.stop()
	return p


func _count_playing_sounds() -> int:
	# Count how many pooled players are currently playing
	var cnt: int = 0
	for p in sound_player_pool:
		if is_instance_valid(p) and p.playing:
			cnt += 1
	return cnt

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return

	# Compute current active playing count from the pool (more robust than relying on signals)
	var playing_count = _count_playing_sounds()
	if playing_count >= max_concurrent_sounds:
		# No available concurrent slot
		return

	# Use a pooled AudioStreamPlayer2D to avoid allocations
	var player = _get_free_sound_player()
	if not player:
		return

	player.global_position = world_pos
	player.pitch_scale = randf_range(0.9, 1.1)
	player.volume_db = -5
	player.play()

	# Update throttling state
	last_sound_time = current_time
	# Keep active_sounds as a convenience cache in sync
	active_sounds = _count_playing_sounds()

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play paper impact sound effect at specific position (legacy - non-throttled)"""
	# Load the paper impact sound for paper targets
	var impact_sound = preload("res://audio/paper_hit.ogg")
	
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

func get_cached_rotation_angle() -> float:
	"""Get the current rotation angle with caching for performance"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Use cached value if still valid
	if (current_time - rotation_cache_time) < rotation_cache_duration:
		return rotation_cache_angle
	
	# Update cache with current rotation
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		rotation_cache_angle = rotation_center.rotation
		rotation_cache_time = current_time
		return rotation_cache_angle
	
	return 0.0

func handle_websocket_bullet_hit_rotating(world_pos: Vector2, t: int = 0) -> void:
	"""Optimized hit processing for rotating targets without bullet spawning"""
	
	# Don't process if target is disappearing
	if is_disappearing:
		return
	
	# DISABLE animation pausing for rotating targets - let ipsc_mini_rotate.gd control animation
	# bullet_activity_count += 1
	# monitor_bullet_activity()
	
	# Convert world position to local coordinates (this handles rotation automatically)
	var local_pos = to_local(world_pos)
	
	# 1. FIRST: Check if bullet hit the BarrelWall (for rotating targets)
	var barrel_wall_hit = false
	var parent_scene = get_parent().get_parent()  # Get the IPSCMiniRotate scene
	if parent_scene and parent_scene.name.contains("IPSCMiniRotate"):
		var barrel_wall = parent_scene.get_node_or_null("BarrelWall")
		if barrel_wall:
			var collision_shape = barrel_wall.get_node_or_null("CollisionShape2D")
			if collision_shape and collision_shape.shape:
				# Convert world position to barrel wall's local coordinate system
				var barrel_local_pos = barrel_wall.to_local(world_pos)
				# Check if point is inside barrel wall collision shape
				var shape = collision_shape.shape
				if shape is RectangleShape2D:
					var rect_shape = shape as RectangleShape2D
					var half_extents = rect_shape.size / 2.0
					var shape_pos = collision_shape.position
					var relative_pos = barrel_local_pos - shape_pos
					if abs(relative_pos.x) <= half_extents.x and abs(relative_pos.y) <= half_extents.y:
						barrel_wall_hit = true
	
	# 2. SECOND: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	
	if barrel_wall_hit:
		# Barrel wall hit - count as miss
		zone_hit = "barrel_miss"
		points = ScoreUtils.new().get_points_for_hit_area("barrel_miss", 0)
		is_target_hit = false
	else:
		# Check target zones (highest score first)
		if is_point_in_zone("AZone", local_pos):
			zone_hit = "AZone"
			points = ScoreUtils.new().get_points_for_hit_area("AZone", 5)
			is_target_hit = true
		elif is_point_in_zone("CZone", local_pos):
			zone_hit = "CZone"
			points = ScoreUtils.new().get_points_for_hit_area("CZone", 3)
			is_target_hit = true
		elif is_point_in_zone("DZone", local_pos):
			zone_hit = "DZone"
			points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
			is_target_hit = true
		else:
			zone_hit = "miss"
			points = ScoreUtils.new().get_points_for_hit_area("miss", 0)
			is_target_hit = false
	
	# 3. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
	
	# 4. For performance: only spawn bullet effects for misses (skip for valid target hits)
	if not is_target_hit:
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
	
	# 5. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos, t)
	
	# 6. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1
		
		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()

func monitor_bullet_activity():
	"""Monitor bullet activity and pause/resume animation accordingly"""
	# Pause animation if activity is high
	if bullet_activity_count >= activity_threshold and not animation_paused:
		pause_rotation_animation()
	
	# Reset cooldown timer when activity increases
	if bullet_activity_count > 0:
		activity_cooldown_timer = 0.0
	else:
		# Increment cooldown timer when no activity
		activity_cooldown_timer += get_process_delta_time()
		
		# Resume animation after cooldown period
		if activity_cooldown_timer >= activity_cooldown_duration and animation_paused:
			resume_rotation_animation()

func pause_rotation_animation():
	"""Pause the rotation animation to improve performance"""
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		var animation_player = rotation_center.get_parent().get_node_or_null("AnimationPlayer")
		if animation_player and animation_player.is_playing():
			animation_player.pause()
			animation_paused = true

func resume_rotation_animation():
	"""Resume the rotation animation"""
	var rotation_center = get_parent()
	if rotation_center and rotation_center.name == "RotationCenter":
		var animation_player = rotation_center.get_parent().get_node_or_null("AnimationPlayer")
		if animation_player and not animation_player.is_playing():
			animation_player.play()
			animation_paused = false
			activity_cooldown_timer = 0.0

func clear_all_bullet_holes() -> void:
	# Reset instanced MultiMesh counts
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0

	# Reset legacy node pool (if used anywhere)
	for hole in bullet_hole_pool:
		if is_instance_valid(hole):
			hole.visible = false

	active_bullet_holes.clear()
	available_holes.clear()
