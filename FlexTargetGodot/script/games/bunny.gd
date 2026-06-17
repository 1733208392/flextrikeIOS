extends Area2D

enum State {IN, OUT, HIT}

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var smoke_scene = preload("res://scene/games/wack-a-mole/smoke.tscn")

var state: State = State.IN

signal bunny_hit(position: Vector2)

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	input_event.connect(_on_input_event)
	
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
	
	state = State.IN
	visible = false
	anim.animation = "in"
	anim.frame = anim.sprite_frames.get_frame_count("in") - 1

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_bullet_hit(get_global_mouse_position())

func is_in() -> bool:
	return state == State.IN

func go_out() -> void:
	visible = true
	state = State.OUT
	anim.play("out")

func go_in() -> void:
	state = State.IN
	visible = false
	anim.play("in")

func simulate_hit() -> void:
	if visible:
		on_hit()

func start_appearance(_visible_time: float = 0.0) -> void:
	go_out()

func is_hittable() -> bool:
	return visible

func _on_bullet_hit(hit_pos: Vector2, _a: int = 0, _t: int = 0) -> void:
	var local_hit_pos = to_local(hit_pos)
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		if local_hit_pos.distance_to(Vector2.ZERO) <= shape.radius:
			var smoke = smoke_scene.instantiate()
			smoke.global_position = hit_pos
			get_parent().add_child(smoke)
			simulate_hit()

func on_hit() -> void:
	if state == State.HIT:
		return
	state = State.HIT
	anim.play("hurt")
	audio_player.play()
	bunny_hit.emit(global_position)

func _on_animation_finished() -> void:
	if state == State.OUT:
		anim.play("idle")
	elif state == State.HIT:
		go_in()
