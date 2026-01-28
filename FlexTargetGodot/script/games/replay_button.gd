extends Button

# Signal emitted when the replay button is pressed
signal replay_pressed

func _ready() -> void:
	# Connect the button's pressed signal
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	"""Called when the button is pressed"""
	emit_signal("replay_pressed")
	print("Replay button pressed!")
