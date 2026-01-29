extends Node2D

# Emitted when the ClearArea is clicked; scenes can connect to this to perform
# a custom restart. As a fallback the spawner will reload the current scene
# so the game restarts even if nothing is connected.
signal restart_requested

@export var pool_size: int = 24
@export var base_splat_size: int = 128
@export var min_splat_radius: float = 48.0
@export var draw_layer: NodePath = NodePath("CanvasLayer")

# Prompt gating: only spawn splat when the click is inside the prompt
# Enable in inspector to require prompt hit. You can set either a `prompt_center_node`
# (NodePath to a Node2D) or a fixed `prompt_center_pos` (Vector2). If `prompt_center_node`
# is set and resolves to a Node2D its `global_position` will be used.
@export var prompt_use_stem_manager: bool = true
@export var prompt_center_pos: Vector2 = Vector2.ZERO
@export var prompt_radius: float = 50.0
@export var prompt_stem_manager_node: NodePath = NodePath("")
@export var snapshot_node: NodePath = NodePath("")
@export var capture_manager_node: NodePath = NodePath("CaptureManager")
@export var capture_area_node: NodePath = NodePath("../../CaptureManager/Overlay/UI/CpatureArea")

var rng := RandomNumberGenerator.new()
var pool: Array = []
var noise_tex: Texture2D
var base_splat_texture: Texture2D
var splat_shader: Shader
var draw_parent: Node
@export var debug_draw: bool = false
@export var prompt_clear_area_node: NodePath = NodePath("")

func _ready():
	rng.randomize()
	# updated shader path to moved location
	splat_shader = load("res://games/shoot-painter/shader/splat.gdshader")
	_make_noise_texture(32)
	base_splat_texture = _make_base_splat_image(base_splat_size)
	_create_pool()
	draw_parent = get_node_or_null(draw_layer)
	if not draw_parent:
		draw_parent = self

	# If debug drawing is enabled, ensure this node processes so _draw() runs
	if debug_draw:
		set_process(true)

	# Listen for bullet hits coming from the WebSocket listener (for remote firing)
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		ws_listener.menu_control.connect(_on_menu_control)
		if debug_draw:
			print("[SplatSpawner] Connected to WebSocketListener bullet_hit signal")

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# spawn_splat will check prompt gating if enabled
		spawn_splat(event.position, randf_range(min_splat_radius, 96.0), Color.from_hsv(rng.randf(), 0.8, 0.9))

func _on_websocket_bullet_hit(global_pos: Vector2, a: int = 0, t: int = 0) -> void:
	if not is_inside_tree():
		return
	# Use the existing spawn logic (which already respects snapshot/clear areas)
	# if _handle_capture_area_hit(global_pos):
	# 	return
	spawn_splat(global_pos, randf_range(min_splat_radius, 96.0), Color.from_hsv(rng.randf(), 0.8, 0.9))

func _process(_delta: float) -> void:
	if debug_draw:
		queue_redraw()

func _on_menu_control(directive: String) -> void:
	if directive == "homepage":
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
	elif directive == "back":
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")

func _is_in_prompt(global_pos: Vector2) -> bool:

	# If configured to use the stem manager, consult its ready tip positions.
	# NOTE: There is no fallback to a single-center prompt when stem manager usage
	# is requested — if the manager node is missing or doesn't expose
	# get_ready_tip_positions(), the prompt will be considered not hit.
	if not prompt_stem_manager_node:
		return false
	var mgr = get_node_or_null(prompt_stem_manager_node)
	if not mgr or not mgr.has_method("get_ready_tip_positions"):
		return false
	var tips = mgr.get_ready_tip_positions()
	for t in tips:
		if t.distance_to(global_pos) <= prompt_radius:
			return true
	return false

func _make_noise_texture(size: int):
	var img = Image.create(size, size, false, Image.FORMAT_R8)
	for y in range(size):
		for x in range(size):
			var v = rng.randf()
			img.set_pixel(x, y, Color(v, 0, 0))
	noise_tex = ImageTexture.create_from_image(img)

func _make_base_splat_image(size: int) -> Texture2D:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(float(size) / 2.0, float(size) / 2.0)
	for y in range(size):
		for x in range(size):
			var d = center.distance_to(Vector2(x, y)) / (size * 0.5)
			var a = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.4)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _create_pool():
	for i in range(pool_size):
		var inst = _create_splat_instance()
		add_child(inst)
		pool.append(inst)

func _get_pooled() -> Node2D:
	for s in pool:
		var sprite = s.get_node_or_null("Sprite") as Sprite2D
		if sprite and not sprite.visible:
			return s
	var inst = _create_splat_instance()
	add_child(inst)
	pool.append(inst)
	return inst

func _create_splat_instance() -> Node2D:
	var inst := Node2D.new()
	var sprite = _configure_sprite(inst)
	sprite.visible = false
	return inst

func _configure_sprite(inst: Node2D) -> Sprite2D:
	var sprite = inst.get_node_or_null("Sprite") as Sprite2D
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		inst.add_child(sprite)
	if base_splat_texture:
		sprite.texture = base_splat_texture
	var mat = sprite.material
	if mat and mat is ShaderMaterial:
		if splat_shader and mat.shader != splat_shader:
			mat.shader = splat_shader
	else:
		mat = ShaderMaterial.new()
		mat.shader = splat_shader
		sprite.material = mat
	if mat and splat_shader:
		mat.set_shader_parameter("noise_tex", noise_tex)
	sprite.centered = true
	return sprite

func spawn_splat(global_pos: Vector2, radius := 64.0, color := Color(1, 0.2, 0.2)):
	# If a Snapshot area is configured and the click is inside it, trigger
	# the CaptureManager's handler and do not spawn a splat.
	if snapshot_node != NodePath(""):
		var snap = get_node_or_null(snapshot_node)
		if snap and snap.has_method("get_global_rect"):
			if snap.get_global_rect().has_point(global_pos):
				var cap_node: Node = null
				if capture_manager_node != NodePath(""):
					cap_node = get_node_or_null(capture_manager_node)
				if not cap_node:
					cap_node = get_node_or_null("CaptureManager")
				if cap_node:
					if cap_node.has_method("_on_capture_pressed"):
						cap_node._on_capture_pressed()
					elif cap_node.has_method("capture_canvas"):
						cap_node.capture_canvas()
				return

	# If a ClearArea is configured and the click is inside it, treat this as
	# a restart request rather than spawning a splat. Emit a signal so the
	# scene can handle restart; as a fallback reload the current scene.
	if prompt_clear_area_node != NodePath(""):
		var clear_node = get_node_or_null(prompt_clear_area_node)
		if clear_node and clear_node.has_method("get_global_rect"):
			if clear_node.get_global_rect().has_point(global_pos):
				emit_signal("restart_requested")
				# Fallback reload to ensure restart happens even if nobody
				# connected to the signal.
				get_tree().reload_current_scene()
				return

	
	# Respect prompt gating: if enabled, only spawn when inside prompt
	if not _is_in_prompt(global_pos):
		return

	# If using the stem manager prompt, attempt to consume the matching tip so
	# a prompt can only be used once.
	if prompt_use_stem_manager and prompt_stem_manager_node != NodePath(""):
		var mgr = get_node_or_null(prompt_stem_manager_node)
		if mgr and mgr.has_method("consume_tip_at_position"):
			var consumed = mgr.consume_tip_at_position(global_pos, prompt_radius)
			if not consumed:
				# Either no tip matched or it was already consumed; do not spawn
				return

	var inst = _get_pooled()
	var sprite = inst.get_node_or_null("Sprite") as Sprite2D
	if not sprite:
		sprite = _configure_sprite(inst)
	sprite.visible = true
	var sscale = clamp(radius / float(base_splat_size) * 2.0, 0.2, 3.0)
	inst.scale = Vector2.ONE * sscale
	var mat = sprite.material
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("seed", rng.randf())
		mat.set_shader_parameter("rim", rng.randf_range(0.7, 1.0))
		mat.set_shader_parameter("edge_rough", rng.randf_range(0.6, 1.2))
		mat.set_shader_parameter("noise_scale", rng.randf_range(3.0, 8.0))
		mat.set_shader_parameter("splat_color", color)
	if inst.get_parent() != draw_parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		if draw_parent:
			draw_parent.add_child(inst)
		else:
			add_child(inst)
	inst.position = global_pos

func _handle_capture_area_hit(global_pos: Vector2) -> bool:
	# Mirror prompt_clear_area_node treatment: skip when the path is empty.
	if capture_area_node == NodePath(""):
		return false
	var capture_area = get_node_or_null(capture_area_node)
	if not capture_area or not capture_area.has_method("get_global_rect"):
		return false
	if not capture_area.get_global_rect().has_point(global_pos):
		return false
	var cap_node: Node = null
	if capture_manager_node != NodePath(""):
		cap_node = get_node_or_null(capture_manager_node)
	if not cap_node:
		cap_node = get_node_or_null("CaptureManager")
	if cap_node:
		if cap_node.has_method("_on_capture_pressed"):
			cap_node._on_capture_pressed()
		elif cap_node.has_method("capture_canvas"):
			cap_node.capture_canvas()
	return true

func _draw() -> void:
	if not debug_draw:
		return

	# Draw prompt areas for debugging
	var outline_col = Color(0.0, 1.0, 0.0, 0.35)
	var fill_col = Color(0.0, 1.0, 0.0, 0.08)
	# If using stem manager, draw ready-tip circles
	if prompt_use_stem_manager and prompt_stem_manager_node != NodePath(""):
		var mgr = get_node_or_null(prompt_stem_manager_node)
		if mgr and mgr.has_method("get_ready_tip_positions"):
			var tips = mgr.get_ready_tip_positions()
			for t in tips:
				var local_pos = to_local(t)
				draw_circle(local_pos, prompt_radius, fill_col)
				draw_circle(local_pos, prompt_radius - 4.0, outline_col)
		# Also draw the spawner position for reference
		var loc = to_local(global_position)
		# small marker at spawner
		draw_circle(loc, 4.0, Color(1, 1, 0, 1.0))

func randf_range(a, b):
	return rng.randf() * (b - a) + a
