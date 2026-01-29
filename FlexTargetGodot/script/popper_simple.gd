extends Node2D

const DEBUG_DISABLE = true

@onready var animation_player = $AnimationPlayer
@onready var sprite = $PopperSprite

var is_fallen = false
var instance_id: String  # Unique identifier for this instance

signal popper_disappeared

func _ready():
	instance_id = str(get_instance_id())  # Get unique instance ID
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Ready")
	
	# CRITICAL: Duplicate the material to avoid shader parameter sharing between instances
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Material duplicated to avoid shader sharing")

func trigger_fall_animation():
	"""Trigger the popper fall animation and disappearing"""
	if is_fallen:
		if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Already fallen, ignoring trigger")
		return
		
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] ⚠️  TRIGGERING FALL ANIMATION - WHO CALLED THIS?")
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Node name: ", name)
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Parent: ", str(get_parent().name) if get_parent() else "no parent")
	is_fallen = true
	
	# Play the fall animation
	if animation_player.has_animation("fall_down"):
		animation_player.play("fall_down")
		# Connect to animation finished signal if not already connected
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	else:
		if not DEBUG_DISABLE: print("[popper_simple] Warning: fall_down animation not found")
		# Immediately hide if no animation
		_hide_popper()

func _on_animation_finished(anim_name: String):
	"""Called when animation finishes"""
	if anim_name == "fall_down":
		if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Fall animation completed")
		_hide_popper()

func _hide_popper():
	"""Hide the popper and emit disappeared signal"""
	visible = false
	popper_disappeared.emit()
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Popper hidden and disappeared signal emitted")

func reset_popper():
	"""Reset the popper to its initial state"""
	if not DEBUG_DISABLE: print("[popper_simple ", instance_id, "] Resetting popper")
	is_fallen = false
	visible = true
	
	# Reset shader parameters if they exist
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("fall_progress", 0.0)
		sprite.material.set_shader_parameter("rotation_angle", 0.0)
