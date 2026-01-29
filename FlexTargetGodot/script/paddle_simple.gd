extends Area2D

@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

const DEBUG_DISABLED = true

var is_fallen = false
var instance_id: String  # Unique identifier for this instance
var initial_position: Vector2  # Store the paddle's starting position

signal paddle_disappeared

func is_paddle_fallen() -> bool:
	return is_fallen

func _ready():
	instance_id = str(get_instance_id())  # Get unique instance ID
	
	# Store the initial position for relative animation
	initial_position = position
	if not DEBUG_DISABLED:
		print("[paddle_simple ", instance_id, "] Initial position stored: ", initial_position)
	
	# CRITICAL: Duplicate the material to avoid shader parameter sharing between instances
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] Material duplicated to avoid shader sharing")
	
	# Create unique animation with correct starting position
	create_relative_animation()
	
	# Initialize shader parameters to ensure paddle is visible initially
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("fall_progress", 0.0)
		sprite.material.set_shader_parameter("rotation_angle", 0.0)
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] Shader parameters initialized to visible state")

func create_relative_animation():
	"""Create a relative animation that starts from the paddle's actual position"""
	if not animation_player:
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] ERROR: AnimationPlayer not found!")
		return
		
	if not animation_player.has_animation("fall_down"):
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] ERROR: Animation 'fall_down' not found!")
		return
	
	# Get the original animation
	var original_animation = animation_player.get_animation("fall_down")
	
	# Duplicate it to avoid modifying the shared resource
	var new_animation = original_animation.duplicate()
	
	# Find the position track (should be track 2 based on the scene structure)
	var position_track_idx = -1
	for i in range(new_animation.get_track_count()):
		if new_animation.track_get_path(i) == NodePath(".:position"):
			position_track_idx = i
			break
	
	if position_track_idx == -1:
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] ERROR: Position track not found in animation!")
		return
	
	# Update the position track to use relative positions
	var fall_offset = Vector2(0, 120)  # The original fall distance
	var start_pos = initial_position
	var end_pos = initial_position + fall_offset
	
	new_animation.track_set_key_value(position_track_idx, 0, start_pos)
	new_animation.track_set_key_value(position_track_idx, 1, end_pos)
	
	# Create a new animation library with the modified animation
	var new_library = AnimationLibrary.new()
	new_library.add_animation("fall_down", new_animation)
	
	# Replace the animation library
	animation_player.remove_animation_library("")
	animation_player.add_animation_library("", new_library)

	if not DEBUG_DISABLED:
		print("[paddle_simple ", instance_id, "] Created relative animation starting from ", initial_position)

func trigger_fall_animation():
	if is_fallen:
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] Already fallen, ignoring trigger")
		return

	if not DEBUG_DISABLED:	
		print("[paddle_simple ", instance_id, "] ⚠️  TRIGGERING FALL ANIMATION - WHO CALLED THIS?")
		print("[paddle_simple ", instance_id, "] Node name: ", name)
		print("[paddle_simple ", instance_id, "] Parent: ", get_parent().name if get_parent() else "no parent")
	
	is_fallen = true
	
	# Play the fall animation
	if animation_player.has_animation("fall_down"):
		animation_player.play("fall_down")
		# Connect to animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	else:
		if not DEBUG_DISABLED:
			print("[paddle_simple] Warning: fall_down animation not found")
		# Immediately hide if no animation
		_hide_paddle()

func _on_animation_finished(anim_name: String):
	"""Called when animation finishes"""
	if anim_name == "fall_down":
		if not DEBUG_DISABLED:
			print("[paddle_simple ", instance_id, "] Fall animation completed")
		_hide_paddle()

func _hide_paddle():
	"""Hide the paddle and emit disappeared signal"""
	visible = false
	paddle_disappeared.emit()
	if not DEBUG_DISABLED:
		print("[paddle_simple ", instance_id, "] Paddle hidden and disappeared signal emitted")

func reset_paddle():
	"""Reset the paddle to its initial state"""
	if not DEBUG_DISABLED:
		print("[paddle_simple ", instance_id, "] Resetting paddle")
	is_fallen = false
	visible = true
	position = initial_position  # Reset to initial position, not (0,0)
	
	# Reset shader parameters if they exist
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("fall_progress", 0.0)
		sprite.material.set_shader_parameter("rotation_angle", 0.0)
