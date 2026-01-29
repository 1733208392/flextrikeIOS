extends Node2D

# References to vines
var vine_left: Node2D = null
var vine_right: Node2D = null
var current_vine: Node2D = null

# Reference to animated sprite and collision shape
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_sound: AudioStreamPlayer = $HitSound

# Preload bullet impact scene
var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")

# Cache parent reference
var game_parent: Node2D = null

# Attachment to vine
var is_attached: bool = false
var attachment_offset: float = 0.0  # Absolute Y offset from vine top where monkey landed
var vine_length_at_landing: float = 0.0  # Vine length when monkey landed
var landed_on_right_side: bool = false  # Which side of vine monkey landed on

var monkey_start_side: String = "left"  # Will be set via signal

# Game start protection
var game_start_time: float = 0.0
var bullet_protection_duration: float = 2.0  # 2 seconds protection after game starts

func _ready():
	# Get references to the vines from parent (GameMonkey)
	game_parent = get_parent() as Node2D
	if game_parent:
		vine_left = game_parent.get_node_or_null("VineLeft")
		vine_right = game_parent.get_node_or_null("VineRight")
		
		if vine_left and vine_right:
			# Connect to settings_applied signal for initial monkey setup
			if has_node("/root/SignalBus"):
				var signal_bus = get_node("/root/SignalBus")
				if signal_bus.has_signal("settings_applied"):
					signal_bus.settings_applied.connect(_on_settings_applied)
				else:
					print("Warning: settings_applied signal not found in SignalBus")
			else:
				print("Warning: SignalBus autoload not found")
			
			# Default start side (will be overridden by settings_applied signal)
			monkey_start_side = "left"
			print("Monkey _ready: Waiting for settings_applied signal")
			
			# Start on the specified vine
			if monkey_start_side == "left":
				current_vine = vine_left
				# Face left
				if animated_sprite:
					animated_sprite.flip_h = false
			else:
				current_vine = vine_right
				# Face right
				if animated_sprite:
					animated_sprite.flip_h = true
	
	# Connect to WebSocket bullet_hit signal
	if has_node("/root/WebSocketListener"):
		var ws_listener = get_node("/root/WebSocketListener")
		if ws_listener.has_signal("bullet_hit"):
			ws_listener.bullet_hit.connect(_on_bullet_hit)
			print("Monkey: Connected to bullet_hit signal")
		else:
			print("Warning: bullet_hit signal not found in WebSocketListener")
	else:
		print("Warning: WebSocketListener autoload not found")
	
	# Play idle animation by default
	if animated_sprite:
		animated_sprite.play("idle")
	
	# Start a coroutine to wait for game start
	_wait_for_game_start.call_deferred()

func _wait_for_game_start():
	# Wait for game to start (when state is RUNNING)
	if not game_parent:
		print("Error: game_parent not initialized")
		return
	
	while game_parent.current_state != game_parent.GameState.RUNNING:
		await get_tree().create_timer(0.1).timeout
	
	# Record game start time for bullet protection
	game_start_time = Time.get_ticks_msec() / 1000.0
	print("Game started at time: ", game_start_time)
	
	# Get the monkey start side
	print("Monkey _wait_for_game_start: monkey_start_side = ", monkey_start_side)
	
	# Game has started, move monkey to the starting vine
	print("Monkey: Game started! Moving to ", monkey_start_side, " vine...")
	
	if monkey_start_side == "right":
		# Play jump animation when starting on right vine
		if animated_sprite:
			animated_sprite.play("jump")
		# Move to the right vine
		_move_to_random_position()
		# Emit monkey landed signal
		if has_node("/root/SignalBus"):
			var signal_bus = get_node("/root/SignalBus")
			if signal_bus.has_signal("monkey_landed"):
				signal_bus.monkey_landed.emit()
				print("Monkey: Emitted monkey_landed signal for right start")
		# Wait for jump animation to finish
		if animated_sprite:
			await animated_sprite.animation_finished
	else:
		# Just move to left vine without jump
		_move_to_random_position()
		# Emit monkey landed signal
		if has_node("/root/SignalBus"):
			var signal_bus = get_node("/root/SignalBus")
			if signal_bus.has_signal("monkey_landed"):
				signal_bus.monkey_landed.emit()
				print("Monkey: Emitted monkey_landed signal for left start")

func _process(_delta):
	# Only update monkey position if attached to vine and game is running
	if not game_parent:
		return
	
	if game_parent.current_state != game_parent.GameState.RUNNING:
		return
	
	if is_attached and current_vine:
		_update_attached_position()

func _input(event):
	# Allow input only when game is RUNNING
	if not game_parent:
		return
	
	if game_parent.current_state != game_parent.GameState.RUNNING:
		return
	
	# Simulate bullet_hit on mouse click for testing
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos = event.position
			print("Mouse clicked at: ", click_pos, " - Simulating bullet_hit")
			_on_bullet_hit(click_pos)

func _on_bullet_hit(pos: Vector2, a: int = 0, t: int = 0):
	# Only accept bullet hits when game is fully RUNNING (countdown complete)
	if not game_parent:
		return
	
	# Only process hits in RUNNING state, not during countdown
	if game_parent.current_state != game_parent.GameState.RUNNING:
		print("Bullet hit rejected: Countdown still active")
		return
	
	# Check if the bullet hit position is inside the monkey's collision shape
	if not _is_point_in_collision_shape(pos):
		print("Bullet missed the monkey at position: ", pos)
		# Spawn bullet impact and play sound for miss
		_spawn_bullet_impact(pos)
		_play_hit_sound()
		return
	
	print("Bullet hit the monkey at position: ", pos)
	
	# Detach during jump
	is_attached = false
	
	# Switch to the other vine before jumping
	if current_vine == vine_left:
		current_vine = vine_right
		# Flip to face right
		if animated_sprite:
			animated_sprite.flip_h = true
	else:
		current_vine = vine_left
		# Flip to face left
		if animated_sprite:
			animated_sprite.flip_h = false
	
	# Trigger jump animation
	if animated_sprite:
		animated_sprite.play("jump")
	
	# Play sound and spawn bullet impact concurrently while jumping
	_play_hit_sound()
	_spawn_bullet_impact(pos)
	
	# Move to the other vine immediately while animation plays
	_move_to_random_position()
	
	# Return to idle after jump animation finishes
	if animated_sprite:
		await animated_sprite.animation_finished
		animated_sprite.play("idle")
		await animated_sprite.animation_finished
		animated_sprite.play("idle")

func _play_hit_sound():
	"""Play hit sound effect for 1.5 seconds"""
	if hit_sound:
		hit_sound.play()
		# Stop the sound after 1.5 seconds
		await get_tree().create_timer(1.5).timeout
		hit_sound.stop()

func _spawn_bullet_impact(pos: Vector2):
	"""Spawn bullet impact at hit position"""
	var impact = bullet_impact_scene.instantiate()
	impact.global_position = pos
	if game_parent:
		game_parent.add_child(impact)
	print("Spawned bullet impact at: ", pos)

func _is_point_in_collision_shape(point: Vector2) -> bool:
	# Check if a point is inside the monkey's collision shape (CapsuleShape2D)
	if not collision_shape:
		return false
	
	var shape = collision_shape.shape
	if not shape is CapsuleShape2D:
		return false
	
	# Get the capsule shape properties
	var capsule = shape as CapsuleShape2D
	var radius = capsule.radius
	var height = capsule.height
	
	# Transform the point to local space relative to the collision shape
	var local_point = point - global_position - collision_shape.position
	
	# Capsule is vertical, so check distance from the central axis
	var half_height = (height - 2 * radius) / 2.0
	
	# Check if point is within the cylindrical section
	if abs(local_point.y) <= half_height:
		# Point is in the cylindrical part
		return abs(local_point.x) <= radius
	
	# Check if point is within the top or bottom hemisphere
	var circle_center_y = half_height if local_point.y > 0 else -half_height
	var distance_to_center = Vector2(local_point.x, local_point.y - circle_center_y).length()
	return distance_to_center <= radius

func _move_to_random_position():
	if not current_vine:
		return
	
	# Get the sprite from the vine
	var vine_sprite = current_vine.get_node_or_null("Sprite2D")
	if not vine_sprite:
		return
	
	# Get the region rect
	var region = vine_sprite.region_rect
	
	# Calculate the world position of the vine
	var vine_position = current_vine.global_position
	
	# Calculate random position
	# X: position based on which vine - right side for left vine, left side for right vine
	var vine_width = region.size.x
	
	# Get the sprite offset from the vine node
	var vine_sprite_offset = vine_sprite.position.x if vine_sprite else 0
	
	# Determine horizontal position based on which vine
	var target_x: float
	var land_on_right_side = randi() % 2 == 0  # Randomly choose left or right side
	
	if land_on_right_side:
		# Land on the RIGHT side of the vine
		target_x = vine_position.x + vine_sprite_offset + vine_width
		print("Landing on RIGHT side: vine_position.x=", vine_position.x, ", sprite_offset=", vine_sprite_offset, ", vine_width=", vine_width, ", target_x=", target_x)
	else:
		# Land on the LEFT side of the vine
		target_x = vine_position.x + vine_sprite_offset
		print("Landing on LEFT side: vine_position.x=", vine_position.x, ", sprite_offset=", vine_sprite_offset, ", vine_width=", vine_width, ", target_x=", target_x)
	
	# Store which side we landed on
	landed_on_right_side = land_on_right_side
	
	# Y: random between top and bottom of visible vine (excluding bottom 20px)
	# Since sprite is not centered, the vine draws from its top
	var vine_height = region.size.y  # This is the vine_length
	var landable_height = max(vine_height - 200, 0)  # Exclude bottom 20px
	var random_y_offset = randf_range(0, landable_height)
	var target_y = vine_position.y + random_y_offset
	
	# Store the absolute offset from vine top and current vine length
	attachment_offset = random_y_offset
	vine_length_at_landing = vine_height
	
	# Move monkey to the position
	global_position = Vector2(target_x, target_y)
	
	# Attach monkey to vine
	is_attached = true
	
	# Emit signal if it exists
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("monkey_landed"):
			signal_bus.emit_signal("monkey_landed")
	
	print("Monkey moved to: ", global_position, " (attachment offset: ", attachment_offset, ", vine length: ", vine_height, ")")
	print("Current vine: ", current_vine.name, " at position: ", vine_position)

func _update_attached_position():
	# Update monkey position based on current vine state
	if not current_vine:
		return
	
	var vine_sprite = current_vine.get_node_or_null("Sprite2D")
	if not vine_sprite:
		return
	
	var region = vine_sprite.region_rect
	var vine_position = current_vine.global_position
	var vine_sprite_offset = vine_sprite.position.x if vine_sprite else 0
	var vine_width = region.size.x
	
	# Calculate how much the vine has grown/shrunk since landing
	var current_vine_height = region.size.y
	var vine_length_change = current_vine_height - vine_length_at_landing
	
	# Keep the same absolute offset from top, but shift down/up as vine grows/shrinks
	# Maintain the same horizontal position based on which side we landed on
	var target_x: float
	if landed_on_right_side:
		# Stay on the RIGHT side of the vine
		target_x = vine_position.x + vine_sprite_offset + vine_width
	else:
		# Stay on the LEFT side of the vine
		target_x = vine_position.x + vine_sprite_offset
	
	var new_offset = attachment_offset + vine_length_change
	
	# Clamp the offset to keep monkey within vine bounds (excluding bottom 20px)
	# If vine shrinks too much, keep monkey at the bottom of the landable region
	var max_landable_offset = max(current_vine_height - 20, 0)
	new_offset = clamp(new_offset, 0, max_landable_offset)
	
	var target_y = vine_position.y + new_offset
	
	# Update monkey position
	global_position = Vector2(target_x, target_y)

func _on_settings_applied(start_side: String, _growth_speed: float, _duration: float):
	"""Update monkey start side from settings"""
	monkey_start_side = start_side
	if not is_attached:
		if start_side == "left":
			current_vine = vine_left
			if animated_sprite:
				animated_sprite.flip_h = false
		else:
			current_vine = vine_right
			if animated_sprite:
				animated_sprite.flip_h = true
	print("[Monkey] Settings applied: start_side = ", start_side)
