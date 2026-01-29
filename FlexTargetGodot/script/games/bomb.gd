extends RigidBody2D

var is_bomb: bool = true
var is_hit: bool = false

func _ready():
	# Bomb node is now a RigidBody2D, so we don't need to create one
	print("Bomb ready - position: ", global_position, " is RigidBody2D: ", self is RigidBody2D)
	
	# Enable contact monitoring to detect collisions with fruits
	contact_monitor = true
	max_contacts_reported = 10
	
	# Connect to body_entered signal to detect fruit collisions
	body_entered.connect(_on_body_entered)
	
	# Connect WebSocketListener bullet hit signal
	if WebSocketListener:
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
		
func bullet_hit():
	"""Called when bomb is hit by bullet"""
	if not is_hit:
		is_hit = true
		_explode()

func explode():
	"""Trigger explosion effect and destroy bomb"""
	if not is_hit:
		is_hit = true
		_explode()

func _explode():
	"""Trigger explosion effect and destroy bomb"""
	print("BOMB EXPLODED at position: ", global_position)
	
	var explosion = get_node_or_null("debris")
	if explosion:
		explosion.emitting = true
		print("Explosion particles started")
	
	# Play smoke particles
	var smoke = get_node_or_null("smoke/GPUParticles2D")
	if smoke:
		smoke.emitting = true
		print("Smoke particles started")
	
	# Get game scene reference (node name is "game" in lowercase)
	var game = get_tree().current_scene
	print("Game reference: ", game)
	print("Game name: ", game.name if game else "null")
	print("Game has _shake_camera method: ", game.has_method("_shake_camera") if game else false)
	
	# Trigger lightning effect
	if game and game.has_method("_play_lightning_effect"):
		game._play_lightning_effect()
		print("Lightning effect triggered")
	
	# Trigger camera shake
	if game and game.has_method("_shake_camera"):
		print("About to call _shake_camera...")
		game.call("_shake_camera", 15.0, 0.6)  # Intensity: 15, Duration: 0.6 seconds
		print("Camera shake triggered")
	else:
		print("ERROR: Game does not have _shake_camera method!")
	
	# Play explosion sound
	$AudioStreamPlayer2D.play()
	
	# Destroy all floating fruits when bomb explodes
	_destroy_all_floating_fruits()
	
	print("Bomb exploded!")
	
	# Queue free after a short delay to let particles finish
	await get_tree().create_timer(0.5).timeout
	queue_free()

func _destroy_all_floating_fruits():
	"""Destroy all floating fruits in the scene when bomb explodes"""
	var game = get_tree().current_scene
	if not game:
		print("ERROR: Could not get game scene reference")
		return
	
	var fruits_destroyed = 0
	
	# Find all floating fruits (not in truck)
	for child in game.get_children():
		if child.get("is_fruit") == true:
			if child is RigidBody2D:
				# Only destroy if not a child of truck (floating fruits only)
				if child.get_parent() == game:
					print("Destroying floating fruit: ", child.name)
					child.queue_free()
					fruits_destroyed += 1
	
	print("Bomb explosion destroyed ", fruits_destroyed, " floating fruits")

func _on_bullet_hit(hit_position: Vector2, a: int = 0, t: int = 0):
	"""Check if bomb was hit by bullet"""
	if is_hit:
		return
	
	var distance = global_position.distance_to(hit_position)
	if distance < 50:  # Hit radius
		bullet_hit()

func _on_body_entered(body: Node):
	"""Handle collision with other bodies - explode if hit by truck"""
	if is_hit:
		return
	
	# Check if colliding body is the truck
	if body.get("is_truck") == true or body.has_meta("is_truck"):
		print("Bomb hit by truck: ", body.name)
		explode()
