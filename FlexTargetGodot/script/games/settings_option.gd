extends OptionButton

@onready var popup = get_popup()

func _ready():
	popup.theme = Theme.new()
	popup.theme.set_font("font", "PopupMenu", load("res://assets/soupofjustice.ttf"))
	popup.theme.set_font_size("font_size", "PopupMenu", 24)
