extends Area2D

const DEBUG_DISABLED = false

# Bullet system - GPU instanced MultiMesh system (like custom_target)
var bullet_hole_multimesh: MultiMeshInstance2D = null
var bullet_hole_texture: Texture2D = null
var max_instances: int = 12
var active_instance_count: int = 0

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

# Bullet hole texture for Mozambique (blood splatter)
const BULLET_HOLE_TEXTURE_PATH = "res://asset/blood-splatter.png"

# Bullet visual effect
const BulletScene = preload("res://scene/bullet.tscn")

# Sound throttling for impact SFX
var last_sound_time: float = 0.0
var sound_cooldown: float = 0.05

# Animation state tracking
var is_disappearing: bool = false
var last_click_frame = -1

# Scoring system
var total_score: int = 0
var drill_active: bool = false
signal target_hit(zone: String, points: int, hit_position: Vector2)

# Mozambique drill specific variables
var drill_in_progress: bool = false
var restart_timer: Timer = null
var shot_timer_scene: Node = null

@onready var drill_complete_overlay = $drill_complete_overlay

# Drill state tracking
var shots_in_torso: int = 0
var shots_in_head: int = 0
var drill_start_time: float = 0.0
var first_shot_time: float = 0.0
var last_shot_time: float = 0.0
var fastest_shot_interval: float = 999.0
var drill_duration: float = 0.0
var drill_success: bool = false
var shot_times: Array[float] = []

func _ready():
	"""Initialize the mozambique target"""
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
	# Initialize GPU-instanced MultiMesh bullet hole system
	initialize_bullet_hole_multimesh()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("[Mozambique] Connected to WebSocketListener bullet_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("[Mozambique] WebSocketListener singleton not found!")
	
	# Get the drill complete overlay from the scene
	if drill_complete_overlay:
		drill_complete_overlay.visible = false
	
	if not DEBUG_DISABLED:
		print("[Mozambique] Target initialized")
	
	# Start the drill automatically
	start_drill()

func _on_input_event(_viewport, event, _shape_idx):
	"""Handle click events on the target"""
	if is_disappearing or not drill_in_progress or not drill_active:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		var world_pos = event.global_position
		
		# Process the hit (this will spawn bullet and play sound)
		handle_websocket_bullet_hit_fast(world_pos)

func spawn_bullet_at_position(pos: Vector2):
	"""Spawn a bullet at the specified world position"""
	if BulletScene:
		var bullet = BulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = pos
		_play_shot_sound()
		if not DEBUG_DISABLED:
			print("[Mozambique] Bullet spawned at position: ", pos)

func _play_shot_sound():
	"""Play a gunshot sound with cooldown"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time > sound_cooldown:
		last_sound_time = current_time

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Handle bullet hits with mozambique-specific logic"""
	if not DEBUG_DISABLED:
		print("[Mozambique] WebSocket hit at: ", world_pos, " drill_active: ", drill_active, " in_progress: ", drill_in_progress)
	
	if not drill_active or is_disappearing:
		if not DEBUG_DISABLED:
			print("[Mozambique] Hit ignored - drill_active: ", drill_active, " disappearing: ", is_disappearing)
		return
	
	# Convert to local coordinates
	var local_pos = to_local(world_pos)
	
	# Determine if hit is in valid area (head or torso only)
	var is_head_hit = _is_point_in_head(local_pos)
	var is_torso_hit = _is_point_in_torso(local_pos)
	
	# Record shot time (for all shots, including invalid ones)
	var shot_time = Time.get_ticks_msec() / 1000.0
	shot_times.append(shot_time)
	
	# Set first shot time on first hit
	if shots_in_torso + shots_in_head + 1 == 1:  # This will be true on first shot
		first_shot_time = shot_time
	
	# Calculate interval from last shot
	if shot_times.size() > 1:
		var interval = shot_times[-1] - shot_times[-2]
		if interval < fastest_shot_interval:
			fastest_shot_interval = interval
	
	# Track shots by area and check drill completion
	if is_torso_hit:
		shots_in_torso += 1
		if not DEBUG_DISABLED:
			print("[Mozambique] Torso hit! Count: ", shots_in_torso)
		_spawn_bullet_hole(local_pos)
		target_hit.emit("torso", 1, world_pos)
	elif is_head_hit:
		shots_in_head += 1
		if not DEBUG_DISABLED:
			print("[Mozambique] Head hit! Count: ", shots_in_head)
		_spawn_bullet_hole(local_pos)
		target_hit.emit("head", 1, world_pos)
	else:
		# Shot outside head/torso areas - still spawn effects but mark as failure
		if not DEBUG_DISABLED:
			print("[Mozambique] Shot outside head/torso areas - FAILURE")
	
	_play_shot_sound()
	
	# Spawn bullet visual feedback regardless of hit location
	spawn_bullet_at_position(world_pos)
	
	# Hide shot timer on first shot
	if shot_timer_scene and shot_timer_scene.visible:
		shot_timer_scene.visible = false
	
	# Check if drill is complete or failed
	_check_drill_completion()

func _is_point_in_head(point: Vector2) -> bool:
	"""Check if point is in the head collision area"""
	var head_node = get_node_or_null("head")
	if not head_node or not head_node is CollisionShape2D:
		return false
	
	var shape = head_node.shape
	if not shape:
		return false
	
	# Offset point by head position
	var local_point = point - head_node.position
	
	if shape is CircleShape2D:
		return local_point.length() <= shape.radius
	
	return false

func _is_point_in_torso(point: Vector2) -> bool:
	"""Check if point is in the torso collision area"""
	var torso_node = get_node_or_null("torso")
	if not torso_node or not torso_node is CollisionShape2D:
		return false
	
	var shape = torso_node.shape
	if not shape:
		return false
	
	# Offset point by torso position
	var local_point = point - torso_node.position
	
	if shape is RectangleShape2D:
		var rect = Rect2(-shape.size / 2, shape.size)
		return rect.has_point(local_point)
	
	return false

func _spawn_bullet_hole(local_position: Vector2):
	"""Spawn a blood splatter at the specified local position using GPU instancing"""
	if not bullet_hole_multimesh or not bullet_hole_multimesh.multimesh:
		if not DEBUG_DISABLED:
			print("[Mozambique] MultiMesh not initialized; skipping blood splatter spawn")
		return
	
	# Check if we have room for another instance
	if active_instance_count >= max_instances:
		if not DEBUG_DISABLED:
			print("[Mozambique] MultiMesh instance pool exhausted; skipping blood splatter spawn")
		return
	
	# Create transform with random rotation and scale
	var t = _reusable_transform
	var scale_factor = randf_range(0.5, 1.2)  # Same range as before
	var rotation = randf() * 2 * PI  # Full 360° rotation
	
	# Build transform properly: rotation matrix with scale, then set origin
	var cos_r = cos(rotation)
	var sin_r = sin(rotation)
	t.x = Vector2(cos_r * scale_factor, sin_r * scale_factor)
	t.y = Vector2(-sin_r * scale_factor, cos_r * scale_factor)
	
	# Add random position offset to the local position
	var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	t.origin = local_position + offset
	
	# Set the instance transform
	bullet_hole_multimesh.multimesh.set_instance_transform_2d(active_instance_count, t)
	bullet_hole_multimesh.multimesh.visible_instance_count = active_instance_count + 1
	active_instance_count += 1
	
	if not DEBUG_DISABLED:
		print("[Mozambique] Blood splatter spawned at local position: ", local_position, " (instance ", active_instance_count, ")")

func _check_drill_completion():
	"""Check if drill is complete and display results"""
	var drill_complete = false
	var success = false
	var total_shots = shots_in_torso + shots_in_head
	
	# Check for shots outside valid areas (head or torso)
	if shot_times.size() > total_shots:
		# A shot was fired outside head/torso - FAILURE
		drill_complete = true
		success = false
	# Mozambique pattern validation: check each shot immediately
	elif total_shots == 1:
		# First shot must be in torso
		if shots_in_torso == 1:
			# Valid so far, waiting for 2nd shot
			pass
		else:
			# First shot not in torso - FAILURE
			drill_complete = true
			success = false
	elif total_shots == 2:
		# Second shot must also be in torso
		if shots_in_torso == 2:
			# Valid so far, waiting for 3rd shot
			pass
		else:
			# Second shot not in torso - FAILURE
			drill_complete = true
			success = false
	elif total_shots == 3:
		# Third shot must be in head (pattern: 2 torso + 1 head)
		if shots_in_head == 1 and shots_in_torso == 2:
			# Perfect sequence - SUCCESS
			drill_complete = true
			success = true
		elif shots_in_head == 0 and shots_in_torso == 3:
			# All three shots in torso - FAILURE
			if not DEBUG_DISABLED:
				print("[Mozambique] FAILURE: All 3 shots in torso (expected 2 torso + 1 head)")
			drill_complete = true
			success = false
		else:
			# Any other pattern - FAILURE
			if not DEBUG_DISABLED:
				print("[Mozambique] FAILURE: Invalid pattern (head: ", shots_in_head, " torso: ", shots_in_torso, ")")
			drill_complete = true
			success = false
	
	if drill_complete:
		_finish_drill(success)

func _finish_drill(success: bool):
	"""Finish the drill and show results"""
	drill_in_progress = false
	drill_active = false
	drill_success = success
	drill_duration = (Time.get_ticks_msec() / 1000.0) - drill_start_time
	
	# Disable bullet spawning
	# var ws_listener = get_node_or_null("/root/WebSocketListener")
	# if ws_listener:
	# 	ws_listener.set_bullet_spawning_enabled(false)
	
	if not DEBUG_DISABLED:
		print("[Mozambique] Drill finished! Success: ", success, " Duration: ", drill_duration)
	
	# Wait a frame to allow bullet visual effects to render before showing overlay
	await get_tree().process_frame
	
	# Show stats overlay
	_show_stats_overlay()
	
	# Schedule restart after 8 seconds
	if restart_timer:
		restart_timer.queue_free()
	restart_timer = Timer.new()
	restart_timer.wait_time = 8.0
	restart_timer.one_shot = true
	restart_timer.timeout.connect(_restart_drill)
	add_child(restart_timer)
	restart_timer.start()

func _show_stats_overlay():
	"""Display the stats overlay with drill results"""
	if not DEBUG_DISABLED:
		print("[Mozambique] _show_stats_overlay called - drill_success: ", drill_success)
	
	if not drill_complete_overlay:
		if not DEBUG_DISABLED:
			print("[Mozambique] ERROR: drill_complete_overlay not found")
		return
	
	if drill_success:
		# Show success with detailed stats
		if not DEBUG_DISABLED:
			print("[Mozambique] Showing SUCCESS overlay with stats")
		var result_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ResultLabel")
		var duration_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/DurationLabel")
		var first_shot_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/FirstShotLabel")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/FastestShotLabel")
		
		if result_label:
			result_label.text = tr("SUCCESS")
			result_label.visible = true
		
		if duration_label:
			duration_label.text = tr("duration") + ": %.2f s" % drill_duration
			duration_label.visible = true
		
		if first_shot_label:
			var first_shot_delay = first_shot_time - drill_start_time
			first_shot_label.text = tr("first_shot") + ": %.2f s" % first_shot_delay
			first_shot_label.visible = true
		
		if fastest_shot_label:
			if fastest_shot_interval < 999.0:
				fastest_shot_label.text = tr("fastest_shot") + ": %.2f s" % fastest_shot_interval
			else:
				fastest_shot_label.text = tr("fastest_shot") + ": N/A"
			fastest_shot_label.visible = true
	else:
		# Show failure - no detailed stats
		if not DEBUG_DISABLED:
			print("[Mozambique] Showing FAILURE overlay")
		var result_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ResultLabel")
		if result_label:
			result_label.text = tr("FAILURE")
			result_label.visible = true
		
		# Hide the stats labels on failure
		var duration_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/DurationLabel")
		var first_shot_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/FirstShotLabel")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/FastestShotLabel")
		
		if duration_label:
			duration_label.visible = false
		if first_shot_label:
			first_shot_label.visible = false
		if fastest_shot_label:
			fastest_shot_label.visible = false
	
	# Set overlay z_index to render on top of bullet holes
	drill_complete_overlay.z_index = 2
	drill_complete_overlay.visible = true
	
	# Start countdown display
	_start_countdown_display()

func _restart_drill():
	"""Restart the drill"""
	if not DEBUG_DISABLED:
		print("[Mozambique] Restarting drill...")
	
	# Reset state
	shots_in_torso = 0
	shots_in_head = 0
	shot_times.clear()
	fastest_shot_interval = 999.0
	drill_success = false
	
	# Hide stats overlay
	if drill_complete_overlay:
		drill_complete_overlay.visible = false
	
	# Reset bullet holes
	_reset_bullet_hole_pool()
	
	# Enable bullet spawning for the new drill
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("[Mozambique] Bullet spawning enabled for restart")
	
	# Start shot timer
	_start_shot_timer()

func _start_countdown_display():
	"""Start displaying countdown on overlay"""
	var countdown_label = drill_complete_overlay.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/CountdownLabel")
	if not countdown_label:
		if not DEBUG_DISABLED:
			print("[Mozambique] CountdownLabel not found in overlay")
		return
	
	# Display countdown from 8 to 0
	for i in range(8, -1, -1):
		countdown_label.text = "(" + str(i) + ")"
		await get_tree().create_timer(1.0).timeout

func _start_shot_timer():
	"""Start the shot timer using the existing ShotTimer scene child node"""
	# Get the shot_timer scene from this node's children
	if not shot_timer_scene:
		# Try to find ShotTimer as a sibling in parent or in root
		shot_timer_scene = get_node_or_null("ShotTimer")
		
		if not shot_timer_scene:
			shot_timer_scene = get_parent().get_node_or_null("ShotTimer")
		
		if not shot_timer_scene:
			shot_timer_scene = get_tree().root.get_node_or_null("ShotTimer")
		
		if shot_timer_scene:
			# Connect timer ready signal
			if shot_timer_scene.has_signal("timer_ready"):
				shot_timer_scene.timer_ready.connect(_on_shot_timer_ready)
				if not DEBUG_DISABLED:
					print("[Mozambique] Connected to shot_timer ready signal")
		else:
			if not DEBUG_DISABLED:
				print("[Mozambique] ERROR: ShotTimer node not found - check scene structure")
			return
	
	# Make sure it's visible
	if shot_timer_scene:
		shot_timer_scene.visible = true
	
	if shot_timer_scene and shot_timer_scene.has_method("start_timer_sequence"):
		if not DEBUG_DISABLED:
			print("[Mozambique] Starting shot timer sequence")
		shot_timer_scene.start_timer_sequence()
	else:
		if not DEBUG_DISABLED:
			print("[Mozambique] ERROR: ShotTimer missing start_timer_sequence method")

func _on_shot_timer_ready(delay: float):
	"""Handle shot timer ready signal - delay is the random delay in seconds"""
	if not DEBUG_DISABLED:
		print("[Mozambique] Shot timer ready! Delay: %.2f seconds" % delay)
	
	# Activate drill (shot timer will be hidden when first shot is detected)
	drill_in_progress = true
	drill_active = true
	drill_start_time = Time.get_ticks_msec() / 1000.0
	
	if not DEBUG_DISABLED:
		print("[Mozambique] Drill activated!")

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	"""Handle WebSocket bullet hit signals"""
	if not DEBUG_DISABLED:
		print("[Mozambique] _on_websocket_bullet_hit called at: ", pos, " drill_active: ", drill_active, " in_progress: ", drill_in_progress)
	
	if not drill_active or not drill_in_progress:
		if not DEBUG_DISABLED:
			print("[Mozambique] Signal ignored")
		return
	
	handle_websocket_bullet_hit_fast(pos)

func _reset_bullet_hole_pool():
	"""Reset the MultiMesh instance count"""
	if bullet_hole_multimesh and bullet_hole_multimesh.multimesh:
		bullet_hole_multimesh.multimesh.visible_instance_count = 0
		active_instance_count = 0
	
	if not DEBUG_DISABLED:
		print("[Mozambique] MultiMesh instances reset")

func initialize_bullet_hole_multimesh():
	"""Initialize GPU-instanced MultiMesh bullet hole system"""
	
	# Load blood splatter texture
	bullet_hole_texture = load(BULLET_HOLE_TEXTURE_PATH)
	if not bullet_hole_texture:
		if not DEBUG_DISABLED:
			print("[Mozambique] ERROR: Failed to load blood splatter texture!")
		return
	
	# Create MultiMeshInstance2D
	bullet_hole_multimesh = MultiMeshInstance2D.new()
	add_child(bullet_hole_multimesh)
	bullet_hole_multimesh.z_index = 1
	
	# Create and configure MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.instance_count = max_instances
	multimesh.visible_instance_count = 0
	
	# Create mesh with blood splatter texture
	var mesh = create_bullet_hole_mesh(bullet_hole_texture)
	multimesh.mesh = mesh
	
	bullet_hole_multimesh.multimesh = multimesh
	
	# Try to propagate material/texture to the instance for compatibility across engine versions
	if mesh and mesh.material:
		for prop in bullet_hole_multimesh.get_property_list():
			if prop.name == "material":
				bullet_hole_multimesh.material = mesh.material
				if bullet_hole_multimesh.material is ShaderMaterial:
					bullet_hole_multimesh.material.set_shader_parameter("texture_albedo", bullet_hole_texture)
				break
	
	# Some engine versions expose a `texture` property on MultiMeshInstance2D
	for p in bullet_hole_multimesh.get_property_list():
		if p.name == "texture":
			bullet_hole_multimesh.set("texture", bullet_hole_texture)
			break
	
	active_instance_count = 0
	
	if not DEBUG_DISABLED:
		print("[Mozambique] MultiMesh bullet hole system initialized with ", max_instances, " instances")

func create_bullet_hole_mesh(texture: Texture2D) -> QuadMesh:
	"""Create a QuadMesh with a shader material for the provided texture"""
	var mesh = QuadMesh.new()
	mesh.size = texture.get_size()
	
	var shader_material = ShaderMaterial.new()
	var shader = load("res://shader/bullet_hole_instanced.gdshader")
	if shader:
		shader_material.shader = shader
		shader_material.set_shader_parameter("texture_albedo", texture)
	
	mesh.material = shader_material
	return mesh

func start_drill():
	"""Start the mozambique drill"""
	if not DEBUG_DISABLED:
		print("[Mozambique] Starting drill...")
	
	shots_in_torso = 0
	shots_in_head = 0
	shot_times.clear()
	fastest_shot_interval = 999.0
	drill_success = false
	
	# Enable bullet spawning if WebSocketListener exists
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("[Mozambique] Bullet spawning enabled")
	
	_start_shot_timer()

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0

func reset_target():
	"""Reset the target to its original state"""
	is_disappearing = false
	
	# Reset drill state
	shots_in_torso = 0
	shots_in_head = 0
	shot_times.clear()
	fastest_shot_interval = 999.0
	drill_success = false
	drill_in_progress = false
	drill_active = false
	
	# Reset visual properties
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	
	# Reset score
	reset_score()
	
	# Reset bullet hole pool
	_reset_bullet_hole_pool()
	
	if not DEBUG_DISABLED:
		print("[Mozambique] Target reset to original state")
