extends Control

# Performance optimization
# NOTE: temporarily enable debug prints to diagnose overlay visibility issues
const DEBUG_DISABLED = true  # Set to true to silence verbose debugging

# Timeout warning state
var timeout_warning_active: bool = false

# Drill type tracking
var is_idpa_drill: bool = false

# UI Node references
@onready var target_type_title = $TopContainer/TopLayout/HeaderContainer/TargetTypeTitle
@onready var shot_timer_overlay = $ShotTimerOverlay
@onready var drill_complete_overlay = $drill_complete_overlay
@onready var fastest_interval_label = $TopContainer/TopLayout/HeaderContainer/FastestContainer/FastestInterval
@onready var timer_label = $TopContainer/TopLayout/TimerContainer/Timer
@onready var score_label = $TopContainer/TopLayout/HeaderContainer/ScoreContainer/Score
@onready var progress_bar = $TopContainer/TopLayout/ProgressBarContainer/CustomProgressBar

func _ready():
	"""Initialize the drill UI"""
	if not DEBUG_DISABLED:
		print("=== DRILL UI INITIALIZED ===")
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Load drill sequence setting from global settings
	load_drill_sequence_from_global_settings()
	
	# Connect to the parent drills manager signals
	var drills_manager = get_parent()
	if not DEBUG_DISABLED:
		print("[DrillUI._ready()] drills_manager: ", drills_manager)
		print("[DrillUI._ready()] drills_manager script: ", drills_manager.get_script() if drills_manager else "N/A")
	if drills_manager:
		# Detect if this is an IDPA or IPSC drill
		var script_path = drills_manager.get_script().resource_path
		is_idpa_drill = "idpa" in script_path.to_lower()
		if not DEBUG_DISABLED:
			print("[DrillUI] Detected drill type - IDPA: ", is_idpa_drill, " (script: ", script_path, ")")
		
		# Configure progress bar based on drill type
		if progress_bar:
			if is_idpa_drill:
				# Reduced IDPA mini drill sequence to 4 targets -> update progress bar
				progress_bar.total_targets = 4
				progress_bar.segments_per_target = PackedInt32Array([4, 4, 4, 3])
			# Add other configurations if needed
		if drills_manager.has_signal("ui_show_completion"):
			drills_manager.ui_show_completion.connect(_on_show_completion)
		if drills_manager.has_signal("ui_timer_update"):
			drills_manager.ui_timer_update.connect(_on_timer_update)
		if drills_manager.has_signal("ui_target_title_update"):
			drills_manager.ui_target_title_update.connect(_on_target_title_update)
		if drills_manager.has_signal("ui_fastest_time_update"):
			drills_manager.ui_fastest_time_update.connect(_on_fastest_time_update)
		if drills_manager.has_signal("ui_show_completion_with_timeout"):
			drills_manager.ui_show_completion_with_timeout.connect(_on_show_completion_with_timeout)
		if drills_manager.has_signal("ui_hide_completion"):
			drills_manager.ui_hide_completion.connect(_on_hide_completion)
		if drills_manager.has_signal("ui_timeout_warning"):
			drills_manager.ui_timeout_warning.connect(_on_timeout_warning)
		if drills_manager.has_signal("ui_score_update"):
			drills_manager.ui_score_update.connect(_on_score_update)
		if drills_manager.has_signal("ui_show_shot_timer"):
			drills_manager.ui_show_shot_timer.connect(_on_show_shot_timer)
		if drills_manager.has_signal("ui_hide_shot_timer"):
			drills_manager.ui_hide_shot_timer.connect(_on_hide_shot_timer)
		if drills_manager.has_signal("ui_progress_update"):
			drills_manager.ui_progress_update.connect(_on_progress_update)
		
		if not DEBUG_DISABLED:
			print("[DrillUI] Connected to drills manager UI signals")

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[DrillUI] Loaded language from GlobalData: ", language)
	else:
		if not DEBUG_DISABLED:
			print("[DrillUI] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

func load_drill_sequence_from_global_settings():
	# Read drill sequence setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("drill_sequence"):
		var drill_sequence = global_data.settings_dict.get("drill_sequence", "Fixed")
		if not DEBUG_DISABLED:
			print("[DrillUI] Loaded drill_sequence from GlobalData: ", drill_sequence)
		return drill_sequence
	else:
		if not DEBUG_DISABLED:
			print("[DrillUI] GlobalData not found or no drill_sequence setting, using default Fixed")
		return "Fixed"

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
		print("[DrillUI] Set locale to: ", locale)

func _on_timer_update(time_elapsed: float):
	"""Update the timer display with the current elapsed time"""
	var total_seconds = int(time_elapsed)
	var minutes = int(total_seconds / 60.0)
	var seconds = total_seconds % 60
	var milliseconds = int((time_elapsed - total_seconds) * 100)
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	timer_label.text = time_string
	
	# Change color to red if timeout warning is active
	if timeout_warning_active:
		timer_label.modulate = Color.RED
	else:
		timer_label.modulate = Color.WHITE

func _on_timeout_warning(remaining_seconds: float):
	"""Handle timeout warning - show red timer"""
	timeout_warning_active = true
	if not DEBUG_DISABLED:
		print("[DrillUI] Timeout warning activated - %.1f seconds remaining" % remaining_seconds)

func _on_target_title_update(target_index: int, total_targets: int):
	"""Update the target title based on the current target number"""
	var target_number = target_index + 1
	target_type_title.text = tr("target") + " " + str(target_number) + "/" + str(total_targets)
	if not DEBUG_DISABLED:
		print("Updated title to: ", tr("target"), " ", target_number, "/", total_targets)

func _on_fastest_time_update(fastest_time: float):
	"""Update the fastest interval label with the current fastest time"""
	if fastest_time < 999.0:  # Only update if we have a valid time
		fastest_interval_label.text = "%.2fs" % fastest_time
	else:
		fastest_interval_label.text = "--"

func _on_score_update(score: int):
	"""Update the score display"""
	# For IPSC, just show the score number
	score_label.text = str(score)

func _on_progress_update(targets_completed: int):
	"""Update the progress bar based on targets completed"""
	if progress_bar and progress_bar.has_method("update_progress"):
		progress_bar.update_progress(targets_completed)
	else:
		if not DEBUG_DISABLED:
			print("Warning: Progress bar not found or missing update_progress method")

func _on_show_completion(final_time: float, fastest_time: float, final_score: int, show_hit_factor: bool = true):
	"""Show the completion overlay with drill statistics"""
	if not DEBUG_DISABLED:
		print("=== _on_show_completion CALLED ===")
		print("final_time: ", final_time, ", fastest_time: ", fastest_time, ", final_score: ", final_score, ", show_hit_factor: ", show_hit_factor)
		print("drill_complete_overlay node: ", drill_complete_overlay)
		print("drill_complete_overlay visible before: ", drill_complete_overlay.visible)
	
	# Prefer the final score passed by the drills manager (stage).
	# Fall back to the performance tracker only if the final_score is 0 or unavailable.
	var actual_total_score = final_score
	var drills_manager = get_parent()
	if (actual_total_score == 0) and drills_manager and drills_manager.has_method("get_performance_tracker"):
		var tracker = drills_manager.get_performance_tracker()
		if tracker and tracker.has_method("get_current_total_score"):
			actual_total_score = tracker.get_current_total_score()
			if not DEBUG_DISABLED:
				print("Fell back to performance tracker total score: ", actual_total_score)
		else:
			if not DEBUG_DISABLED:
				print("Performance tracker not available, using final_score: ", final_score)
	
	# Calculate hit factor using the consistent total score
	var hit_factor = 0.0
	if final_time > 0:
		hit_factor = actual_total_score / final_time
	
	# Check if the overlay has its script properly attached
	if drill_complete_overlay.get_script() == null:
		if not DEBUG_DISABLED:
			print("[drill_ui] Script missing from drill_complete_overlay, attempting to reattach")
		var script_path = "res://script/drill_complete_overlay.gd"
		var script = load(script_path)
		if script:
			drill_complete_overlay.set_script(script)
			if not DEBUG_DISABLED:
				print("[drill_ui] Script reattached successfully")
		else:
			if not DEBUG_DISABLED:
				print("[drill_ui] Failed to load drill_complete_overlay script")
	else:
		if not DEBUG_DISABLED:
			print("[drill_ui] Overlay script is properly attached")
	
	# Try to use the new method if available
	if drill_complete_overlay.has_method("show_drill_complete"):
		if not DEBUG_DISABLED:
			print("[drill_ui] Calling show_drill_complete method")
		drill_complete_overlay.show_drill_complete(actual_total_score, hit_factor, fastest_time, show_hit_factor)
		if not DEBUG_DISABLED:
			print("Updated drill complete overlay with: score=%d, hit_factor=%.2f, fastest=%.2f, show_hit_factor=%s" % [actual_total_score, hit_factor, fastest_time, show_hit_factor])
			print("drill_complete_overlay visible after show_drill_complete: ", drill_complete_overlay.visible)
	else:
		# Fallback to manual update
		if not DEBUG_DISABLED:
			print("[drill_ui] Using fallback method to update overlay")
		
		# Update individual labels
		var completion_score_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
		var hf_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
		
		if completion_score_label:
			completion_score_label.text = "Score: %d points" % actual_total_score
		if hf_label:
			hf_label.text = "Hit Factor: %.1f" % hit_factor
		if fastest_shot_label:
			var fastest_string = "%.2fs" % fastest_time if fastest_time < 999.0 else "--"
			fastest_shot_label.text = "Fastest Shot: " + fastest_string
		
		if not DEBUG_DISABLED:
			print("[drill_ui] Setting overlay visible = true")
		drill_complete_overlay.visible = true
	
	# Connect button signals and set up focus
	connect_completion_overlay_buttons()
	setup_overlay_focus()
	
	# Reset timeout warning state and timer color
	timeout_warning_active = false
	timer_label.modulate = Color.WHITE
	
	if not DEBUG_DISABLED:
		print("=== _on_show_completion FINISHED ===")
		print("drill_complete_overlay visible final: ", drill_complete_overlay.visible)
		print("drill_complete_overlay size final: ", drill_complete_overlay.size)

func _on_show_completion_with_timeout(final_time: float, fastest_time: float, final_score: int, timed_out: bool, _show_hit_factor: bool):
	"""Show the completion overlay with timeout message"""
	if not DEBUG_DISABLED:
		print("Showing completion overlay with timeout")
	
	# Prefer the final score passed by the drills manager (stage).
	# Fall back to the performance tracker only if the final_score is 0 or unavailable.
	var actual_total_score = final_score
	var drills_manager = get_parent()
	if (actual_total_score == 0) and drills_manager and drills_manager.has_method("get_performance_tracker"):
		var tracker = drills_manager.get_performance_tracker()
		if tracker and tracker.has_method("get_current_total_score"):
			actual_total_score = tracker.get_current_total_score()
			if not DEBUG_DISABLED:
				print("Fell back to performance tracker total score: ", actual_total_score)
		else:
			if not DEBUG_DISABLED:
				print("Performance tracker not available, using final_score: ", final_score)
	
	# Calculate hit factor using the consistent total score
	var hit_factor = 0.0
	if final_time > 0:
		hit_factor = actual_total_score / final_time
	
	# Check if the overlay has its script properly attached
	if drill_complete_overlay.get_script() == null:
		if not DEBUG_DISABLED:
			print("[drill_ui] Script missing from drill_complete_overlay, attempting to reattach")
		var script_path = "res://script/drill_complete_overlay.gd"
		var script = load(script_path)
		if script:
			drill_complete_overlay.set_script(script)
			if not DEBUG_DISABLED:
				print("[drill_ui] Script reattached successfully")
		else:
			if not DEBUG_DISABLED:
				print("[drill_ui] Failed to load drill_complete_overlay script")
	
	# Try to use the new method if available
	if drill_complete_overlay.has_method("show_drill_complete_with_timeout"):
		drill_complete_overlay.show_drill_complete_with_timeout(final_score, hit_factor, fastest_time, timed_out, _show_hit_factor)
		if not DEBUG_DISABLED:
			print("Updated drill complete overlay with timeout: score=%d, hit_factor=%.2f, fastest=%.2f, timed_out=%s, show_hit_factor=%s" % [final_score, hit_factor, fastest_time, timed_out, _show_hit_factor])
	else:
		# Fallback to manual update with timeout handling
		if not DEBUG_DISABLED:
			print("[drill_ui] Using fallback method to update overlay with timeout")
		
		# Update individual labels
		var title_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Title")
		var completion_score_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/Score")
		var hf_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/HitFactor")
		var fastest_shot_label = drill_complete_overlay.get_node_or_null("VBoxContainer/MarginContainer/VBoxContainer/FastestShot")
		
		# Set timeout title in red
		if title_label and timed_out:
			title_label.text = "TIMEOUT!"
			title_label.modulate = Color.RED
		elif title_label:
			title_label.text = "Drill Completed"
			title_label.modulate = Color.WHITE
		
		if completion_score_label:
			completion_score_label.text = "Score: %d points" % actual_total_score
		if hf_label:
			hf_label.text = "Hit Factor: %.1f" % hit_factor
		if fastest_shot_label:
			var fastest_string = "%.2fs" % fastest_time if fastest_time < 999.0 else "--"
			fastest_shot_label.text = "Fastest Shot: " + fastest_string
		
		drill_complete_overlay.visible = true
	
	# Connect button signals and set up focus
	connect_completion_overlay_buttons()
	setup_overlay_focus()
	
	# Reset timeout warning state and timer color
	timeout_warning_active = false
	timer_label.modulate = Color.WHITE

func connect_completion_overlay_buttons():
	"""Connect the completion overlay button signals"""
	var restart_button = drill_complete_overlay.get_node("VBoxContainer/RestartButton")
	var review_replay_button = drill_complete_overlay.get_node("VBoxContainer/ReviewReplayButton")
	
	if restart_button:
		# Disconnect any existing connections to avoid duplicates
		if restart_button.pressed.is_connected(_on_restart_button_pressed):
			restart_button.pressed.disconnect(_on_restart_button_pressed)
		restart_button.pressed.connect(_on_restart_button_pressed)
		if not DEBUG_DISABLED:
			print("Connected restart button signal")
	
	if review_replay_button:
		# Disconnect any existing connections to avoid duplicates
		if review_replay_button.pressed.is_connected(_on_review_replay_button_pressed):
			review_replay_button.pressed.disconnect(_on_review_replay_button_pressed)
		review_replay_button.pressed.connect(_on_review_replay_button_pressed)
		if not DEBUG_DISABLED:
			print("Connected review replay button signal")

func _on_restart_button_pressed():
	"""Handle restart button click - restart the drill"""
	if not DEBUG_DISABLED:
		print("Restart button pressed - restarting drill")
	
	# Reset timeout warning state
	timeout_warning_active = false
	
	# Reset timer color back to white
	timer_label.modulate = Color.WHITE
	
	# Hide the completion overlay
	drill_complete_overlay.visible = false
	
	# Call restart drill on the parent drills manager
	var drills_manager = get_parent()
	if drills_manager and drills_manager.has_method("restart_drill"):
		drills_manager.restart_drill()
	else:
		if not DEBUG_DISABLED:
			print("Warning: Could not find drills manager or restart_drill method")

func _on_review_replay_button_pressed():
	"""Handle review and replay button click - navigate to drill replay scene"""
	if not DEBUG_DISABLED:
		print("Review and replay button pressed - navigating to drill replay")
	
	# Navigate to the drill replay scene
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")
	else:
		if not DEBUG_DISABLED:
			print("Warning: Node not in tree, cannot change scene")

func _on_show_shot_timer():
	"""Show the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== DRILL_UI: Received ui_show_shot_timer signal ===")
		print("DEBUG: shot_timer_overlay node: ", shot_timer_overlay)
	shot_timer_overlay.visible = true
	
	# The shot_timer_overlay IS the shot timer, so call its methods directly
	if not DEBUG_DISABLED:
		print("DEBUG: Calling start_timer_sequence() on shot_timer_overlay")
	shot_timer_overlay.start_timer_sequence()
	if not DEBUG_DISABLED:
		print("[DrillUI] Started shot timer sequence")

	# Hide the completion overlay if visible
	drill_complete_overlay.visible = false

func _on_hide_shot_timer():
	"""Hide the shot timer overlay"""
	if not DEBUG_DISABLED:
		print("=== HIDING SHOT TIMER OVERLAY ===")
	shot_timer_overlay.visible = false
	
	# The shot_timer_overlay IS the shot timer, so call its methods directly
	if shot_timer_overlay.has_method("reset_timer"):
		shot_timer_overlay.reset_timer()
		if not DEBUG_DISABLED:
			print("[DrillUI] Reset shot timer")
	else:
		if not DEBUG_DISABLED:
			print("[DrillUI] Warning: Shot timer overlay missing reset_timer method")

func setup_overlay_focus():
	"""Set up focus for the overlay buttons"""
	var restart_button = drill_complete_overlay.get_node_or_null("VBoxContainer/RestartButton")
	var replay_button = drill_complete_overlay.get_node_or_null("VBoxContainer/ReviewReplayButton")
	
	if restart_button:
		restart_button.focus_mode = Control.FOCUS_ALL
		restart_button.grab_focus()
		if not DEBUG_DISABLED:
			print("[drill_ui] Set up focus for restart button")
	
	if replay_button:
		replay_button.focus_mode = Control.FOCUS_ALL
		if not DEBUG_DISABLED:
			print("[drill_ui] Set up focus for replay button")

func _on_hide_completion():
	"""Hide the completion overlay"""
	if not DEBUG_DISABLED:
		print("[DrillUI] Hiding completion overlay")
	
	if drill_complete_overlay:
		drill_complete_overlay.visible = false
