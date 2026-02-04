extends Control

const DEBUG_DISABLED = false  # Set to true to disable debug prints for production

@onready var copyright_label = $Label
@onready var background_music = $BackgroundMusic
@onready var ipsc_button = $CenterContainer/GridContainer/IPSCButton
@onready var idpa_button = $CenterContainer/GridContainer/IDPAButton
@onready var history_ipsc_button = $CenterContainer/GridContainer/HistoryIPSCButton
@onready var history_idpa_button = $CenterContainer/GridContainer/HistoryIDPAButton

var focused_index
var buttons = []

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[SubMenu] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
		call_deferred("update_ui_texts")

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
		_:
			locale = "en"  # Default to English
	TranslationServer.set_locale(locale)
	if not DEBUG_DISABLED:
		print("[SubMenu] Set locale to: ", locale)

func update_ui_texts():
	# Update copyright label with current language
	copyright_label.text = tr("copyright")

	if not DEBUG_DISABLED:
		print("[SubMenu] UI texts updated")

func _ready():
	# Show status bar when entering sub menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		if not DEBUG_DISABLED:
			print("[SubMenu] Showed status bar: ", status_bar.name)

	# Load and apply current language setting
	load_language_setting()

	# Load SFX volume from GlobalData and apply it
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume)
		if not DEBUG_DISABLED:
			print("[SubMenu] Loaded SFX volume from GlobalData: ", sfx_volume)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		if not DEBUG_DISABLED:
			print("[SubMenu] Using default SFX volume: 5")

	# Play background music
	if background_music:
		background_music.play()
		if not DEBUG_DISABLED:
			print("[SubMenu] Playing background music")

	# Initialize buttons array
	focused_index = 0
	buttons = [
		ipsc_button,
		idpa_button,
		history_ipsc_button,
		history_idpa_button
	]

	# Verify all buttons exist
	if not ipsc_button or not idpa_button or not history_ipsc_button or not history_idpa_button:
		print("[SubMenu] ERROR: One or more buttons not found in scene!")
		print("[SubMenu] ipsc_button: ", ipsc_button)
		print("[SubMenu] idpa_button: ", idpa_button)
		print("[SubMenu] history_ipsc_button: ", history_ipsc_button)
		print("[SubMenu] history_idpa_button: ", history_idpa_button)
		return

	# Connect button signals
	ipsc_button.pressed.connect(_on_ipsc_pressed)
	idpa_button.pressed.connect(_on_idpa_pressed)
	history_ipsc_button.pressed.connect(_on_history_ipsc_pressed)
	history_idpa_button.pressed.connect(_on_history_idpa_pressed)

	# Set initial focus on top-left button (index 0)
	focused_index = 0
	print("[SubMenu] Setting initial focus to button index 0: ", ipsc_button.name)
	_update_button_styles()

	# Connect to WebSocket menu control signals (deferred to ensure WebSocketListener is ready)
	call_deferred("_connect_to_websocket")

func _update_button_styles():
	for i in range(buttons.size()):
		if i == focused_index:
			buttons[i].add_theme_stylebox_override("normal", buttons[i].get_theme_stylebox("hover", "Button"))
			buttons[i].add_theme_color_override("font_color", buttons[i].get_theme_color("font_hover_color", "Button"))
			buttons[i].add_theme_font_override("font", buttons[i].get_theme_font("font_hover", "Button"))
			buttons[i].add_theme_color_override("icon_normal_color", buttons[i].get_theme_color("icon_hover_color", "Button"))
		else:
			buttons[i].remove_theme_stylebox_override("normal")
			buttons[i].remove_theme_color_override("font_color")
			buttons[i].remove_theme_font_override("font")
			buttons[i].remove_theme_color_override("icon_normal_color")

func _on_ipsc_pressed():
	if not DEBUG_DISABLED:
		print("[SubMenu] IPSC button pressed")
	# Call HTTP service to start IPSC game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[SubMenu] Calling start_game for IPSC...")
		http_service.start_game(_on_ipsc_response)
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] HttpService not found!")

func _on_ipsc_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[SubMenu] IPSC start_game response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[SubMenu] IPSC start game success, changing scene")
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.selected_variant = "IPSC"
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro/intro.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] IPSC start game failed")

func _on_idpa_pressed():
	if not DEBUG_DISABLED:
		print("[SubMenu] IDPA button pressed")
	# Call HTTP service to start IDPA game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[SubMenu] Calling start_game for IDPA...")
		http_service.start_game(_on_idpa_response)
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] HttpService not found!")

func _on_idpa_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[SubMenu] IDPA start_game response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[SubMenu] IDPA start game success, changing scene")
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.selected_variant = "IDPA"
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/intro/intro.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] IDPA start game failed")

func _on_history_ipsc_pressed():
	if not DEBUG_DISABLED:
		print("[SubMenu] History IPSC button pressed")
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/history.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] Warning: Node not in tree, cannot change scene")

func _on_history_idpa_pressed():
	if not DEBUG_DISABLED:
		print("[SubMenu] History IDPA button pressed")
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/history_idpa.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] Warning: Node not in tree, cannot change scene")

func power_off():
	if not DEBUG_DISABLED:
		print("[SubMenu] power_off() called")
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	if not DEBUG_DISABLED:
		print("[SubMenu] Dialog scene preloaded")
	var dialog = dialog_scene.instantiate()
	if not DEBUG_DISABLED:
		print("[SubMenu] Dialog instantiated")
	dialog.set_alert_text(tr("power_off_alert"))
	if not DEBUG_DISABLED:
		print("[SubMenu] Alert text set")
	add_child(dialog)
	if not DEBUG_DISABLED:
		print("[SubMenu] Dialog added to scene tree")
	dialog.show()
	if not DEBUG_DISABLED:
		print("[SubMenu] Dialog shown")

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func _connect_to_websocket():
	"""Connect to WebSocketListener signals (called deferred to ensure WebSocketListener is ready)"""
	print("[SubMenu] _connect_to_websocket() called")
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		print("[SubMenu] WebSocketListener found")
		ws_listener.menu_control.connect(_on_menu_control)
		print("[SubMenu] Connected to WebSocketListener.menu_control signal")
	else:
		print("[SubMenu] ERROR: WebSocketListener singleton not found! Remote control will not work.")

func _on_menu_control(directive: String):
	print("[SubMenu] _on_menu_control called with directive: ", directive)
	if has_visible_power_off_dialog():
		print("[SubMenu] Power off dialog is visible, ignoring directive")
		return
	print("[SubMenu] Received menu_control signal with directive: ", directive, ", focused_index: ", focused_index)
	match directive:
		"up":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus up in grid")
			if focused_index == 2 and buttons[0].visible:
				focused_index = 0
			elif focused_index == 3 and buttons[1].visible:
				focused_index = 1
			# else stay
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus down in grid")
			if focused_index == 0 and buttons[2].visible:
				focused_index = 2
			elif focused_index == 1 and buttons[3].visible:
				focused_index = 3
			# else stay
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"left":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus left in grid")
			if focused_index == 1 and buttons[0].visible:
				focused_index = 0
			elif focused_index == 3 and buttons[2].visible:
				focused_index = 2
			# else stay
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"right":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus right in grid")
			if focused_index == 0 and buttons[1].visible:
				focused_index = 1
			elif focused_index == 2 and buttons[3].visible:
				focused_index = 3
			# else stay
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			if not DEBUG_DISABLED:
				print("[SubMenu] Simulating button press")
			buttons[focused_index].pressed.emit()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"power":
			if not DEBUG_DISABLED:
				print("[SubMenu] Power off")
			power_off()
		"back":
			if not DEBUG_DISABLED:
				print("[SubMenu] Back to main menu")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		"homepage":
			if not DEBUG_DISABLED:
				print("[SubMenu] Homepage to main menu")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		_:
			if not DEBUG_DISABLED:
				print("[SubMenu] Unknown directive: ", directive)

func _on_sfx_volume_changed(volume: int):
	"""Handle SFX volume changes from Option scene.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	if not DEBUG_DISABLED:
		print("[SubMenu] SFX volume changed to: ", volume)
	_apply_sfx_volume(volume)

func _apply_sfx_volume(volume: int):
	"""Apply SFX volume level to audio.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	# Convert volume (0-10) to Godot's decibel scale
	# 0 = silence (mute), 10 = full volume (0dB)
	# We use approximately -40dB for silence and 0dB for maximum
	if volume <= 0:
		# Stop all SFX
		if background_music:
			background_music.volume_db = -80  # Effectively mute
		if not DEBUG_DISABLED:
			print("[SubMenu] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		if not DEBUG_DISABLED:
			print("[SubMenu] Set audio volume_db to ", db, " (volume level: ", volume, ")")
