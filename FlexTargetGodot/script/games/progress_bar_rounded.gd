extends ProgressBar

func _ready() -> void:
	value_changed.connect(_on_value_changed)
	_on_value_changed(0)

func _on_value_changed(new_value: float) -> void:
	var fill_style = get_theme_stylebox("fill") as StyleBoxFlat
	
	if fill_style == null:
		return
	
	# When progress is at 100%, add radius to right corners
	if new_value >= 99.9:
		fill_style.corner_radius_top_right = 15
		fill_style.corner_radius_bottom_right = 15
	else:
		# Remove radius from right corners when not full
		fill_style.corner_radius_top_right = 0
		fill_style.corner_radius_bottom_right = 0