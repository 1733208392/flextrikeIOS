extends Node

# Target Animation Library
# Provides predefined animation sequences for targets
# Each animation is defined by a set of actions and duration

class_name TargetAnimationLibrary

# Signal emitted when a scene is swapped during flash_sequence animation
signal target_swapped(old_target: Node, new_target: Node)

# Dictionary to track active tweens for flash sequences
var active_tweens: Dictionary = {}

# Configurable default durations for animations (in seconds)
@export var flash_duration: float = 3.0
@export var run_through_duration: float = 2.0
@export var swing_left_duration: float = 2.0
@export var swing_right_duration: float = 2.0
@export var up_duration: float = 1.5
@export var down_duration: float = 1.5

# Animation action definitions
enum AnimationAction {
	FLASH,           # Show target for duration then disappear
	RUN_THROUGH,     # Move target from left to right
	RUN_THROUGH_REVERSE, # Move target from right to left
	SWING_LEFT,      # Appear rotated from left, disappear after duration
	SWING_RIGHT,     # Appear rotated from right, disappear after duration
	UP,              # Show target from bottom, stop at 1/3 visible
	DOWN,            # Show target from top, stop at 1/3 visible
	FLASH_SEQUENCE,  # Sequence of scene swaps with specified durations
}

# Animation configuration structure
class AnimationConfig:
	var action: AnimationAction
	var duration: float
	var start_delay: float = 0.0
	var easing: Tween.EaseType = Tween.EASE_IN_OUT
	var transition: Tween.TransitionType = Tween.TRANS_SINE
	var amplitude: float = 1.0  # Multiplier for movement/rotation amplitude
	var direction: int = 1      # 1 for normal, -1 for reverse direction

	func _init(p_action: AnimationAction, p_duration: float, p_start_delay: float = 0.0):
		action = p_action
		duration = p_duration
		start_delay = p_start_delay

# Flash sequence configuration
class FlashSequenceConfig extends AnimationConfig:
	var sequence_steps: Array = []  # [{"scene": "path/to/scene.tscn", "duration": 3.0}, ...]
	var animation_parent: Node = null  # Parent container for scene swapping

	func _init(p_duration: float = 0.0, p_start_delay: float = 0.0, p_parent: Node = null):
		super(AnimationAction.FLASH_SEQUENCE, p_duration, p_start_delay)
		animation_parent = p_parent

# Predefined animation templates (dynamically generated)
func _get_animation_templates() -> Dictionary:
	return {
		"flash": {
			"action": AnimationAction.FLASH,
			"default_duration": flash_duration,
			"description": "Display target for duration then disappear"
		},
		"run_through": {
			"action": AnimationAction.RUN_THROUGH,
			"default_duration": run_through_duration,
			"description": "Target moves from left to right"
		},
		"run_through_reverse": {
			"action": AnimationAction.RUN_THROUGH_REVERSE,
			"default_duration": run_through_duration,
			"description": "Target moves from right to left"
		},
		"swing_left": {
			"action": AnimationAction.SWING_LEFT,
			"default_duration": swing_left_duration,
			"description": "Appear rotated from left, disappear after duration"
		},
		"swing_right": {
			"action": AnimationAction.SWING_RIGHT,
			"default_duration": swing_right_duration,
			"description": "Appear rotated from right, disappear after duration"
		},
		"up": {
			"action": AnimationAction.UP,
			"default_duration": up_duration,
			"description": "Show target from bottom, stop at 1/3 visible"
		},
		"down": {
			"action": AnimationAction.DOWN,
			"default_duration": down_duration,
			"description": "Show target from top, stop at 1/3 visible"
		},
		"disguised_enemy_flash": {
			"action": AnimationAction.FLASH_SEQUENCE,
			"default_duration": 0.0,  # Duration is sum of sequence steps
			"description": "Flash sequence: disguised_enemy_surrender (3s) → disguised_enemy (3s)",
			"sequence_steps": [
				{"scene": "res://scene/targets/disguised_enemy_surrender.tscn", "duration": 3.0},
				{"scene": "res://scene/targets/disguised_enemy.tscn", "duration": 3.0}
			]
		}
	}

# Apply a predefined animation to a target
# target: The target node (should have AnimationPlayer)
# animation_name: Name of the predefined animation (e.g., "flash", "run_through")
# custom_duration: Override the default duration (optional)
# start_delay: Delay before animation starts (optional)
# parent_container: Parent container for scene swapping in flash_sequence (optional, required for flash_sequence)
# Returns: AnimationPlayer animation name that was created
func apply_animation(target: Node, animation_name: String, custom_duration: float = -1.0, start_delay: float = 0.0, parent_container: Node = null) -> String:
	if not target:
		push_error("TargetAnimationLibrary: Target is null")
		return ""

	var templates = _get_animation_templates()
	if not animation_name in templates:
		push_error("TargetAnimationLibrary: Unknown animation '" + animation_name + "'")
		return ""

	var template = templates[animation_name]
	
	# Handle flash_sequence specifically
	if template.action == AnimationAction.FLASH_SEQUENCE:
		if not parent_container:
			push_error("TargetAnimationLibrary: flash_sequence requires parent_container parameter")
			return ""
		
		var flash_config = FlashSequenceConfig.new(0.0, start_delay, parent_container)
		if "sequence_steps" in template:
			flash_config.sequence_steps = template.sequence_steps
			# Calculate total duration from sequence steps
			for step in flash_config.sequence_steps:
				flash_config.duration += step.duration
		return _apply_animation_config(target, flash_config, animation_name)
	
	var duration = custom_duration if custom_duration > 0 else template.default_duration

	var config = AnimationConfig.new(template.action, duration, start_delay)
	return _apply_animation_config(target, config, animation_name)


# Apply the first-frame pose of a predefined animation to a target.
# This is useful to prevent an initial "jump" (e.g. target spawns centered, then instantly snaps
# to the animation's start position when the animation begins).
func apply_start_pose(target: Node, animation_name: String) -> void:
	if not target:
		return
	if not (target is Node2D):
		return

	var templates = _get_animation_templates()
	if not animation_name in templates:
		return

	var template = templates[animation_name]
	match template.action:
		AnimationAction.SWING_LEFT:
			# Keep in sync with _create_swing_animation(direction = -1)
			(target as Node2D).position = Vector2(360, 0)
		AnimationAction.SWING_RIGHT:
			# Keep in sync with _create_swing_animation(direction = 1)
			(target as Node2D).position = Vector2(-440, 0)
		_:
			pass

# Internal method to apply animation configuration
func _apply_animation_config(target: Node, config: AnimationConfig, animation_name: String) -> String:
	# Special handling for FLASH_SEQUENCE - use Tween-based approach
	if config.action == AnimationAction.FLASH_SEQUENCE:
		return _apply_flash_sequence(target, config as FlashSequenceConfig)
	
	var animation_player = target.get_node_or_null("AnimationPlayer")
	if not animation_player:
		push_error("TargetAnimationLibrary: Target does not have AnimationPlayer")
		return ""

	# Create unique animation name
	var unique_name = animation_name + "_" + str(Time.get_ticks_msec())

	# Create new animation
	var animation = Animation.new()
	animation.resource_name = unique_name
	animation.length = config.duration + config.start_delay

	# Add tracks based on animation action
	match config.action:
		AnimationAction.FLASH:
			_create_flash_animation(animation, config)
			animation.length += 0.1  # Extra time for fade out
		AnimationAction.RUN_THROUGH:
			_create_run_through_animation(animation, config, 1)
		AnimationAction.RUN_THROUGH_REVERSE:
			_create_run_through_animation(animation, config, -1)
		AnimationAction.SWING_LEFT:
			_create_swing_animation(animation, config, -1)
		AnimationAction.SWING_RIGHT:
			_create_swing_animation(animation, config, 1)
		AnimationAction.UP:
			_create_up_animation(animation, config)
		AnimationAction.DOWN:
			_create_down_animation(animation, config)

	# Add animation to library
	var library = animation_player.get_animation_library("")
	if not library:
		library = AnimationLibrary.new()
		animation_player.add_animation_library("", library)

	library.add_animation(unique_name, animation)

	# Play the animation
	if config.start_delay > 0:
		# Use a timer for delayed start
		var timer = Timer.new()
		timer.wait_time = config.start_delay
		timer.one_shot = true
		target.add_child(timer)
		timer.timeout.connect(func():
			animation_player.play(unique_name)
			timer.queue_free()
		)
		timer.start()
	else:
		animation_player.play(unique_name)

	return unique_name

# Apply flash sequence animation using Tween for scene swaps
func _apply_flash_sequence(target: Node, config: FlashSequenceConfig) -> String:
	if config.sequence_steps.is_empty():
		push_error("TargetAnimationLibrary: Flash sequence has no steps")
		return ""
	
	if not target is Node2D:
		push_error("TargetAnimationLibrary: Target must be Node2D for flash_sequence")
		return ""
	
	if not config.animation_parent:
		push_error("TargetAnimationLibrary: animation_parent not set for flash_sequence")
		return ""

	var target_position = (target as Node2D).position
	var target_ref = {"current": target}  # Use dict to store mutable reference
	var unique_name = "flash_sequence_" + str(Time.get_ticks_msec())
	
	# Create a tween bound to the parent container to handle scene swaps
	# Binding to the parent container allows the drill system to stop all sequence tweens at once
	var tween = config.animation_parent.create_tween()
	active_tweens[unique_name] = tween
	
	# Cleanup when finished
	tween.finished.connect(func():
		if active_tweens.has(unique_name):
			active_tweens.erase(unique_name)
	)
	
	if config.start_delay > 0:
		tween.tween_callback(func(): pass).set_delay(config.start_delay)
	
	# Process all steps
	for i in range(config.sequence_steps.size()):
		# Capture step data by value to avoid closure reference issues
		var step_scene = config.sequence_steps[i]["scene"]
		var step_duration = config.sequence_steps[i]["duration"]
		
		# Swap to this scene
		tween.tween_callback(func():
			# Verify the current target is still valid before swapping
			if is_instance_valid(target_ref["current"]) and step_scene != "":
				target_ref["current"] = _swap_target_scene(target_ref["current"], step_scene, target_position, config.animation_parent)
		)
		
		# Wait for this step's duration (except after the last step)
		if i < config.sequence_steps.size() - 1:
			tween.tween_callback(func(): pass).set_delay(step_duration)
	
	return unique_name

# Create flash animation (show then disappear)
func _create_flash_animation(animation: Animation, config: AnimationConfig):
	# Modulate track for visibility
	var modulate_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, ".:modulate")
	animation.track_insert_key(modulate_track, config.start_delay, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, config.start_delay + 0.1, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay + 0.1, Color(1, 1, 1, 0))

# Create run through animation (left to right movement)
func _create_run_through_animation(animation: Animation, config: AnimationConfig, direction: int = 1):
	var screen_size = Vector2(720, 1280)  # Game viewport size
	var start_x = -200 * direction
	var end_x = screen_size.x + 200 * direction

	# Position track
	var position_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, ".:position")
	animation.track_insert_key(position_track, config.start_delay, Vector2(start_x, 0))
	animation.track_insert_key(position_track, config.duration + config.start_delay, Vector2(end_x, 0))

	# Modulate track for fade in/out
	var modulate_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, ".:modulate")
	animation.track_insert_key(modulate_track, config.start_delay, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, config.start_delay + 0.2, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay - 0.2, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay, Color(1, 1, 1, 0))

# Create swing animation (appear rotated, disappear)
func _create_swing_animation(animation: Animation, config: AnimationConfig, direction: int):
	# var max_rotation = PI/12 * config.amplitude * direction  # 15 degrees max

	# Position track (fixed position)
	var pos_start = Vector2(-440, 0) if direction == 1 else Vector2(360, 0)
	var pos_end = Vector2(-80, 0) if direction == 1 else Vector2(0, 0)
	var position_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, ".:position")
	animation.track_insert_key(position_track, config.start_delay, pos_start)
	animation.track_insert_key(position_track, (config.duration + config.start_delay)/2, pos_end)
	animation.track_insert_key(position_track, config.duration + config.start_delay, pos_start)

	# Rotation track
	# var rotation_track = animation.add_track(Animation.TYPE_VALUE)
	# animation.track_set_path(rotation_track, ".:rotation")
	# animation.track_insert_key(rotation_track, config.start_delay, 0)
	# animation.track_insert_key(rotation_track, (config.start_delay + config.duration)/2, max_rotation)
	# animation.track_insert_key(rotation_track, config.duration + config.start_delay, 0)

# Create up animation (show from bottom, stop at 1/3 visible)
func _create_up_animation(animation: Animation, config: AnimationConfig):
	var _screen_size = Vector2(720, 1280)  # Game viewport size
	# Assuming target height is roughly 200-300 pixels, 1/3 visible means 2/3 covered
	# Start position: target mostly below screen (y positive is down in Godot)
	var start_y = 1280 + 200 * config.amplitude
	# End position: 1/3 of target visible at bottom (target top at screen bottom - 1/3 target height)
	var end_y = 1280 - 100 * config.amplitude  # Adjust based on typical target size

	# Position Y track for moving up
	var position_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, ".:position:y")
	animation.track_insert_key(position_track, config.start_delay, start_y)
	animation.track_insert_key(position_track, config.duration + config.start_delay, end_y)

	# Modulate track for fade in
	var modulate_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, ".:modulate")
	animation.track_insert_key(modulate_track, config.start_delay, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, config.start_delay + 0.2, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay, Color(1, 1, 1, 1))

# Create down animation (show from top, stop at 1/3 visible)
func _create_down_animation(animation: Animation, config: AnimationConfig):
	var _screen_size = Vector2(720, 1280)  # Game viewport size
	# Start position: target mostly above screen (y negative is up in Godot)
	var start_y = -200 * config.amplitude
	# End position: 1/3 of target visible at top (target bottom at screen top + 1/3 target height)
	var end_y = 100 * config.amplitude  # Adjust based on typical target size

	# Position Y track for moving down
	var position_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, ".:position:y")
	animation.track_insert_key(position_track, config.start_delay, start_y)
	animation.track_insert_key(position_track, config.duration + config.start_delay, end_y)

	# Modulate track for fade in
	var modulate_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, ".:modulate")
	animation.track_insert_key(modulate_track, config.start_delay, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, config.start_delay + 0.2, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay, Color(1, 1, 1, 1))

# Create flash sequence animation (swap scenes at specified times)
func _create_flash_sequence_animation(animation: Animation, config: FlashSequenceConfig):
	# For flash_sequence, we don't use animation tracks
	# Instead, we create a simple placeholder animation and handle scene swaps via Tween
	# Add a dummy modulate track so the animation has some content
	var modulate_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, ".:modulate")
	animation.track_insert_key(modulate_track, config.start_delay, Color(1, 1, 1, 1))
	animation.track_insert_key(modulate_track, config.duration + config.start_delay, Color(1, 1, 1, 1))

# Helper method called by animation tracks to swap scenes
func _on_flash_sequence_swap(_scene_path: String, _swap_time: float):
	# This will be called during animation playback
	# The actual swap needs to happen on the target node that triggered the animation
	pass

# Swap target scene in the parent container
func _swap_target_scene(old_target: Node, scene_path: String, position: Vector2, parent_node: Node) -> Node:
	if not parent_node:
		push_error("TargetAnimationLibrary: parent_node not set for scene swap")
		return null
	
	# Load the new scene
	var scene = load(scene_path)
	if not scene:
		push_error("TargetAnimationLibrary: Failed to load scene at " + scene_path)
		return null
	
	# Instantiate the new target
	var new_target = scene.instantiate()
	if not new_target:
		push_error("TargetAnimationLibrary: Failed to instantiate scene " + scene_path)
		return null
	
	# Position the new target at the same location as the old one
	if new_target is Node2D:
		(new_target as Node2D).position = position
	
	# If the scene is a "surrender" variant, mark it as no-shoot
	if scene_path.contains("surrender") and new_target.has_method("set"):
		new_target.set("is_no_shoot", true)
		print("[TargetAnimationLibrary] _swap_target_scene: Marked target as no_shoot (surrender)")

	# Add new target to parent container
	parent_node.add_child(new_target)
	
	# Queue the old target for deletion
	old_target.queue_free()
	
	# Emit signal to notify caller about the swap
	target_swapped.emit(old_target, new_target)
	
	return new_target

# Stop all active flash sequences
func stop_all_sequences():
	print("[TargetAnimationLibrary] stop_all_sequences: Killing ", active_tweens.size(), " active tweens")
	for unique_name in active_tweens.keys():
		var tween = active_tweens[unique_name]
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()

# Get list of available animation names
func get_available_animations() -> Array[String]:
	return _get_animation_templates().keys()

# Get animation description
func get_animation_description(animation_name: String) -> String:
	var templates = _get_animation_templates()
	if animation_name in templates:
		return templates[animation_name].description
	return ""

# Get default duration for animation
func get_default_duration(animation_name: String) -> float:
	var templates = _get_animation_templates()
	if animation_name in templates:
		return templates[animation_name].default_duration
	return 1.0
