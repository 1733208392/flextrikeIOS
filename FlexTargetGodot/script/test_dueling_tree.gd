extends Node2D

@onready var animated_sprite = $AnimatedSprite2D

var is_moving_left = true
var original_x

# Audio system for impact sounds
var last_sound_time: float = 0.0
var sound_cooldown: float = 0.05  # 50ms minimum between sounds
var max_concurrent_sounds: int = 1  # Maximum number of concurrent sound effects
var active_sounds: int = 0

# Animation state
var is_animating = false

func _ready():
	$AnimatedSprite2D/Area2D.connect("input_event", Callable(self, "_on_sprite_input_event"))
	original_x = animated_sprite.position.x
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[TestDuelingTree] Connected to WebSocketListener.bullet_hit signal")
	else:
		print("[TestDuelingTree] WebSocketListener not found!")

func _on_sprite_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Simulate websocket bullet hit at mouse position
		var mouse_pos = get_global_mouse_position()
		print("[TestDuelingTree] Mouse click simulated bullet hit at: %s" % mouse_pos)
		_on_websocket_bullet_hit(mouse_pos)

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	"""Handle websocket bullet hit"""
	print("[TestDuelingTree] WebSocket bullet hit at: %s" % pos)
	
	# Ignore hits while animating
	if is_animating:
		print("[TestDuelingTree] Ignoring bullet hit while animating")
		return
	
	# Check if the hit is within the collision area
	var area = $AnimatedSprite2D/Area2D
	if area:
		var collision_shape = area.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			var circle_global_pos = collision_shape.global_position
			var circle_radius = circle_shape.radius
			
			# Convert hit position to circle's local space
			var hit_local_pos = pos - circle_global_pos
			var distance = hit_local_pos.length()
			
			# Check if the hit is within the circle area
			if distance <= circle_radius:
				print("[TestDuelingTree] Hit detected within collision area, distance: %.2f, radius: %.2f" % [distance, circle_radius])
				
				# Play metal hit sound
				play_metal_hit_sound(pos)
				
				# Trigger the animation
				is_animating = true
				var tween = create_tween()
				if is_moving_left:
					animated_sprite.play()
					tween.tween_property(animated_sprite, "position:x", original_x + 200, 0.5)
				else:
					animated_sprite.play_backwards()
					tween.tween_property(animated_sprite, "position:x", original_x, 0.5)
				is_moving_left = not is_moving_left
				tween.finished.connect(func(): is_animating = false)
			else:
				print("[TestDuelingTree] Hit outside collision area, distance: %.2f, radius: %.2f" % [distance, circle_radius])

func play_metal_hit_sound(world_pos: Vector2):
	"""Play metal hit sound for bullet impacts"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return
	
	# Check concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return
	
	# Load the metal hit sound
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
