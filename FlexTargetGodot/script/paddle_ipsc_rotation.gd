extends Area2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var circle_area: CollisionShape2D = $CircleArea
@onready var popper_sprite: Sprite2D = $PopperSprite

func _ready():
	# CRITICAL: Duplicate the material to avoid shader parameter sharing between instances
	if popper_sprite and popper_sprite.material:
		popper_sprite.material = popper_sprite.material.duplicate()
	
	# Initialize shader parameters to ensure paddle is visible initially
	if popper_sprite and popper_sprite.material:
		popper_sprite.material.set_shader_parameter("fall_progress", 0.0)
		popper_sprite.material.set_shader_parameter("rotation_angle", 0.0)

func reset_paddle():
	visible = true
	if popper_sprite:
		popper_sprite.visible = true
		var shader_material = popper_sprite.material as ShaderMaterial
		if shader_material:
			shader_material.set_shader_parameter("fall_progress", 0.0)
			shader_material.set_shader_parameter("rotation_angle", 0.0)

	if circle_area and circle_area is CollisionShape2D:
		circle_area.disabled = false

	if animation_player:
		animation_player.stop()
		if animation_player.has_animation("fall_down"):
			animation_player.seek(0.0, true)
