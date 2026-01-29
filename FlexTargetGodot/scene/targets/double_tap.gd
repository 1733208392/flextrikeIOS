extends Area2D

const DEBUG_DISABLED = true

# Animation state tracking
var is_disappearing: bool = false
var last_click_frame = -1

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")

# Bullet hole pool for performance optimization
var bullet_hole_pool: Array[Node] = []
var pool_size: int = 12
var active_bullet_holes: Array[Node] = []

# Effect throttling for performance optimization
var last_sound_time: float = 0.0
var sound_cooldown: float = 0.05

# Scoring system - using AZero from IPSC mini target
var drill_active: bool = false
signal target_hit(zone: String, points: int, hit_position: Vector2)

# Double Tap specific variables
var drill_in_progress: bool = false
var restart_timer: Timer = null
var shot_timer_scene: Node = null

@onready var drill_complete_overlay = $double_tap_complete_overlay

# Drill state tracking
var total_shots: int = 0
var shots_in_a_zone: int = 0
var drill_start_time: float = 0.0
var shot_times: Array[float] = []
var drill_success: bool = false

func _ready():
	"""Initialize the Double Tap target"""
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
	# Initialize bullet hole pool
	_initialize_bullet_hole_pool()
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		ws_listener.set_bullet_spawning_enabled(true)
	
	# Hide overlay initially
	if drill_complete_overlay:
		drill_complete_overlay.visible = false
	
	# Small delay before starting first drill
	await get_tree().create_timer(1.5).timeout
	_start_shot_timer()

func _on_input_event(_viewport, event, _shape_idx):
	"""Handle click events on the target"""
	if is_disappearing or not drill_in_progress or not drill_active:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		handle_websocket_bullet_hit_fast(event.global_position)

func _on_websocket_bullet_hit(pos: Vector2, _a: int = 0, _t: int = 0):
	"""Handle WebSocket bullet hit signals"""
	handle_websocket_bullet_hit_fast(pos)

func handle_websocket_bullet_hit_fast(world_pos: Vector2):
	"""Process hit with Double Tap logic"""
	if not drill_active or is_disappearing or total_shots >= 2:
		return
	
	# Filter out shots that are outside the valid 720x1280 space
	# This avoids invalid shots being detected by the beep sound
	if world_pos.x < 0 or world_pos.x > 720 or world_pos.y < 0 or world_pos.y > 1280:
		if not DEBUG_DISABLED:
			print("[Double Tap] Filtering out invalid shot at: ", world_pos)
		return

	# Record shot time
	var shot_time = Time.get_ticks_msec() / 1000.0
	
	# Convert to local coordinates
	var local_pos = to_local(world_pos)
	
	# Determine hit zone
	var is_a_zone = _is_point_in_zone("AZone", local_pos)
	var is_c_zone = _is_point_in_zone("CZone", local_pos)
	var is_d_zone = _is_point_in_zone("DZone", local_pos)
	var is_on_target = is_a_zone or is_c_zone or is_d_zone

	# Update stats
	total_shots += 1
	shot_times.append(shot_time)
	
	if is_a_zone:
		shots_in_a_zone += 1
		target_hit.emit("AZone", 5, world_pos)
	elif is_c_zone:
		target_hit.emit("CZone", 3, world_pos)
	elif is_d_zone:
		target_hit.emit("DZone", 1, world_pos)
	else:
		target_hit.emit("miss", 0, world_pos)

	# Visual feedback
	if is_on_target:
		_spawn_bullet_hole(local_pos)
	
	_play_shot_sound()
	_spawn_bullet_visual(world_pos)
	
	# Auto-stop after 2 shots
	if total_shots >= 2:
		_check_drill_completion()

func _is_point_in_zone(zone_name: String, local_pt: Vector2) -> bool:
	"""Check if point is inside a specific target zone polygon"""
	var zone = get_node_or_null(zone_name)
	if zone and zone is CollisionPolygon2D:
		return Geometry2D.is_point_in_polygon(local_pt, zone.polygon)
	return false

func _spawn_bullet_visual(pos: Vector2):
	"""Spawn a bullet visual effect"""
	if BulletScene:
		var bullet = BulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = pos

func _play_shot_sound():
	"""Play a shot sound with throttling"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time > sound_cooldown:
		last_sound_time = current_time
		# Sound is usually handled by the bullet scene or specialized player

func _initialize_bullet_hole_pool():
	"""Create a pool of bullet hole nodes"""
	for i in range(pool_size):
		var hole = BulletHoleScene.instantiate()
		add_child(hole)
		hole.visible = false
		bullet_hole_pool.append(hole)

func _get_bullet_hole_from_pool() -> Node:
	if bullet_hole_pool.size() > 0:
		return bullet_hole_pool.pop_back()
	return BulletHoleScene.instantiate()

func _spawn_bullet_hole(local_pos: Vector2):
	var hole = _get_bullet_hole_from_pool()
	if hole.has_method("set_hole_position"):
		hole.set_hole_position(local_pos)
	else:
		hole.position = local_pos
	hole.visible = true
	active_bullet_holes.append(hole)

func _reset_bullet_hole_pool():
	for hole in active_bullet_holes:
		hole.visible = false
		bullet_hole_pool.append(hole)
	active_bullet_holes.clear()

func _check_drill_completion():
	"""Determine success and finish drill"""
	drill_success = (shots_in_a_zone == 2)
	_finish_drill(drill_success)

func _finish_drill(success: bool):
	"""Finish the drill and show results"""
	drill_in_progress = false
	drill_active = false
	
	var total_duration = 0.0
	if shot_times.size() > 0:
		total_duration = shot_times[-1] - drill_start_time
	
	_show_stats_overlay(success, total_duration)
	
	# Schedule restart
	if restart_timer: restart_timer.queue_free()
	restart_timer = Timer.new()
	restart_timer.wait_time = 8.0
	restart_timer.one_shot = true
	restart_timer.timeout.connect(_restart_drill)
	add_child(restart_timer)
	restart_timer.start()

func _show_stats_overlay(success: bool, duration: float):
	if not drill_complete_overlay: return
	
	var v_box = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer")
	if not v_box: return
	
	var res_lbl = v_box.get_node_or_null("ResultLabel")
	var s1_lbl = v_box.get_node_or_null("Shot1Label")
	var s2_lbl = v_box.get_node_or_null("Shot2Label")
	var dur_lbl = v_box.get_node_or_null("DurationLabel")
	
	if res_lbl:
		res_lbl.text = tr("SUCCESS") if success else tr("FAILURE")
		res_lbl.label_settings.font_color = Color.GREEN if success else Color.RED
	
	if s1_lbl and shot_times.size() >= 1:
		s1_lbl.text = tr("shot_1") + ": %.2f s" % (shot_times[0] - drill_start_time)
	
	if s2_lbl and shot_times.size() >= 2:
		var split_time = shot_times[1] - shot_times[0]
		s2_lbl.text = tr("shot_2") + ": %.2f s" % split_time
	
	if dur_lbl:
		dur_lbl.text = tr("total") + ": %.2f s" % duration

	drill_complete_overlay.visible = true
	_start_countdown_display()

func _start_countdown_display():
	var countdown_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/CountdownLabel")
	if not countdown_label: return
	
	for i in range(8, -1, -1):
		if not is_instance_valid(self) or not drill_complete_overlay.visible: break
		countdown_label.text = "(%d)" % i
		await get_tree().create_timer(1.0).timeout

func _restart_drill():
	"""Reset state and start a new sequence"""
	total_shots = 0
	shots_in_a_zone = 0
	shot_times.clear()
	drill_success = false
	
	if drill_complete_overlay:
		drill_complete_overlay.visible = false
	
	_reset_bullet_hole_pool()
	_start_shot_timer()

func _start_shot_timer():
	"""Trigger the shot timer sequence"""
	if not shot_timer_scene:
		shot_timer_scene = get_node_or_null("ShotTimer")
	
	if shot_timer_scene:
		if not shot_timer_scene.timer_ready.is_connected(_on_shot_timer_ready):
			shot_timer_scene.timer_ready.connect(_on_shot_timer_ready)
		
		# Set the Double Tap specific delay range (2-4s)
		shot_timer_scene.min_delay = 2.0
		shot_timer_scene.max_delay = 4.0
		
		shot_timer_scene.visible = true
		shot_timer_scene.start_timer_sequence()

func _on_shot_timer_ready(_delay: float):
	"""Called when the beep sounds"""
	drill_in_progress = true
	drill_active = true
	drill_start_time = Time.get_ticks_msec() / 1000.0
