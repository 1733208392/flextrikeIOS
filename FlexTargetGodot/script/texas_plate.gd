extends Node2D

signal fell(plate_index)

@export var index: int = -1
@export var gravity: float = 1000.0
@export var offscreen_y: float = 10000.0
@export var mass: float = 1.0
@export var reparent_root: NodePath = NodePath("")

var falling: bool = false
var velocity: Vector2 = Vector2.ZERO
var ang_vel: float = 0.0

func _ready():
	if $Area2D:
		$Area2D.connect("area_entered", Callable(self, "_on_area_entered"))
	add_to_group("texas_plate")

func _on_area_entered(area):
	if falling:
		return
	# Accept objects in group "bullet" or any Area2D named "Bullet"/"bullet"
	var is_bullet = false
	if area.has_method("is_in_group"):
		is_bullet = area.is_in_group("bullet")
	if area.name.to_lower().find("bullet") != -1:
		is_bullet = true
	if not is_bullet:
		return
	detach()

func detach():
	falling = true
	# initial explosion-like impulse when plate detaches
	var angle = randf() * TAU
	var speed = randf_range(60.0, 220.0)
	velocity = Vector2(cos(angle), -0.2 + sin(angle)).normalized() * speed
	ang_vel = randf_range(-8.0, 8.0)
	# reparent to root so falling uses world coordinates.
	# Do this deferred to avoid timing issues where get_tree() may be null.
	var current_global_rot = global_rotation
	var current_global_pos = global_position
	call_deferred("_reparent_to_root", current_global_pos, current_global_rot)
	if $Area2D:
		$Area2D.monitoring = false
		$Area2D.monitorable = false
	emit_signal("fell", index)
	set_process(false)
	set_physics_process(true)

func _reparent_to_root(pos: Vector2, rot: float) -> void:
	# safe reparent helper — only runs when in tree
	if not is_inside_tree():
		# try again next idle
		call_deferred("_reparent_to_root", pos, rot)
		return
	var parent = get_parent()
	if parent:
		parent.remove_child(self)

	var scene = null
	var tree = get_tree()
	if tree:
		scene = tree.current_scene
	#try Engine main loop to get current scene
	if scene == null:
		var main_loop = Engine.get_main_loop()
		if main_loop:
			if main_loop.has_method("get_current_scene"):
				scene = main_loop.get_current_scene()
			elif main_loop.has_method("current_scene"):
				scene = main_loop.current_scene
	# if still no scene, try again deferred
	if scene == null:
		call_deferred("_reparent_to_root", pos, rot)
		return
	# Prefer attaching to a child node named 'Node2D' (matches test_plate.tscn root), else attach to scene root
	var target = null
	# find first Node2D child as a fallback
	for c in scene.get_children():
		if c is Node2D:
			target = c
			break
			
	if target == null:
		target = scene
	target.add_child(self)
	# restore global transform so position/rotation remain consistent in world space
	global_position = pos
	global_rotation = rot

func _physics_process(delta):
	if not falling:
		return
	velocity.y += gravity * delta
	# move in world coordinates so gravity is always down regardless of parent transforms
	global_position += velocity * delta
	global_rotation += ang_vel * delta
	# slight angular damping
	ang_vel = lerp(ang_vel, 0.0, 0.03 * delta * 60)
	# free when far below the screen
	if position.y > offscreen_y:
		queue_free()
