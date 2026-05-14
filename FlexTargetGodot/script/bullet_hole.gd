extends Node2D

const DEBUG_DISABLED = true

# Screen spec: 1280x720 px over 476.4x268 mm -> ~2.687 px/mm
# 6mm diameter = 3mm radius * 2.687 px/mm = ~8.06 px radius
const DPM: float = 2.687
const HOLE_RADIUS_PX: float = 3.0 * DPM  # 6mm diameter

@export var z_index_offset: int = 1

func _ready():
	z_index = z_index_offset
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, HOLE_RADIUS_PX, Color(0.06, 0.04, 0.04))

func set_hole_position(pos: Vector2):
	"""Set the local position of the bullet hole relative to parent"""
	position = pos
	if not DEBUG_DISABLED:
		print("Bullet hole positioned at local: ", pos)

func initialize_appearance():
	# Appearance is drawn procedurally; nothing to initialize
	pass
