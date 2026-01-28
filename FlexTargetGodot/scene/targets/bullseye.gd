extends Area2D

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
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

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# GPU instanced bullet hole rendering (optional - faster at scale)
var bullet_hole_multimeshes: Array = []
var bullet_hole_textures: Array = []
var max_instances_per_texture: int = 32
var active_instances: Dictionary = {}

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

# Time tracking for shots
var shot_timestamps: Array[float] = []
var drill_active: bool = false  # Flag to ignore shots before drill starts
signal shot_time_diff(time_diff: float, hit_position: Vector2)


func _ready():
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		if not DEBUG_DISABLED:
			print("[Bullseye] Connected to WebSocketListener.bullet_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("[Bullseye] WebSocketListener not found!")	

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionShape2D:
		var shape = zone_node.shape
		if shape is CircleShape2D:
			# Check if point is inside the circle
			var distance = point.distance_to(zone_node.position)
			return distance <= shape.radius
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

func handle_bullet_collision(_bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this target"""
	# NOTE: This collision handling is now obsolete due to WebSocket fast path
	return "ignored"


func reset_target():
	"""Reset the target to its original state (useful for restarting)"""
	# Reset visual properties
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2(0.9, 0.9)
	
	# Reset shot tracking
	shot_timestamps.clear()
	
	# Reset bullet hole pool - hide all active holes
	reset_bullet_hole_pool()
	

func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""
	
	# Hide all active bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false
	
	# Clear active list
	active_bullet_holes.clear()
	

func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""

	# Load bullet hole textures for instancing
	load_bullet_hole_textures()

	# Create a MultiMeshInstance2D for each texture so we can render many holes cheaply
	for i in range(bullet_hole_textures.size()):
		var multimesh_instance = MultiMeshInstance2D.new()
		add_child(multimesh_instance)
		multimesh_instance.z_index = 0

		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.instance_count = max_instances_per_texture
		multimesh.visible_instance_count = 0

		var mesh = create_bullet_hole_mesh(bullet_hole_textures[i])
		multimesh.mesh = mesh
		multimesh_instance.multimesh = multimesh

		# Try to propagate material/texture to the instance for compatibility across engine versions
		if mesh and mesh.material:
			var has_material_prop := false
			for prop in multimesh_instance.get_property_list():
				if prop.name == "material":
					has_material_prop = true
					break
			if has_material_prop:
				multimesh_instance.material = mesh.material
				if multimesh_instance.material is ShaderMaterial:
					multimesh_instance.material.set_shader_parameter("texture_albedo", bullet_hole_textures[i])
			elif mesh.material is ShaderMaterial:
				mesh.material.set_shader_parameter("texture_albedo", bullet_hole_textures[i])

		# Some engine versions expose a `texture` property on MultiMeshInstance2D
		for p in multimesh_instance.get_property_list():
			if p.name == "texture":
				multimesh_instance.set("texture", bullet_hole_textures[i])
				break

		bullet_hole_multimeshes.append(multimesh_instance)
		active_instances[i] = 0

	# --- Keep legacy node pool initialization for fallback ---
	if not BulletHoleScene:
		return

	# Clear existing pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole):
			hole.queue_free()
	bullet_hole_pool.clear()
	active_bullet_holes.clear()

	# Pre-instantiate bullet holes
	for i in range(pool_size):
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.visible = false  # Hide until needed
		# Set z-index to ensure bullet holes appear below effects
		bullet_hole.z_index = 0
		bullet_hole_pool.append(bullet_hole)
	

func get_pooled_bullet_hole() -> Node:
	"""Get an available bullet hole from the pool, or create new if needed"""
	# Try to find an inactive bullet hole in the pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not hole.visible:
			return hole
	
	# If no available holes in pool, create a new one (fallback)
	if BulletHoleScene:
		var new_hole = BulletHoleScene.instantiate()
		add_child(new_hole)
		bullet_hole_pool.append(new_hole)  # Add to pool for future use
		return new_hole
	
	return null

func return_bullet_hole_to_pool(hole: Node):
	"""Return a bullet hole to the pool by hiding it"""
	if is_instance_valid(hole):
		hole.visible = false
		# Remove from active list
		if hole in active_bullet_holes:
			active_bullet_holes.erase(hole)

func clear_all_bullet_holes() -> void:
	"""Clear all bullet holes (both MultiMesh and legacy node pool)"""
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

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""

	# Prefer GPU-instanced MultiMesh if available
	if bullet_hole_multimeshes.size() > 0 and bullet_hole_textures.size() > 0:
		var texture_index = randi() % bullet_hole_textures.size()
		if texture_index >= bullet_hole_multimeshes.size():
			return

		var mm_inst = bullet_hole_multimeshes[texture_index]
		var multimesh = mm_inst.multimesh
		var current_count = active_instances.get(texture_index, 0)
		if current_count >= max_instances_per_texture:
			return

		# Reuse preallocated transform to avoid allocations
		var t = _reusable_transform
		var scale_factor = randf_range(0.6, 0.8)
		# Uniform scale (no rotation)
		t.x = Vector2(scale_factor, 0.0)
		t.y = Vector2(0.0, scale_factor)
		t.origin = local_position

		multimesh.set_instance_transform_2d(current_count, t)
		multimesh.visible_instance_count = current_count + 1
		active_instances[texture_index] = current_count + 1
		return

	# Fallback to node pool
	var bullet_hole = get_pooled_bullet_hole()
	if bullet_hole:
		# Configure the bullet hole
		bullet_hole.set_hole_position(local_position)
		bullet_hole.visible = true
		# Ensure bullet holes appear below smoke/debris effects
		bullet_hole.z_index = 0
		
		# Track as active
		if bullet_hole not in active_bullet_holes:
			active_bullet_holes.append(bullet_hole)
		
func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	if not DEBUG_DISABLED:
		print("[Bullseye] _on_websocket_bullet_hit called with pos: ", pos)
	
	# Ignore shots if drill is not active yet
	if not drill_active:
		if not DEBUG_DISABLED:
			print("[Bullseye] Ignoring shot - drill not active")
		return
	
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		if not DEBUG_DISABLED:
			print("[Bullseye] Ignoring shot - bullet spawning disabled")
		return
	
	if not DEBUG_DISABLED:
		print("[Bullseye] Processing bullet hit")
	
	# Direct bullet hole spawning for WebSocket hits
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	
	if not DEBUG_DISABLED:
		print("[Bullseye] local_pos: ", local_pos)
	
	# Determine if target was hit
	var is_target_hit = false
	
	# Check which zone was hit
	if is_point_in_zone("BullseyeZone", local_pos) or is_point_in_zone("OuterZone", local_pos):
		is_target_hit = true
	
	if not DEBUG_DISABLED:
		print("[Bullseye] BullseyeZone hit: ", is_point_in_zone("BullseyeZone", local_pos))
		print("[Bullseye] OuterZone hit: ", is_point_in_zone("OuterZone", local_pos))
		print("[Bullseye] is_target_hit: ", is_target_hit)
	
	# Track time for hits
	var time_diff = -1.0  # Default to miss
	if is_target_hit:
		var current_time = Time.get_ticks_msec() / 1000.0  # seconds
		time_diff = 0.0
		if shot_timestamps.size() > 0:
			time_diff = current_time - shot_timestamps.back()
		shot_timestamps.append(current_time)
	
	if not DEBUG_DISABLED:
		print("[Bullseye] Emitting shot_time_diff with time_diff: ", time_diff, " world_pos: ", world_pos)
	shot_time_diff.emit(time_diff, world_pos)
	
	# Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
	# Always spawn bullet effects (impact/sound)
	spawn_bullet_effects_at_position(world_pos, is_target_hit)
func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
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

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return
	
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
		
		# Update throttling state
		last_sound_time = current_time
		active_sounds += 1
		
		# Clean up audio player after sound finishes and decrease active count
		audio_player.finished.connect(func(): 
			active_sounds -= 1
			audio_player.queue_free()
		)
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

# Helper functions for MultiMesh instancing
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

	var shader_material = ShaderMaterial.new()
	var shader = load("res://shader/bullet_hole_instanced.gdshader")
	if shader:
		shader_material.shader = shader
		shader_material.set_shader_parameter("texture_albedo", texture)

	mesh.material = shader_material
	return mesh
# ROTATION PERFORMANCE OPTIMIZATIONS
