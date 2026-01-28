extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

@onready var copyright_label = $Label
@onready var background_music = $BackgroundMusic
@onready var v_box_container = $VBoxContainer

var focused_index
var buttons = []
var menu_config = {}  # Configuration for menu items

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

func set_menu_config(config: Dictionary):
	"""Set the menu configuration. Config should have:
	- title: String - The title for this sub menu
	- items: Array of dictionaries, each with:
		- text: String - Button text (can be translation key)
		- action: String - Action to perform when pressed
		- scene: String (optional) - Scene to load
		- http_call: String (optional) - HTTP service method to call
	"""
	menu_config = config
	if not DEBUG_DISABLED:
		print("[SubMenu] Menu config set: ", config)

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

	# Create menu buttons based on configuration
	_load_menu_config()
	_create_menu_buttons()

	# Connect to WebSocket menu control signals (deferred to ensure WebSocketListener is ready)
	call_deferred("_connect_to_websocket")

func _load_menu_config():
	"""Load menu configuration from GlobalData"""
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.sub_menu_config.size() > 0:
		menu_config = global_data.sub_menu_config
		if not DEBUG_DISABLED:
			print("[SubMenu] Loaded menu config from GlobalData: ", menu_config)
	else:
		# Default configuration if none provided
		menu_config = {
			"title": "Sub Menu",
			"items": []
		}
		if not DEBUG_DISABLED:
			print("[SubMenu] Using default menu config")

func _create_menu_buttons():
	"""Create buttons dynamically based on menu_config"""
	if not menu_config.has("items"):
		if not DEBUG_DISABLED:
			print("[SubMenu] No menu items in config")
		return

	var items = menu_config["items"]
	focused_index = 0
	buttons = []

	for i in range(items.size()):
		var item = items[i]
		var button = Button.new()

		# Set button properties similar to main menu
		button.layout_mode = 2
		button.size_flags_vertical = 0  # Don't expand, use custom size
		button.custom_minimum_size = Vector2(0, 76)  # Same height as main menu buttons
		button.set("theme_override_colors/font_color", Color(1, 0.5411765, 0, 1))
		button.set("theme_override_colors/font_focus_color", Color(0.95, 0.95, 0.95, 1))
		button.set("theme_override_font_sizes/font_size", 32)

		# Create style boxes
		var normal_style = StyleBoxTexture.new()
		normal_style.texture = load("res://asset/start_button_back.png")
		button.set("theme_override_styles/normal", normal_style)

		var hover_style = StyleBoxTexture.new()
		hover_style.texture = load("res://asset/start_button_back_hover.png")
		hover_style.modulate_color = Color(1, 1, 1, 0.9)
		button.set("theme_override_styles/hover", hover_style)

		var focus_style = StyleBoxTexture.new()
		focus_style.texture = load("res://asset/start_button_back_hover.png")
		button.set("theme_override_styles/focus", focus_style)

		var pressed_style = StyleBoxTexture.new()
		pressed_style.texture = load("res://asset/start_button_back.png")
		button.set("theme_override_styles/pressed", pressed_style)

		# Set button text
		button.text = tr(item.get("text", "Menu Item"))

		# Store item data in button
		button.set_meta("menu_item", item)

		# Connect signal
		button.pressed.connect(_on_menu_item_pressed.bind(button))

		# Add to container and buttons array
		v_box_container.add_child(button)
		buttons.append(button)

	# Set initial focus
	if buttons.size() > 0:
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data and global_data.has_meta("sub_menu_focused_index"):
			focused_index = global_data.get_meta("sub_menu_focused_index")
			if focused_index < 0 or focused_index >= buttons.size():
				focused_index = 0
		else:
			focused_index = 0
		buttons[focused_index].grab_focus()

func _on_menu_item_pressed(button: Button):
	var item = button.get_meta("menu_item")
	var action = item.get("action", "")

	if not DEBUG_DISABLED:
		print("[SubMenu] Menu item pressed: ", item)

	match action:
		"load_scene":
			var scene_path = item.get("scene", "")
			if scene_path and is_inside_tree():
				var global_data = get_node_or_null("/root/GlobalData")
				if global_data:
					global_data.set_meta("sub_menu_focused_index", focused_index)
				get_tree().change_scene_to_file(scene_path)
			else:
				if not DEBUG_DISABLED:
					print("[SubMenu] Warning: Invalid scene path or not in tree")
		"http_call":
			var http_method = item.get("http_call", "")
			if http_method:
				_call_http_service(http_method, item)
		_:
			if not DEBUG_DISABLED:
				print("[SubMenu] Unknown action: ", action)

func _call_http_service(method: String, item: Dictionary):
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[SubMenu] Calling HTTP service method: ", method)
		match method:
			"start_game":
				http_service.start_game(_on_http_response.bind(item))
			_:
				if not DEBUG_DISABLED:
					print("[SubMenu] Unknown HTTP method: ", method)
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] HttpService singleton not found!")

func _on_http_response(result, response_code, _headers, body, item):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[SubMenu] HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[SubMenu] HTTP call success")
		
		# Store variant in GlobalData if present in item
		if item.has("variant"):
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.selected_variant = item.get("variant")
				if not DEBUG_DISABLED:
					print("[SubMenu] Stored variant in GlobalData: ", item.get("variant"))
		
		var scene_path = item.get("success_scene", "")
		if scene_path and is_inside_tree():
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.set_meta("sub_menu_focused_index", focused_index)
			get_tree().change_scene_to_file(scene_path)
		else:
			if not DEBUG_DISABLED:
				print("[SubMenu] No success scene specified")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] HTTP call failed or invalid response.")

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
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[SubMenu] Connected to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[SubMenu] WebSocketListener singleton not found!")

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[SubMenu] Received menu_control signal with directive: ", directive)
	match directive:
		"up":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus up")
			focused_index = (focused_index - 1) % buttons.size()
			# Skip invisible buttons
			while not buttons[focused_index].visible:
				focused_index = (focused_index - 1) % buttons.size()
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
				print("[SubMenu] Button has_focus before grab_focus: ", buttons[focused_index].has_focus())
			buttons[focused_index].grab_focus()
			if not DEBUG_DISABLED:
				print("[SubMenu] Button has_focus after grab_focus: ", buttons[focused_index].has_focus())
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			if not DEBUG_DISABLED:
				print("[SubMenu] Moving focus down")
			focused_index = (focused_index + 1) % buttons.size()
			# Skip invisible buttons
			while not buttons[focused_index].visible:
				focused_index = (focused_index + 1) % buttons.size()
			if not DEBUG_DISABLED:
				print("[SubMenu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
				print("[SubMenu] Button has_focus before grab_focus: ", buttons[focused_index].has_focus())
			buttons[focused_index].grab_focus()
			if not DEBUG_DISABLED:
				print("[SubMenu] Button has_focus after grab_focus: ", buttons[focused_index].has_focus())
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
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.set_meta("sub_menu_focused_index", 0)
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		"homepage":
			if not DEBUG_DISABLED:
				print("[SubMenu] Homepage to main menu")
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.set_meta("sub_menu_focused_index", 0)
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
