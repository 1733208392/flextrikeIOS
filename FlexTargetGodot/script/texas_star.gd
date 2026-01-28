extends Node2D

const PlateScene = preload("res://scene/texas_plate.tscn")
const BulletImpactScene = preload("res://scene/bullet_impact.tscn")
var metal_sound = null

@export var plate_count: int = 5
@export var radius: float = 200.0
@export var spin_decay: float = 0.97 # per frame multiplier approximation
@export var gravity_strength: float = 900.0
@export var max_angular_accel: float = 20.0

var plates: Array = []
var angular_velocity: float = 0.0
var _reset_pending: bool = false

func _make_circle_polygon(r: float, segments: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _ready():
	randomize()
	# load metal sound if available
	if ResourceLoader.exists("res://audio/metal_hit.WAV"):
		metal_sound = preload("res://audio/metal_hit.WAV")
	elif ResourceLoader.exists("res://audio/bullet-hit-metal.mp3"):
		metal_sound = preload("res://audio/bullet-hit-metal.mp3")
	# draw hub circle
	var hub_radius = min(40.0, radius * 0.18)
	var hub = Polygon2D.new()
	hub.polygon = _make_circle_polygon(hub_radius, 32)
	hub.color = Color(0.04, 0.04, 0.04)
	add_child(hub)

	# instantiate plates and arms
	_create_arms_and_plates()

	# Connect WebSocketListener.bullet_hit to this star's websocket handler (if available)
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		var cb = Callable(self, "websocket_bullet_hit")
		if not ws_listener.is_connected("bullet_hit", cb):
			ws_listener.bullet_hit.connect(cb)

func _create_arms_and_plates() -> void:
	plates.clear()
	for i in range(plate_count):
		var angle = i * TAU / plate_count
		# create visual arm
		var arm = Node2D.new()
		arm.name = "Arm_%d" % i
		add_child(arm)
		arm.rotation = angle
		# thin rectangular rod polygon (from center outward)
		var rod = Polygon2D.new()
		var rod_length = max(8.0, radius - 30.0)
		rod.polygon = PackedVector2Array([Vector2(0, -10), Vector2(rod_length, -10), Vector2(rod_length, 10), Vector2(0, 10)])
		rod.color = Color(0.08, 0.08, 0.08)
		arm.add_child(rod)
		# hinge marker at base of arm
		var hinge = Polygon2D.new()
		hinge.polygon = _make_circle_polygon(min(40.0, radius * 0.18) * 0.4, 16)
		hinge.color = Color(0.2, 0.2, 0.2)
		hinge.position = Vector2(0, 0)
		arm.add_child(hinge)
		# attach plate at end of arm
		var plate = PlateScene.instantiate()
		arm.add_child(plate)
		plate.position = Vector2(radius, 0)
		plate.rotation = 0
		plate.index = i
		plate.connect("fell", Callable(self, "_on_plate_fell"))
		plates.append(plate)

func reset_star() -> void:
	# remove arms and plates then recreate
	for child in get_children():
		if child.name.begins_with("Arm_"):
			child.queue_free()
	plates.clear()
	angular_velocity = 0.0
	_reset_pending = false
	_create_arms_and_plates()

func _schedule_reset(delay: float = 1.0) -> void:
	if _reset_pending:
		return
	_reset_pending = true
	call_deferred("_delayed_reset", delay)

func _delayed_reset(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	reset_star()

func _on_plate_fell(_plate_index):
	# Kick the hub into a randomized spin when any plate falls
	angular_velocity += randf_range(-6.0, 6.0)

func _physics_process(delta):
	# compute gravity-induced torque from remaining plates
	var torque: float = 0.0
	var I: float = 0.0
	for plate in plates:
		if not plate or not plate.is_inside_tree():
			continue
		# plate has `falling` flag when detached (safe read)
		var plate_falling = false
		var pf = null
		if plate.has_method("get"):
			pf = plate.get("falling")
		if pf != null:
			plate_falling = pf
		if plate_falling:
			continue
		# mass fallback (safe read)
		var m = 1.0
		var mval = null
		if plate.has_method("get"):
			mval = plate.get("mass")
		if mval != null:
			m = float(mval)
		# local position relative to hub center
		var local_pos = to_local(plate.global_position)
		# torque from gravity (gravity acts in +y direction in our coord space)
		torque += local_pos.x * m * gravity_strength
		I += m * local_pos.length_squared()

	if I > 0.0001:
		var angular_accel = torque / I
		# clamp to avoid too large jumps
		angular_accel = clamp(angular_accel, -max_angular_accel, max_angular_accel)
		angular_velocity += angular_accel * delta

	if abs(angular_velocity) > 0.00001:
		rotation += angular_velocity * delta
	# apply simple decay so spin slows down naturally
	angular_velocity = lerp(angular_velocity, 0.0, 1.0 - pow(spin_decay, delta * 60.0))

	# if all plates are falling/removed, schedule reset
	var remaining = 0
	for plate in plates:
		if not plate or not plate.is_inside_tree():
			continue
		var pf = null
		if plate.has_method("get"):
			pf = plate.get("falling")
		if pf == null or pf == false:
			remaining += 1
	if remaining == 0 and plates.size() > 0:
		_schedule_reset(1.0)

func _input(event):
	# Left mouse click simulates a bullet hit at mouse position
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var global_pos = get_global_mouse_position()
		websocket_bullet_hit(global_pos)

func websocket_bullet_hit(world_pos: Vector2, a: int = 0, t: int = 0) -> void:
	# spawn impact visual at world_pos
	var impact = null
	if BulletImpactScene:
		impact = BulletImpactScene.instantiate()
		# Attach to current scene for proper coordinates
		var tree = get_tree()
		if tree and tree.current_scene:
			tree.current_scene.add_child(impact)
		else:
			add_child(impact)
		impact.global_position = world_pos

	# check plates for hit inside their collision area
	var hit_any = false
	for plate in plates:
		if not plate or not plate.is_inside_tree():
			continue
		# Find any Area2D child (plate scenes may name it differently)
		var area = null
		if plate.has_node("PlateArea2D"):
			area = plate.get_node("PlateArea2D")
		else:
			for c in plate.get_children():
				if c is Area2D:
					area = c
					break
		if area == null:
			continue
		# find CollisionShape2D child of that area
		var cs = area.get_node_or_null("CollisionShape2D")
		if cs == null:
			# try any CollisionShape2D child
			for c2 in area.get_children():
				if c2 is CollisionShape2D:
					cs = c2
					break
		if cs == null or cs.shape == null:
			continue
		var shape = cs.shape
		# convert world_pos to plate local coordinates
		var local = plate.to_local(world_pos)
		if shape is CircleShape2D:
			if local.length() <= shape.radius:
				if plate.has_method("detach"):
					plate.detach()
				else:
					if plate.has_method("emit_signal"):
						plate.emit_signal("fell", plate)
					plate.hide()
				hit_any = true
				break
		elif shape is RectangleShape2D:
			var half = shape.size * 0.5
			if abs(local.x) <= half.x and abs(local.y) <= half.y:
				if plate.has_method("detach"):
					plate.detach()
				else:
					if plate.has_method("emit_signal"):
						plate.emit_signal("fell", plate)
					plate.hide()
				hit_any = true
				break

	# play metal sound only if we hit a plate
	if hit_any and metal_sound:
		var player = AudioStreamPlayer2D.new()
		player.stream = metal_sound
		add_child(player)
		player.global_position = world_pos
		player.play()
		# free after a short default duration
		var dur = 1.0
		call_deferred("_free_audio_player", player, dur)

func _free_audio_player(player: Node, dur: float) -> void:
	await get_tree().create_timer(dur).timeout
	if player and player.is_inside_tree():
		player.queue_free()
