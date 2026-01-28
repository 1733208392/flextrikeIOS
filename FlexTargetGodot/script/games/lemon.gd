extends RigidBody2D

var is_fruit: bool = true
var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")

func _ready():
	# Connect to WebSocket bullet_hit signal
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)

func hit():
	# Play hit sound
	$HitSound.play()
	# Play animation once
	$Sprite.play()
	
	# Add score with coin animation
	var game = get_parent()
	game.add_score(8, global_position)
	
	# Wait for animation to finish, then remove the lemon
	await $Sprite.animation_finished
	queue_free()

func truck_hit():
	# Disappear immediately without playing animation
	queue_free()

func _on_bullet_hit(hit_pos: Vector2, a: int = 0, t: int = 0):
	"""Handle bullet hit from WebSocket"""
	# Spawn bullet impact at hit position
	var impact = bullet_impact_scene.instantiate()
	impact.global_position = hit_pos
	get_parent().add_child(impact)
	print("Spawned bullet impact at: ", hit_pos)

	# Get the lemon's collision shape
	var collision_shape = get_node("CollisionShape")
	if collision_shape == null:
		return
	
	# Convert hit_pos to local coordinates of the lemon
	var local_hit_pos = to_local(hit_pos)
	
	# Check if hit is within the circle collision shape
	var hit_detected = false
	
	if collision_shape.shape is CircleShape2D:
		var circle = collision_shape.shape as CircleShape2D
		var distance = local_hit_pos.length()
		if distance <= circle.radius:
			hit_detected = true
	
	if hit_detected:
		print("Hit detected on lemon at: ", hit_pos)
		# Trigger the lemon animation/split
		hit()
		# Disconnect from signal after being hit
		WebSocketListener.bullet_hit.disconnect(_on_bullet_hit)
	else:
		print("Hit missed lemon at: ", hit_pos)
