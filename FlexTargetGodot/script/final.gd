extends Node2D

var final_id: String = ""
var collision_radius: float = 0.0
var collision_center: Vector2 = Vector2.ZERO
@onready var audio_player = $AudioStreamPlayer2D
@onready var idle_sprite = $Area2D/idle
@onready var hit_sprite = $Area2D/hit

# Signal emitted when final target is hit
signal final_target_hit(hit_position: Vector2)

func _ready():
	# Set default ID if not already set
	if final_id == "":
		final_id = name
	
	# Get the collision shape radius and position from the Area2D's CollisionShape2D
	var area_2d = get_node_or_null("Area2D")
	if area_2d:
		var collision_shape = area_2d.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_radius = collision_shape.shape.radius
			collision_center = collision_shape.position
			print("[final %s] Collision radius set to: %f, center offset: %s" % [final_id, collision_radius, collision_center])
		else:
			print("[final %s] ERROR: Could not find CircleShape2D!" % final_id)
	else:
		print("[final %s] ERROR: Could not find Area2D!" % final_id)
	
	# Connect to WebSocket bullet hit signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		print("[final %s] Connected to WebSocketListener bullet_hit signal" % final_id)
	else:
		print("[final %s] WARNING: WebSocketListener singleton not found!" % final_id)

func _on_websocket_bullet_hit(pos: Vector2):
	"""Handle WebSocket bullet hit - check if position is within the collision circle"""
	# Check if bullet spawning is enabled
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener and not ws_listener.bullet_spawning_enabled:
		print("[final %s] WebSocket bullet spawning disabled during shot timer" % final_id)
		return
	
	print("[final %s] Received bullet hit at position: %s" % [final_id, pos])
	# Convert world position to local coordinates
	var area_2d = get_node_or_null("Area2D")
	if not area_2d:
		print("[final %s] ERROR: Area2D not found" % final_id)
		return
	
	var local_pos = area_2d.to_local(pos)
	print("[final %s] World pos: %s -> Local pos: %s" % [final_id, pos, local_pos])
	
	# Check if the hit position is within the collision circle
	if is_point_in_collision_circle(local_pos):
		print("[final %s] FINAL TARGET HIT at position: %s" % [final_id, pos])
		show_hit_state()
		play_hit_sound()
		final_target_hit.emit(pos)
	else:
		print("[final %s] Bullet hit outside collision circle" % final_id)

func is_point_in_collision_circle(local_point: Vector2) -> bool:
	"""Check if a local point is within the collision circle"""
	# The circle is centered at the collision_center offset (e.g., (0, -70))
	var distance = (local_point - collision_center).length()
	return distance <= collision_radius

func show_hit_state():
	"""Toggle sprites to show hit state"""
	if idle_sprite and hit_sprite:
		idle_sprite.visible = false
		hit_sprite.visible = true
	else:
		print("[final %s] WARNING: Could not find idle or hit sprites" % final_id)

func play_hit_sound():
	"""Play the collision sound effect"""
	if audio_player:
		audio_player.play()
	else:
		print("[final %s] WARNING: AudioStreamPlayer2D not found" % final_id)

func get_collision_radius() -> float:
	"""Return the collision circle radius"""
	return collision_radius
