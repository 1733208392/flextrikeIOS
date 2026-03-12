extends Node2D

class_name ClayTarget

var velocity = Vector2.ZERO
var gravity = 180.0 # Adjust based on screen scale
var rotation_speed = 0.0

@onready var sprite = $ClayExplode
@onready var particles = $GPUParticles2D
@onready var area = $Area2D

var hit_sound_path = "res://audio/cartoon-splat.mp3"

signal destroyed(score)
signal missed

func _ready():
	# Ensure sprite is hidden or set to frame 0 if not playing
	sprite.frame = 0
	sprite.stop()
	particles.emitting = false
	
	# Connect to WebSocket bullet_hit signal
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
	
	# Connect collision if needed or handle via input/click
	area.input_event.connect(_on_input_event)
	# Random rotation speed for visual variety
	rotation_speed = randf_range(-5.0, 5.0)

func _on_bullet_hit(hit_pos: Vector2, _a: int = 0, _t: int = 0):
	"""Handle bullet hit from WebSocket"""
	# Convert hit_pos to local coordinates of the clay target
	var local_hit_pos = to_local(hit_pos)
	
	# Check if hit is within the collision shape
	var collision_shape = area.get_node("CollisionShape2D")
	if collision_shape and collision_shape.shape is CapsuleShape2D:
		var capsule = collision_shape.shape as CapsuleShape2D
		var radius = capsule.radius
		var half_height = (capsule.height * 0.5) - radius
		
		# For CapsuleShape2D, the height is the total length including ends.
		# The capsule is oriented along the Y axis in Godot by default.
		var dist_to_axis = abs(local_hit_pos.x)
		var dist_along_axis = abs(local_hit_pos.y)
		
		var inside = false
		if dist_along_axis <= half_height:
			# Within the cylindrical part
			inside = dist_to_axis <= radius
		else:
			# Within the hemispherical ends
			var circle_center_dist = dist_along_axis - half_height
			inside = sqrt(pow(dist_to_axis, 2) + pow(circle_center_dist, 2)) <= radius
			
		if inside:
			print("[ClayTarget] Hit detected at: ", hit_pos)
			hit()
			# Disconnect after being hit
			if WebSocketListener.bullet_hit.is_connected(_on_bullet_hit):
				WebSocketListener.bullet_hit.disconnect(_on_bullet_hit)
	elif collision_shape and collision_shape.shape is CircleShape2D:
		var circle = collision_shape.shape as CircleShape2D
		if local_hit_pos.length() <= circle.radius:
			print("[ClayTarget] Hit detected at: ", hit_pos)
			hit()
			# Disconnect after being hit
			if WebSocketListener.bullet_hit.is_connected(_on_bullet_hit):
				WebSocketListener.bullet_hit.disconnect(_on_bullet_hit)

func _process(delta):
	# Manual physics integration
	velocity.y += gravity * delta
	position += velocity * delta
	rotation += rotation_speed * delta
	
	# Check if off-screen (bottom)
	var screen_size = get_viewport_rect().size
	if position.y > screen_size.y + 100:
		missed.emit()
		queue_free()
	
	# Check if off-screen (sides/top) with some buffer
	if position.x < -200 or position.x > screen_size.x + 200 or position.y < -500:
		queue_free()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		hit()

func hit():
	# Stop movement and rotation
	set_process(false)
	area.monitoring = false
	area.monitorable = false
	
	# Play sound effect
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = load(hit_sound_path)
	# Use the SFX bus if it exists (assuming bus 1 or "SFX")
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	if sfx_bus_index != -1:
		audio_player.bus = "SFX"
	audio_player.play()
	
	# Visual effects
	sprite.play("default")
	particles.emitting = true
	
	# Wait for animation or specific time before queue_free
	destroyed.emit(100) # Base score
	
	# Auto-cleanup after effects
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(queue_free)

func launch(start_pos: Vector2, start_velocity: Vector2):
	position = start_pos
	velocity = start_velocity
