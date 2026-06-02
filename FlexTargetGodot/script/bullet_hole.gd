extends Node2D

const DEBUG_DISABLED = true

# Screen spec: 1280x720 px over 476.4x268 mm -> ~2.687 px/mm
# 6mm diameter = 3mm radius * 2.687 px/mm = ~8.06 px radius
const DPM: float = 2.687
const HOLE_RADIUS_PX: float = 3.0 * DPM  # 6mm diameter

@export var z_index_offset: int = 1
@export var hole_alpha: float = 1.0
@export var hole_color: Color = Color(0.06, 0.04, 0.04, 0.6)

func _ready():
	z_index = z_index_offset
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, HOLE_RADIUS_PX, Color(hole_color.r, hole_color.g, hole_color.b, hole_alpha))

func set_hole_position(pos: Vector2):
	"""Set the local position of the bullet hole relative to parent"""
	position = pos
	if not DEBUG_DISABLED:
		print("Bullet hole positioned at local: ", pos)

func set_hole_alpha(alpha: float):
	"""Set bullet-hole opacity and redraw."""
	hole_alpha = clampf(alpha, 0.0, 1.0)
	queue_redraw()

func set_hole_color(color: Color):
	"""Set bullet-hole color and redraw."""
	hole_color = color
	queue_redraw()

func initialize_appearance():
	# Appearance is drawn procedurally; nothing to initialize
	pass
