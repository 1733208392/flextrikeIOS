extends Node2D

# Signals for score and performance tracking  
signal target_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(paddle_id: String)

# WebSocket connection
var websocket_listener = null

# Bullet impact scene
const BulletImpactScene = preload("res://scene/bullet_impact.tscn")
# Note: BulletHoleScene removed - paddles are steel targets and don't create bullet holes

# Paddle references
@onready var paddle1_area = $Paddle1Area
@onready var paddle2_area = $Paddle2Area
@onready var paddle3_area = $Paddle3Area
@onready var paddle1_simple = $Paddle1Area/Paddle1
@onready var paddle2_simple = $Paddle2Area/Paddle2
@onready var paddle3_simple = $Paddle3Area/Paddle3

# Track which paddles have been hit
var paddle1_hit = false
var paddle2_hit = false
var paddle3_hit = false

# Debug tracking
var hit_counter = 0
var drill_active: bool = false  # Flag to ignore shots before drill starts

# Track total paddles for target_disappeared signal
var total_paddles = 3
var paddles_disappeared = []

# Note: bullet_holes array removed - paddles are steel targets and don't create bullet holes

# Points per hit
const PADDLE_POINTS = 5

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

func _ready():
	if DEBUG_DISABLED:
		print("=== 3PADDLES_SIMPLE READY ===")
	
	# Debug: Check if all nodes are properly loaded
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Node validation:")
		print("  - paddle1_simple: ", paddle1_simple)
		print("  - paddle2_simple: ", paddle2_simple) 
		print("  - paddle3_simple: ", paddle3_simple) 
		print("  - paddle1_area: ", paddle1_area)
		print("  - paddle2_area: ", paddle2_area)
		print("  - paddle3_area: ", paddle3_area)
	
	# Defer initialization to ensure all nodes are fully ready
	call_deferred("initialize_scene")

func initialize_scene():
	"""Initialize the scene after all nodes are ready"""
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Initializing scene...")
	
	# Connect to WebSocket for bullet shots
	connect_websocket()
	
	# Connect to paddle disappeared signals
	connect_paddle_signals()
	
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Scene initialization complete")

func validate_nodes() -> bool:
	"""Validate that all required nodes are loaded and not null"""
	if not paddle1_simple:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle1_simple is null")
		return false
	if not paddle2_simple:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle2_simple is null")
		return false
	if not paddle3_simple:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle3_simple is null")
		return false
	if not paddle1_area:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle1_area is null")
		return false
	if not paddle2_area:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle2_area is null")
		return false
	if not paddle3_area:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - paddle3_area is null")
		return false
	return true

func connect_websocket():
	"""Connect to WebSocket to receive bullet shot positions"""
	websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		# Check if already connected to avoid duplicate connections
		if not websocket_listener.bullet_hit.is_connected(_on_websocket_bullet_hit):
			websocket_listener.bullet_hit.connect(_on_websocket_bullet_hit)
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: Connected to WebSocket for bullet hits")
		else:
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: Already connected to WebSocket")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE ERROR: Could not find WebSocketListener")

func connect_paddle_signals():
	"""Connect to paddle disappeared signals"""
	if paddle1_simple:
		paddle1_simple.paddle_disappeared.connect(func(): _on_paddle_disappeared("Paddle1"))
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Connected to Paddle1 signal")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE ERROR: paddle1_simple is null!")
		
	if paddle2_simple:
		paddle2_simple.paddle_disappeared.connect(func(): _on_paddle_disappeared("Paddle2"))
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Connected to Paddle2 signal")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE ERROR: paddle2_simple is null!")
		
	if paddle3_simple:
		paddle3_simple.paddle_disappeared.connect(func(): _on_paddle_disappeared("Paddle3"))
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Connected to Paddle3 signal")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE ERROR: paddle3_simple is null!")

func _on_websocket_bullet_hit(world_pos: Vector2, a: int = 0, t: int = 0):
	"""Handle bullet hits from WebSocket - check which area was hit"""
	
	# Ignore shots if drill is not active yet
	if not drill_active:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Ignoring shot because drill is not active yet")
		return
	
	# Validate all nodes are ready before processing
	if not validate_nodes():
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ERROR - Nodes not ready, skipping WebSocket hit")
		return
		
	hit_counter += 1
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: ========== WebSocket Hit Test #", hit_counter, " ==========")
		print("3PADDLES_SIMPLE: Received bullet hit at: ", world_pos)
		print("3PADDLES_SIMPLE: Current state - Paddle1_hit: ", paddle1_hit, ", Paddle2_hit: ", paddle2_hit, ", Paddle3_hit: ", paddle3_hit)
	
	# Convert world position to local position for hit detection
	var local_pos = to_local(world_pos)
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Local position: ", local_pos)
	
	# Test each area individually
	var hit_paddle1 = is_point_in_area(world_pos, paddle1_area)
	var hit_paddle2 = is_point_in_area(world_pos, paddle2_area)
	var hit_paddle3 = is_point_in_area(world_pos, paddle3_area)
	
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Area test results:")
		print("  - Paddle1Area hit: ", hit_paddle1)
		print("  - Paddle2Area hit: ", hit_paddle2)
		print("  - Paddle3Area hit: ", hit_paddle3)
	
	# Print area positions for reference
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Area positions:")
		if paddle1_area:
			print("  - Paddle1Area at: ", paddle1_area.global_position)
		else:
			print("  - Paddle1Area: NULL!")
		if paddle2_area:
			print("  - Paddle2Area at: ", paddle2_area.global_position)
		else:
			print("  - Paddle2Area: NULL!")
		if paddle3_area:
			print("  - Paddle3Area at: ", paddle3_area.global_position)
		else:
			print("  - Paddle3Area: NULL!")
	
	# Print paddle positions for reference
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Paddle positions:")
		if paddle1_simple:
			print("  - Paddle1 at: ", paddle1_simple.global_position)
		else:
			print("  - Paddle1: NULL!")
		if paddle2_simple:
			print("  - Paddle2 at: ", paddle2_simple.global_position)
		else:
			print("  - Paddle2: NULL!")
		if paddle3_simple:
			print("  - Paddle3 at: ", paddle3_simple.global_position)
		else:
			print("  - Paddle3: NULL!")
	
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: ================================================")
	
	# Check which area was hit - prioritize closer hits and prevent double hits
	var should_hit_paddle1 = hit_paddle1 and not paddle1_hit
	var should_hit_paddle2 = hit_paddle2 and not paddle2_hit
	var should_hit_paddle3 = hit_paddle3 and not paddle3_hit
	
	# Create bullet impact visual effect - only consider it a hit if the target hasn't fallen
	var is_hit = should_hit_paddle1 or should_hit_paddle2 or should_hit_paddle3
	create_bullet_impact(world_pos, is_hit)
	
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Hit tests - Paddle1: ", should_hit_paddle1, ", Paddle2: ", should_hit_paddle2, ", Paddle3: ", should_hit_paddle3)
	
	# Find all paddles that should be hit and choose the closest one
	var hit_paddles = []
	if should_hit_paddle1:
		hit_paddles.append({"id": 1, "pos": paddle1_simple.global_position, "func": trigger_paddle1_hit})
	if should_hit_paddle2:
		hit_paddles.append({"id": 2, "pos": paddle2_simple.global_position, "func": trigger_paddle2_hit})
	if should_hit_paddle3:
		hit_paddles.append({"id": 3, "pos": paddle3_simple.global_position, "func": trigger_paddle3_hit})
	
	if hit_paddles.size() > 0:
		# If multiple paddles are hit, choose the closest one
		if hit_paddles.size() > 1:
			var closest_paddle = null
			var closest_distance = INF
			
			for paddle_data in hit_paddles:
				var distance = world_pos.distance_to(paddle_data.pos)
				if distance < closest_distance:
					closest_distance = distance
					closest_paddle = paddle_data
			
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: ✅ Multiple hits, triggering closest Paddle", closest_paddle.id, " - FALL ANIMATION WILL START")
			closest_paddle.func.call(world_pos)
		else:
			# Only one paddle hit
			var paddle_data = hit_paddles[0]
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: ✅ Hit detected on Paddle", paddle_data.id, "Area only! - FALL ANIMATION WILL START")
			paddle_data.func.call(world_pos)
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ⭕ No hit detected or paddles already fallen - NO ANIMATION")
		# Emit miss signal if no paddle was hit and not all paddles already fallen
		if not (paddle1_hit and paddle2_hit and paddle3_hit):
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: 🎯 MISS - Emitting miss signal")
			target_hit.emit("miss", "Miss", 0, world_pos)  # 0 points for miss (performance tracker will score from settings)

func is_point_in_area(world_pos: Vector2, area: Area2D) -> bool:
	"""Check if a world position is inside an Area2D"""
	if not area:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Area is null")
		return false
		
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Testing point ", world_pos, " against area at ", area.global_position)
		
	# Get all collision shapes in the area
	for child in area.get_children():
		if child is CollisionShape2D:
			# Convert world position to area's local coordinate system
			var area_local_pos = area.to_local(world_pos)
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: Area local pos: ", area_local_pos)
			
			var shape = child.shape
			if shape is CircleShape2D:
				# Check distance from collision shape center
				var collision_local_pos = child.to_local(area.to_global(area_local_pos))
				var distance = collision_local_pos.length()
				var is_inside = distance <= shape.radius
				if DEBUG_DISABLED:
					print("3PADDLES_SIMPLE: Circle test - distance: ", distance, ", radius: ", shape.radius, ", result: ", is_inside)
				if is_inside:
					return true
	
	return false

func trigger_paddle1_hit(hit_position: Vector2):
	"""Trigger Paddle1 animation and scoring"""
	if paddle1_hit:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle1 already hit, ignoring")
		return  # Already hit
	
	if paddle1_simple and paddle1_simple.has_method("is_paddle_fallen") and paddle1_simple.is_paddle_fallen():
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle1 already fallen, ignoring")
		return  # Already fallen
		
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 🎯 TRIGGERING PADDLE1 HIT")
	paddle1_hit = true
	
	# Note: clear_bullet_holes() removed - paddles don't create bullet holes
	
	# Trigger the animation on paddle_simple
	if paddle1_simple and paddle1_simple.has_method("trigger_fall_animation"):
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: 🎬 Calling trigger_fall_animation() on Paddle1")
		paddle1_simple.trigger_fall_animation()
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ✅ Paddle1 fall animation triggered successfully")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ❌ ERROR - Paddle1 not found or missing method")
	
	# Emit scoring signal
	target_hit.emit("Paddle1", "PaddleZone", PADDLE_POINTS, hit_position)
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 📊 Scored ", PADDLE_POINTS, " points for Paddle1 hit")

func trigger_paddle2_hit(hit_position: Vector2):
	"""Trigger Paddle2 animation and scoring"""
	if paddle2_hit:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle2 already hit, ignoring")
		return  # Already hit
	
	if paddle2_simple and paddle2_simple.has_method("is_paddle_fallen") and paddle2_simple.is_paddle_fallen():
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle2 already fallen, ignoring")
		return  # Already fallen
		
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 🎯 TRIGGERING PADDLE2 HIT")
	paddle2_hit = true
	
	# Note: clear_bullet_holes() removed - paddles don't create bullet holes
	
	# Trigger the animation on paddle_simple
	if paddle2_simple and paddle2_simple.has_method("trigger_fall_animation"):
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: 🎬 Calling trigger_fall_animation() on Paddle2")
		paddle2_simple.trigger_fall_animation()
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ✅ Paddle2 fall animation triggered successfully")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ❌ ERROR - Paddle2 not found or missing method")
	
	# Emit scoring signal
	target_hit.emit("Paddle2", "PaddleZone", PADDLE_POINTS, hit_position)
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 📊 Scored ", PADDLE_POINTS, " points for Paddle2 hit")

func trigger_paddle3_hit(hit_position: Vector2):
	"""Trigger Paddle3 animation and scoring"""
	if paddle3_hit:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle3 already hit, ignoring")
		return  # Already hit
	
	if paddle3_simple and paddle3_simple.has_method("is_paddle_fallen") and paddle3_simple.is_paddle_fallen():
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Paddle3 already fallen, ignoring")
		return  # Already fallen
		
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 🎯 TRIGGERING PADDLE3 HIT")
	paddle3_hit = true
	
	# Note: clear_bullet_holes() removed - paddles don't create bullet holes
	
	# Trigger the animation on paddle_simple
	if paddle3_simple and paddle3_simple.has_method("trigger_fall_animation"):
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: 🎬 Calling trigger_fall_animation() on Paddle3")
		paddle3_simple.trigger_fall_animation()
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ✅ Paddle3 fall animation triggered successfully")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ❌ ERROR - Paddle3 not found or missing method")
	
	# Emit scoring signal
	target_hit.emit("Paddle3", "PaddleZone", PADDLE_POINTS, hit_position)
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: 📊 Scored ", PADDLE_POINTS, " points for Paddle3 hit")

func _on_paddle_disappeared(paddle_id: String):
	"""Handle when a paddle disappears after animation"""
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: ", paddle_id, " disappeared")
	
	# Track which paddles have disappeared
	if paddle_id not in paddles_disappeared:
		paddles_disappeared.append(paddle_id)
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ", paddles_disappeared.size(), "/", total_paddles, " paddles disappeared")
		
		# Only emit target_disappeared when ALL paddles have disappeared
		if paddles_disappeared.size() >= total_paddles:
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: ✅ All paddles disappeared - emitting target_disappeared")
			target_disappeared.emit("3paddles_simple")
		else:
			if DEBUG_DISABLED:
				print("3PADDLES_SIMPLE: Waiting for remaining paddles to disappear")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: ", paddle_id, " already marked as disappeared")

func reset_scene():
	"""Reset all paddles to their initial state"""
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Resetting scene")
	
	paddle1_hit = false
	paddle2_hit = false
	paddle3_hit = false
	paddles_disappeared.clear()
	hit_counter = 0
	
	# Note: clear_bullet_holes() removed - paddles don't create bullet holes
	
	if paddle1_simple:
		paddle1_simple.reset_paddle()
	if paddle2_simple:
		paddle2_simple.reset_paddle()
	if paddle3_simple:
		paddle3_simple.reset_paddle()

func create_bullet_impact(world_pos: Vector2, is_hit: bool = false):
	"""Create bullet impact visual effects at the hit position"""
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: Creating bullet impact at: ", world_pos, " (hit: ", is_hit, ")")
	
	# Always create bullet impact effect (visual)
	if BulletImpactScene:
		var impact = BulletImpactScene.instantiate()
		get_parent().add_child(impact)  # Add to parent so it's not affected by this node's transform
		impact.global_position = world_pos
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Bullet impact visual created")
	
	# Only play impact sound for hits (not misses)
	if is_hit:
		play_impact_sound_at_position(world_pos)
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Impact sound played for hit")
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: No sound played for miss")
	
	# No bullet holes created for paddles (steel targets don't create holes)
	if DEBUG_DISABLED:
		print("3PADDLES_SIMPLE: No bullet hole created - steel target")

func play_impact_sound_at_position(world_pos: Vector2):
	"""Play steel impact sound effect at specific position"""
	# Load the metal impact sound for steel targets
	var impact_sound = preload("res://audio/metal_hit.WAV")
	
	if impact_sound:
		# Create AudioStreamPlayer2D for positional audio
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5  # Adjust volume as needed
		audio_player.pitch_scale = randf_range(0.8, 1)  # Add slight pitch variation for realism
		
		# Add to scene and play
		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()
		
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: Steel impact sound played at: ", world_pos)
	else:
		if DEBUG_DISABLED:
			print("3PADDLES_SIMPLE: No impact sound found!")
