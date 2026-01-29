extends Node2D

# Track shots for the test target
var shot_count: int = 0
var max_shots: int = 2

# Reference to the IPSC White target instance
@onready var ipsc_target = $IPSCWhite

func _ready():
	# Connect to the target's hit signal
	if ipsc_target and ipsc_target.has_signal("target_hit"):
		ipsc_target.target_hit.connect(_on_target_hit)
		print("Connected to IPSC White target hit signal")
	else:
		print("ERROR: Could not connect to target hit signal")

func _on_target_hit(zone: String, points: int):
	"""Handle when the target is hit"""
	shot_count += 1
	print("IPSC White target hit! Shot ", shot_count, "/", max_shots, " - Zone: ", zone, ", Points: ", points)
	
	# Check if we've reached the maximum shots
	if shot_count >= max_shots:
		print("Maximum shots reached! Triggering disappearing animation...")
		trigger_disappearing_animation()

func trigger_disappearing_animation():
	"""Trigger the disappearing animation"""
	if ipsc_target.has_method("play_disappearing_animation"):
		print("Triggering disappearing animation on IPSC White target")
		ipsc_target.play_disappearing_animation()
	else:
		print("ERROR: play_disappearing_animation method not found on IPSC White target")

func reset_target():
	"""Reset the target for another test"""
	shot_count = 0
	
	# Use the target's built-in reset method if available
	if ipsc_target.has_method("reset_target"):
		ipsc_target.reset_target()
	else:
		# Fallback to manual reset
		ipsc_target.modulate = Color.WHITE
		ipsc_target.rotation = 0.0
		ipsc_target.scale = Vector2.ONE
		ipsc_target.collision_layer = 7
		ipsc_target.collision_mask = 0
		
		if ipsc_target.has_method("reset_score"):
			ipsc_target.reset_score()
	
	# Remove existing bullet holes for a clean reset
	remove_bullet_holes()
	
	print("IPSC White target reset for new test")

func remove_bullet_holes():
	"""Remove all bullet hole children from the target"""
	for child in ipsc_target.get_children():
		# Check if this is a bullet hole (you may need to adjust this check based on your bullet hole naming)
		if child.name.begins_with("BulletHole") or child.has_method("set_hole_position"):
			child.queue_free()
			print("Removed bullet hole from IPSC White target: ", child.name)

func _input(event):
	"""Handle input for testing purposes"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				reset_target()
				print("IPSC White target reset manually (R key)")
			KEY_T:
				trigger_disappearing_animation()
				print("IPSC White animation triggered manually (T key)")
			KEY_SPACE:
				print("Current shot count: ", shot_count, "/", max_shots)
