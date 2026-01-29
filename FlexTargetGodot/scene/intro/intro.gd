extends Control

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

@export var variant: String = "IPSC"  # Can be "IPSC" or "IDPA"

@onready var start_button = $StartButton
@onready var main_text = $CenterContainer/ContentVBox/MainText
@onready var prev_button = $CenterContainer/ContentVBox/NavigationContainer/PrevButton
@onready var next_button = $CenterContainer/ContentVBox/NavigationContainer/NextButton
@onready var page_indicator = $CenterContainer/ContentVBox/NavigationContainer/PageIndicator
@onready var title_label = $TitleLabel
@onready var history_button = get_node_or_null("TopBar/HistoryButton")
@onready var background_music = $BackgroundMusic

var current_page = 0
var pages = []

func load_language_setting():
	# Load language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[Intro] Loaded language from GlobalData: ", language)
		call_deferred("initialize_pages_and_ui")
	else:
		if not DEBUG_DISABLED:
			print("[Intro] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
		call_deferred("initialize_pages_and_ui")

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
		print("[Intro] Set locale to: ", locale)

func initialize_pages_and_ui():
	# Initialize pages with translated content
	pages = []
	
	# Get the variant from GlobalData first, fall back to export variant
	var current_variant = variant
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.has_meta("selected_variant"):
		current_variant = global_data.selected_variant
	elif global_data:
		current_variant = global_data.selected_variant
	
	# Get translated content for each page based on variant
	var translation_keys = []
	if current_variant.to_upper() == "IDPA":
		translation_keys = ["idpa_score_rule", "idpa_penalty_rule", "idpa_timer_system", "idpa_drill_rule", "idpa_hit_factor_rule"]
		if not DEBUG_DISABLED:
			print("[Intro] Loading IDPA variant pages")
	else:  # Default to IPSC
		translation_keys = ["score_rule", "panelty_rule", "timer_system", "drill_rule", "hit_factor_rule"]
		if not DEBUG_DISABLED:
			print("[Intro] Loading IPSC variant pages")
	
	for key in translation_keys:
		var translated_content = tr(key)
		if not DEBUG_DISABLED:
			print("[Intro] Raw translation for ", key, ": ", translated_content)
		
		# Try to parse as JSON first
		var parsed_json = JSON.parse_string(translated_content)
		if parsed_json != null and typeof(parsed_json) == TYPE_DICTIONARY and parsed_json.has("content"):
			# Successfully parsed JSON - use only the content
			pages.append({
				"title": parsed_json.get("title", key.to_upper().replace("_", " ")),
				"content": parsed_json.content
			})
			if not DEBUG_DISABLED:
				print("[Intro] Successfully parsed JSON for ", key)
		else:
			# JSON parsing failed, try to extract content manually
			if not DEBUG_DISABLED:
				print("[Intro] JSON parsing failed for ", key, ", trying manual extraction")
			
			# Try to extract content from the string manually
			var content = extract_content_from_string(translated_content)
			pages.append({
				"title": key.to_upper().replace("_", " "),
				"content": content
			})
	
	# Update UI texts
	update_ui_texts()
	
	# Initialize pagination
	update_page_display()

func extract_content_from_string(text: String) -> String:
	# Try to extract content from JSON-like string manually
	var content_start = text.find('"content"')
	if content_start == -1:
		content_start = text.find("\"content\"")
	if content_start == -1:
		return text  # Return original if no content field found
	
	# Find the start of the content value
	var colon_pos = text.find(":", content_start)
	if colon_pos == -1:
		return text
	
	# Find the opening quote of the content value
	var quote_start = text.find('"', colon_pos)
	if quote_start == -1:
		return text
	
	# Find the closing quote (look for last quote before closing brace)
	var brace_pos = text.rfind("}")
	if brace_pos == -1:
		brace_pos = text.length()
	
	var quote_end = text.rfind('"', brace_pos)
	if quote_end == -1 or quote_end <= quote_start:
		return text
	
	# Extract the content between quotes
	var content = text.substr(quote_start + 1, quote_end - quote_start - 1)
	
	# Clean up escaped quotes
	content = content.replace('""', '"')
	
	return content

func update_ui_texts():
	# Update button texts and title
	if title_label:
		title_label.text = tr("rules")
	if prev_button:
		prev_button.text = tr("prev")
	if next_button:
		next_button.text = tr("next")
	if start_button:
		start_button.text = tr("start")
	if history_button:
		history_button.text = tr("leaderboard")

func _ready():
	# Load and apply current language setting first
	load_language_setting()
	
	# Load SFX volume from GlobalData and apply it to background music
	var global_data_for_sfx = get_node_or_null("/root/GlobalData")
	if global_data_for_sfx and global_data_for_sfx.settings_dict.has("sfx_volume"):
		var sfx_volume_value = global_data_for_sfx.settings_dict.get("sfx_volume", 5)
		_apply_sfx_volume(sfx_volume_value)
		if not DEBUG_DISABLED:
			print("[Intro] Loaded SFX volume from GlobalData: ", sfx_volume_value)
	else:
		# Default to volume level 5 if not set
		_apply_sfx_volume(5)
		if not DEBUG_DISABLED:
			print("[Intro] Using default SFX volume: 5")
	
	# Play background music
	if background_music:
		background_music.play()
		if not DEBUG_DISABLED:
			print("[Intro] Playing background music")
	
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Set start button as default focus
	start_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[Intro] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Intro] WebSocketListener singleton not found!")
	
	# Add some visual polish
	setup_ui_styles()

func update_page_display():
	# Safety check: ensure pages exist and current_page is valid
	if pages.is_empty() or current_page < 0 or current_page >= pages.size():
		if not DEBUG_DISABLED:
			print("[Intro] Invalid page state: pages.size()=", pages.size(), " current_page=", current_page)
		return
	
	# Update main text content
	var current_page_data = pages[current_page]
	if current_page_data != null and typeof(current_page_data) == TYPE_DICTIONARY:
		if current_page_data.has("content"):
			main_text.text = current_page_data.content
		else:
			main_text.text = tr("content_not_available")
			if not DEBUG_DISABLED:
				print("[Intro] Page ", current_page, " missing content field")
	else:
		main_text.text = tr("page_data_invalid")
		if not DEBUG_DISABLED:
			print("[Intro] Page ", current_page, " has invalid data: ", current_page_data)
	
	# Update page indicator
	if page_indicator:
		page_indicator.text = str(current_page + 1) + " / " + str(pages.size())
	
	# Update button states
	if prev_button:
		prev_button.disabled = (current_page == 0)
	if next_button:
		next_button.disabled = (current_page == pages.size() - 1)

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_page_display()
		if not DEBUG_DISABLED:
			print("[Intro] Previous page: ", current_page + 1)

func _on_next_pressed():
	if current_page < pages.size() - 1:
		current_page += 1
		update_page_display()
		if not DEBUG_DISABLED:
			print("[Intro] Next page: ", current_page + 1)
	
	# Add some visual polish
	setup_ui_styles()

func setup_ui_styles():
	# Style the start button
	if start_button:
		start_button.add_theme_color_override("font_color", Color.WHITE)
		start_button.add_theme_color_override("font_pressed_color", Color.YELLOW)
		start_button.add_theme_color_override("font_hover_color", Color.CYAN)

func _on_start_pressed():
	# Call the HTTP service to start the game
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Intro] Sending start game HTTP request...")
		http_service.start_game(_on_start_response)
	else:
		if not DEBUG_DISABLED:
			print("[Intro] HttpService singleton not found!")
		if get_tree():
			_jump_to_stage_scene()

func _on_start_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Intro] Start game HTTP response:", _result, response_code, body_str)
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Intro] Start game success, changing scene.")
		if get_tree():
			_jump_to_stage_scene()
	else:
		if not DEBUG_DISABLED:
			print("[Intro] Start game failed or invalid response.")

func _jump_to_stage_scene():
	"""Jump to the appropriate stage scene based on variant"""
	var global_data = get_node_or_null("/root/GlobalData")
	var current_variant = variant  # Use the scene's export variant as fallback
	
	# Try to get variant from GlobalData first
	if global_data:
		current_variant = global_data.selected_variant
	
	if not DEBUG_DISABLED:
		print("[Intro] Jumping to stage scene with variant: ", current_variant)
	
	# Jump to appropriate scene based on variant
	if current_variant.to_upper() == "IDPA":
		if not DEBUG_DISABLED:
			print("[Intro] Loading IDPA mini stage scene")
		if get_tree():
			get_tree().change_scene_to_file("res://scene/idpa_mini_stage/idpa_mini_stage.tscn")
	else:
		# Default to IPSC
		if not DEBUG_DISABLED:
			print("[Intro] Loading IPSC mini stage scene")
		if get_tree():
			get_tree().change_scene_to_file("res://scene/ipsc_mini_stage/ipsc_mini_stage.tscn")

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Intro] Received menu_control signal with directive: ", directive)
	match directive:
		"up", "down", "left", "right":
			if not DEBUG_DISABLED:
				print("[Intro] Navigation: ", directive)
			navigate_buttons()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"enter":
			if not DEBUG_DISABLED:
				print("[Intro] Enter pressed")
			press_focused_button()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"back":
			if not DEBUG_DISABLED:
				print("[Intro] Back - navigating to sub menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "history"
				if not DEBUG_DISABLED:
					print("[Intro] Set return_source to history")
			
			get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")
		"homepage":
			if not DEBUG_DISABLED:
				print("[Intro] Homepage - navigating to main menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "leaderboard"
				if not DEBUG_DISABLED:
					print("[Intro] Set return_source to leaderboard")
			
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
		"volume_up":
			if not DEBUG_DISABLED:
				print("[Intro] Volume up")
			volume_up()
		"volume_down":
			if not DEBUG_DISABLED:
				print("[Intro] Volume down")
			volume_down()
		"power":
			if not DEBUG_DISABLED:
				print("[Intro] Power off")
			power_off()
		_:
			if not DEBUG_DISABLED:
				print("[Intro] Unknown directive: ", directive)

func volume_up():
	# Call the HTTP service to increase the volume
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Intro] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if not DEBUG_DISABLED:
			print("[Intro] HttpService singleton not found!")

func _on_volume_up_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Intro] Volume up HTTP response:", _result, response_code, body_str)

func volume_down():
	# Call the HTTP service to decrease the volume
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Intro] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if not DEBUG_DISABLED:
			print("[Intro] HttpService singleton not found!")

func _on_volume_down_response(_result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Intro] Volume down HTTP response:", _result, response_code, body_str)

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

func navigate_buttons():
	# Enhanced navigation for prev/next and start buttons
	if prev_button.has_focus():
		next_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Intro] Focus moved to next button")
	elif next_button.has_focus():
		start_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Intro] Focus moved to start button")
	elif start_button.has_focus():
		prev_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[Intro] Focus moved to prev button")
	else:
		prev_button.grab_focus()

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
			print("[Intro] Muted audio (volume=", volume, ")")
	else:
		# Map 1-10 to -40dB to 0dB
		# volume 1 = -40dB, volume 10 = 0dB
		var db = -40.0 + ((volume - 1) * (40.0 / 9.0))
		if background_music:
			background_music.volume_db = db
		if not DEBUG_DISABLED:
			print("[Intro] Set audio volume_db to ", db, " (volume level: ", volume, ")")
		if not DEBUG_DISABLED:
			print("[Intro] Focus moved to prev button")

func press_focused_button():
	# Simulate pressing the currently focused button
	if start_button.has_focus():
		if not DEBUG_DISABLED:
			print("[Intro] Simulating start button press")
		_on_start_pressed()
	elif prev_button.has_focus():
		if not DEBUG_DISABLED:
			print("[Intro] Simulating prev button press")
		_on_prev_pressed()
	elif next_button.has_focus():
		if not DEBUG_DISABLED:
			print("[Intro] Simulating next button press")
		_on_next_pressed()
	else:
		if not DEBUG_DISABLED:
			print("[Intro] No button has focus")
