extends Control

# Performance optimization
# NOTE: temporarily enable debug prints to diagnose overlay visibility issues
const DEBUG_DISABLED = false  # Set to true to silence verbose debugging

# Bullet system
@export var bullet_scene: PackedScene = preload("res://scene/bullet.tscn")

# Collision areas for bullet interactions
@onready var area_restart = $VBoxContainer/RestartButton/AreaRestart
@onready var area_replay = $VBoxContainer/ReviewReplayButton/AreaReplay

# UI elements for internationalization
@onready var title_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Title")
@onready var restart_button = get_node_or_null("VBoxContainer/RestartButton")
@onready var replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")

# Countdown timer variables
var countdown_timer: Timer = null
var countdown_seconds: int = 0
var original_restart_text: String = ""

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
	
	# Connect to WebSocket for bullet spawning
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		# NOTE: menu_control signal is now handled by parent IDPA script to avoid duplication
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Connected to WebSocketListener signals")
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] WebSocketListener singleton not found!")
	
	# Set up for mouse input processing - Control nodes need special setup
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Make sure we can receive input when visible
	set_process_input(true)
	set_process_unhandled_input(true)
	# Ensure we can intercept input events with high priority
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect collision area signals for bullet interactions
	setup_collision_areas()
	
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
	var title = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Title")
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	var replay_btn = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if title:
		title.text = tr("complete")
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated title to: ", title.text)
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] ERROR: title node not found at VBoxContainer/MarginContainer/VBoxContainer/Title")
	
	if restart_btn:
		restart_btn.text = tr("restart")
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated restart button to: ", restart_btn.text)
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] ERROR: restart button not found at VBoxContainer/RestartButton")
	
	if replay_btn:
		replay_btn.text = tr("replay")
		# Ensure replay button is enabled for normal completion
		replay_btn.disabled = false
		replay_btn.modulate = Color.WHITE
		# Re-enable the collision area for the replay button
		if area_replay:
			area_replay.monitoring = true
		if not DEBUG_DISABLED:
			print("[DrillComplete] Updated and enabled replay button: ", replay_btn.text)
	else:
		if not DEBUG_DISABLED:
			print("[DrillComplete] ERROR: replay button not found at VBoxContainer/ReviewReplayButton")

func _notification(what):
	"""Debug overlay visibility changes"""
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Visibility changed to: ", visible)
			print("[drill_complete_overlay] Size: ", size)
			print("[drill_complete_overlay] Position: ", position)
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

func setup_collision_areas():
	"""Setup collision detection for the restart and replay areas"""
	if area_restart:
		# Set collision properties for bullets
		area_restart.collision_layer = 7  # Target layer
		area_restart.collision_mask = 8   # Bullet layer
		area_restart.monitoring = true
		area_restart.monitorable = true
		#area_restart.area_entered.connect(_on_area_restart_hit)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] AreaRestart collision setup complete")
			print("[drill_complete_overlay] AreaRestart global position: ", area_restart.global_position)
			print("[drill_complete_overlay] AreaRestart collision_layer: ", area_restart.collision_layer)
			print("[drill_complete_overlay] AreaRestart collision_mask: ", area_restart.collision_mask)
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] AreaRestart not found!")
	
	if area_replay:
		# Set collision properties for bullets
		area_replay.collision_layer = 7  # Target layer
		area_replay.collision_mask = 8   # Bullet layer
		area_replay.monitoring = true
		area_replay.monitorable = true
		area_replay.area_entered.connect(_on_area_replay_hit)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] AreaReplay collision setup complete")
			print("[drill_complete_overlay] AreaReplay global position: ", area_replay.global_position)
			print("[drill_complete_overlay] AreaReplay collision_layer: ", area_replay.collision_layer)
			print("[drill_complete_overlay] AreaReplay collision_mask: ", area_replay.collision_mask)
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] AreaReplay not found!")

func _input(event):
	"""Handle mouse clicks for bullet spawning"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any input event
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] _input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Mouse click detected via _input")
		_handle_mouse_click(event)
		# Mark the event as handled to prevent parent nodes from processing it
		get_viewport().set_input_as_handled()
		return

func _unhandled_input(event):
	"""Handle mouse clicks for bullet spawning - backup method for Control nodes"""
	# Only process input when this overlay is visible
	if not visible:
		return
	
	# Debug: Log any unhandled input event
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] _unhandled_input received event: ", event)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Mouse click detected via _unhandled_input")
		_handle_mouse_click(event)
		# Accept the event to prevent further processing
		get_viewport().set_input_as_handled()

func _handle_mouse_click(_event):
	"""Process the mouse click for bullet spawning"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Processing mouse click")
	
	# Check if bullet spawning is enabled through WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] WebSocketListener found, bullet_spawning_enabled: ", ws_listener.bullet_spawning_enabled)
		if not ws_listener.bullet_spawning_enabled:
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Bullet spawning disabled")
			return
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] WebSocketListener not found!")
		return
		
	var world_pos = get_global_mouse_position()
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Spawning bullet at: ", world_pos)
	spawn_bullet_at_position(world_pos)

func _on_websocket_bullet_hit(hit_position: Vector2, a: int = 0, t: int = 0):
	"""Handle bullet hit from WebSocket data"""
	# Only process websocket bullets when this overlay is visible
	if not visible:
		return
		
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] WebSocket bullet hit at: ", hit_position)
	spawn_bullet_at_position(hit_position)

func spawn_bullet_at_position(world_pos: Vector2):
	"""Spawn a bullet at the specified world position"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Spawning bullet at world position: ", world_pos)
		print("[drill_complete_overlay] Overlay global_position: ", global_position)
		print("[drill_complete_overlay] Overlay size: ", size)
		if area_restart:
			print("[drill_complete_overlay] AreaRestart global_position: ", area_restart.global_position)
		if area_replay:
			print("[drill_complete_overlay] AreaReplay global_position: ", area_replay.global_position)
	
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		
		# Add the bullet to the scene root to avoid Control node hierarchy issues
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)
		else:
			add_child(bullet)
		
		# Set the bullet's spawn position
		if bullet.has_method("set_spawn_position"):
			bullet.set_spawn_position(world_pos)
		else:
			bullet.global_position = world_pos
		
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Bullet spawned successfully")
			print("[drill_complete_overlay] Bullet global_position: ", bullet.global_position)
			print("[drill_complete_overlay] Bullet collision_layer: ", bullet.collision_layer)
			print("[drill_complete_overlay] Bullet collision_mask: ", bullet.collision_mask)
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] ERROR: No bullet scene loaded!")

func _on_area_restart_hit(area: Area2D):
	"""Handle bullet collision with restart area"""
	# Check restart cooldown to prevent rapid successive restarts
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_restart_time) < restart_cooldown:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart cooldown active (%.2fs remaining), ignoring hit" % (restart_cooldown - (current_time - last_restart_time)))
		return
	
	# Check if restart button is disabled (auto restart enabled)
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if restart_btn and restart_btn.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button is disabled (auto restart enabled), ignoring hit")
		return
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Bullet hit AreaRestart - restarting drill")
		if area:
			print("[drill_complete_overlay] Hit by area: ", area.name, " at position: ", area.global_position)
		else:
			print("[drill_complete_overlay] Hit triggered without area (likely WebSocket control)")
	
	# Update last restart time
	last_restart_time = current_time
	
	# Stop countdown if running
	stop_countdown()
	
	# Hide the completion overlay
	visible = false
	
	# Re-enable bullet spawning now that overlay is hidden
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Bullet spawning re-enabled after overlay hidden")
	
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

func _on_area_replay_hit(area: Area2D):
	"""Handle bullet collision with replay area"""
	# Check restart cooldown to prevent rapid successive actions (reuse same cooldown)
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - last_restart_time) < restart_cooldown:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Action cooldown active (%.2fs remaining), ignoring replay hit" % (restart_cooldown - (current_time - last_restart_time)))
		return
	
	var replay_btn = get_node_or_null("VBoxContainer/ReviewReplayButton")
	if replay_btn and replay_btn.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Replay button is disabled, ignoring hit")
		return
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Bullet hit AreaReplay - navigating to drill replay")
		if area:
			print("[drill_complete_overlay] Hit by area: ", area.name, " at position: ", area.global_position)
		else:
			print("[drill_complete_overlay] Hit triggered without area (likely WebSocket control)")
	
	# Update last action time
	last_restart_time = current_time
	
	# Navigate to the drill replay scene
	get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func setup_button_focus():
	"""Set up button focus management"""
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	var replay_btn = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if restart_btn:
		restart_btn.focus_mode = Control.FOCUS_ALL
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] RestartButton focus enabled")
	
	if replay_btn:
		replay_btn.focus_mode = Control.FOCUS_ALL
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] ReviewReplayButton focus enabled")

func update_drill_results(score: int, hit_factor: float, fastest_shot: float, show_hit_factor: bool = true):
	"""Update the drill completion display with results"""
	var score_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
	var hf_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
	var fastest_label = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
	
	# Check if this is an IDPA drill
	var is_idpa = false
	var drill_manager = get_parent()
	if drill_manager:
		drill_manager = drill_manager.get_parent()
		if drill_manager and drill_manager.get_script():
			is_idpa = "idpa" in drill_manager.get_script().resource_path.to_lower()
	
	if score_label:
		var score_key = "points_down" if is_idpa else "score"
		score_label.text = tr(score_key) + ": %d" % score
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated score with key '%s': %d" % [score_key, score])
	
	if hf_label:
		if show_hit_factor:
			hf_label.text = tr("hit_factor") + ": %.1f" % hit_factor
			hf_label.visible = true
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Updated hit factor: %.2f" % hit_factor)
		else:
			hf_label.visible = false
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Hit factor hidden")
	
	if fastest_label:
		fastest_label.text = tr("fastest_shot") + ": %.2fs" % fastest_shot
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated fastest shot: %.2fs" % fastest_shot)

func show_drill_complete(score: int = 0, hit_factor: float = 0.0, fastest_shot: float = 0.0, show_hit_factor: bool = true):
	"""Show the drill complete overlay with updated results"""
	# First make sure we're visible so the nodes are available
	visible = true
	
	# Disable bullet spawning to prevent unwanted hits during overlay display
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(false)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Bullet spawning disabled during overlay display")
	
	# Re-setup collision areas to ensure they're properly positioned
	call_deferred("setup_collision_areas")
	
	# Update UI texts with current language (wait one frame to ensure visibility is processed)
	call_deferred("_update_ui_after_visible")
	
	# Update the results
	update_drill_results(score, hit_factor, fastest_shot, show_hit_factor)
	
	# Temporarily disable restart button to prevent accidental restarts from stray bullets
	_disable_restart_button_temporarily()
	
	# Check auto restart setting and disable restart button if enabled
	_check_and_disable_restart_button()
	
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Drill complete overlay shown with results")

func show_drill_complete_with_timeout(score: int = 0, hit_factor: float = 0.0, fastest_shot: float = 0.0, timed_out: bool = false, show_hit_factor: bool = true):
	"""Show the drill complete overlay with timeout handling"""
	# First make sure we're visible so the nodes are available
	visible = true
	
	# Re-setup collision areas to ensure they're properly positioned
	call_deferred("setup_collision_areas")
	
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
	var title = get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Title")
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	var replay_btn = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
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
			# Also disable the collision area for the replay button
			if area_replay:
				area_replay.monitoring = false
			if not DEBUG_DISABLED:
				print("[DrillComplete] Disabled replay button and collision area due to timeout")
		else:
			replay_btn.disabled = false
			replay_btn.modulate = Color.WHITE
			# Re-enable the collision area for the replay button
			if area_replay:
				area_replay.monitoring = true
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
	var current_restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	# Prefer restart button if it's enabled, otherwise use replay button
	if current_restart_button and not current_restart_button.disabled:
		current_restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] RestartButton focus grabbed")
	elif current_replay_button and not current_replay_button.disabled:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button disabled, focusing ReviewReplayButton")
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] No available button to focus")

func handle_menu_control(directive: String):
	"""Handle menu control directives for menu navigation (called by parent IDPA script)"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Received control directive: ", directive)
	
	match directive:
		"up":
			_navigate_up()
		"down":
			_navigate_down()
		"enter":
			_activate_focused_button()
		_:
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Unknown directive: ", directive)

func _navigate_up():
	"""Navigate to previous button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var current_restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == current_restart_button and current_replay_button:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated up to ReviewReplayButton")
	elif focused_control == current_replay_button and current_restart_button:
		current_restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated up to RestartButton")

func _navigate_down():
	"""Navigate to next button"""
	var focused_control = get_viewport().gui_get_focus_owner()
	var current_restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == current_restart_button and current_replay_button:
		current_replay_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Navigated down to ReviewReplayButton")
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
	var current_restart_button = get_node_or_null("VBoxContainer/RestartButton")
	var current_replay_button = get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if focused_control == current_restart_button:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Activating RestartButton via WebSocket")
		_on_area_restart_hit(null)  # Trigger restart action
	elif focused_control == current_replay_button and not current_replay_button.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Activating ReviewReplayButton via WebSocket")
		_on_area_replay_hit(null)  # Trigger replay action
	elif focused_control == current_replay_button and current_replay_button.disabled:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Replay button is disabled, defaulting to restart")
		_on_area_restart_hit(null)  # Default to restart
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] No button focused, defaulting to restart")
		_on_area_restart_hit(null)  # Default to restart

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
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if not restart_btn:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button not found")
		return
	
	if auto_restart_enabled:
		# Store original text before modifying
		if original_restart_text == "":
			original_restart_text = restart_btn.text
		
		# Keep the restart button enabled but visually indicate auto restart mode
		restart_btn.disabled = false
		restart_btn.modulate = Color.LIGHT_GRAY  # Different color to show it's in auto mode
		# Keep the collision area enabled for potential bullet interactions
		if area_restart:
			area_restart.monitoring = true
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
		# Re-enable the collision area for the restart button
		if area_restart:
			area_restart.monitoring = true
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button enabled in manual mode")

func _disable_restart_button_temporarily():
	"""Temporarily disable the restart button to prevent accidental restarts from stray bullets"""
	var temp_restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if temp_restart_btn:
		temp_restart_btn.disabled = true
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button temporarily disabled")
		
		# Re-enable after a short delay
		await get_tree().create_timer(0.5).timeout
		
		# Only re-enable if not in auto-restart mode
		var temp_global_data = get_node_or_null("/root/GlobalData")
		var temp_auto_restart_enabled = false
		if temp_global_data:
			temp_auto_restart_enabled = temp_global_data.settings_dict.get("auto_restart", false)
		
		if not temp_auto_restart_enabled:
			temp_restart_btn.disabled = false
			if not DEBUG_DISABLED:
				print("[drill_complete_overlay] Restart button re-enabled")
	else:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button not found for temporary disable")

func start_countdown(total_seconds: int):
	"""Start countdown timer on the restart button"""
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Starting countdown: ", total_seconds, " seconds")
	
	# Get the restart button
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if not restart_btn:
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restart button not found for countdown")
		return
	
	# Store original text if not already stored
	if original_restart_text == "":
		original_restart_text = restart_btn.text
	
	# Initialize countdown
	countdown_seconds = total_seconds
	
	# Create and setup countdown timer if it doesn't exist
	if not countdown_timer:
		countdown_timer = Timer.new()
		countdown_timer.wait_time = 1.0
		countdown_timer.timeout.connect(_on_countdown_timeout)
		add_child(countdown_timer)
	
	# Update button text immediately and start timer
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
	"""Update the restart button text with countdown"""
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if restart_btn:
		restart_btn.text = tr("auto_restart_in") + str(countdown_seconds)
		# Make countdown text more visible with larger font and red color
		restart_btn.add_theme_font_size_override("font_size", 48)
		restart_btn.add_theme_color_override("font_color", Color.RED)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Updated countdown text: ", restart_btn.text)

func _restore_restart_button_text():
	"""Restore the original restart button text"""
	var restart_btn = get_node_or_null("VBoxContainer/RestartButton")
	if restart_btn and original_restart_text != "":
		restart_btn.text = original_restart_text
		# Restore original font size and color
		restart_btn.add_theme_font_size_override("font_size", 36)
		restart_btn.add_theme_color_override("font_color", Color.WHITE)
		if not DEBUG_DISABLED:
			print("[drill_complete_overlay] Restored restart button text: ", restart_btn.text)

func stop_countdown():
	"""Stop the countdown timer and restore button text"""
	if countdown_timer and countdown_timer.is_connected("timeout", _on_countdown_timeout):
		countdown_timer.stop()
	_restore_restart_button_text()
	if not DEBUG_DISABLED:
		print("[drill_complete_overlay] Countdown stopped")
