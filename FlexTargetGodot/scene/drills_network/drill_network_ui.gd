extends Control

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# Timeout warning state
var timeout_warning_active: bool = false

# UI Node references
@onready var target_name = $TopContainer/TopLayout/HeaderContainer/TargetName
@onready var fps_label = $FPSLabel
@onready var shot_timer_overlay = $ShotTimerOverlay
@onready var fastest_interval_label = $TopContainer/TopLayout/HeaderContainer/FastestContainer/FastestInterval
@onready var timer_label = $TopContainer/TopLayout/TimerContainer/Timer
@onready var timer_container = $TopContainer/TopLayout/TimerContainer
@onready var score_label = $TopContainer/TopLayout/HeaderContainer/ScoreContainer/Score

# Fastest time tracking
var fastest_time_diff: float = 999.0

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
	if drills_manager:
		# Connect UI update signals
		if drills_manager.has_signal("ui_timer_update"):
			drills_manager.ui_timer_update.connect(_on_timer_update)
		if drills_manager.has_signal("ui_timer_stopped"):
			drills_manager.ui_timer_stopped.connect(_on_timer_stopped)
		if drills_manager.has_signal("ui_target_name_update"):
			drills_manager.ui_target_name_update.connect(_on_target_name_update)
		if drills_manager.has_signal("ui_fastest_time_update"):
			drills_manager.ui_fastest_time_update.connect(_on_fastest_time_update)
		if drills_manager.has_signal("ui_score_update"):
			drills_manager.ui_score_update.connect(_on_score_update)
		if drills_manager.has_signal("ui_show_shot_timer"):
			drills_manager.ui_show_shot_timer.connect(_on_show_shot_timer)
		if drills_manager.has_signal("ui_hide_shot_timer"):
			drills_manager.ui_hide_shot_timer.connect(_on_hide_shot_timer)
		if drills_manager.has_signal("ui_mode_update"):
			drills_manager.ui_mode_update.connect(_on_mode_update)
		
		if not DEBUG_DISABLED:
			print("[DrillUI] Connected to drills manager UI signals")
	
	# Timer is hidden by default until mode is determined
	timer_container.visible = false

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
	var minutes = int(time_elapsed / 60)
	var seconds = int(time_elapsed) % 60
	var milliseconds = int((time_elapsed - int(time_elapsed)) * 100)
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
	timer_label.text = time_string
	
	# Change color to red if timeout warning is active
	if timeout_warning_active:
		timer_label.modulate = Color.RED
	else:
		timer_label.modulate = Color.WHITE

func _on_timer_stopped(final_time: float):
	"""Handle timer stopped - round milliseconds to one decimal place (nearest 10ms)"""
	var minutes = int(final_time / 60)
	var seconds = int(final_time) % 60
	var centiseconds = int((final_time - int(final_time)) * 100)  # 0-99
		
	# Round centiseconds to nearest 10 (one decimal place)
	# 0-4 → 0, 5-14 → 10, 15-24 → 20, etc.
	var rounded_centiseconds = int(round(centiseconds / 10.0)) * 10
		
	# Handle overflow: if rounded >= 100, increment seconds
	if rounded_centiseconds >= 100:
		rounded_centiseconds = 0
		seconds += 1
		if seconds >= 60:
			seconds = 0
			minutes += 1
	
	var time_string = "%02d:%02d:%02d" % [minutes, seconds, rounded_centiseconds]
	timer_label.text = time_string

func _on_timeout_warning(remaining_seconds: float):
	"""Handle timeout warning - show red timer"""
	timeout_warning_active = true
	if not DEBUG_DISABLED:
		print("[DrillUI] Timeout warning activated - %.1f seconds remaining" % remaining_seconds)

func _process(_delta):
	"""Update FPS counter every frame"""
	var fps = Engine.get_frames_per_second()
	fps_label.text = tr("fps_display") + str(fps)

func _on_target_title_update(target_index: int, total_targets: int):
	"""Update the target title based on the current target number"""
	var target_number = target_index + 1
	target_name.text = tr("target") + " " + str(target_number) + "/" + str(total_targets)
	if not DEBUG_DISABLED:
		print("Updated title to: ", tr("target"), " ", target_number, "/", total_targets)

func _on_target_name_update(target_name_text: String):
	"""Update the target name display"""
	target_name.text = target_name_text
	if not DEBUG_DISABLED:
		print("Updated target name to: ", target_name_text)

func _on_fastest_time_update(fastest_time: float):
	"""Update the fastest interval label with the current fastest time"""
	fastest_time_diff = fastest_time
	if fastest_time < 999.0:  # Only update if we have a valid time
		fastest_interval_label.text = "%.2fs" % fastest_time
	else:
		fastest_interval_label.text = "--"

func _on_score_update(score: int):
	"""Update the score display"""
	score_label.text = str(score)

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

func _on_mode_update(is_first: bool):
	"""Update timer visibility based on master/slave mode"""
	timer_container.visible = is_first
	if not DEBUG_DISABLED:
		print("[DrillUI] Timer visibility set to: ", is_first)
