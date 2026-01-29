extends Node2D

# ===== PERFORMANCE OPTIMIZATIONS =====
# 1. Conditional debug logging to reduce print overhead during rapid firing
# 2. Dictionary-based tracking for O(1) lookup instead of Array linear search
# 3. Minimal essential logging only for errors
# =======================================

signal target_hit(popper_id: String, zone: String, points: int, hit_position: Vector2)
signal target_disappeared(popper_id: String)

# Performance optimizations
const DEBUG_DISABLED = true  # Set to false for production release
var poppers_hit = {}  # Use Dictionary for O(1) lookup instead of Array
var poppers_disappeared = {}  # Track which poppers have disappeared

# BANDAGE FIX: Miss detection variables
var recorded_misses = []  # Array of Vector2 positions that missed both poppers
var recorded_hits = []   # Array of Vector2 positions that hit poppers
var websocket_listener = null

func _ready():
	if not DEBUG_DISABLED:
		print("=== 2POPPERS READY ===")
	# Set popper IDs for each child
	set_popper_ids()
	# Connect to all popper signals
	connect_popper_signals()
	# BANDAGE FIX: Connect to WebSocket for miss detection
	connect_websocket_for_miss_detection()

func set_popper_ids():
	"""Set unique IDs for each popper child"""
	for child in get_children():
		if child.has_method("set"):  # Check if it's a node that can have properties set
			child.popper_id = child.name
			if not DEBUG_DISABLED:
				print("Set popper_id for ", child.name, " to: ", child.popper_id)

func connect_popper_signals():
	"""Connect to signals from all popper children"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING TO POPPER SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			if not DEBUG_DISABLED:
				print("Connecting to popper: ", child.name)
			# Use a lambda/callable to pass the popper_id
			child.target_hit.connect(func(zone: String, points: int, hit_position: Vector2): _on_popper_hit(child.name, zone, points, hit_position))
			child.target_disappeared.connect(func(): _on_popper_disappeared(child.name))
		else:
			print("Child ", child.name, " doesn't have expected signals")  # Keep this as it indicates a setup error

func connect_websocket_for_miss_detection():
	"""BANDAGE FIX: Connect to WebSocket to record all bullets for miss detection"""
	websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		websocket_listener.bullet_hit.connect(_on_websocket_bullet_for_miss_detection)
		if not DEBUG_DISABLED:
			print("2POPPERS: Connected to WebSocket for miss detection")
	else:
		print("2POPPERS ERROR: Could not find WebSocketListener for miss detection")

func _on_websocket_bullet_for_miss_detection(world_pos: Vector2):
	"""BANDAGE FIX: Record all WebSocket bullets as potential misses"""
	recorded_misses.append(world_pos)
	if not DEBUG_DISABLED:
		print("2POPPERS: Recorded potential miss at: ", world_pos, " (total recorded: ", recorded_misses.size(), ")")

func _on_popper_hit(popper_id: String, zone: String, points: int, hit_position: Vector2):
	"""Handle when a popper is hit - optimized for performance"""
	if not DEBUG_DISABLED:
		print("=== POPPER HIT IN 2POPPERS ===")
		print("Popper ID: ", popper_id, " Zone: ", zone, " Points: ", points, " Position: ", hit_position)
	
	# BANDAGE FIX: Record hit position for miss deduplication
	recorded_hits.append(hit_position)
	if not DEBUG_DISABLED:
		print("2POPPERS: Recorded hit at: ", hit_position, " (total hits: ", recorded_hits.size(), ")")
	
	# Track which poppers have been hit using O(1) Dictionary lookup
	if not poppers_hit.has(popper_id):
		poppers_hit[popper_id] = true
		if not DEBUG_DISABLED:
			print("Marked popper ", popper_id, " as hit (total hit: ", poppers_hit.size(), ")")
	
	# Emit the signal up to the drills manager
	target_hit.emit(popper_id, zone, points, hit_position)

func _on_popper_disappeared(popper_id: String):
	"""Handle when a popper disappears - optimized for performance"""
	if not DEBUG_DISABLED:
		print("=== POPPER DISAPPEARED IN 2POPPERS ===")
		print("Popper ID: ", popper_id)
	
	# Track which poppers have disappeared using O(1) Dictionary lookup
	if not poppers_disappeared.has(popper_id):
		poppers_disappeared[popper_id] = true
		if not DEBUG_DISABLED:
			print("Marked popper ", popper_id, " as disappeared (total disappeared: ", poppers_disappeared.size(), ")")
		
		# Check if all poppers have disappeared using Dictionary size
		var total_poppers = get_children().size()
		if poppers_disappeared.size() >= total_poppers:  # All poppers disappeared
			if not DEBUG_DISABLED:
				print("All ", total_poppers, " poppers have disappeared - emitting target_disappeared")
			
			# BANDAGE FIX: Perform miss deduplication before emitting target_disappeared
			cleanup_and_emit_misses()
			
			target_disappeared.emit("2poppers")
		else:
			if not DEBUG_DISABLED:
				print("Only ", poppers_disappeared.size(), "/", total_poppers, " poppers disappeared so far")
	else:
		if not DEBUG_DISABLED:
			print("Popper ", popper_id, " already marked as disappeared - ignoring duplicate")

func cleanup_and_emit_misses():
	"""BANDAGE FIX: Clean up recorded misses and emit valid miss signals"""
	if not DEBUG_DISABLED:
		print("=== MISS CLEANUP STARTING ===")
		print("Recorded misses: ", recorded_misses.size())
		print("Recorded hits: ", recorded_hits.size())
	
	var valid_misses = []
	const POSITION_TOLERANCE = 5.0  # Pixels - consider positions within 5px as "same location"
	
	# Step 1: Remove duplicate misses at exactly the same location
	for miss_pos in recorded_misses:
		var is_duplicate = false
		
		# Check if this miss position is already in valid_misses
		for existing_miss in valid_misses:
			if miss_pos.distance_to(existing_miss) <= POSITION_TOLERANCE:
				is_duplicate = true
				break
		
		if not is_duplicate:
			valid_misses.append(miss_pos)
	
	if not DEBUG_DISABLED:
		print("After removing duplicate misses: ", valid_misses.size())
	
	# Step 2: Remove misses that have corresponding hits at the same location
	var final_misses = []
	for miss_pos in valid_misses:
		var has_hit_at_same_position = false
		
		# Check if there's a hit at the same position
		for hit_pos in recorded_hits:
			if miss_pos.distance_to(hit_pos) <= POSITION_TOLERANCE:
				has_hit_at_same_position = true
				break
		
		if not has_hit_at_same_position:
			final_misses.append(miss_pos)
	
	if not DEBUG_DISABLED:
		print("Final misses after removing hit positions: ", final_misses.size())
	
	# Step 3: Emit miss signals for remaining valid misses
	for miss_pos in final_misses:
		target_hit.emit("miss", "Miss", 0, miss_pos)
		if not DEBUG_DISABLED:
			print("Emitted miss signal at: ", miss_pos)
	
	if not DEBUG_DISABLED:
		print("=== MISS CLEANUP COMPLETED ===")
		print("Total misses emitted: ", final_misses.size())
