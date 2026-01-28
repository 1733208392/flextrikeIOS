extends Control

# Global variable for current language
static var current_language = "English"

# Global variable for current drill sequence
static var current_drill_sequence = "Fixed"

# Global variables for auto restart settings
static var auto_restart_enabled = false
static var auto_restart_pause_time = 5  # Changed to store the selected time (5 or 10)

# Global variable for ending target setting
static var has_ending_target = false

# SFX volume setting (0-10 scale, default 5)
static var sfx_volume = 5

# Sensor threshold tracking
var initial_threshold = 0
var current_threshold = 0
var initial_slider_value = 0
var threshold_changed = false

# Constants for sensitivity slider and threshold transformation, 
# The safe range for threshold is (760 - 1460)
const SLIDER_MIN = 0
const SLIDER_MAX = 700
const THRESHOLD_MAX = 1460

# Debug flag for controlling print statements
# Uses the centralized GlobalDebug system
# const DEBUG_DISABLED = true  # Removed - now using GlobalDebug.DEBUG_DISABLED

# Signal emitted when SFX volume changes
signal sfx_volume_changed(volume: int)

# References to language buttons
@onready var chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/SimplifiedChineseButton"
@onready var japanese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/JapaneseButton"
@onready var english_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/EnglishButton"
@onready var traditional_chinese_button = $"VBoxContainer/MarginContainer/tab_container/Languages/MarginContainer/LanguageContainer/TraditionalChineseButton"

# References to labels that need translation
@onready var tab_container = $"VBoxContainer/MarginContainer/tab_container"
@onready var description_label = $"VBoxContainer/MarginContainer/tab_container/About/HBoxContainer/Left/MarginContainer/DescriptionLabel"
@onready var copyright_label = $"CopyrightLabel"

# References to drill button (single CheckButton)
@onready var random_sequence_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/RandomSequenceButton"

# References to auto restart controls
@onready var ending_target_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/EndingTargetButton"
@onready var auto_restart_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartButton"
@onready var pause_5s_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer/Pause5sButton"
@onready var pause_10s_check = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer/Pause10sButton"
@onready var auto_restart_pause_container = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/AutoRestartPauseContainer"

@onready var language_buttons = []

# References to drill note label
@onready var drill_note_label = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/Label"

# References to sensitivity controls
@onready var sensitivity_slider = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SensitivityHSlider"
@onready var sensitivity_label = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SensitivityLabel"

# References to SFX volume controls
@onready var sfx_volume_slider = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SFXVolumnHSlider"
@onready var sfx_label = $"VBoxContainer/MarginContainer/tab_container/Drills/MarginContainer/DrillContainer/SFX"

# Reference to background music
@onready var background_music = $BackgroundMusic

# Reference to upgrade button
@onready var upgrade_button = $"VBoxContainer/MarginContainer/tab_container/About/MarginContainer/Button"

# Reference to networking tab script
@onready var networking_tab = preload("res://scene/option/networking_tab.gd").new()

func _ready():
	# Show status bar when entering options
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		print("[Option] Showed status bar: ", status_bar.name)
	
	# Initialize networking tab script FIRST
	add_child(networking_tab)
	
	# Load saved settings from GlobalData
	load_settings_from_global_data()
	
	# Update UI texts with current language
	update_ui_texts()
	
	# Connect signals for language buttons
	if chinese_button:
		chinese_button.pressed.connect(_on_language_changed.bind("Chinese"))
	if japanese_button:
		japanese_button.pressed.connect(_on_language_changed.bind("Japanese"))
	if english_button:
		english_button.pressed.connect(_on_language_changed.bind("English"))
	if traditional_chinese_button:
		traditional_chinese_button.pressed.connect(_on_language_changed.bind("Traditional Chinese"))
	
	# Connect signals for drill sequence CheckButton
	if random_sequence_check:
		random_sequence_check.toggled.connect(_on_drill_sequence_toggled)
	
	# Connect signals for auto restart controls
	if ending_target_check:
		ending_target_check.toggled.connect(_on_ending_target_toggled)
	if auto_restart_check:
		auto_restart_check.toggled.connect(_on_auto_restart_toggled)
	if pause_5s_check:
		pause_5s_check.toggled.connect(_on_pause_time_changed.bind(5))
	if pause_10s_check:
		pause_10s_check.toggled.connect(_on_pause_time_changed.bind(10))
	
	# Initialize language buttons array
	# Order: Traditional Chinese (0), Chinese (1), Japanese (2), English (3)
	language_buttons = [traditional_chinese_button, chinese_button, japanese_button, english_button]
	
	# Debug: Check which buttons are properly loaded
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Language buttons initialization:")
		for i in range(language_buttons.size()):
			if language_buttons[i]:
				print("[Option]   Button ", i, ": ", language_buttons[i].name, " - OK")
			else:
				print("[Option]   Button ", i, ": NULL - MISSING!")
	
	# Set tab_container focusable
	if tab_container:
		tab_container.focus_mode = Control.FOCUS_ALL

	# Connect upgrade button pressed
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)

	# Connect sensitivity slider value_changed signal
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_value_changed)
		sensitivity_slider.min_value = SLIDER_MIN
		sensitivity_slider.max_value = SLIDER_MAX
		# Update label with initial value
		_update_sensitivity_label()
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Sensitivity slider not found!")
	
	# Connect SFX volume slider value_changed signal
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
		# Update label with initial value
		_update_sfx_label()
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] SFX volume slider not found!")

	# Load SFX volume from GlobalData and apply it to background music
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume_value = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume_value)
		print("[Option] Loaded SFX volume from GlobalData: ", sfx_volume_value)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		print("[Option] Using default SFX volume: 5")
	
	# Play background music
	if background_music:
		background_music.play()
		print("[Option] Playing background music")

	# Load embedded system status to get current threshold
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.embedded_status(Callable(self, "_on_embedded_status_response"))
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Requesting embedded system status")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] HttpService singleton not found!")

	# Focus will be set by load_settings_from_global_data() based on current language
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Connecting to WebSocketListener.menu_control signal")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] WebSocketListener singleton not found!")

func _on_language_changed(language: String):
	current_language = language
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["language"] = current_language
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[language] to: ", current_language)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	set_locale_from_language(language)
	save_settings()
	update_ui_texts()
	if not GlobalDebug.DEBUG_DISABLED:
		print("Language changed to: ", language)

func _on_drill_sequence_toggled(button_pressed: bool):
	var sequence = "Random" if button_pressed else "Fixed"
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Drill sequence toggled to: ", sequence)
		print("[Option] Current drill_sequence before change: ", current_drill_sequence)
	current_drill_sequence = sequence
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Current drill_sequence after change: ", current_drill_sequence)
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["drill_sequence"] = current_drill_sequence
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[drill_sequence] to: ", current_drill_sequence)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_ending_target_toggled(button_pressed: bool):
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Ending target toggled to: ", button_pressed)
	has_ending_target = button_pressed
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["has_ending_target"] = has_ending_target
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[has_ending_target] to: ", has_ending_target)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_auto_restart_toggled(button_pressed: bool):
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Auto restart toggled to: ", button_pressed)
	auto_restart_enabled = button_pressed
	
	# Show/hide pause time container based on auto restart state
	if auto_restart_pause_container:
		auto_restart_pause_container.visible = button_pressed
	
	# Enable/disable pause time buttons based on auto restart state
	if pause_5s_check:
		pause_5s_check.disabled = !button_pressed
	if pause_10s_check:
		pause_10s_check.disabled = !button_pressed
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["auto_restart"] = auto_restart_enabled
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[auto_restart] to: ", auto_restart_enabled)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

func _on_pause_time_changed(selected_time: int):
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Pause time changed to: ", selected_time)
	auto_restart_pause_time = selected_time
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["auto_restart_pause_time"] = auto_restart_pause_time
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[auto_restart_pause_time] to: ", auto_restart_pause_time)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	save_settings()

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

func set_language_button_pressed():
	# First reset all buttons
	if english_button:
		english_button.button_pressed = false
	if chinese_button:
		chinese_button.button_pressed = false
	if traditional_chinese_button:
		traditional_chinese_button.button_pressed = false
	if japanese_button:
		japanese_button.button_pressed = false
	
	# Then set the current language button as pressed
	match current_language:
		"Chinese":
			if chinese_button:
				chinese_button.button_pressed = true
		"Traditional Chinese":
			if traditional_chinese_button:
				traditional_chinese_button.button_pressed = true
		"Japanese":
			if japanese_button:
				japanese_button.button_pressed = true
		"English":
			if english_button:
				english_button.button_pressed = true

func set_drill_button_pressed():
	# Set CheckButton state: checked = Random, unchecked = Fixed
	if random_sequence_check:
		random_sequence_check.button_pressed = (current_drill_sequence == "Random")

func set_ending_target_button_pressed():
	# Set CheckButton state for ending target
	if ending_target_check:
		ending_target_check.button_pressed = has_ending_target

func set_auto_restart_button_pressed():
	# Set CheckButton state for auto restart
	if auto_restart_check:
		auto_restart_check.button_pressed = auto_restart_enabled
		# Show/hide pause time container based on auto restart state
		if auto_restart_pause_container:
			auto_restart_pause_container.visible = auto_restart_enabled
		# Set pause time button states based on auto restart state and selected time
		if pause_5s_check:
			pause_5s_check.disabled = !auto_restart_enabled
			pause_5s_check.button_pressed = (auto_restart_enabled and auto_restart_pause_time == 5)
		if pause_10s_check:
			pause_10s_check.disabled = !auto_restart_enabled
			pause_10s_check.button_pressed = (auto_restart_enabled and auto_restart_pause_time == 10)

func set_focus_to_current_language():
	# Set focus to the button corresponding to the current language
	match current_language:
		"English":
			if english_button:
				english_button.grab_focus()
		"Chinese":
			if chinese_button:
				chinese_button.grab_focus()
		"Traditional Chinese":
			if traditional_chinese_button:
				traditional_chinese_button.grab_focus()
		"Japanese":
			if japanese_button:
				japanese_button.grab_focus()
		_:
			# Default to English if unknown language
			if english_button:
				english_button.grab_focus()

func set_focus_based_on_tab():
	# Set focus based on the current tab
	var current = tab_container.current_tab if tab_container else 0
	match current:
		0:
			networking_tab.set_focus_to_first_button()
		1:
			set_focus_to_current_language()
		2:
			if ending_target_check:
				ending_target_check.grab_focus()
			else:
				tab_container.grab_focus()
		_:
			tab_container.grab_focus()

func update_ui_texts():
	if tab_container:
		# New tab order: 0 Networking, 1 Languages, 2 Drills, 3 About
		tab_container.set_tab_title(0, tr("networking"))
		tab_container.set_tab_title(1, tr("languages"))
		tab_container.set_tab_title(2, tr("drill"))
		tab_container.set_tab_title(3, tr("about"))
	if description_label:
		description_label.text = tr("about_description_intro") + "\n" + tr("about_description_features")
	if copyright_label:
		copyright_label.text = tr("copyright")
	if random_sequence_check:
		random_sequence_check.text = tr("random_sequence")
	
	# Update networking tab UI texts
	networking_tab.update_ui_texts()
	
	# Drills tab labels
	if ending_target_check:
		ending_target_check.text = tr("ending_target")
	if auto_restart_check:
		auto_restart_check.text = tr("auto_restart")
	if pause_5s_check:
		pause_5s_check.text = tr("pause_5s")
	if pause_10s_check:
		pause_10s_check.text = tr("pause_10s")
	if sensitivity_label:
		sensitivity_label.text = tr("sensor_sensitivity")
	if sfx_label:
		sfx_label.text = tr("sound_sfx")
	if drill_note_label:
		drill_note_label.text = tr("auto_restart_note")

func save_settings():
	# Save settings directly using current GlobalData
	var http_service = get_node("/root/HttpService")
	if not http_service:
		if not GlobalDebug.DEBUG_DISABLED:
			print("HttpService not found!")
		return
	
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data or global_data.settings_dict.size() == 0:
		if not GlobalDebug.DEBUG_DISABLED:
			print("GlobalData not available, cannot save settings")
		return
	
	var settings_data = global_data.settings_dict.duplicate()
	var content = JSON.stringify(settings_data)
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Saving settings directly: ", settings_data)
	
	http_service.save_game(_on_save_settings_callback, "settings", content)

func _on_save_settings_callback(_result, response_code, _headers, _body):
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Save settings callback - Response code: ", response_code)
		if response_code == 200:
			print("[Option] Settings saved successfully to HTTP server")
			# GlobalData is already updated immediately when settings change
			print("[Option] Settings save completed successfully")
		else:
			print("[Option] Failed to save settings to HTTP server: ", response_code)
			print("[Option] Response body: ", _body.get_string_from_utf8() if _body else "NO_BODY")
			print("[Option] Note: GlobalData has been updated locally, but HTTP save failed")

func load_settings_from_global_data():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		current_language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(current_language)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded language from GlobalData: ", current_language)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] GlobalData not found or no language setting, using default English")
		current_language = "English"
		set_locale_from_language(current_language)
	
	# Load drill sequence setting
	if global_data and global_data.settings_dict.has("drill_sequence"):
		current_drill_sequence = global_data.settings_dict.get("drill_sequence", "Fixed")
		if current_drill_sequence == "":
			current_drill_sequence = "Fixed"
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded drill_sequence from GlobalData: ", current_drill_sequence)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No drill_sequence setting, using default Fixed")
		current_drill_sequence = "Fixed"
	
	# Load ending target setting
	if global_data and global_data.settings_dict.has("has_ending_target"):
		has_ending_target = global_data.settings_dict.get("has_ending_target", false)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded has_ending_target from GlobalData: ", has_ending_target)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No has_ending_target setting, using default false")
		has_ending_target = false
	
	# Load auto restart settings
	if global_data and global_data.settings_dict.has("auto_restart"):
		auto_restart_enabled = global_data.settings_dict.get("auto_restart", false)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded auto_restart from GlobalData: ", auto_restart_enabled)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No auto_restart setting, using default false")
		auto_restart_enabled = false
	
	if global_data and global_data.settings_dict.has("auto_restart_pause_time"):
		auto_restart_pause_time = global_data.settings_dict.get("auto_restart_pause_time", 5)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded auto_restart_pause_time from GlobalData: ", auto_restart_pause_time)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No auto_restart_pause_time setting, using default 5")
		auto_restart_pause_time = 5
	
	# Load SFX volume setting
	if global_data and global_data.settings_dict.has("sfx_volume"):
		sfx_volume = global_data.settings_dict.get("sfx_volume", 5)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Loaded sfx_volume from GlobalData: ", sfx_volume)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No sfx_volume setting, using default 5")
		sfx_volume = 5
	
	# Update UI to reflect the loaded settings
	set_language_button_pressed()
	set_drill_button_pressed()
	set_ending_target_button_pressed()
	set_auto_restart_button_pressed()
	update_ui_texts()
	
	# Set SFX slider value to loaded setting
	if sfx_volume_slider:
		sfx_volume_slider.value = sfx_volume
	
	# Use call_deferred to ensure focus is set after all UI updates are complete
	call_deferred("set_focus_based_on_tab")

# Functions to get current auto restart settings (can be called from other scripts)

# Function to get current language (can be called from other scripts)
static func get_current_language() -> String:
	return current_language

# Function to get current drill sequence (can be called from other scripts)
static func get_current_drill_sequence() -> String:
	return current_drill_sequence

# Function to get ending target setting (can be called from other scripts)
static func get_has_ending_target() -> bool:
	return has_ending_target

# Functions to get current auto restart settings (can be called from other scripts)
static func get_auto_restart_enabled() -> bool:
	return auto_restart_enabled

static func get_auto_restart_pause_time() -> int:
	return auto_restart_pause_time

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down":
			if tab_container:
				match tab_container.current_tab:
					0:
						if not GlobalDebug.DEBUG_DISABLED:
							print("[Option] Navigation: ", directive, " on Networking tab")
						networking_tab.navigate_network_buttons(directive)
					1:
						if not GlobalDebug.DEBUG_DISABLED:
							print("[Option] Navigation: ", directive, " on Languages tab")
						navigate_buttons(directive)
					2:
						if not GlobalDebug.DEBUG_DISABLED:
							print("[Option] Navigation: ", directive, " on Drills tab")
						navigate_drill_buttons(directive)
					_:
						if not GlobalDebug.DEBUG_DISABLED:
							print("[Option] Navigation: ", directive, " ignored - current tab has no navigation")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"left", "right":
			# Check if sensitivity slider is focused on Drills tab
			if tab_container and tab_container.current_tab == 2 and sensitivity_slider and sensitivity_slider.has_focus():
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Adjusting sensitivity slider: ", directive)
				adjust_sensitivity_slider(directive)
			# Check if SFX volume slider is focused on Drills tab
			elif tab_container and tab_container.current_tab == 2 and sfx_volume_slider and sfx_volume_slider.has_focus():
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Adjusting SFX volume slider: ", directive)
				adjust_sfx_volume_slider(directive)
			else:
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Tab switch: ", directive)
				switch_tab(directive)
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Enter pressed")
			press_focused_button()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			_save_threshold_if_changed()
		"back", "homepage":
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] ", directive, " - navigating to main menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			# Save threshold before leaving the scene
			_save_threshold_if_changed()
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "options"
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Set return_source to options")
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Warning: Node not in tree, cannot change scene")
		"volume_up":
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Volume up")
			volume_up()
		"volume_down":
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Volume down")
			volume_down()
		"power":
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Power off")
			power_off()
		_:
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Unknown directive: ", directive)

func navigate_buttons(direction: String):
	var current_index = -1
	for i in range(language_buttons.size()):
		if language_buttons[i] and language_buttons[i].has_focus():
			current_index = i
			break
	if current_index == -1:
		# If no button has focus, start with the first valid button
		for i in range(language_buttons.size()):
			if language_buttons[i]:
				language_buttons[i].grab_focus()
				if not GlobalDebug.DEBUG_DISABLED:
					print("[Option] Focus set to first valid button: ", language_buttons[i].name)
				return
		return
	
	# Find the next valid button in the specified direction
	var attempts = 0
	var target_index = current_index
	while attempts < language_buttons.size():
		if direction == "up":
			target_index = (target_index - 1 + language_buttons.size()) % language_buttons.size()
		else:  # down
			target_index = (target_index + 1) % language_buttons.size()
		
		# Check if the target button exists and is valid
		if language_buttons[target_index] and language_buttons[target_index] != language_buttons[current_index]:
			language_buttons[target_index].grab_focus()
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Focus moved to ", language_buttons[target_index].name)
			return
		
		attempts += 1
	
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] No other valid buttons found for navigation")

func navigate_drill_buttons(direction: String):
	# With multiple drill buttons, we need to handle navigation between them
	var drill_buttons = []
	if ending_target_check:
		drill_buttons.append(ending_target_check)
	if random_sequence_check:
		drill_buttons.append(random_sequence_check)
	if auto_restart_check:
		drill_buttons.append(auto_restart_check)
	if pause_5s_check and auto_restart_enabled:
		drill_buttons.append(pause_5s_check)
	if pause_10s_check and auto_restart_enabled:
		drill_buttons.append(pause_10s_check)
	if sensitivity_slider:
		drill_buttons.append(sensitivity_slider)
	if sfx_volume_slider:
		drill_buttons.append(sfx_volume_slider)
	
	if drill_buttons.is_empty():
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] No drill buttons found for navigation")
		return
	
	# Find current focused button
	var current_index = -1
	for i in range(drill_buttons.size()):
		if drill_buttons[i].has_focus():
			current_index = i
			break
	
	if current_index == -1:
		# If no button has focus, focus the first one
		if drill_buttons[0]:
			drill_buttons[0].grab_focus()
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Focus set to first drill button")
		return
	
	# Find the next valid button in the specified direction
	var attempts = 0
	var target_index = current_index
	while attempts < drill_buttons.size():
		if direction == "up":
			target_index = (target_index - 1 + drill_buttons.size()) % drill_buttons.size()
		else:  # down
			target_index = (target_index + 1) % drill_buttons.size()
		
		# Check if the target button exists and is valid
		if drill_buttons[target_index]:
			drill_buttons[target_index].grab_focus()
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Focus moved to drill button at index: ", target_index)
			return
		
		attempts += 1
	
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] No other valid drill buttons found for navigation")

func press_focused_button():
	# Networking tab
	if tab_container and tab_container.current_tab == 0:
		networking_tab.press_focused_button()
		return

	for button in language_buttons:
		if button and button.has_focus():
			var language = ""
			if button == english_button:
				language = "English"
			elif button == chinese_button:
				language = "Chinese"
			elif button == traditional_chinese_button:
				language = "Traditional Chinese"
			elif button == japanese_button:
				language = "Japanese"
			_on_language_changed(language)
			set_language_button_pressed()
			break
	
	# Handle drill CheckButton
	if random_sequence_check and random_sequence_check.has_focus():
		# Toggle the CheckButton
		random_sequence_check.button_pressed = !random_sequence_check.button_pressed
		# This will trigger the toggled signal which calls _on_drill_sequence_toggled
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Toggled drill CheckButton to: ", random_sequence_check.button_pressed)
	
	# Handle ending target CheckButton
	if ending_target_check and ending_target_check.has_focus():
		# Toggle the CheckButton
		ending_target_check.button_pressed = !ending_target_check.button_pressed
		# This will trigger the toggled signal which calls _on_ending_target_toggled
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Toggled ending target CheckButton to: ", ending_target_check.button_pressed)
	
	# Handle auto restart CheckButton
	if auto_restart_check and auto_restart_check.has_focus():
		# Toggle the CheckButton
		auto_restart_check.button_pressed = !auto_restart_check.button_pressed
		# This will trigger the toggled signal which calls _on_auto_restart_toggled
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Toggled auto restart CheckButton to: ", auto_restart_check.button_pressed)
	
	# Handle pause time check buttons
	if pause_5s_check and pause_5s_check.has_focus():
		# Toggle the 5s button (this will automatically untoggle the 10s button due to ButtonGroup)
		pause_5s_check.button_pressed = true
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Selected pause time: 5s")
		_on_pause_time_changed(5)
	if pause_10s_check and pause_10s_check.has_focus():
		# Toggle the 10s button (this will automatically untoggle the 5s button due to ButtonGroup)
		pause_10s_check.button_pressed = true
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Selected pause time: 10s")
		_on_pause_time_changed(10)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] HttpService singleton not found!")

func _on_volume_up_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Volume up HTTP response:", _result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] HttpService singleton not found!")

func _on_volume_down_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Volume down HTTP response:", _result, response_code, body_str)

func power_off():
	var dialog_scene = preload("res://scene/power_off_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	dialog.set_alert_text(tr("power_off_alert"))
	add_child(dialog)

func has_visible_power_off_dialog() -> bool:
	for child in get_children():
		if child.name == "PowerOffDialog":
			return true
	return false

func switch_tab(direction: String):
	if not tab_container:
		return
	var current = tab_container.current_tab
	if direction == "right":
		current = (current + 1) % tab_container.get_tab_count()
	else:
		current = (current - 1 + tab_container.get_tab_count()) % tab_container.get_tab_count()
	tab_container.current_tab = current
	match current:
		0:
			networking_tab.set_focus_to_first_button()
		1:
			set_focus_to_current_language()
		2:
			if random_sequence_check:
				random_sequence_check.grab_focus()
			else:
				tab_container.grab_focus()
		_:
			tab_container.grab_focus()
	print("[Option] Switched to tab: ", tab_container.get_tab_title(current))

func _on_upgrade_pressed():
	var global_data = get_node_or_null("/root/GlobalData")
	
	# Navigate to software upgrade scene (only works in OTA mode)
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Navigating to software upgrade scene")
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/option/software_upgrade.tscn")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: Node not in tree, cannot change scene")

func _on_upgrade_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Upgrade engine HTTP response:", result, response_code, body_str)

func _on_embedded_status_response(_result, _response_code, _headers, body):
	"""Handle embedded system status response."""
	var body_str = body.get_string_from_utf8()
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Embedded status response:", body_str)
	
	var response = JSON.parse_string(body_str)
	if response and response.has("code") and response.code == 0 and response.has("data"):
		var threshold = response.data.threshold
		# Round to nearest 10
		threshold = round(threshold / 10.0) * 10
		initial_threshold = threshold
		current_threshold = threshold
		threshold_changed = false
		
		# Calculate slider value: THRESHOLD_MAX - threshold, clamped to SLIDER_MIN-SLIDER_MAX
		var slider_value = clamp(THRESHOLD_MAX - threshold, SLIDER_MIN, SLIDER_MAX)
		initial_slider_value = slider_value
		if sensitivity_slider:
			sensitivity_slider.value = slider_value
			_update_sensitivity_label()
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Set sensitivity slider to: ", slider_value, " (threshold: ", threshold, ")")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Invalid embedded status response")

func _on_sensitivity_value_changed(value: float):
	"""Called when the sensitivity slider value changes."""
	current_threshold = round((THRESHOLD_MAX - int(value)) / 10.0) * 10
	threshold_changed = (value != initial_slider_value)
	_update_sensitivity_label()

func _update_sensitivity_label():
	"""Update the sensitivity label with the current slider value."""
	if sensitivity_slider and sensitivity_label:
		sensitivity_label.text = tr("sensor_sensitivity")

func adjust_sensitivity_slider(direction: String):
	"""Adjust the sensitivity slider with left/right directives."""
	if not sensitivity_slider:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Sensitivity slider not found!")
		return
	
	var current_value = sensitivity_slider.value
	var step = 50

	if direction == "right":
		var new_value = min(sensitivity_slider.max_value, current_value + step)
		sensitivity_slider.value = new_value
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Increased sensitivity to: ", sensitivity_slider.value)
	elif direction == "left":
		var new_value = max(sensitivity_slider.min_value, current_value - step)
		sensitivity_slider.value = new_value
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Decreased sensitivity to: ", sensitivity_slider.value)

func _save_threshold_if_changed():
	"""Save threshold to embedded system if it has changed."""
	if threshold_changed:
		var http_service = get_node_or_null("/root/HttpService")
		if http_service:
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] Threshold changed from ", initial_threshold, " to ", current_threshold, ", saving...")
			# Use empty callable since we're exiting anyway
			http_service.embedded_set_threshold(Callable(), current_threshold)
		else:
			if not GlobalDebug.DEBUG_DISABLED:
				print("[Option] HttpService not found, cannot save threshold")
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Threshold not changed, no need to save")

func _on_threshold_set_response(_result, _response_code, _headers, body):
	"""Handle threshold set response."""
	var body_str = body.get_string_from_utf8()
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] Threshold set response: ", body_str)

func _on_sfx_volume_changed(value: float):
	"""Called when the SFX volume slider value changes."""
	sfx_volume = int(value)
	_update_sfx_label()
	
	# Apply volume to background music immediately
	_apply_sfx_volume(sfx_volume)
	
	# Update GlobalData immediately to ensure consistency
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["sfx_volume"] = sfx_volume
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Immediately updated GlobalData.settings_dict[sfx_volume] to: ", sfx_volume)
	else:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Warning: GlobalData not found, cannot update settings_dict")
	
	# Emit signal for bootcamp and mainmenu to listen
	sfx_volume_changed.emit(sfx_volume)
	
	# Also notify any scenes that are listening via a global method
	_notify_sfx_listeners(sfx_volume)
	
	# Save settings to HTTP
	save_settings()
	
	if not GlobalDebug.DEBUG_DISABLED:
		print("[Option] SFX volume changed to: ", value)

func _notify_sfx_listeners(volume: int):
	"""Notify all listening scenes about SFX volume change."""
	# Try to notify bootcamp scene if it's loaded
	var bootcamp_node = get_tree().root.get_node_or_null("Bootcamp")
	if bootcamp_node and bootcamp_node.has_method("_on_sfx_volume_changed"):
		bootcamp_node._on_sfx_volume_changed(volume)
	
	# Try to notify main_menu scene if it's loaded
	var main_menu_node = get_tree().root.get_node_or_null("MainMenu")
	if main_menu_node and main_menu_node.has_method("_on_sfx_volume_changed"):
		main_menu_node._on_sfx_volume_changed(volume)

func _update_sfx_label():
	"""Update the SFX volume label with the current slider value."""
	if sfx_volume_slider and sfx_label:
		sfx_label.text = tr("sound_sfx")
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Updated SFX label to: ", sfx_label.text)

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
		print("[Option] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		print("[Option] Set audio volume_db to ", db, " (volume level: ", volume, ")")

func adjust_sfx_volume_slider(direction: String):
	"""Adjust the SFX volume slider with left/right directives."""
	if not sfx_volume_slider:
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] SFX volume slider not found!")
		return
	
	var current_value = sfx_volume_slider.value
	var step = 1  # Step by 1 for 0-10 range

	if direction == "right":
		sfx_volume_slider.value = min(sfx_volume_slider.max_value, current_value + step)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Increased SFX volume to: ", sfx_volume_slider.value)
	elif direction == "left":
		sfx_volume_slider.value = max(sfx_volume_slider.min_value, current_value - step)
		if not GlobalDebug.DEBUG_DISABLED:
			print("[Option] Decreased SFX volume to: ", sfx_volume_slider.value)
