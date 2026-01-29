extends Area2D

var last_click_frame = -1

# Animation state tracking
var is_disappearing: bool = false

# Bullet system
const BulletScene = preload("res://scene/bullet.tscn")
const BulletHoleScene = preload("res://scene/bullet_hole.tscn")
const ScoreUtils = preload("res://script/score_utils.gd")

# Scoring system
var total_score: int = 0
signal target_hit(zone: String, points: int, hit_position: Vector2)
signal target_disappeared

func _ready():
	# Connect the input_event signal to detect mouse clicks
	input_event.connect(_on_input_event)
	
	# Set up collision detection for bullets
	collision_layer = 7  # Target layer
	collision_mask = 0   # Don't detect other targets

func _input(event):
	# Handle mouse clicks for bullet spawning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_screen_pos = event.position
		var world_pos = get_global_mouse_position()
		print("Mouse screen pos: ", mouse_screen_pos, " -> World pos: ", world_pos)
		spawn_bullet_at_position(world_pos)

func _on_input_event(_viewport, event, _shape_idx):
	# Don't process input events if target is disappearing
	if is_disappearing:
		print("IPSC White target is disappearing - ignoring input event")
		return
		
	# Check if it's a left mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Prevent duplicate events in the same frame
		var current_frame = Engine.get_process_frames()
		if current_frame == last_click_frame:
			return
		last_click_frame = current_frame
		
		# Get the click position in local coordinates
		var local_pos = to_local(event.global_position)
		
		# Check if hit is in the target zone (ipsc_white only has D-Zone)
		if is_point_in_zone("DZone", local_pos):
			print("IPSC White target hit - 1 point!")
			return
		
		print("Clicked outside target zone")

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	# Find the collision shape by name
	var zone_node = get_node(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		# Check if point is inside the polygon
		return Geometry2D.is_point_in_polygon(point, zone_node.polygon)
	return false

func spawn_bullet_at_position(world_pos: Vector2):
	print("Spawning bullet at world position: ", world_pos)
	
	if BulletScene:
		var bullet = BulletScene.instantiate()
		
		# Find the top-level scene node to add bullet effects
		# This ensures effects don't get rotated with rotating targets
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
		else:
			# Fallback to immediate parent if scene_root not found
			get_parent().add_child(bullet)
		
		# Use the new set_spawn_position method to ensure proper positioning
		bullet.set_spawn_position(world_pos)
		
		print("Bullet spawned and position set to: ", world_pos)

func handle_bullet_collision(bullet_position: Vector2):
	"""Handle collision detection when a bullet hits this target"""
	# Don't process bullet collisions if target is disappearing
	if is_disappearing:
		print("IPSC White target is disappearing - ignoring bullet collision")
		return "ignored"
	
	print("Bullet collision detected at position: ", bullet_position)
	
	# Convert bullet world position to local coordinates for zone checking
	var local_pos = to_local(bullet_position)
	
	var zone_hit = ""
	var points = 0
	
	# Check if hit is in the target zone (ipsc_white only has D-Zone)
	if is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
		print("COLLISION: IPSC White target hit - 1 point!")
	else:
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", 0)
		print("COLLISION: Bullet hit target but outside scoring zone")
	
	# Update score and emit signal
	total_score += points
	target_hit.emit(zone_hit, points, bullet_position)
	print("Total score: ", total_score)
	
	# Note: Bullet hole is now spawned by bullet script before this method is called
	
	return zone_hit

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position on this target"""
	if BulletHoleScene:
		var bullet_hole = BulletHoleScene.instantiate()
		add_child(bullet_hole)
		bullet_hole.set_hole_position(local_position)
		print("Bullet hole spawned on hostage target at local position: ", local_position)
	else:
		print("ERROR: BulletHoleScene not found!")

func get_total_score() -> int:
	"""Get the current total score for this target"""
	return total_score

func reset_score():
	"""Reset the score to zero"""
	total_score = 0
	print("Score reset to 0")

func play_disappearing_animation():
	"""Start the disappearing animation and disable collision detection"""
	print("Starting disappearing animation for ipsc_white")
	is_disappearing = true
	
	# Get the AnimationPlayer
	var animation_player = get_node("AnimationPlayer")
	if animation_player:
		# Connect to the animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		
		# Play the disappear animation
		animation_player.play("disappear")
		print("Disappear animation started")
	else:
		print("ERROR: AnimationPlayer not found")

func _on_animation_finished(animation_name: String):
	"""Called when any animation finishes"""
	if animation_name == "disappear":
		print("Disappear animation completed")
		_on_disappear_animation_finished()

func _on_disappear_animation_finished():
	"""Called when the disappearing animation completes"""
	print("IPSC White target disappearing animation finished")
	
	# Disable collision detection completely
	set_collision_layer(0)
	set_collision_mask(0)
	
	# Emit signal to notify the drills system that the target has disappeared
	target_disappeared.emit()
	print("target_disappeared signal emitted")
	
	# Keep the disappearing state active to prevent any further interactions
	# is_disappearing remains true

func reset_target():
	"""Reset the target to its original state (useful for restarting)"""
	# Reset animation state
	is_disappearing = false
	
	# Reset visual properties
	modulate = Color.WHITE
	rotation = 0.0
	scale = Vector2.ONE
	
	# Re-enable collision detection
	collision_layer = 7
	collision_mask = 0
	
	# Reset score
	reset_score()
	
	print("IPSC White target reset to original state")
