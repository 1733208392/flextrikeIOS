extends Node2D

# Test script for 2poppers_simple scene
var test_positions = [
	Vector2(-150, 100),  # Should hit Popper1Area
	Vector2(150, 100),   # Should hit Popper2Area
	Vector2(0, 100),     # Should miss both
]

var current_test = 0
var websocket_listener = null

func _ready():
	print("=== TEST 2POPPERS SIMPLE ===")
	
	# Connect to WebSocket listener if available
	websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		print("TEST: WebSocket listener found")
	else:
		print("TEST: WebSocket listener not found - will simulate hits")
	
	# Start test after a delay
	await get_tree().create_timer(2.0).timeout
	start_test()

func start_test():
	print("TEST: Starting automated hit tests...")
	
	# Test each position
	for i in range(test_positions.size()):
		print("TEST: Simulating hit at position: ", test_positions[i])
		simulate_bullet_hit(test_positions[i])
		await get_tree().create_timer(1.5).timeout

func simulate_bullet_hit(pos: Vector2):
	"""Simulate a bullet hit by directly calling the WebSocket bullet handler"""
	var poppers_simple = get_node_or_null("2PoppersSimple")
	if poppers_simple and poppers_simple.has_method("_on_websocket_bullet_hit"):
		poppers_simple._on_websocket_bullet_hit(pos)
	else:
		print("TEST ERROR: Could not find 2PoppersSimple node or method")

func _input(event):
	"""Allow manual testing with mouse clicks"""
	if event is InputEventMouseButton and event.pressed:
		print("TEST: Manual click at: ", event.global_position)
		simulate_bullet_hit(event.global_position)