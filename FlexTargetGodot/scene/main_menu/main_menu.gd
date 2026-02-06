extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

@onready var stages_button = $CenterContainer/GridContainer/StagesButton
@onready var targets_button = $CenterContainer/GridContainer/TargetsButton
@onready var games_button = $CenterContainer/GridContainer/GamesButton
@onready var option_button = $CenterContainer/GridContainer/OptionsButton
@onready var copyright_label = $Label
@onready var background_music = $BackgroundMusic

var focused_index
var buttons = []
var upgrade_in_progress = false

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[Menu] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not found or no language setting, using default English")
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
		print("[Menu] Set locale to: ", locale)

func update_ui_texts():
	copyright_label.text = tr("copyright")
	
	# Append version info
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		copyright_label.text += " v" + global_data.VERSION
	
	if not DEBUG_DISABLED:
		print("[Menu] UI texts updated")

func _ready():
	# Show status bar when entering main menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		if not DEBUG_DISABLED:
			print("[Menu] Showed status bar: ", status_bar.name)
	
	# Load and apply current language setting
	load_language_setting()
	
	# Load SFX volume from GlobalData and apply it
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume)
		if not DEBUG_DISABLED:
			print("[Menu] Loaded SFX volume from GlobalData: ", sfx_volume)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		if not DEBUG_DISABLED:
			print("[Menu] Using default SFX volume: 5")
	
	# Play background music
	if background_music:
		background_music.play()
		# Ensure looping
		if not background_music.finished.is_connected(background_music.play):
			background_music.finished.connect(background_music.play)
		if not DEBUG_DISABLED:
			print("[Menu] Playing background music")
	
	# Connect button signals
	focused_index = 0
	buttons = []
	if targets_button:
		buttons.append(targets_button)
	if stages_button:
		buttons.append(stages_button)
	if games_button:
		buttons.append(games_button)
	if option_button:
		buttons.append(option_button)
		
	# Check return source and set focus accordingly
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.return_source != "":
		var source = global_data.return_source  # Store before resetting
		# Set focus based on return source
		match source:
			"drills":
				focused_index = 1  # stages_button
			"bootcamp":
				focused_index = 0  # targets_button
			"leaderboard":
				focused_index = 1  # stages_button
			"stage":
				focused_index = 1  # stages_button
			"games":
				focused_index = 2  # games_button
			"options":
				focused_index = 3  # option_button
			_:
				focused_index = 0  # default
		global_data.return_source = ""
		if not DEBUG_DISABLED:
			print("[Menu] Returning from ", source, ", setting focus to button index ", focused_index)
		
	#buttons[focused_index].grab_focus()
	_update_button_styles()

	# Use get_node instead of Engine.has_singleton
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		# Connect BLE ready command signal to jump to drills scene
		if ws_listener.has_signal("ble_ready_command"):
			ws_listener.ble_ready_command.connect(_on_ble_ready_command)
			if not DEBUG_DISABLED:
				print("[Menu] Connected to WebSocketListener.ble_ready_command signal")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] WebSocketListener has no ble_ready_command signal")
		if not DEBUG_DISABLED:
			print("[Menu] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] WebSocketListener singleton not found!")

	# Connect to GlobalData netlink_status_loaded signal
	if global_data:
		if not DEBUG_DISABLED:
			print("[Menu] Connected to GlobalData.netlink_status_loaded signal")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not found!")
	
	# Connect to SignalBus signals
	stages_button.pressed.connect(_on_drills_pressed)
	targets_button.pressed.connect(_on_bootcamp_pressed)
	games_button.pressed.connect(_on_games_pressed)
	option_button.pressed.connect(_on_option_pressed)

	# Check OTA mode and auto-jump to software upgrade scene if in OTA mode
	var gd = get_node_or_null("/root/GlobalData")
	if gd and gd.ota_mode:
		if not DEBUG_DISABLED:
			print("[Menu] OTA mode detected, automatically jumping to software upgrade scene")
		if is_inside_tree():
			call_deferred("_jump_to_upgrade_scene")
		return
	
	# Send version info only in normal mode (not OTA mode) via HttpService.forward_data_to_app
	# This allows mobile app to verify upgrade success
	if gd:
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			var version_message = {
				"type": "forward",
				"content": {
					"version": gd.VERSION
				}
			}
			http_service.forward_data_to_app(func(_result, _response_code, _headers, _body):
				if not DEBUG_DISABLED:
					print("[Menu] Sent version info to mobile app via forward_data_to_app")
			, version_message["content"])
			if not DEBUG_DISABLED:
				print("[Menu] Sending version info on main menu load: ", version_message)
		else:
			if not DEBUG_DISABLED:
				print("[Menu] HttpService not found for sending version info")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not found for OTA mode check")

func _jump_to_upgrade_scene():
	"""Jump to software upgrade scene (deferred call)"""
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/software_upgrade.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func on_stage_pressed():
	if upgrade_in_progress:
		return
	# Set up sub menu configuration for Stage options
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.sub_menu_config = {
			"title": "Stage Options",
			"items": [
				{
					"text": "ipsc",
					"action": "http_call",
					"http_call": "start_game",
					"success_scene": "res://scene/intro/intro.tscn",
					"variant": "IPSC"
				},
				{
					"text": "idpa",
					"action": "http_call",
					"http_call": "start_game",
					"success_scene": "res://scene/intro/intro.tscn",
					"variant": "IDPA"
				},
				{
					"text": "ipsc_leaderboard",
					"action": "load_scene",
					"scene": "res://scene/history.tscn",
				},
				{
					"text": "idpa_leaderboard",
					"action": "load_scene",
					"scene": "res://scene/history_idpa.tscn",
				}
			]
		}
		global_data.return_source = "stage"
		if not DEBUG_DISABLED:
			print("[Menu] Set sub menu config for Stage options")
	
	# Load the sub menu scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_drills_pressed():
	if upgrade_in_progress:
		return
	# Load the mini stages sub menu scene
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.return_source = "drills"
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_bootcamp_pressed():
	if upgrade_in_progress:
		return
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Menu] Sending start game HTTP request...")
		http_service.start_game(_on_bootcamp_response)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] HttpService singleton not found!")
	if not DEBUG_DISABLED:
		print("Boot Camp button pressed - Load training mode")

func _on_bootcamp_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Menu] Start game HTTP response:", result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Menu] Bootcamp Start game success, changing scene.")
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.return_source = "bootcamp"
		# Stop background music before transitioning to bootcamp
		if background_music:
			background_music.stop()
			if not DEBUG_DISABLED:
				print("[Menu] Stopped background music for bootcamp transition")
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/bootcamp.tscn")
		else:
			if not DEBUG_DISABLED:
				print("[Menu] Warning: Node not in tree, cannot change scene")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Start bootcamp failed or invalid response.")

func _on_games_pressed():
	if upgrade_in_progress:
		return
	# Load the games scene
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.return_source = "games"
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_option_pressed():
	if upgrade_in_progress:
		return
	# Load the options scene
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.return_source = "options"
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/option.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func power_off():
	if not DEBUG_DISABLED:
		print("[Menu] power_off() called")
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	if not DEBUG_DISABLED:
		print("[Menu] Dialog scene preloaded")
	var dialog = dialog_scene.instantiate()
	if not DEBUG_DISABLED:
		print("[Menu] Dialog instantiated")
	dialog.set_alert_text(tr("power_off_alert"))
	if not DEBUG_DISABLED:
		print("[Menu] Alert text set")
	add_child(dialog)
	if not DEBUG_DISABLED:
		print("[Menu] Dialog added to scene tree")
	dialog.show()
	if not DEBUG_DISABLED:
		print("[Menu] Dialog shown")

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func _update_button_styles():
	for i in range(buttons.size()):
		if buttons[i] == null:
			if not DEBUG_DISABLED:
				print("[Menu] Warning: Button at index ", i, " is null, skipping style update")
			continue
		if i == focused_index:
			buttons[i].add_theme_stylebox_override("normal", buttons[i].get_theme_stylebox("hover"))
			buttons[i].add_theme_color_override("font_color", buttons[i].get_theme_color("font_hover_color", "Button"))
			buttons[i].add_theme_font_override("font", buttons[i].get_theme_font("font_hover", "Button"))
			buttons[i].add_theme_color_override("icon_normal_color", buttons[i].get_theme_color("icon_hover_color", "Button"))
		else:
			buttons[i].remove_theme_stylebox_override("normal")
			buttons[i].remove_theme_color_override("font_color")
			buttons[i].remove_theme_font_override("font")
			buttons[i].remove_theme_color_override("icon_normal_color")
		
		# Update child label color based on button selection status
		var label = buttons[i].get_node_or_null("Label")
		if label:
			if i == focused_index:
				# Button is selected: change label color to #191919
				label.add_theme_color_override("font_color", Color("#191919"))
			else:
				# Button is unselected: change label color to #de3823
				label.add_theme_color_override("font_color", Color("#de3823"))

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Menu] Received menu_control signal with directive: ", directive)
	match directive:
		"up":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus up in grid")
			if focused_index == 2 and buttons[0].visible:
				focused_index = 0
			elif focused_index == 3 and buttons[1].visible:
				focused_index = 1
			# else stay
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus down in grid")
			if focused_index == 0 and buttons[2].visible:
				focused_index = 2
			elif focused_index == 1 and buttons[3].visible:
				focused_index = 3
			# else stay
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"left":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus left in grid")
			if focused_index == 1 and buttons[0].visible:
				focused_index = 0
			elif focused_index == 3 and buttons[2].visible:
				focused_index = 2
			# else stay
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"right":
			if not DEBUG_DISABLED:
				print("[Menu] Moving focus right in grid")
			if focused_index == 0 and buttons[1].visible:
				focused_index = 1
			elif focused_index == 2 and buttons[3].visible:
				focused_index = 3
			# else stay
			if not DEBUG_DISABLED:
				print("[Menu] Focused index: ", focused_index, " Button: ", buttons[focused_index].name, " visible: ", buttons[focused_index].visible)
			_update_button_styles()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			if not DEBUG_DISABLED:
				print("[Menu] Simulating button press")
			buttons[focused_index].pressed.emit()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"power":
			if not DEBUG_DISABLED:
				print("[Menu] Power off")
			power_off()
		_:
			if not DEBUG_DISABLED:
				print("[Menu] Unknown directive: ", directive)

func _on_ble_ready_command(content: Dictionary) -> void:
	if not DEBUG_DISABLED:
		print("[Menu] Received ble_ready_command with content: ", content)
	# Optionally inspect content to decide target scene or additional behavior
	# Store content on GlobalData so the drills_network scene can read it on startup
	var gd = get_node_or_null("/root/GlobalData")
	if gd:
		gd.ble_ready_content = content
		# Save game mode separately for global access
		if content.has("mode"):
			gd.game_mode = content["mode"]
			if not DEBUG_DISABLED:
				print("[Menu] Saved game_mode in GlobalData: ", content["mode"])
		if not DEBUG_DISABLED:
			print("[Menu] Stored ble_ready_content in GlobalData: ", content)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] GlobalData not available; cannot persist ble content")

	# Send ACK back to mobile app before changing scene
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		var ack_data = {"ack": "ready"}
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				if not DEBUG_DISABLED:
					print("[Menu] ACK for ready command sent successfully")
				# Defer scene change to ensure ACK is fully processed
				call_deferred("_jump_to_drills_network")
			else:
				if not DEBUG_DISABLED:
					print("[Menu] Failed to send ACK for ready command")
				# Still jump to drills network even if ACK failed
				call_deferred("_jump_to_drills_network")
		, ack_data)
	else:
		if not DEBUG_DISABLED:
			print("[Menu] HttpService not available; cannot send ACK")
		# Jump to drills network even if HttpService unavailable
		call_deferred("_jump_to_drills_network")

func _jump_to_drills_network():
	"""Jump to drills network scene (deferred call)"""
	if is_inside_tree():
		var global_data = get_node_or_null("/root/GlobalData")
		if global_data:
			global_data.return_source = "drills"
		if not DEBUG_DISABLED:
			print("[Menu] Jumping to drills_network scene")
		get_tree().change_scene_to_file("res://scene/drills_network/drills_network.tscn")
	else:
		if not DEBUG_DISABLED:
			print("[Menu] Warning: Node not in tree, cannot change scene")

func _on_sfx_volume_changed(volume: int):
	"""Handle SFX volume changes from Option scene.
	Volume ranges from 0 to 10, where 0 stops audio and 10 is max volume."""
	if not DEBUG_DISABLED:
		print("[Menu] SFX volume changed to: ", volume)
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
			print("[Menu] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		if not DEBUG_DISABLED:
			print("[Menu] Set audio volume_db to ", db, " (volume level: ", volume, ")")
