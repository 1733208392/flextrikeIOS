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
const DEBUG_DISABLED = false

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
	
	# Play reset animation to ensure scene starts in clean state
	reset_target_visual()

func _input(event: InputEvent):
	"""Handle mouse clicks to simulate websocket bullet hits for testing"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		if not DEBUG_DISABLED: print("[IDPA-NS] Mouse click at position: ", click_pos)
		_on_websocket_bullet_hit(click_pos)
		get_tree().root.set_input_as_handled()

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

		# Get the click position in local coordinates
		var local_pos = to_local(event.global_position)

		# Head zone has highest priority (0 points in IDPA-NS scoring)
		if is_point_in_zone("head-0", local_pos):
			return

		# Heart zone has high priority (0 points in IDPA-NS scoring)
		if is_point_in_zone("heart-0", local_pos):
			return

		# Body zone has medium priority (-1 points in IDPA-NS scoring)
		if is_point_in_zone("body-1", local_pos):
			return

		# Other zone has lowest priority (-3 points in IDPA-NS scoring)
		if is_point_in_zone("other-3", local_pos):
			return


func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	"""Check if a point (in Area2D local space) is in a collision zone"""
	# Find the collision shape by name
	var zone_node = get_node_or_null(zone_name)
	if not zone_node:
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Zone node not found: ", zone_name)
		return false
	
	if zone_node is CollisionPolygon2D:
		# For polygons, adjust point relative to the polygon's position
		var relative_point = point - zone_node.position
		var result = Geometry2D.is_point_in_polygon(relative_point, zone_node.polygon)
		if not DEBUG_DISABLED and result:
			print("[IDPA-NS] Point", point, "is in polygon zone", zone_name, "at relative pos", relative_point)
		return result
	elif zone_node is CollisionShape2D:
		# For shapes, check relative to the shape's position
		var shape = zone_node.shape
		if shape is CircleShape2D:
			var distance = point.distance_to(zone_node.position)
			var result = distance <= shape.radius
			if not DEBUG_DISABLED and result:
				print("[IDPA-NS] Point", point, "is in circle zone", zone_name, "distance:", distance, "radius:", shape.radius)
			return result
		elif shape is RectangleShape2D:
			var rect = Rect2(zone_node.position - shape.size / 2, shape.size)
			var result = rect.has_point(point)
			if not DEBUG_DISABLED and result:
				print("[IDPA-NS] Point", point, "is in rectangle zone", zone_name)
			return result
	
	if not DEBUG_DISABLED:
		print("[IDPA-NS] Point", point, "not in zone", zone_name)
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

	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()

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

	# Reset score
	reset_score()

	# Reset bullet hole pool - hide all active holes
	reset_bullet_hole_pool()


func reset_target_visual():
	"""Reset the visual state by playing the reset animation"""
	# Reset animation state
	is_disappearing = false

	# Reset shot count
	shot_count = 0

	# Reset score
	reset_score()

	# Reset bullet hole pool
	reset_bullet_hole_pool()
	
	# Play reset animation to ensure clean visual state
	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		animation_player.play("reset")
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Playing reset animation")
	else:
		# Fallback: manually set properties if animation player not found
		modulate = Color.WHITE
		rotation = 0.0
		scale = Vector2.ONE
		if not DEBUG_DISABLED:
			print("[IDPA-NS] WARNING: AnimationPlayer not found, manually reset properties")


func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""

	# Hide all active bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false

	# Clear active list
	active_bullet_holes.clear()


	# Reset GPU-instanced MultiMesh visible instance counts if present
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0


func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""
	# Initialize GPU-instanced bullet hole rendering system (ported from ipsc_mini.gd).
	# Creates a MultiMeshInstance2D for each bullet hole texture and parents them to the
	# Area2D so they move with the target when appropriate.

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
	# Create a MultiMesh instance for each texture
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

	if not DEBUG_DISABLED:
		print("[IDPA-NS] Initialized bullet hole pool with ", pool_size, " holes")


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

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""

	# Use GPU instanced MultiMesh if available
	if bullet_hole_multimeshes.size() == 0:
		var bullet_hole = get_pooled_bullet_hole()
		if bullet_hole:
			add_child(bullet_hole)
			bullet_hole.set_hole_position(local_position)
			bullet_hole.visible = true
			bullet_hole.z_index = 0
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

	var transform = Transform2D()
	var scale_factor = randf_range(0.6, 0.8)
	transform = transform.scaled(Vector2(scale_factor, scale_factor))
	transform.origin = local_position

	multimesh.set_instance_transform_2d(current_count, transform)
	multimesh.visible_instance_count = current_count + 1
	active_instances[texture_index] = current_count + 1

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):

	# Ignore shots if drill is not active yet
	if not drill_active:
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Ignoring WebSocket hit - drill not active")
		return

	handle_websocket_bullet_hit_ns(pos)

func handle_websocket_bullet_hit_ns(world_pos: Vector2):
	"""Handle WebSocket bullet hits with IDPA-NS specific scoring logic
	
	Scoring logic:
	- If hit in ns-5 collision area: -5 points
	- If not in ns-5, check zones:
	  - Head/Heart: 0 points
	  - Body: -1 point
	  - Other: -3 points
	  - Miss: -5 points
	"""

	# Don't process if target is disappearing
	if is_disappearing:
		return

	# Convert world position to local coordinates
	var local_pos = to_local(world_pos)

	# 1. Determine hit zone and scoring
	var zone_hit = ""
	var points = 0
	var is_target_hit = false

	# Check if point is in ns-5 collision area (highest priority - IDPA-NS specific zone)
	if is_point_in_zone("ns-5", local_pos):
		zone_hit = "ns-5"
		points = ScoreUtils.new().get_points_for_hit_area("ns-5", -5)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Hit detected in ns-5 zone at local_pos:", local_pos)
	# Head zone (0 points in IDPA-NS scoring)
	elif is_point_in_zone("head-0", local_pos):
		zone_hit = "head-0"
		points = ScoreUtils.new().get_points_for_hit_area("head-0", 0)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Hit detected in head-0 zone at local_pos:", local_pos)
	# Heart zone (0 points in IDPA-NS scoring)
	elif is_point_in_zone("heart-0", local_pos):
		zone_hit = "heart-0"
		points = ScoreUtils.new().get_points_for_hit_area("heart-0", 0)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Hit detected in heart-0 zone at local_pos:", local_pos)
	# Body zone (-1 point in IDPA-NS scoring)
	elif is_point_in_zone("body-1", local_pos):
		zone_hit = "body-1"
		points = ScoreUtils.new().get_points_for_hit_area("body-1", -1)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Hit detected in body-1 zone at local_pos:", local_pos)
	# Other zone (-3 points in IDPA-NS scoring)
	elif is_point_in_zone("other-3", local_pos):
		zone_hit = "other-3"
		points = ScoreUtils.new().get_points_for_hit_area("other-3", -3)
		is_target_hit = true
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Hit detected in other-3 zone at local_pos:", local_pos)
	else:
		# Miss
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", -5)
		is_target_hit = false
		if not DEBUG_DISABLED:
			print("[IDPA-NS] Miss detected at local_pos:", local_pos)

	# 2. Spawn bullet hole if target was actually hit
	if is_target_hit:
		spawn_bullet_hole(local_pos)
	
	# 3. Spawn bullet effects (impact/sound)
	spawn_bullet_effects_at_position(world_pos, is_target_hit)

	# 4. Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, world_pos)
	if not DEBUG_DISABLED:
		print("[IDPA-NS] Emitted target_hit signal: zone=", zone_hit, " points=", points, " pos=", world_pos)

	# 5. Increment shot count and check for disappearing animation (only for valid target hits)
	if is_target_hit:
		shot_count += 1

		# Check if we've reached the maximum valid target hits
		if shot_count >= max_shots:
			play_disappearing_animation()

func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
	"""Spawn bullet impact effects with throttling for performance"""

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
		var _on_audio_finished = func():
			active_sounds -= 1
			audio_player.queue_free()
		audio_player.finished.connect(_on_audio_finished)

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
		var _on_audio_finished_legacy = func():
			audio_player.queue_free()
		audio_player.finished.connect(_on_audio_finished_legacy)


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
			print("[IDPA-NS] ERROR: Failed to load bullet hole texture ", i + 1)


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
