extends Node2D

# Performance optimization
# NOTE: temporarily enable debug prints to diagnose overlay visibility issues
const DEBUG_DISABLED = true  # Set to true to silence verbose debugging

# UI elements for internationalization
@onready var title_label = get_node_or_null("Background/Title")
@onready var restart_button = get_node_or_null("Background/HBoxContainer/RestartButton")
@onready var replay_button = get_node_or_null("Background/HBoxContainer/ReplayButton")
@onready var back_button = get_node_or_null("Background/HBoxContainerTitle/BackButton")
@onready var countdown_label = get_node_or_null("Background/CountdownLabel")

# Countdown timer variables
var countdown_timer: Timer = null
var countdown_seconds: int = 0

# Restart cooldown to prevent rapid successive restarts
var last_restart_time: float = 0.0
var restart_cooldown: float = 1.0  # 1 second cooldown between restarts

func _ready():
	"""Initialize the drill complete overlay"""
	if not DEBUG_DISABLED:
		print("=== DRILL COMPLETE OVERLAY INITIALIZED ===")
		print("[DrillComplete] Scene tree structure:")
		_debug_print_children(self, 0)
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Set up button focus management
	setup_button_focus()
	
	# Connect to GlobalData settings_loaded signal for language changes
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and not global_data.settings_loaded.is_connected(_on_global_settings_loaded):
		global_data.settings_loaded.connect(_on_global_settings_loaded)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Connected to GlobalData settings_loaded signal")

func _debug_print_children(node: Node, depth: int):
	"""Debug helper to print scene tree structure"""
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_debug_print_children(child, depth + 1)

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if not DEBUG_DISABLED:
		print("[DrillComplete] load_language_from_global_settings called")
		if global_data:
			print("[DrillComplete] GlobalData found, settings_dict: ", global_data.settings_dict)
		else:
			print("[DrillComplete] GlobalData not found!")
	
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[DrillComplete] Loaded language from GlobalData: ", language)
		call_deferred("update_ui_texts")
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] GlobalData not found or no language setting, using default English")
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
		print("[DrillComplete] Set locale to: ", locale)

func update_ui_texts():
	# Update static text elements with translations
	if not DEBUG_DISABLED:
		print("[DrillComplete] update_ui_texts called")
		print("[DrillComplete] Current locale: ", TranslationServer.get_locale())
		print("[DrillComplete] Available locales: ", TranslationServer.get_loaded_locales())
		print("[DrillComplete] Translation for 'complete': ", tr("complete"))
		print("[DrillComplete] Translation for 'restart': ", tr("restart"))
		print("[DrillComplete] Translation for 'replay': ", tr("replay"))
	
	# Re-get the nodes to ensure they exist (in case of timing issues)
	var title = get_node_or_null("Background/Title")
	var _restart_btn = get_node_or_null("Background/HBoxContainer/RestartButton")
	var _replay_btn = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	if title:
		title.text = tr("complete")
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated title to: ", title.text)
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] ERROR: title node not found at Background/Title")
	
	# if restart_btn:
	# 	restart_btn.text = tr("restart")
	# 	if not DEBUG_DISABLED:
	# 		print("[DrillComplete] Updated restart button to: ", restart_btn.text)
	# else:
	# 	if not DEBUG_DISABLED:
	# 		print("[DrillComplete] ERROR: restart button not found at Background/HBoxContainer/RestartButton")

func _notification(what):
	"""Debug overlay visibility changes"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Visibility changed to: ", visible)
			print("[drill_complete_overlay] Global position: ", global_position)
		if visible:
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Overlay is now visible and ready for input")
			# Grab focus for the restart button when overlay becomes visible
			grab_restart_button_focus()
		else:
			# Cleanup when overlay becomes invisible
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Overlay hidden - cleaning up countdown")
			stop_countdown()
			
			# Disable WebSocket UI click injection when overlay is hidden
			var ws_listener = get_node_or_null("/root/WebSocketListener")
			if ws_listener:
				ws_listener.set_emit_click_for_ui(false)
				if not DEBUG_DISABLED:
					print("[drill_complete_overlay] WebSocket UI click injection disabled")

func _on_restart_pressed():
	"""Handle restart button press"""
	# Check restart cooldown to prevent rapid successive restarts
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_restart_time) < restart_cooldown:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart cooldown active (%.2fs remaining), ignoring" % (restart_cooldown - (current_time - last_restart_time)))
		return
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Restart button pressed")
	last_restart_time = current_time
	
	# Find the drill manager and restart the drill
	var drill_ui = get_parent()
	if drill_ui:
		var drills_manager = drill_ui.get_parent()
		if drills_manager and drills_manager.has_method("restart_drill"):
			drills_manager.restart_drill()
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Drill restarted successfully")
		else:
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Warning: Could not find drills manager or restart_drill method")
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Warning: Could not find drill UI parent")

func _on_replay_pressed():
	"""Handle replay button press - navigate to drill replay scene"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Replay button pressed")
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_restart_time) < restart_cooldown:
		return
	last_restart_time = current_time
	
	# Navigate to the drill replay scene
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _on_back_pressed():
	"""Handle back button press - navigate to sub_menu scene"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Back button pressed")
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_restart_time) < restart_cooldown:
		return
	last_restart_time = current_time
	get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")

func setup_button_focus():
	"""Set up button focus management"""
	var restart_btn = get_node_or_null("Background/HBoxContainer/RestartButton")
	var replay_btn = get_node_or_null("Background/HBoxContainer/ReplayButton")
	var back_btn = get_node_or_null("Background/HBoxContainerTitle/BackButton")
	
	if restart_btn:
		restart_btn.focus_mode = Control.FOCUS_ALL
		restart_btn.pressed.connect(_on_restart_pressed)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] RestartButton focus enabled and signal connected")
	
	if replay_btn:
		replay_btn.focus_mode = Control.FOCUS_ALL
		replay_btn.pressed.connect(_on_replay_pressed)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] ReplayButton focus enabled and signal connected")
	
	if back_btn:
		back_btn.focus_mode = Control.FOCUS_ALL
		back_btn.pressed.connect(_on_back_pressed)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] BackButton focus enabled and signal connected")

func update_drill_results(score: int, hit_factor: float, fastest_shot: float, show_hit_factor: bool = true):
	"""Update the drill completion display with results"""
	var score_label = get_node_or_null("Background/CenterContainer/GridContainer/ScoreValue")
	var factor_label = get_node_or_null("Background/CenterContainer/GridContainer/FactorValue")
	var factor = get_node_or_null("Background/CenterContainer/GridContainer/Factor")
	var split_label = get_node_or_null("Background/CenterContainer/GridContainer/SplitValue")
	
	# Check if this is an IDPA drill
	var is_idpa = false
	var drill_manager = get_parent()
	if drill_manager:
		drill_manager = drill_manager.get_parent()
		if drill_manager and drill_manager.get_script():
			is_idpa = "idpa" in drill_manager.get_script().resource_path.to_lower()
	
	if score_label:
		score_label.text = "%d" % score
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated score: %d" % score)
	
	if factor_label:
		if show_hit_factor and not is_idpa:
			factor_label.text = "%.1f" % hit_factor
			factor_label.visible = true
			factor.visible = true
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Updated hit factor: %.2f" % hit_factor)
		else:
			factor_label.visible = false
			factor.visible = false
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Hit factor hidden")
	
	if split_label:
		split_label.text = "%.2fs" % fastest_shot
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated fastest shot: %.2fs" % fastest_shot)

func show_drill_complete(score: int = 0, hit_factor: float = 0.0, fastest_shot: float = 0.0, show_hit_factor: bool = true):
	"""Show the drill complete overlay with updated results"""
	# First make sure we're visible so the nodes are available
	visible = true
	
	# Setup for WebSocket UI click injection
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		# UI click injection is fed by websocket bullet_hit events, which are gated by bullet_spawning_enabled.
		ws_listener.set_bullet_spawning_enabled(true)
		ws_listener.set_emit_click_for_ui(true)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] WebSocket UI click injection enabled")
	
	# Update UI texts with current language (wait one frame to ensure visibility is processed)
	call_deferred("_update_ui_after_visible")
	
	# Update the results
	update_drill_results(score, hit_factor, fastest_shot, show_hit_factor)
	
	# Temporarily disable restart button during overlay startup
	# This function will also handle applying the final state based on auto-restart setting
	_disable_restart_button_temporarily()
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Drill complete overlay shown with results")

func show_drill_complete_with_timeout(score: int = 0, hit_factor: float = 0.0, fastest_shot: float = 0.0, timed_out: bool = false, show_hit_factor: bool = true):
	"""Show the drill complete overlay with timeout handling"""
	# First make sure we're visible so the nodes are available
	visible = true
	
	# Setup for WebSocket UI click injection
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		# UI click injection is fed by websocket bullet_hit events, which are gated by bullet_spawning_enabled.
		ws_listener.set_bullet_spawning_enabled(true)
		ws_listener.set_emit_click_for_ui(true)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] WebSocket UI click injection enabled")
	
	# Update UI texts with current language (wait one frame to ensure visibility is processed)
	call_deferred("_update_ui_after_visible_with_timeout", timed_out)
	
	# Update the results
	update_drill_results(score, hit_factor, fastest_shot, show_hit_factor)
	
	# Check auto restart setting and disable restart button if enabled
	_check_and_disable_restart_button()
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Drill complete overlay shown with timeout state: %s" % timed_out)

func _update_ui_after_visible_with_timeout(timed_out: bool):
	"""Update UI texts after the overlay becomes visible with timeout handling"""
	# Always reload language settings from GlobalData to catch any changes
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[DrillComplete] Reloaded language from GlobalData: ", language)
	
	# Update the UI texts with timeout consideration
	update_ui_texts_with_timeout(timed_out)

func update_ui_texts_with_timeout(timed_out: bool):
	"""Update UI texts with timeout consideration"""
	if not DEBUG_DISABLED:
		print("[DrillComplete] Updating UI texts with timeout state: ", timed_out)
		print("[DrillComplete] Current locale: ", TranslationServer.get_locale())
	
	# Get the title node
	var title = get_node_or_null("Background/Title")
	var restart_btn = get_node_or_null("Background/HBoxContainer/RestartButton")
	var replay_btn = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	if title:
		if timed_out:
			title.text = tr("timeout")
			title.modulate = Color.RED
		else:
			title.text = tr("complete")
			title.modulate = Color.WHITE
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated title to: ", title.text, " with color: ", title.modulate)
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] ERROR: title node not found")
	
	if restart_btn:
		restart_btn.text = tr("restart")
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated restart button to: ", restart_btn.text)
	
	if replay_btn:
		replay_btn.text = tr("replay")
		# Disable the replay button if drill timed out
		if timed_out:
			replay_btn.disabled = true
			replay_btn.modulate = Color.GRAY
			if not DEBUG_DISABLED:
				print("[DrillComplete] Disabled replay button and collision area due to timeout")
		else:
			replay_btn.disabled = false
			replay_btn.modulate = Color.WHITE
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated replay button to: ", replay_btn.text)

func _update_ui_after_visible():
	"""Update UI texts after the overlay becomes visible"""
	# Always reload language settings from GlobalData to catch any changes
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[DrillComplete] Reloaded language from GlobalData: ", language)
	
	# Then update the UI texts
	update_ui_texts()

func grab_restart_button_focus():
	"""Grab focus for the restart button, or replay button if restart is disabled"""
	var current_restart_button = get_node_or_null("Background/HBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	# Prefer restart button if it's enabled, otherwise use replay button
	if current_restart_button and not current_restart_button.disabled:
		current_restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] RestartButton focus grabbed")
	elif current_replay_button and not current_replay_button.disabled:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button disabled, focusing ReplayButton")
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] No available button to focus")

func handle_menu_control(directive: String):
	"""Handle menu control directives for menu navigation (called by parent IDPA script)"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Received control directive: ", directive)
	
	match directive:
		"right":
			_navigate_left()
		"left":
			_navigate_right()
		"enter":
			_activate_focused_button()
		_:
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Unknown directive: ", directive)

func _navigate_right():
	"""Navigate to previous button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var current_restart_button = get_node_or_null("Background/HBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	if focused_control == current_restart_button and current_replay_button:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated up to ReplayButton")
	elif focused_control == current_replay_button and current_restart_button:
		current_restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated up to RestartButton")

func _navigate_left():
	"""Navigate to next button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var current_restart_button = get_node_or_null("Background/HBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	if focused_control == current_restart_button and current_replay_button:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated down to ReplayButton")
	elif focused_control == current_replay_button and current_restart_button:
		current_restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated down to RestartButton")

func _on_global_settings_loaded():
	"""Handle when GlobalData settings are loaded/updated"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Settings loaded signal received")
	# Wait a frame to ensure everything is ready, then reload language settings
	call_deferred("load_language_from_global_settings")

func _activate_focused_button():
	"""Activate the currently focused button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var current_restart_button = get_node_or_null("Background/HBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("Background/HBoxContainer/ReplayButton")
	
	if focused_control == current_restart_button:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Activating RestartButton")
		_on_restart_pressed()
	elif focused_control == current_replay_button and not current_replay_button.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Activating ReplayButton")
		_on_replay_pressed()
	elif focused_control == current_replay_button and current_replay_button.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Replay button is disabled, defaulting to restart")
		_on_restart_pressed()
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] No button focused, defaulting to restart")
		_on_restart_pressed()

func _check_and_disable_restart_button():
	"""Check if auto restart is enabled and disable the restart button accordingly"""
	# Get auto restart setting from GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] GlobalData not found")
		return
	
	# Check if auto restart is enabled
	var auto_restart_enabled = global_data.settings_dict.get("auto_restart", false)
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Auto restart enabled: ", auto_restart_enabled)
	
	# Get the restart button
	var restart_btn = get_node_or_null("Background/HBoxContainer/RestartButton")
	if not restart_btn:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button not found")
		return
	
	if auto_restart_enabled:
		# Keep the restart button enabled but visually indicate auto restart mode
		restart_btn.disabled = false
		restart_btn.modulate = Color.LIGHT_GRAY  # Different color to show it's in auto mode
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button set to auto restart mode")
		
		# Update focus to the available button
		grab_restart_button_focus()
	else:
		# Stop any running countdown
		stop_countdown()
		
		# Ensure the restart button is enabled and normal
		restart_btn.disabled = false
		restart_btn.modulate = Color.WHITE
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button enabled in manual mode")

func _disable_restart_button_temporarily():
	"""Temporarily disable the restart button during overlay startup, then apply final auto-restart state"""
	var temp_restart_btn = get_node_or_null("Background/HBoxContainer/RestartButton")
	if temp_restart_btn:
		temp_restart_btn.disabled = true
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button temporarily disabled")
		
		# Re-enable after a short delay
		await get_tree().create_timer(0.5).timeout
		
		# After temp disable, apply the correct final state based on auto-restart setting
		var temp_global_data = get_node_or_null("/root/GlobalData")
		var temp_auto_restart_enabled = false
		if temp_global_data:
			temp_auto_restart_enabled = temp_global_data.settings_dict.get("auto_restart", false)
		
		if temp_auto_restart_enabled:
			# Auto restart mode: button enabled but visually different
			temp_restart_btn.disabled = false
			temp_restart_btn.modulate = Color.LIGHT_GRAY
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Restart button set to auto restart mode")
		else:
			# Manual mode: button fully enabled
			temp_restart_btn.disabled = false
			temp_restart_btn.modulate = Color.WHITE
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Restart button re-enabled in manual mode")
		
		# Update focus to the available button
		grab_restart_button_focus()
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button not found for temporary disable")

func start_countdown(total_seconds: int):
	"""Start countdown timer on the restart button"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Starting countdown: ", total_seconds, " seconds")
	
	# Initialize countdown
	countdown_seconds = total_seconds
	
	# Create and setup countdown timer if it doesn't exist
	if not countdown_timer:
		countdown_timer = Timer.new()
		countdown_timer.wait_time = 1.0
		countdown_timer.timeout.connect(_on_countdown_timeout)
		add_child(countdown_timer)
	
	# Update countdown label immediately and start timer
	_update_countdown_text()
	countdown_timer.start()

func _on_countdown_timeout():
	"""Handle countdown timer timeout"""
	countdown_seconds -= 1
	
	if countdown_seconds <= 0:
		# Countdown finished
		countdown_timer.stop()
		_restore_restart_button_text()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Countdown finished")
	else:
		# Update countdown display
		_update_countdown_text()

func _update_countdown_text():
	"""Update the countdown label with remaining seconds"""
	if countdown_label:
		countdown_label.text = str(countdown_seconds)
		countdown_label.visible = true
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated countdown text: ", countdown_label.text)

func _restore_restart_button_text():
	"""Hide the countdown label"""
	if countdown_label:
		countdown_label.visible = false
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Countdown label hidden")

func stop_countdown():
	"""Stop the countdown timer and restore button text"""
	if countdown_timer and countdown_timer.is_connected("timeout", _on_countdown_timeout):
		countdown_timer.stop()
	_restore_restart_button_text()
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Countdown stopped")
