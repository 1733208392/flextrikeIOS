extends Node2D

# Signals for score and performance tracking  
signal target_hit(popper_id: String, zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared(popper_id: String)

# WebSocket connection
var websocket_listener = null

# Bullet impact scene
const BulletImpactScene = preload("res://scene/bullet_impact.tscn")
# Note: BulletHoleScene removed - poppers are steel targets and don't create bullet holes

# Popper references
@onready var popper1_area = $Popper1Area
@onready var popper2_area = $Popper2Area
@onready var popper1_simple = $Popper1Area/Popper1_simple
@onready var popper2_simple = $Popper2Area/Popper2_simple

# Track which poppers have been hit
var popper1_hit = false
var popper2_hit = false

# Debug tracking
var hit_counter = 0
var drill_active: bool = false  # Flag to ignore shots before drill starts

# Track total poppers for target_disappeared signal
var total_poppers = 2
var poppers_disappeared = []

# Note: bullet_holes array removed - poppers are steel targets and don't create bullet holes

# Points per hit
const POPPER_POINTS = 5

func _ready():
	
	# Debug: Check if all nodes are properly loaded
	
	# Defer initialization to ensure all nodes are fully ready
	call_deferred("initialize_scene")

func initialize_scene():
	"""Initialize the scene after all nodes are ready"""
	
	# Connect to WebSocket for bullet shots
	connect_websocket()
	
	# Connect to popper disappeared signals
	connect_popper_signals()
	

func validate_nodes() -> bool:
	"""Validate that all required nodes are loaded and not null"""
	if not popper1_simple:
		return false
	if not popper2_simple:
		return false
	if not popper1_area:
		return false
	if not popper2_area:
		return false
	return true

func connect_websocket():
	"""Connect to WebSocket to receive bullet shot positions"""
	websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		# Check if already connected to avoid duplicate connections
		if not websocket_listener.bullet_hit.is_connected(_on_websocket_bullet_hit):
			websocket_listener.bullet_hit.connect(_on_websocket_bullet_hit)

func connect_popper_signals():
	"""Connect to popper disappeared signals"""
	if popper1_simple:
		popper1_simple.popper_disappeared.connect(func(): _on_popper_disappeared("Popper1"))
		
	if popper2_simple:
		popper2_simple.popper_disappeared.connect(func(): _on_popper_disappeared("Popper2"))

func _on_websocket_bullet_hit(world_pos: Vector2, a: int = 0, t: int = 0):
	"""Handle bullet hits from WebSocket - check which area was hit"""
	
	# Ignore shots if drill is not active yet
	if not drill_active:
		return
	
	# Validate all nodes are ready before processing
	if not validate_nodes():
		return
		
	hit_counter += 1
	
	# Test each area individually
	var hit_popper1 = is_point_in_area(world_pos, popper1_area)
	var hit_popper2 = is_point_in_area(world_pos, popper2_area)
	
	# Check which area was hit - prioritize closer hits and prevent double hits
	var should_hit_popper1 = hit_popper1 and not popper1_hit
	var should_hit_popper2 = hit_popper2 and not popper2_hit
	
	# Create bullet impact visual effect - only consider it a hit if the target hasn't fallen
	var is_hit = should_hit_popper1 or should_hit_popper2
	create_bullet_impact(world_pos, is_hit)
	
	# Only trigger one popper per hit, prioritize based on distance if both are hit
	if should_hit_popper1 and should_hit_popper2:
		# If both areas are hit, choose the closer one
		if popper1_simple and popper2_simple:
			var dist1 = world_pos.distance_to(popper1_simple.global_position)
			var dist2 = world_pos.distance_to(popper2_simple.global_position)
			
			if dist1 <= dist2:
				trigger_popper1_hit(world_pos, t)
			else:
				trigger_popper2_hit(world_pos, t)
		else:
			pass
	elif should_hit_popper1:
		trigger_popper1_hit(world_pos, t)
	elif should_hit_popper2:
		trigger_popper2_hit(world_pos, t)
	else:
		# Emit miss signal if no popper was hit and not already fallen
		if not (popper1_hit and popper2_hit):
			target_hit.emit("miss", "Miss", 0, world_pos, t)  # 0 points for miss (performance tracker will score from settings)

func is_point_in_area(world_pos: Vector2, area: Area2D) -> bool:
	"""Check if a world position is inside an Area2D"""
	if not area:
		return false
		
	# Get all collision shapes in the area
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			# Convert world position to area's local coordinate system
			var area_local_pos = area.to_local(world_pos)
			
			if child is CollisionPolygon2D:
				var polygon = child.polygon
				if polygon.size() > 0:
					# Convert world position to collision polygon's local coordinate system
					var collision_local_pos = child.to_local(area.to_global(area_local_pos))
					# Use Godot's built-in point-in-polygon test (same as popper.gd)
					var result = Geometry2D.is_point_in_polygon(collision_local_pos, polygon)
					if result:
						return true
	
	return false

func trigger_popper1_hit(hit_position: Vector2, t: int = 0):
	"""Trigger Popper1 animation and scoring"""
	if popper1_hit:
		return  # Already hit
		
	popper1_hit = true
	
	# Trigger the animation on popper_simple
	if popper1_simple and popper1_simple.has_method("trigger_fall_animation"):
		popper1_simple.trigger_fall_animation()
	
	# Emit scoring signal with t parameter
	target_hit.emit("Popper1", "PopperZone", POPPER_POINTS, hit_position, t)

func trigger_popper2_hit(hit_position: Vector2, t: int = 0):
	"""Trigger Popper2 animation and scoring"""
	if popper2_hit:
		return  # Already hit
		
	popper2_hit = true
	
	# Trigger the animation on popper_simple
	if popper2_simple and popper2_simple.has_method("trigger_fall_animation"):
		popper2_simple.trigger_fall_animation()
	
	# Emit scoring signal with t parameter
	target_hit.emit("Popper2", "PopperZone", POPPER_POINTS, hit_position, t)

func _on_popper_disappeared(popper_id: String):
	"""Handle when a popper disappears after animation"""
	
	# Track which poppers have disappeared
	if popper_id not in poppers_disappeared:
		poppers_disappeared.append(popper_id)
		
		# Only emit target_disappeared when ALL poppers have disappeared
		if poppers_disappeared.size() >= total_poppers:
			target_disappeared.emit("2poppers_simple")

func reset_scene():
	"""Reset both poppers to their initial state"""
	
	popper1_hit = false
	popper2_hit = false
	poppers_disappeared.clear()
	hit_counter = 0
	
	if popper1_simple:
		popper1_simple.reset_popper()
	if popper2_simple:
		popper2_simple.reset_popper()

func create_bullet_impact(world_pos: Vector2, is_hit: bool = false):
	"""Create bullet impact visual effects at the hit position"""
	
	# Always create bullet impact effect (visual)
	if BulletImpactScene:
		var impact = BulletImpactScene.instantiate()
		get_parent().add_child(impact)  # Add to parent so it's not affected by this node's transform
		impact.global_position = world_pos
	
	# Only play impact sound for hits (not misses)
	if is_hit:
		play_impact_sound_at_position(world_pos)
	
	# NO BULLET HOLES: Poppers are steel targets, don't create bullet holes

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play steel impact sound effect at specific position"""
	# Load the metal impact sound for steel targets
	var impact_sound = preload("res://audio/metal_hit.WAV")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.9, 1.1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
