extends Node2D

const DEBUG_DISABLE = false

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

signal target_disappeared

var drill_active: bool = false

# Animation state tracking
var is_disappearing: bool = false

# Shot tracking for disappearing animation - only valid target hits count
var shot_count: int = 0
@export var max_shots: int = 2  # Exported so scenes can override in the editor; default 2

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 8  # Keep 8 bullet holes pre-instantiated
var active_bullet_holes: Array[Node] = []

# GPU instanced bullet hole rendering (ported from `ipsc_mini.gd`)
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
const ScoreUtils = preload("res://script/score_utils.gd")
signal target_hit(zone: String, points: int, hit_position: Vector2, target_position: Vector2, target_rotation: float, t: int)

func _ready():
	# Initialize drill_active to false by default
	drill_active = false
	
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()
	
	# Z-index values are set manually in the editor
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Connected to WebSocketListener bullet_hit signal")
	else:
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] WebSocketListener singleton not found!")
	
	# NOTE: Animation will start when paddle is hit and falls down
	# var animation_player = get_node_or_null("AnimationPlayer")
	# if animation_player:
	#     if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Starting continuous random animation sequence")
	#     _play_random_animations_continuous(animation_player)
	
	# If loaded by drills_network (networked drills loader), set max_shots high for testing
	var drills_network = get_node_or_null("/root/drills_network")
	if drills_network:
		max_shots = 1000

func _input(event):
	"""Handle mouse clicks for testing - simulate websocket bullet hits"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Simulate websocket bullet hit at mouse position
		var mouse_pos = get_global_mouse_position()
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Mouse click simulated bullet hit at: %s" % mouse_pos)
		_on_websocket_bullet_hit(mouse_pos)

func _play_random_animations_continuous(animation_player: AnimationPlayer):
	"""Continuously play random sequences of the available animations"""
	while true:
		var animations = ["right", "up"]
		animations.shuffle()  # Randomize the order each sequence
		
		for anim in animations:
			animation_player.play(anim)
			if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Playing animation: %s" % anim)
			await animation_player.animation_finished

func handle_websocket_bullet_hit_rotating(world_pos: Vector2, t: int = 0) -> void:
	"""Optimized hit processing for rotating targets without bullet spawning"""
	
	# Don't process if target is disappearing
	if is_disappearing:
		return

	# Don't process if drill is not active (deactivated by drills_network)
	if not drill_active:
		if not DEBUG_DISABLE:
			print("[ipsc_mini_rotate] Ignoring bullet hit because drill_active is false")
		return
	
	# Get the IPSCMini child node
	var ipsc_mini = get_node_or_null("IPSCMini")
	if not ipsc_mini:
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] IPSCMini child not found")
		return
	
	# Convert world position to local coordinates (this handles rotation automatically)
	var local_pos = ipsc_mini.to_local(world_pos)
	
	# 1. FIRST: Check if bullet hit the BarrelWall (for rotating targets)
	var barrel_wall_hit = false
	var barrel_wall = get_node_or_null("BarrelWall")
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
		points = ScoreUtils.new().get_points_for_hit_area("miss", 0)
		is_target_hit = false
	else:
		# Check target zones (highest score first)
		if is_point_in_zone(ipsc_mini, "AZone", local_pos):
			zone_hit = "AZone"
			is_target_hit = true
		elif is_point_in_zone(ipsc_mini, "CZone", local_pos):
			zone_hit = "CZone"
			is_target_hit = true
		elif is_point_in_zone(ipsc_mini, "DZone", local_pos):
			zone_hit = "DZone"
			is_target_hit = true
		else:
			zone_hit = "miss"
			is_target_hit = false

		# Lookup points from settings (or fallback)
		points = ScoreUtils.new().get_points_for_hit_area(zone_hit, 0)
	
	# 3. CONDITIONAL: Only spawn bullet hole if target was actually hit
	if not DEBUG_DISABLE: print("[ipsc_mini_rotate] zone_hit: %s, is_target_hit: %s, local_pos: %s" % [zone_hit, is_target_hit, local_pos])
	if is_target_hit:
		spawn_bullet_hole(ipsc_mini, local_pos)
		play_impact_sound_at_position_throttled(world_pos, Time.get_ticks_msec() / 1000.0)
	
	# 4. ALWAYS: Spawn bullet effects (impact/sound) but skip smoke for misses
	else:
		spawn_bullet_effects_at_position(world_pos, is_target_hit)
	
	# 5. Update score and emit signal for actual target hits or misses (but not paddle hits)
	var should_emit = is_target_hit or zone_hit == "miss" or zone_hit == "barrel_miss"
	if should_emit:
		if is_target_hit:
			total_score += points
		target_hit.emit(zone_hit, points, world_pos, ipsc_mini.global_position, ipsc_mini.global_rotation, t)
		
		# 6. Increment shot count and check for disappearing animation (only for valid target hits)
		if is_target_hit:
			shot_count += 1
			
			# Check if we've reached the maximum valid target hits
			if shot_count >= max_shots:
				play_disappearing_animation()

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	"""Handle websocket bullet hit - check if it hits the paddle or target"""
	# Ignore hits when target is deactivated by drills_network
	if not drill_active:
		if not DEBUG_DISABLE:
			print("[ipsc_mini_rotate] _on_websocket_bullet_hit ignored because drill_active is false")
		return
	# First check if it hits the paddle
	var paddle = get_node_or_null("Paddle/Paddle")
	if paddle:
		# Get the circle area collision shape from the paddle
		var circle_area = paddle.get_node_or_null("CircleArea")
		if circle_area:
			# Get the circle shape
			var circle_shape = circle_area.shape
			if circle_shape and circle_shape is CircleShape2D:
				# Calculate the circle area position in global coordinates
				var circle_global_pos = circle_area.global_position
				var circle_radius = circle_shape.radius
				
				# Convert hit position to circle's local space
				var hit_local_pos = pos - circle_global_pos
				var distance = hit_local_pos.length()
				
				# Check if the hit is within the circle area
				if distance <= circle_radius:
					if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Paddle hit detected at position %s, distance: %.2f, radius: %.2f" % [pos, distance, circle_radius])
					
					# Play metal hit sound for paddle
					play_paddle_hit_sound(pos)
					
					# Disable the collision area to prevent further hits
					circle_area.disabled = true
					if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Disabled paddle collision area")
					
					# Trigger the fall_down animation on the paddle
					var paddle_animation_player = paddle.get_node_or_null("AnimationPlayer")
					if paddle_animation_player:
						# Connect to animation finished signal to remove paddle when done
						if not paddle_animation_player.animation_finished.is_connected(_on_paddle_animation_finished):
							paddle_animation_player.animation_finished.connect(_on_paddle_animation_finished)
						
						paddle_animation_player.play("fall_down")
						if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Triggered paddle fall_down animation")
					else:
						if not DEBUG_DISABLE: print("[ipsc_mini_rotate] AnimationPlayer not found in paddle")
					return  # Paddle hit, don't process target hit
	
	# If not paddle hit, process as target hit
	handle_websocket_bullet_hit_rotating(pos, t)

func is_point_in_zone(target_node: Node, zone_name: String, point: Vector2) -> bool:
	"""Check if a point is within a specific zone of the target node"""
	# Find the collision shape by name
	var zone_node = target_node.get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		var inside = Geometry2D.is_point_in_polygon(point, zone_node.polygon)
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Checking zone %s at point %s, inside: %s" % [zone_name, point, inside])
		return inside
	if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Zone %s not found or not CollisionPolygon2D" % zone_name)
	return false

func spawn_bullet_hole(target_node: Node, local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""
	if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Spawning bullet hole at local pos: %s" % local_position)

	# Use GPU instanced MultiMesh if available (ported from ipsc_mini.gd)
	if bullet_hole_multimeshes.size() == 0:
		# Fallback to legacy node pool if instancing hasn't been initialized
		var bullet_hole = get_pooled_bullet_hole()
		if bullet_hole:
			target_node.add_child(bullet_hole)
			bullet_hole.position = local_position
			bullet_hole.visible = true
			if bullet_hole not in active_bullet_holes:
				active_bullet_holes.append(bullet_hole)
		else:
			if not DEBUG_DISABLE: print("[ipsc_mini_rotate] No bullet hole available from pool (fallback)")
		return

	# Randomly choose a texture/index
	if bullet_hole_textures.size() == 0:
		return
	var texture_index = randi() % bullet_hole_textures.size()
	if texture_index >= bullet_hole_multimeshes.size():
		return

	var mm_inst = bullet_hole_multimeshes[texture_index]
	var multimesh = mm_inst.multimesh
	var current_count = active_instances.get(texture_index, 0)
	if current_count >= max_instances_per_texture:
		# Pool exhausted for this texture
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

func spawn_bullet_effects_at_position(world_pos: Vector2, _is_target_hit: bool = true):
	"""Spawn bullet smoke and impact effects with throttling for performance"""
	var time_stamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Load the effect scenes directly
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")
	
	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()
	
	# Throttled impact effect - ALWAYS spawn (for both hits and misses)
	if bullet_impact_scene and (time_stamp - last_impact_time) >= impact_cooldown:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = world_pos
		effects_parent.add_child(impact)
		# Z-index is set manually in the editor
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

func play_paddle_hit_sound(world_pos: Vector2):
	"""Play metal hit sound for paddle hits"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return
	
	# Load the metal hit sound for paddle
	var metal_sound = preload("res://audio/metal_hit.WAV")
	
	if metal_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = metal_sound
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

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	is_disappearing = true
	
	# Get the IPSCMini child node
	var ipsc_mini = get_node_or_null("IPSCMini")
	if not ipsc_mini:
		if not DEBUG_DISABLE: print("[ipsc_mini_rotate] IPSCMini child not found for disappearing animation")
		return
	
	# Get the AnimationPlayer from the child
	var animation_player = ipsc_mini.get_node("AnimationPlayer")
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
	
	# Keep the disappearing state active to prevent any further interactions
	# is_disappearing remains true

func _on_paddle_animation_finished(animation_name: String):
	"""Called when paddle animation finishes"""
	if animation_name == "fall_down":
		# Remove the paddle from the scene
		var paddle = get_node_or_null("Paddle/Paddle")
		if paddle:
			paddle.queue_free()
			if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Removed paddle from scene after fall_down animation")
		
		# Start the ipsc_mini animation sequence now that paddle has fallen
		var animation_player = get_node_or_null("AnimationPlayer")
		if animation_player:
			if not DEBUG_DISABLE: print("[ipsc_mini_rotate] Starting ipsc_mini animation sequence after paddle fall")
			_play_random_animations_continuous(animation_player)

func reset_target():
	"""Reset the target to its original state (useful for restarting)"""
	# Reset animation state
	is_disappearing = false
	
	# Reset shot count
	shot_count = 0
	
	# Reset visual properties
	var ipsc_mini = get_node_or_null("IPSCMini")
	if ipsc_mini:
		ipsc_mini.modulate = Color.WHITE
		ipsc_mini.rotation = 0.0
		ipsc_mini.scale = Vector2.ONE
	
	_reset_local_paddle()
	
	# Reset score
	reset_score()
	
	# Reset bullet hole pool - hide all active holes
	reset_bullet_hole_pool()

func reset_score():
	"""Reset the score to zero"""
	total_score = 0

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_bullet_hole_pool():
	"""Reset the bullet hole pool by hiding all active holes"""
	# Reset GPU-instanced MultiMesh visible instance counts
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0

	# Fallback: hide any legacy node-pool bullet holes
	for hole in active_bullet_holes:
		if is_instance_valid(hole):
			hole.visible = false

	# Clear active list
	active_bullet_holes.clear()

func reset_paddle():
	"""External hook used by bootcamp to restore a disconnected paddle"""
	_reset_local_paddle()

func _reset_local_paddle():
	var paddle = get_node_or_null("Paddle/Paddle")
	if not paddle:
		return
	if paddle.has_method("reset_paddle"):
		paddle.reset_paddle()
		return

func initialize_bullet_hole_pool():
	"""Initialize GPU-instanced bullet hole rendering system (ported from ipsc_mini.gd).
	Creates a MultiMeshInstance2D for each bullet hole texture and parents them to the
	`IPSCMini` child so they rotate/move with the target.
	"""

	# Clear any existing multimeshes
	for multimesh in bullet_hole_multimeshes:
		if is_instance_valid(multimesh):
			multimesh.queue_free()
	bullet_hole_multimeshes.clear()
	bullet_hole_textures.clear()
	active_instances.clear()

	# Load bullet hole textures
	load_bullet_hole_textures()

	# Determine parent for multimesh instances (prefer IPSCMini child so holes rotate with it)
	var parent_node = get_node_or_null("IPSCMini")
	if not parent_node:
		parent_node = self

	# Create a MultiMesh instance for each texture
	for i in range(bullet_hole_textures.size()):
		var multimesh_instance = MultiMeshInstance2D.new()
		parent_node.add_child(multimesh_instance)
		multimesh_instance.z_index = 0

		# Create and configure the MultiMesh
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.instance_count = max_instances_per_texture
		multimesh.visible_instance_count = 0

		# Create mesh for this texture
		var mesh = create_bullet_hole_mesh(bullet_hole_textures[i])
		multimesh.mesh = mesh
		multimesh_instance.multimesh = multimesh

		# Try to attach material/texture to the instance if supported
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

		# Additional attempt to set a 'texture' property if present
		for p in multimesh_instance.get_property_list():
			if p.name == "texture":
				multimesh_instance.set("texture", bullet_hole_textures[i])
				break

		bullet_hole_multimeshes.append(multimesh_instance)
		active_instances[i] = 0  # Track active instances for this texture

	# Keep legacy node pool arrays intact for fallback

func get_pooled_bullet_hole() -> Node:
	"""Minimal fallback: return an inactive pooled node or instantiate a new one."""
	for hole in bullet_hole_pool:
		if is_instance_valid(hole) and not hole.visible:
			return hole

	if BulletHoleScene:
		var new_hole = BulletHoleScene.instantiate()
		bullet_hole_pool.append(new_hole)
		return new_hole

	return null


func return_bullet_hole_to_pool(hole: Node):
	if is_instance_valid(hole):
		hole.visible = false
		if hole in active_bullet_holes:
			active_bullet_holes.erase(hole)

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

func setup_z_index_layering():
	"""Set up proper z-index layering for visual elements"""
	# Z-index values are now set manually in the editor
	pass


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
