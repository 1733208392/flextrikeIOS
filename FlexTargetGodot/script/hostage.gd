extends Area2D

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

var last_click_frame = -1

# Animation state tracking
var is_disappearing: bool = false

# Shot tracking for disappearing animation
var shot_count: int = 0
@export var max_shots: int = 2  # Exported so scenes can override in the editor; default 2

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")
const ScoreUtils = preload("res://script/score_utils.gd")

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
var active_bullet_holes: Array[Node] = []

# GPU instanced bullet hole rendering (ported from ipsc_mini.gd)
var bullet_hole_multimeshes: Array = []
var bullet_hole_textures: Array = []
var max_instances_per_texture: int = 32  # Maximum bullet holes per texture type
var active_instances: Dictionary = {}

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
var drill_active: bool = false  # Flag to ignore shots before drill starts
signal target_hit(zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared

# Reference to drills manager
var drills_manager = null

func _ready():
	# Try to find the drills manager
	drills_manager = get_node("/root/drills") if get_node_or_null("/root/drills") else null

	# If loaded by drills_network (networked drills loader), set max_shots high for testing
	var drills_network = get_node_or_null("/root/drills_network")
	if drills_network:
		max_shots = 1000
		if not DEBUG_DISABLED:
			print("[hostage] drills_network detected at /root/drills_network - max_shots set to ", max_shots)
	# Fallback: if drills_manager name suggests it's networked, also set
	elif drills_manager and typeof(drills_manager.name) == TYPE_STRING and drills_manager.name.to_lower().find("network") != -1:
		max_shots = 1000
		if not DEBUG_DISABLED:
			print("[hostage] drills_manager with 'network' in name detected - max_shots set to ", max_shots)
	if not drills_manager:
		# Try to find it in the scene tree
		var current = get_parent()
		while current and not drills_manager:
			if current.has_method("is_bullet_spawning_allowed"):
				drills_manager = current
				break
			current = current.get_parent()
	
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		if not DEBUG_DISABLED:
			print("[hostage] Connected to WebSocketListener bullet_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("[hostage] WebSocketListener singleton not found!")


func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Adjust the point by the zone's position offset
		var adjusted_point = point - zone_node.position
		# Check if the adjusted point is inside the polygon
		return Geometry2D.is_point_in_polygon(adjusted_point, zone_node.polygon)
	return false

func spawn_bullet_at_position(world_pos: Vector2):
	if not DEBUG_DISABLED:
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
		
		if not DEBUG_DISABLED:
			print("Bullet spawned and position set to: ", world_pos)



func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""
	# Prefer GPU instanced MultiMesh if available
	if bullet_hole_multimeshes.size() > 0 and bullet_hole_textures.size() > 0:
		var texture_index = randi() % bullet_hole_textures.size()
		if texture_index >= bullet_hole_multimeshes.size():
			return

		var mm_inst = bullet_hole_multimeshes[texture_index]
		var multimesh = mm_inst.multimesh
		var current_count = active_instances.get(texture_index, 0)
		if current_count >= max_instances_per_texture:
			return

		# Reuse a preallocated Transform2D to avoid per-shot allocations and improve speed.
		var t = _reusable_transform
		var scale_factor = randf_range(0.6, 0.8)
		# Set axes for uniform scale (no rotation)
		t.x = Vector2(scale_factor, 0.0)
		t.y = Vector2(0.0, scale_factor)
		t.origin = local_position

		multimesh.set_instance_transform_2d(current_count, t)
		multimesh.visible_instance_count = current_count + 1
		active_instances[texture_index] = current_count + 1

		if not DEBUG_DISABLED:
			print("[hostage] Instanced bullet hole spawned idx=", texture_index, " at ", local_position)
		return

	# Fallback to legacy node pool
	if not DEBUG_DISABLED:
		print("[hostage] POOL: Spawning bullet hole at local position: ", local_position)

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

		if not DEBUG_DISABLED:
			print("[hostage] POOL: Bullet hole activated at position: ", local_position, " (Active: ", active_bullet_holes.size(), ") with z_index: 0")
	else:
		if not DEBUG_DISABLED:
			print("[hostage] POOL ERROR: Failed to get bullet hole from pool!")

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	if not DEBUG_DISABLED:
		print("Score reset to 0")

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	if not DEBUG_DISABLED:
		print("Starting disappearing animation for ipsc_mini")
	is_disappearing = true
	
	# Get the AnimationPlayer
	var animation_player = get_node("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
		# Play the disappear animation
		animation_player.play("disappear")
		if not DEBUG_DISABLED:
			print("Disappear animation started")
	else:
		if not DEBUG_DISABLED:
			print("ERROR: AnimationPlayer not found")

func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		if not DEBUG_DISABLED:
			print("Disappear animation completed")
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	if not DEBUG_DISABLED:
		print("Target disappearing animation finished")
	
	# Disable collision detection completely
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()
	if not DEBUG_DISABLED:
		print("target_disappeared signal emitted")
	
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
	
	if not DEBUG_DISABLED:
		print("Target reset to original state")

func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""
	if not DEBUG_DISABLED:
		print("[hostage] Resetting bullet hole pool")
	
	# Hide all active bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false
	
	# Clear active list
	active_bullet_holes.clear()
	
	if not DEBUG_DISABLED:
		print("[hostage] Bullet hole pool reset - all holes returned to pool")

	# Also reset GPU-instanced MultiMesh visible instance counts if initialized
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0

func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""
	if not DEBUG_DISABLED:
		print("[hostage] Initializing bullet hole pool with size: ", pool_size)
	
	if not BulletHoleScene:
		if not DEBUG_DISABLED:
			print("[hostage] ERROR: BulletHoleScene not found for pool initialization!")
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
		if not DEBUG_DISABLED:
			print("[hostage] Pre-instantiated bullet hole ", i + 1, "/", pool_size, " with z_index: 0")
	
	if not DEBUG_DISABLED:
		print("[hostage] Bullet hole pool initialized successfully with ", bullet_hole_pool.size(), " holes")

	# --- Initialize GPU instanced MultiMesh system (if possible) ---
	# Clear any existing multimeshes
	for mm in bullet_hole_multimeshes:
		if is_instance_valid(mm):
			mm.queue_free()
	bullet_hole_multimeshes.clear()
	bullet_hole_textures.clear()
	active_instances.clear()

	# Load textures and create a MultiMeshInstance2D per texture
	load_bullet_hole_textures()

	var parent_node = self
	for i in range(bullet_hole_textures.size()):
		var multimesh_instance = MultiMeshInstance2D.new()
		parent_node.add_child(multimesh_instance)
		multimesh_instance.z_index = 0

		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.instance_count = max_instances_per_texture
		multimesh.visible_instance_count = 0

		var mesh = create_bullet_hole_mesh(bullet_hole_textures[i])
		multimesh.mesh = mesh
		multimesh_instance.multimesh = multimesh

		# Try to set material/texture on the instance if supported
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

		for p in multimesh_instance.get_property_list():
			if p.name == "texture":
				multimesh_instance.set("texture", bullet_hole_textures[i])
				break

		bullet_hole_multimeshes.append(multimesh_instance)
		active_instances[i] = 0

func get_pooled_bullet_hole() -> Node:
	"""Get an available bullet hole from the pool, or create new if needed"""
	# Try to find an inactive bullet hole in the pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not hole.visible:
			if not DEBUG_DISABLED:
				print("[hostage] Reusing pooled bullet hole")
			return hole
	
	# If no available holes in pool, create a new one (fallback)
	if not DEBUG_DISABLED:
		print("[hostage] Pool exhausted, creating new bullet hole")
	if BulletHoleScene:
		var new_hole = BulletHoleScene.instantiate()
		add_child(new_hole)
		bullet_hole_pool.append(new_hole)  # Add to pool for future use
		return new_hole
	
	if not DEBUG_DISABLED:
		print("[hostage] ERROR: Cannot create new bullet hole - BulletHoleScene missing!")
	return null

func return_bullet_hole_to_pool(hole: Node):
	"""Return a bullet hole to the pool by hiding it"""
	if is_instance_valid(hole):
		hole.visible = false
		# Remove from active list
		if hole in active_bullet_holes:
			active_bullet_holes.erase(hole)
		if not DEBUG_DISABLED:
			print("[hostage] Bullet hole returned to pool, active holes: ", active_bullet_holes.size())

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	# Ignore shots if drill is not active yet
	if not drill_active:
		if not DEBUG_DISABLED:
			print("[hostage] Ignoring shot because drill is not active yet")
		return
	
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		if not DEBUG_DISABLED:
			print("[hostage] WebSocket bullet spawning disabled during shot timer")
		return
	
	if not DEBUG_DISABLED:
		print("[hostage] Received bullet hit at position: ", pos)
	
	# FAST PATH: Direct bullet hole spawning for WebSocket hits
	handle_websocket_bullet_hit_fast(pos, t)

func handle_websocket_bullet_hit_fast(world_pos: Vector2, t: int = 0):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""
	if not DEBUG_DISABLED:
		print("[hostage] FAST PATH: Processing WebSocket bullet hit at: ", world_pos)
	
	# Don't process if target is disappearing
	if is_disappearing:
		if not DEBUG_DISABLED:
			print("[hostage] Target is disappearing - ignoring WebSocket hit")
		return
	
	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)
	if not DEBUG_DISABLED:
		print("[hostage] World pos: ", world_pos, " -> Local pos: ", local_pos)
	
	# 1. FIRST: Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false
	
	# Check which zone was hit (highest score first, including WhiteZone penalty)
	if is_point_in_zone("WhiteZone", local_pos):
		zone_hit = "WhiteZone"
		points = ScoreUtils.new().get_points_for_hit_area("WhiteZone", -5)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[hostage] FAST: WhiteZone hit - -5 points!")
	elif is_point_in_zone("AZone", local_pos):
		zone_hit = "AZone"
		points = ScoreUtils.new().get_points_for_hit_area("AZone", 5)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Zone A hit - 5 points!")
	elif is_point_in_zone("CZone", local_pos):
		zone_hit = "CZone"
		points = ScoreUtils.new().get_points_for_hit_area("CZone", 3)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Zone C hit - 3 points!")
	elif is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Zone D hit - 1 point!")
	else:
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", 0)
		is_target_hit = false
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Bullet missed target - no bullet hole")
	
	var time_stamp = Time.get_ticks_msec() / 1000.0
	# 2. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
		# For hits: play sound only (no impact particle)
		play_impact_sound_at_position_throttled(world_pos, time_stamp)
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Bullet hole spawned and sound played for target hit")
	else:
		if not DEBUG_DISABLED:
			print("[hostage] FAST: No bullet hole - bullet missed target")
		# For misses: spawn impact particle and play sound
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
	
	# 4. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos, t)
	if not DEBUG_DISABLED:
		print("[hostage] FAST: Total score: ", total_score)
	
	# 5. Increment shot count and check for disappearing animation (only for hits)
	if is_target_hit:
		shot_count += 1
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Shot count: ", shot_count, "/", max_shots)
		
		# Check if we've reached the maximum shots
		if shot_count >= max_shots:
			if not DEBUG_DISABLED:
				print("[hostage] FAST: Maximum shots reached! Triggering disappearing animation...")
			play_disappearing_animation()
	else:
		if not DEBUG_DISABLED:
			print("[hostage] FAST: Miss - shot count not incremented")

func spawn_bullet_effects_at_position(world_pos: Vector2, is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	if not DEBUG_DISABLED:
		print("[hostage] Spawning bullet effects at: ", world_pos, " (Target hit: ", is_target_hit, ")")
	
	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Load the effect scenes directly
	var bullet_smoke_scene = preload("res://scene/bullet_smoke.tscn")
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
			print("[hostage] Smoke effect disabled for performance optimization")
	
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Ensure impact effects appear above bullet holes
		impact.z_index = 15
		last_impact_time = time_stamp
		if not DEBUG_DISABLED:
			print("[hostage] Impact effect spawned at: ", world_pos, " with z_index: 15")
	elif (time_stamp - last_impact_time) < impact_cooldown:
		if not DEBUG_DISABLED:
			print("[hostage] Impact effect throttled (too fast)")
	
	# Throttled sound effect - ALWAYS play (for both hits and misses)
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		if not DEBUG_DISABLED:
			print("[hostage] Sound effect throttled (too fast - ", current_time - last_sound_time, "s since last)")
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		if not DEBUG_DISABLED:
			print("[hostage] Sound effect throttled (too many concurrent sounds: ", active_sounds, "/", max_concurrent_sounds, ")")
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
			if not DEBUG_DISABLED:
				print("[hostage] Sound finished, active sounds: ", active_sounds)
		)
		if not DEBUG_DISABLED:
			print("[hostage] Steel impact sound played at: ", world_pos, " (Active sounds: ", active_sounds, ")")
	else:
		if not DEBUG_DISABLED:
			print("[hostage] No impact sound found!")

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
		if not DEBUG_DISABLED:
			print("[hostage] Steel impact sound played at: ", world_pos)
	else:
		if not DEBUG_DISABLED:
			print("[hostage] No impact sound found!")


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
			print("[hostage] ERROR: Failed to load bullet hole texture ", i + 1)


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
