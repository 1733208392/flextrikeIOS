extends Area2D

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

@export var bullet_smoke_scene: PackedScene
@export var bullet_impact_scene: PackedScene
@export var impact_sound: AudioStream  # Steel impact sound effect
var impact_duration = 1  # How long the impact effect lasts
var show_bullet_sprite = false  # Set to true if you want to see the bullet sprite for debugging
var spawn_position: Vector2  # Store the actual spawn position
var has_collided: bool = false  # Prevent multiple collision detections
var has_played_sound: bool = false  # Prevent multiple sound effects

func set_spawn_position(pos: Vector2):
	spawn_position = pos
	global_position = pos
	if not DEBUG_DISABLED:
		print("Bullet spawn position set to: ", spawn_position)

# Performance optimization flags
var optimized_collision: bool = false

func _ready():
	# Set up collision detection
	collision_layer = 8  # Bullet layer
	collision_mask = 15  # Target layer (7) + Wall layer (8) = 15 (binary 1111)
	
	# Optimize collision mask for non-rotating targets when WebSocket is available
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		# Use more specific collision mask since rotating targets use WebSocket direct path
		# But still include UI targets (layer 7) for menu interactions
		collision_mask = 15  # Include both walls (8) and UI targets (7) = 8 + 7 = 15
		optimized_collision = true
		if not DEBUG_DISABLED:
			print("[bullet] Using optimized collision detection - WebSocket handles target hits, UI targets still detected")
	
	# Connect area_entered signal for collision detection with targets
	area_entered.connect(_on_area_entered)
	
	# Connect body_entered signal for collision detection with walls/obstacles
	body_entered.connect(_on_body_entered)
	
	# Hide bullet sprite if not needed (since it's instant impact)
	var sprite = $Sprite2D
	if sprite and not show_bullet_sprite:
		sprite.visible = false
	
	# Wait a frame to ensure position is set, then trigger impact
	call_deferred("trigger_impact")

func _on_area_entered(area: Area2D):
	# Performance optimization: Skip game target collision processing when using optimized collision
	# But still handle UI areas (like menu buttons)
	if optimized_collision and area.has_method("handle_bullet_collision"):
		if not DEBUG_DISABLED:
			print("[bullet] Skipping game target collision - using WebSocket optimization")
		return
	
	# Handle collision with UI areas (menu buttons, etc.) - these don't have handle_bullet_collision method
	if not has_collided and not area.has_method("handle_bullet_collision"):
		has_collided = true
		if not DEBUG_DISABLED:
			print("Bullet collided with UI area: ", area.name)
		# Trigger impact effects for UI collisions
		on_impact()
		return
	
	# Handle collision with target areas (game targets)
	if not has_collided and area.has_method("handle_bullet_collision"):
		has_collided = true
		if not DEBUG_DISABLED:
			print("Bullet collided with target: ", area.name)
		
		# First, spawn bullet hole if target supports it
		if area.has_method("spawn_bullet_hole"):
			var local_pos = area.to_local(global_position)
			area.spawn_bullet_hole(local_pos)
			if not DEBUG_DISABLED:
				print("Bullet hole spawned first at local position: ", local_pos)
		
		# Then let the target handle the collision detection (scoring, animations)
		area.handle_bullet_collision(global_position)
		
		# Finally trigger our own impact effects (smoke, impact animation)
		on_impact()

func _on_body_entered(body: StaticBody2D):
	# Handle collision with walls/obstacles (like barrel wall)
	if not has_collided:
		has_collided = true
		if not DEBUG_DISABLED:
			print("Bullet collided with wall/obstacle: ", body.name)
		# Just trigger impact effects without scoring
		on_impact()

func trigger_impact():
	# Use spawn_position if it was set, otherwise use current global_position
	if spawn_position != Vector2.ZERO:
		global_position = spawn_position
	
	# Only trigger impact if we haven't collided with a target
	# (collision will handle impact effects)
	if not has_collided:
		on_impact()

func on_impact():
	if not DEBUG_DISABLED:
		print("Bullet impact at position: ", global_position)
	
	# Play steel impact sound effect
	play_impact_sound()
	
	# Use the bullet's exact global position for effects
	# This should match exactly where the bullet was spawned
	var impact_position = global_position
	
	if not DEBUG_DISABLED:
		print("Impact effects spawning at: ", impact_position)
	
	# Create smoke effect at exact impact position
	if bullet_smoke_scene:
		var smoke = bullet_smoke_scene.instantiate()
		smoke.global_position = impact_position
		get_parent().add_child(smoke)
		if not DEBUG_DISABLED:
			print("Smoke spawned at: ", smoke.global_position)
	
	# Create impact effect at exact impact position
	if bullet_impact_scene:
		var impact = bullet_impact_scene.instantiate()
		impact.global_position = impact_position
		get_parent().add_child(impact)
		if not DEBUG_DISABLED:
			print("Impact effect spawned at: ", impact.global_position)
	
	# Remove the bullet after a short duration to allow effects to play
	var timer = Timer.new()
	timer.wait_time = impact_duration
	timer.one_shot = true
	timer.timeout.connect(_on_impact_finished)
	add_child(timer)
	timer.start()

func _on_impact_finished():
	if not DEBUG_DISABLED:
		print("Bullet impact finished, removing bullet")
	queue_free()

func play_impact_sound():
	"""Play realistic steel target impact sound effect with deduplication"""
	# Prevent multiple sounds from the same bullet
	if has_played_sound:
		if not DEBUG_DISABLED:
			print("Sound already played for this bullet - skipping duplicate")
		return
		
	if impact_sound:
		has_played_sound = true  # Mark sound as played
		
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		get_parent().add_child(audio_player)
		audio_player.global_position = global_position
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		if not DEBUG_DISABLED:
			print("Steel impact sound played at: ", global_position, " (deduplicated)")
	else:
		if not DEBUG_DISABLED:
			print("No impact sound assigned - add steel impact audio file to bullet scene!")
