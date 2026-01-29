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

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
var active_bullet_holes: Array[Node] = []

# GPU instanced bullet hole rendering (ported from `ipsc_mini.gd`)
var bullet_hole_multimeshes: Array = []
var bullet_hole_textures: Array = []
var max_instances_per_texture: int = 32
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

# Performance optimization
const DEBUG_DISABLED = true

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

# Performance optimization for rotating targets
var rotation_cache_angle: float = 0.0
var rotation_cache_time: float = 0.0
var rotation_cache_duration: float = 0.1  # Cache rotation for 100ms

# Bullet activity monitoring for animation pausing
var bullet_activity_count: int = 0
var activity_threshold: int = 3  # Pause rotation if 3+ bullets in flight
var activity_cooldown_timer: float = 0.0
var activity_cooldown_duration: float = 1.0  # Resume after 1 second of low activity
var animation_paused: bool = false

# Scoring system
var total_score: int = 0
@export var drill_active: bool = false  # Flag to ignore shots before drill starts
signal target_hit(zone: String, points: int, hit_position: Vector2)
signal target_disappeared

func _ready():
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)

	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()

	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)

	# If loaded by drills_network (networked drills loader), set max_shots high for testing
	var drills_network = get_node_or_null("/root/drills_network")
	if drills_network:
		max_shots = 1000

func _on_input_event(_viewport, event, _shape_idx):
	# Don't process input events if target is disappearing
	if is_disappearing:
		return

	# Check if it's a left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame

		# Simulate WebSocket bullet hit at mouse position
		_on_websocket_bullet_hit(event.global_position)

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if not zone_node:
		return false

	if zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	elif zone_node is CollisionShape2D:
		var shape = zone_node.shape
		var local_point = point - zone_node.position
		if shape is CircleShape2D:
			return local_point.length() <= shape.radius
		elif shape is RectangleShape2D:
			var rect = shape.get_rect()
			rect.position -= shape.size / 2  # Center the rect
			return rect.has_point(local_point)
		# Add other shape types if needed
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
	shot_count = 0

func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance"""
	# Initialize GPU-instanced bullet hole rendering system and keep legacy pool as fallback

	# Clear any existing multimeshes
	for mm in bullet_hole_multimeshes:
		if is_instance_valid(mm):
			mm.queue_free()
	bullet_hole_multimeshes.clear()
	bullet_hole_textures.clear()
	active_instances.clear()

	# Load bullet hole textures
	load_bullet_hole_textures()

	# Parent multimeshes to this Area2D so they follow the target
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

	# --- Keep legacy node pool initialization for fallback ---
	if not BulletHoleScene:
		return

	# Clear existing pool
	for hole in bullet_hole_pool:
		if is_instance_valid(hole):
			hole.queue_free()
	bullet_hole_pool.clear()
	active_bullet_holes.clear()

	# Pre-instantiate bullet holes as children of Area2D root
	for i in range(pool_size):
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.visible = false  # Hide until needed
		# Set z-index to ensure bullet holes appear below effects
		bullet_hole.z_index = 0
		bullet_hole_pool.append(bullet_hole)

func get_bullet_hole_from_pool() -> Node:
	"""Get a bullet hole from the pool or create a new one if pool is empty"""
	var bullet_hole: Node = null

	# Try to get from pool first
	if bullet_hole_pool.size() > 0:
		bullet_hole = bullet_hole_pool.pop_back()
		bullet_hole.visible = true
	else:
		# Pool is empty, create new instance
		bullet_hole = BulletHoleScene.instantiate()

	return bullet_hole

func return_bullet_hole_to_pool(bullet_hole: Node):
	"""Return a bullet hole to the pool for reuse"""
	bullet_hole.visible = false
	if bullet_hole not in bullet_hole_pool:
		bullet_hole_pool.append(bullet_hole)

	# Remove from active list
	active_bullet_holes.erase(bullet_hole)

func spawn_bullet_hole(local_pos: Vector2):
	"""Spawn a bullet hole at the specified local position"""
	# Use GPU instanced MultiMesh if available
	if bullet_hole_multimeshes.size() == 0:
		var bullet_hole = get_bullet_hole_from_pool()
		if bullet_hole:
			add_child(bullet_hole)
			bullet_hole.position = local_pos
			bullet_hole.z_index = 5
			if bullet_hole not in active_bullet_holes:
				active_bullet_holes.append(bullet_hole)
		return

	if bullet_hole_textures.size() == 0:
		return
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
	t.origin = local_pos

	multimesh.set_instance_transform_2d(current_count, t)
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

	# FAST PATH: Direct bullet hole spawning for WebSocket hits (non-rotating targets only)
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Fast path for WebSocket bullet hits - check zones first, then spawn appropriate effects"""

	# Don't process if target is disappearing
	if is_disappearing:
		return

	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)

	# Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false

	# Check if hard cover was hit first
	if is_point_in_zone("hard-cover", local_pos):
		zone_hit = "hard-cover"
		points = ScoreUtils.new().get_points_for_hit_area("hard-cover", 0)  # No score for hard cover
		is_target_hit = true
	# Check which zone was hit (highest score first)
	elif is_point_in_zone("head-0", local_pos):
		zone_hit = "head-0"
		points = ScoreUtils.new().get_points_for_hit_area("head-0", 0)
		is_target_hit = true
	elif is_point_in_zone("heart-0", local_pos):
		zone_hit = "heart-0"
		points = ScoreUtils.new().get_points_for_hit_area("heart-0", 0)
		is_target_hit = true
	elif is_point_in_zone("body-1", local_pos):
		zone_hit = "body-1"
		points = ScoreUtils.new().get_points_for_hit_area("body-1", -1)
		is_target_hit = true
	elif is_point_in_zone("other-3", local_pos):
		zone_hit = "other-3"
		points = ScoreUtils.new().get_points_for_hit_area("other-3", -3)
		is_target_hit = true
	else:
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", -5)
		is_target_hit = false

	# 2. CONDITIONAL: Only spawn bullet hole if target was actually hit (not hard cover or miss)
	if is_target_hit:
		spawn_bullet_hole(local_pos)

	# 3. ALWAYS: Spawn bullet effects (impact/sound) for all hits
	spawn_bullet_effects_at_position(world_pos, is_target_hit)

	# 4. Update score and emit signal (emit for all hits including misses for bootcamp stats)
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)

	# 5. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1

		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()

func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""

	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds

	# Load the effect scenes directly
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")

	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()


	# If this was a miss, spawn impact visual + sound. If it was a valid target hit,
	# only play the sound (faster and less noisy visually).
	if not _is_target_hit:
		if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
			var impact = bullet_impact_scene.instantiate()
			impact.global_position = world_pos
			effects_parent.add_child(impact)
			# Ensure impact effects appear above bullet holes
			impact.z_index = 15
			last_impact_time = time_stamp

	# Always play throttled impact sound (for both hits and misses)
	play_impact_sound_at_position_throttled(world_pos, time_stamp)

func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play steel impact sound effect with throttling and concurrent sound limiting"""
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return

	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return

	# Load and play the sound
	var audio_player = AudioStreamPlayer2D.new()
	var sound_stream = preload("res://audio/paper_hit.ogg")
	if sound_stream:
		audio_player.stream = sound_stream
		audio_player.global_position = world_pos
		audio_player.volume_db = -10  # Slightly quieter
		audio_player.max_distance = 1000  # Long range for target sounds

		# Find the scene root for audio
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)

		# Connect finished signal to clean up and track active sounds
		var _on_audio_finished = func():
			audio_player.queue_free()
			active_sounds = max(0, active_sounds - 1)
		audio_player.finished.connect(_on_audio_finished)

		audio_player.play()
		active_sounds += 1
		last_sound_time = current_time

func play_disappearing_animation():
	"""Play the disappearing animation when target is fully hit"""
	if is_disappearing:
		return

	is_disappearing = true

	# Get the animation player
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		animation_player.play("disappear")
		# Wait for animation to finish, then emit signal
		await animation_player.animation_finished

	# Emit the disappeared signal
	target_disappeared.emit()

func set_drill_active(active: bool):
	"""Enable or disable drill mode for this target"""
	drill_active = active

	if not DEBUG_DISABLED:
		print("IDPA Hard Cover 2 drill_active set to: ", active)

func _process(_delta):
	# Handle bullet activity monitoring for rotating targets
	if bullet_activity_count > activity_threshold:
		activity_cooldown_timer += _delta
		if activity_cooldown_timer >= activity_cooldown_duration:
			bullet_activity_count = 0
			activity_cooldown_timer = 0.0
			if animation_paused:
				resume_animation()
	else:
		activity_cooldown_timer = 0.0

func pause_animation():
	"""Pause the rotation animation when too many bullets are active"""
	if animation_paused:
		return

	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player and animation_player.is_playing():
		animation_player.pause()
		animation_paused = true

func resume_animation():
	"""Resume the rotation animation when bullet activity decreases"""
	if not animation_paused:
		return

	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		animation_player.play()
		animation_paused = false


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
			print("[IDPA-HARD-COVER-2] ERROR: Failed to load bullet hole texture ", i + 1)


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
