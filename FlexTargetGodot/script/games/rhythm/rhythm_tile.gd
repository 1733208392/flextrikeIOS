extends Button

signal tile_hit(note: String)

enum State { IDLE, ACTIVE, HIT, MISS }
var current_state = State.IDLE
var note_name: String = "C4"
var is_active_beat: bool = false

@onready var pulse_rect: ColorRect = get_node_or_null("Pulse")

func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	
	# Create a unique stylebox for this button so we can modify it safely
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_right = 32
	style.corner_radius_bottom_left = 32
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	_update_visuals()

func setup(n: String) -> void:
	note_name = n
	text = n

func pulse(scale_factor: float = 1.2) -> void:
	if not is_inside_tree() or pulse_rect == null: return
	pulse_rect.visible = true
	pulse_rect.scale = Vector2.ONE
	pulse_rect.modulate.a = 0.5
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse_rect, "scale", Vector2.ONE * scale_factor, 0.2)
	tween.tween_property(pulse_rect, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func(): if is_instance_valid(pulse_rect): pulse_rect.visible = false)

func set_active(active: bool) -> void:
	is_active_beat = active
	current_state = State.ACTIVE if active else State.IDLE
	_update_visuals()

func flash_hit() -> void:
	current_state = State.HIT
	_update_visuals()
	var tween = create_tween()
	tween.tween_interval(0.2)
	tween.finished.connect(func(): 
		current_state = State.IDLE
		_update_visuals()
	)

func flash_miss() -> void:
	current_state = State.MISS
	_update_visuals()
	var tween = create_tween()
	tween.tween_interval(0.2)
	tween.finished.connect(func(): 
		current_state = State.IDLE
		_update_visuals()
	)

func _update_visuals() -> void:
	var style = get_theme_stylebox("normal")
	if not style is StyleBoxFlat: return
	
	match current_state:
		State.IDLE:
			style.bg_color = Color(0.12, 0.12, 0.12) # Dark grey background
			add_theme_color_override("font_color", Color(0.25, 0.25, 0.25)) # Subtle text
		State.ACTIVE:
			style.bg_color = Color("de3823") # Vibrant accent red
			add_theme_color_override("font_color", Color.WHITE) # High contrast white text
		State.HIT:
			style.bg_color = Color.GREEN
			add_theme_color_override("font_color", Color.WHITE)
		State.MISS:
			style.bg_color = Color(0.08, 0.08, 0.08)
			add_theme_color_override("font_color", Color.DARK_SLATE_GRAY)
	
	text = note_name

func _pressed() -> void:
	if is_active_beat:
		tile_hit.emit(note_name)
