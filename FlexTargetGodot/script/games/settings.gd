extends Control

var controls = []
var current_focus_index = 0

func _ready():
	print("[Settings] _ready called")
	
	# Load language setting from GlobalData (like option.gd does)
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[Settings] Loaded language from GlobalData: ", language)
	else:
		print("[Settings] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
	
	# Set translatable texts
	$VBoxContainer/DifficultyLabel.text = tr("difficulty_level")
	$VBoxContainer/DurationLabel.text = tr("duration")
	$StartButton.text = tr("start")
	
	# Set option button items
	$VBoxContainer/DifficultyOption.clear()
	$VBoxContainer/DifficultyOption.add_item(tr("low"))
	$VBoxContainer/DifficultyOption.add_item(tr("medium"))
	$VBoxContainer/DifficultyOption.add_item(tr("high"))
	
	$VBoxContainer/DurationOption.clear()
	$VBoxContainer/DurationOption.add_item(tr("20_seconds"))
	$VBoxContainer/DurationOption.add_item(tr("30_seconds"))
	$VBoxContainer/DurationOption.add_item(tr("60_seconds"))
	$VBoxContainer/DurationOption.add_item(tr("90_seconds"))
	
	controls = [$VBoxContainer/DifficultyOption, $VBoxContainer/DurationOption, $StartButton]
	print("[Settings] Controls: ", controls)
	current_focus_index = 2  # StartButton
	$StartButton.grab_focus()
	
	# Connect Start button pressed
	$StartButton.pressed.connect(_on_start_pressed)
	
	# Connect to remote control for controller support
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_remote_enter)
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Settings] Connected to MenuController signals")
	else:
		print("[Settings] MenuController autoload not found!")

func set_locale_from_language(language: String):
	var locale = ""
	match language:
		"English":
			locale = "en"
		"Chinese":
			locale = "zh_CN"
		"Traditional Chinese":
			locale = "zh_TW"
		"Japanese":
			locale = "ja"
	TranslationServer.set_locale(locale)

func _on_remote_navigate(direction: String):
	"""Handle navigation from remote control"""
	print("[Settings] Remote navigate: ", direction)
	var current_control = controls[current_focus_index]
	if current_control is OptionButton and current_control.get_popup().visible:
		# Popup is open, send key to popup for navigation
		var event = InputEventKey.new()
		event.pressed = true
		if direction == "up":
			event.keycode = KEY_UP
		elif direction == "down":
			event.keycode = KEY_DOWN
		Input.parse_input_event(event)
	else:
		# Normal navigation
		if direction == "up" or direction == "left":
			current_focus_index = (current_focus_index - 1 + controls.size()) % controls.size()
		elif direction == "down" or direction == "right":
			current_focus_index = (current_focus_index + 1) % controls.size()
		print("[Settings] New focus index: ", current_focus_index)
		call_deferred("grab_focus_on_control", current_focus_index)

func _on_remote_enter():
	"""Handle enter press from remote control"""
	if not visible:
		return
	print("[Settings] Remote enter")
	var current_control = controls[current_focus_index]
	if current_control == $StartButton:
		print("[Settings] Start button focused, starting game")
		_on_start_pressed()
	else:
		print("[Settings] Enter on non-start control")
		var event = InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		Input.parse_input_event(event)

func _on_start_pressed():
	"""Handle Start button pressed"""
	print("[Settings] Start button pressed")
	
	# Get selected options
	var difficulty_index = $VBoxContainer/DifficultyOption.selected
	var duration_index = $VBoxContainer/DurationOption.selected
	
	# Set growth speed based on difficulty
	var growth_speed = 1 if difficulty_index == 0 else 2 if difficulty_index == 1 else 3
	print("[Settings] Setting vine growth_speed to: ", growth_speed)
	
	# Set game duration based on selection
	var duration = 30.0 if duration_index == 0 else 60.0 if duration_index == 1 else 120.0
	print("[Settings] Setting game duration to: ", duration, " seconds")
	
	# Randomly choose start side
	var start_side = "left" if randi() % 2 == 0 else "right"
	print("[Settings] Randomly chose monkey_start_side: ", start_side)
	
	# Emit settings signal
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("settings_applied"):
			signal_bus.settings_applied.emit(start_side, growth_speed, duration)
			print("[Settings] Emitted settings_applied on SignalBus")
		else:
			print("[Settings] settings_applied signal not found on SignalBus")
	else:
		print("[Settings] SignalBus not found, cannot emit settings_applied")
	
	visible = false
	get_parent().start_countdown()

func grab_focus_on_control(index: int):
	controls[index].grab_focus()

func _on_remote_back_pressed():
	"""Handle back/home directive from remote control to return to menu"""
	print("[Settings] Remote back/home pressed - returning to menu...")
	_return_to_menu()

func _return_to_menu():
	print("[Settings] Returning to menu scene")
	var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
	if error != OK:
		print("[Settings] Failed to change scene: ", error)
	else:
		print("[Settings] Scene change initiated")
