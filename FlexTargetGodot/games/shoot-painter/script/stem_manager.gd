extends Node2D

@export var stem_count: int = 12
@export var ground_y: float = 1080.0
@export var min_stem_height: float = 200.0
@export var max_stem_height: float = 900.0
@export var growth_speed: float = 70.0
@export var prompt_offset: float = 32.0
@export var horizontal_padding: float = 70.0
@export var spawn_width: float = 720.0
@export var spacing_jitter: float = 30.0
@export var max_angle_degrees: float = 18.0
@export var line_width: float = 10.0

var stems: Array = []
var rng := RandomNumberGenerator.new()
var tip_prompt_script := preload("res://games/shoot-painter/script/tip_prompt.gd")
var stem_gradient: Gradient
@export var cartoon_splat_stream: AudioStream = preload("res://audio/cartoon-splat.mp3")
var cartoon_splat_player: AudioStreamPlayer

func _ready() -> void:
	rng.randomize()
	stem_gradient = _create_gradient()
	for i in range(stem_count):
		_spawn_stem(i)
	set_process(true)
	_setup_cartoon_splat_player()

func _process(delta: float) -> void:
	for data in stems:
		var length = data.current_len
		if data.state == "growing":
			length += growth_speed * delta
			if length >= data.target_len:
				length = data.target_len
				data.state = "ready"
				data.prompt.visible = true
			data.current_len = length
		else:
			length = data.target_len
		var tip_vec = data.direction * length
		data.line.points = [Vector2.ZERO, tip_vec]
		data.prompt.position = tip_vec + data.direction * prompt_offset

func _spawn_stem(idx: int) -> void:
	var stem = Node2D.new()
	var usable_width = max(0.0, spawn_width - horizontal_padding * 2.0)
	var base_x = horizontal_padding + (usable_width * float(idx) / max(1, stem_count - 1))
	var offset = rng.randf_range(-spacing_jitter, spacing_jitter)
	var x = clamp(base_x + offset, horizontal_padding, spawn_width - horizontal_padding)
	stem.position = Vector2(x, ground_y)
	var line = Line2D.new()
	line.width = line_width
	line.gradient = stem_gradient
	line.points = [Vector2.ZERO, Vector2.ZERO]
	stem.add_child(line)
	var prompt = tip_prompt_script.new()
	prompt.visible = false
	stem.add_child(prompt)
	add_child(stem)

	var angle_rad = deg_to_rad(rng.randf_range(-max_angle_degrees, max_angle_degrees))
	var direction = Vector2(sin(angle_rad), -cos(angle_rad))
	var target_len = rng.randf_range(min_stem_height, max_stem_height)
	var tip_global_x = stem.position.x + direction.x * target_len
	var clamped_tip_x = clamp(tip_global_x, 50.0, 670.0)
	stem.position.x += clamped_tip_x - tip_global_x
	stems.append({
		"node": stem,
		"line": line,
		"prompt": prompt,
		"current_len": 0.0,
		"target_len": target_len,
		"direction": direction,
		"state": "growing"
	})

func _create_gradient() -> Gradient:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(0.33, 0.18, 0.04), Color(0.12, 0.7, 0.26)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	return grad

func get_ready_tip_positions() -> Array:
	var tips: Array = []
	for data in stems:
		if data.state == "ready":
			# Return the prompt global position (tip position + prompt offset)
			var prompt_local = data.direction * (data.target_len + prompt_offset)
			tips.append(data.node.to_global(prompt_local))
	return tips


func consume_tip_at_position(global_pos: Vector2, radius: float) -> bool:
	"""Consume (use) the first ready tip within `radius` of `global_pos`.
	When a tip is consumed its state is set to "used" and its prompt hidden.
	Returns true if a tip was consumed, false otherwise.
	"""
	for data in stems:
		if data.state == "ready":
			# Compute prompt global position (tip + prompt_offset)
			var prompt_local = data.direction * (data.target_len + prompt_offset)
			var prompt_pos = data.node.to_global(prompt_local)
			if prompt_pos.distance_to(global_pos) <= radius:
				data.state = "used"
				if data.prompt and is_instance_valid(data.prompt):
					data.prompt.visible = false
					_play_cartoon_splat()
				return true
	return false

func _setup_cartoon_splat_player() -> void:
	if not cartoon_splat_stream:
		return
	cartoon_splat_player = AudioStreamPlayer.new()
	cartoon_splat_player.stream = cartoon_splat_stream
	cartoon_splat_player.autoplay = false
	cartoon_splat_player.bus = "SFX"
	add_child(cartoon_splat_player)

func _play_cartoon_splat() -> void:
	if not cartoon_splat_player:
		return
	cartoon_splat_player.stop()
	cartoon_splat_player.play()
