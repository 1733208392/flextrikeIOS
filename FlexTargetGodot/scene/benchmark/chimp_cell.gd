extends Button

signal cell_clicked(cell)

var main: Control
var cell_index: int = -1
var current_number: int = 0

func _ready():
	text = ""
	self_modulate.a = 1
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
	cell_clicked.emit(self)

func show_number(number: int):
	current_number = number
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale:x", 0, 0.25)
	tween.tween_callback(func(): text = str(number))
	tween.tween_property(self, "scale:x", 1, 0.25)

func hide_number():
	text = ""

func show_number_brief(number: int, duration: float = 1.0):
	show_number(number)
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func(): hide_number())

func flash_cell(duration: float = 0.5):
	var tween = get_tree().create_tween()
	tween.tween_property(self, "self_modulate:a", 0, duration / 2)
	tween.tween_property(self, "self_modulate:a", 1, duration / 2)
	tween.tween_property(self, "self_modulate:a", 0, duration / 2)
	tween.tween_property(self, "self_modulate:a", 1, duration / 2)
