extends Area2D

enum State {IN, OUT, HIT}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var smoke_scene = preload("res://scene/games/wack-a-mole/smoke.tscn")

var state: State = State.IN

signal mole_hit(position: Vector2, score: int)

func _ready() -> void:
	# Connect signals
	anim.animation_finished.connect(_on_animation_finished)
	input_event.connect(_on_input_event)
	
	# Connect to WebSocket bullet_hit signal
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
	
	# Start in default state (hidden, no animation)
	state = State.IN
	anim.animation = "in"
	anim.frame = anim.sprite_frames.get_frame_count("in") - 1

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit_pos = get_global_mouse_position()
		_on_bullet_hit(hit_pos)

func simulate_hit() -> void:
	if state == State.OUT and (not anim.is_playing() or anim.animation == "idle"):
		on_hit()

func is_in() -> bool:
	return state == State.IN

func _on_bullet_hit(hit_pos: Vector2, a: int = 0, t: int = 0) -> void:
	"""Handle bullet hit from WebSocket"""
	# Convert hit_pos to local coordinates of the mole
	var local_hit_pos = to_local(hit_pos)
	
	# Check if hit is within the circle collision shape
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		var distance = local_hit_pos.distance_to(Vector2.ZERO)
		if distance <= shape.radius:
			print("Hit detected on mole at: ", hit_pos)
			# Spawn smoke effect
			var smoke = smoke_scene.instantiate()
			smoke.global_position = hit_pos
			get_parent().add_child(smoke)
			simulate_hit()
		else:
			print("Hit missed mole at: ", hit_pos)

func _on_timer_timeout() -> void:
	if state == State.OUT:
		go_in()

func go_out() -> void:
	state = State.OUT
	anim.play("out")

func go_in() -> void:
	state = State.IN
	anim.play("in")

func on_hit() -> void:
	state = State.HIT
	anim.play("hurt")
	audio_player.play()
	# Emit signal with hit position and score
	mole_hit.emit(global_position, 100)

func _on_animation_finished() -> void:
	if state == State.OUT:
		anim.play("idle")
	elif state == State.HIT:
		state = State.IN
		anim.animation = "in"
		anim.frame = 3
