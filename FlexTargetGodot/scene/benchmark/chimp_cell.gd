extends Button

signal cell_clicked(cell)

var main: Control
var cell_index: int = -1
var current_number: int = 0

@onready var background = $Background
@onready var border = $Border
@onready var number_label: Label = $NumberLabel

func _ready():
    self_modulate.a = 0
    connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
    cell_clicked.emit(self)

func flash_number(number: int, duration: float = 0.5):
    current_number = number
    number_label.text = str(number)
    number_label.visible = true
    var tween = get_tree().create_tween()
    self_modulate.a = 0
    tween.tween_property(self, "self_modulate:a", 1, duration / 2)
    tween.tween_property(self, "self_modulate:a", 0, duration / 2)
    tween.tween_callback(func(): number_label.visible = false)

func glow(color: Color, duration: float = 0.5):
    var tween = get_tree().create_tween()
    background.modulate = color
    background.modulate.a = 0
    tween.tween_property(background, "modulate:a", 1, duration / 2)
    tween.tween_property(background, "modulate:a", 0, duration / 2)