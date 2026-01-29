extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var smoke_scene = preload("res://scene/games/wack-a-mole/smoke.tscn")

var coin_visible: bool = true

signal coin_hit

func _ready() -> void:
	# Connect to WebSocket bullet_hit signal
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
	
	# Connect input for mouse clicks
	input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit_pos = get_global_mouse_position()
		_on_bullet_hit(hit_pos)

func _on_bullet_hit(hit_pos: Vector2, a: int = 0, t: int = 0) -> void:
	"""Handle bullet hit from WebSocket"""
	if not coin_visible:
		return
	
	# Convert hit_pos to local coordinates
	var local_hit_pos = to_local(hit_pos)
	
	# Check if hit is within the circle collision shape
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		var distance = local_hit_pos.distance_to(Vector2.ZERO)
		if distance <= shape.radius:
			print("Hit detected on coin at: ", hit_pos)
			# Spawn smoke effect
			var smoke = smoke_scene.instantiate()
			smoke.global_position = hit_pos
			get_parent().add_child(smoke)
			# Play sound effect
			audio_player.play()
			# Make coin disappear
			disappear()

		else:
			print("Hit missed coin at: ", hit_pos)

func disappear() -> void:
	"""Make the coin disappear and emit signal, then queue free"""
	coin_visible = false
	animated_sprite.visible = false
	collision_shape.disabled = true

	# Emit signal before disappearing
	coin_hit.emit()
	# Wait for audio to finish playing before removing the node
	if audio_player.playing:
		await audio_player.finished
	queue_free()
