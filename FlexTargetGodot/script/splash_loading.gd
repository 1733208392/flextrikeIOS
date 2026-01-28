extends Control

const DEBUG_DISABLED = true

@onready var loading_label = $VBoxContainer/LoadingLabel
@onready var logo_container = $VBoxContainer/LogoContainer

var dots_count = 0
var loading_timer: Timer
var timeout_timer: Timer
var max_loading_time = 10.0  # Maximum 10 seconds loading time

func _ready():	
	# Setup loading animation
	setup_loading_animation()
	
	# Setup timeout fallback
	setup_timeout_fallback()
	
	# Connect to GlobalData settings loaded signal
	var global_data = get_node("/root/GlobalData")
	if global_data:
		# Check if settings are already loaded
		if global_data.settings_dict.size() > 0:
			if not DEBUG_DISABLED:
				print("[Splash] Settings already loaded, proceeding to main menu")
			proceed_to_main_menu()
		else:
			# Wait for settings to load
			global_data.settings_loaded.connect(_on_settings_loaded)
	else:
		if not DEBUG_DISABLED:
			print("[Splash] GlobalData not found, proceeding anyway")
		proceed_to_main_menu()

func setup_loading_animation():
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.5
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	loading_timer.autostart = true
	add_child(loading_timer)
	
	# Initial text
	loading_label.text = tr("loading")

func setup_timeout_fallback():
	timeout_timer = Timer.new()
	timeout_timer.wait_time = max_loading_time
	timeout_timer.timeout.connect(_on_timeout)
	timeout_timer.one_shot = true
	timeout_timer.autostart = true
	add_child(timeout_timer)

func _on_loading_timer_timeout():
	dots_count = (dots_count + 1) % 4
	var dots = ""
	for i in range(dots_count):
		dots += "."
	loading_label.text = tr("loading") + dots

func _on_settings_loaded():
	if not DEBUG_DISABLED:
		print("[Splash] Settings loaded signal received, proceeding to main menu")
	proceed_to_main_menu()

func _on_timeout():
	if not DEBUG_DISABLED:
		print("[Splash] Loading timeout reached, proceeding to main menu anyway")
	loading_label.text = tr("timeout_loading")
	await get_tree().create_timer(1.0).timeout
	proceed_to_main_menu()

func proceed_to_main_menu():
	# Stop timers
	if loading_timer:
		loading_timer.queue_free()
	if timeout_timer:
		timeout_timer.queue_free()
	
	# Transition to main menu
	if not DEBUG_DISABLED:
		print("[Splash] Transitioning to main menu")
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
