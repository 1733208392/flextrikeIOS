extends Node2D

# ===== PERFORMANCE OPTIMIZATIONS =====
# 1. Conditional debug logging to reduce print overhead during rapid firing
# 2. Dictionary-based tracking for O(1) lookup instead of Array linear search
# 3. Minimal essential logging only for errors
# =======================================

signal target_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2, t: int)
signal target_disappeared(paddle_id: String)

# Performance optimizations
const DEBUG_DISABLED = true  # Set to true for verbose debugging
var paddles_hit = {}  # Use Dictionary for O(1) lookup instead of Array

func _ready():
	if not DEBUG_DISABLED:
		print("=== 3PADDLES READY ===")
	# Connect to all paddle signals
	connect_paddle_signals()

func connect_paddle_signals():
	"""Connect to signals from all paddle children"""
	if not DEBUG_DISABLED:
		print("=== CONNECTING TO PADDLE SIGNALS ===")
	
	for child in get_children():
		if child.has_signal("target_hit") and child.has_signal("target_disappeared"):
			if not DEBUG_DISABLED:
				print("Connecting to paddle: ", child.name)
			child.target_hit.connect(_on_paddle_hit)
			child.target_disappeared.connect(_on_paddle_disappeared)
		else:
			print("Child ", child.name, " doesn't have expected signals")  # Keep this as it indicates a setup error

func _on_paddle_hit(paddle_id: String, zone: String, points: int, hit_position: Vector2, t: int = 0):
	"""Handle when a paddle is hit - optimized for performance"""
	if not DEBUG_DISABLED:
		print("=== PADDLE HIT IN 3PADDLES ===")
		print("Paddle ID: ", paddle_id, " Zone: ", zone, " Points: ", points, " Position: ", hit_position)
	
	# Track which paddles have been hit using O(1) Dictionary lookup
	if not paddles_hit.has(paddle_id):
		paddles_hit[paddle_id] = true
		if not DEBUG_DISABLED:
			print("Marked paddle ", paddle_id, " as hit (total hit: ", paddles_hit.size(), ")")
	
	# Emit the signal up to the drills manager, passing through the t value
	target_hit.emit(paddle_id, zone, points, hit_position, t)

func _on_paddle_disappeared(paddle_id: String):
	"""Handle when a paddle disappears - optimized for performance"""
	if not DEBUG_DISABLED:
		print("=== PADDLE DISAPPEARED IN 3PADDLES ===")
		print("Paddle ID: ", paddle_id)
	
	# Check if all paddles have been hit using Dictionary size
	if paddles_hit.size() >= 3:  # All 3 paddles hit
		if not DEBUG_DISABLED:
			print("All paddles have been hit - emitting target_disappeared")
		target_disappeared.emit("3paddles")
	else:
		if not DEBUG_DISABLED:
			print("Only ", paddles_hit.size(), " paddles hit so far")
