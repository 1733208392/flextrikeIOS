extends Control

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# Shot timer states
enum TimerState {
	WAITING,    # Waiting for user to start
	STANDBY,    # Showing "STANDBY" text
	READY       # After beep, ready to shoot
}

# Node references
@onready var standby_label = $CenterContainer/StandbyLabel
@onready var standby_player = $StandbyPlayer
@onready var ready_player = $ReadyPlayer
@onready var beep_player = $BeepPlayer
@onready var animation_player = $AnimationPlayer
@onready var timer_delay = $TimerDelay
#@onready var instructions = $Instructions

# Timer configuration
@export var min_delay: float = 2.0  # Minimum delay before beep (seconds)
@export var max_delay: float = 5.0  # Maximum delay before beep (seconds)

var fixed_delay: float = -1.0  # If set (>=0), use this delay instead of random

# State tracking
var current_state: TimerState = TimerState.WAITING
var start_time: float = 0.0
var beep_time: float = 0.0
var actual_delay: float = 0.0  # Store the actual delay duration

func _ready():
	"""Initialize the shot timer"""
	if not DEBUG_DISABLED:
		print("=== SHOT TIMER INITIALIZED ===")
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Connect timer signal
	timer_delay.timeout.connect(_on_timer_timeout)
	
	# Hide instructions (not needed anymore)
	#instructions.visible = false
	
	# Don't start automatically - wait for drill UI to call start_timer_sequence()
	current_state = TimerState.WAITING
	standby_label.visible = false

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[ShotTimer] Loaded language from GlobalData: ", language)
	else:
		if not DEBUG_DISABLED:
			print("[ShotTimer] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")

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
		print("[ShotTimer] Set locale to: ", locale)

func get_standby_text() -> String:
	# Since there's no specific "standby" translation key, use localized text
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "准备"
		"zh_TW":
			return "準備"
		"ja":
			return "スタンバイ"
		_:
			return "STANDBY"

func set_fixed_delay(delay: float):
	fixed_delay = delay

func _input(_event):
	"""Handle input events - removed manual controls"""
	# No manual controls needed - timer starts automatically
	pass

func _process(_delta):
	"""Update timer display and check for state changes"""
	match current_state:
		TimerState.STANDBY:
			# Update standby display with pulsing animation
			pass
		TimerState.READY:
			# Calculate reaction time since beep
			var _reaction_time = Time.get_unix_time_from_system() - beep_time
			# You could display this or send it to a parent scene
			pass

func start_timer_sequence():
	"""Start the shot timer sequence"""
	if not DEBUG_DISABLED:
		print("=== STARTING SHOT TIMER SEQUENCE ===")
	
	# Play dynamic "Ready?" audio first if available
	if ready_player:
		ready_player.play()
		# Wait for "Ready?" audio to finish or a fixed comfortable delay
		await get_tree().create_timer(2).timeout
	
	# Set state to standby
	current_state = TimerState.STANDBY
	
	# Show STANDBY text
	standby_label.text = get_standby_text()
	standby_label.label_settings.font_color = Color.YELLOW
	standby_label.visible = true
	
	# Play standby sound
	standby_player.play()
	
	# Start pulsing animation
	animation_player.play("standby_pulse")
	
	# Set delay: use fixed if set, else random
	var delay_to_use: float
	if fixed_delay >= 0:
		delay_to_use = fixed_delay
		actual_delay = fixed_delay
		fixed_delay = -1.0  # Reset after use
	else:
		var random_delay = randf_range(min_delay, max_delay)
		delay_to_use = random_delay
		actual_delay = round(random_delay * 100.0) / 100.0
	timer_delay.wait_time = delay_to_use
	timer_delay.start()
	
	if not DEBUG_DISABLED:
		if fixed_delay >= 0:
			print("Fixed delay set to: ", delay_to_use, " seconds")
		else:
			print("Random delay set to: ", delay_to_use, " seconds (rounded: ", actual_delay, ")")
	
	# Record start time
	start_time = Time.get_unix_time_from_system()

func _on_timer_timeout():
	"""Handle when the random delay timer expires - play beep and show ready"""
	if current_state != TimerState.STANDBY:
		return
	
	if not DEBUG_DISABLED:
		print("=== TIMER BEEP - READY TO SHOOT ===")
	
	# Record beep time
	beep_time = Time.get_unix_time_from_system()
	
	# Play the shot timer beep
	beep_player.play()
	
	# Change to ready state
	current_state = TimerState.READY
	
	# Update visual feedback
	standby_label.text = tr("shoot_command")
	standby_label.label_settings.font_color = Color.GREEN
	
	# Stop pulsing animation and start flash animation
	animation_player.stop()
	animation_player.play("ready_flash")
	
	# Emit signal that timer is ready (for parent scenes to use)
	timer_ready.emit(actual_delay)

# Signals
signal timer_ready(delay: float)
signal timer_reset()

func reset_timer():
	"""Reset the timer to initial state without auto-starting"""
	if not DEBUG_DISABLED:
		print("=== RESETTING SHOT TIMER ===")
	
	# Stop all timers and animations
	timer_delay.stop()
	animation_player.stop()
	standby_player.stop()
	beep_player.stop()
	
	# Reset state
	current_state = TimerState.WAITING
	start_time = 0.0
	beep_time = 0.0
	actual_delay = 0.0
	fixed_delay = -1.0
	
	# Reset visual elements and hide them
	standby_label.text = get_standby_text()
	standby_label.label_settings.font_color = Color.YELLOW
	standby_label.visible = false  # Hide until explicitly started
	standby_label.scale = Vector2.ONE
	standby_label.modulate = Color.WHITE
	
	# Hide instructions (not needed anymore)
	#instructions.visible = false
	
	# Don't auto-start - wait for explicit call to start_timer_sequence()
	
	# Emit reset signal
	timer_reset.emit()

func get_reaction_time() -> float:
	"""Get the current reaction time since beep (only valid in READY state)"""
	if current_state == TimerState.READY and beep_time > 0:
		return Time.get_unix_time_from_system() - beep_time
	return 0.0

func is_timer_ready() -> bool:
	"""Check if the timer is in ready state (after beep)"""
	return current_state == TimerState.READY

func is_timer_waiting() -> bool:
	"""Check if the timer is waiting for user to start"""
	return current_state == TimerState.WAITING

func get_current_state() -> TimerState:
	"""Get the current timer state"""
	return current_state
