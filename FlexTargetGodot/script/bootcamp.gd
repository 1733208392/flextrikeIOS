extends Node2D

# Performance optimization
const DEBUG_DISABLED = false  # Set to true for verbose debugging

# Target sequence for bootcamp cycling
var target_sequence: Array[String] = ["bullseye","dueling_tree_composite","texas_start_composite","ipsc_mini","ipsc_mini_black_1", "ipsc_mini_black_2", "hostage", "2poppers", "3paddles", "ipsc_mini_rotate", "uspsa", "idpa", "idpa_ns", "idpa_hard_cover_1", "idpa_hard_cover_2", "mozambique", "double_tap", "custom_target"]
var current_target_index: int = 0
var current_target_instance = null

# Zoom levels: 0.5x, 0.7x, 1x
var scales = [0.5, 0.7, 1.0]
var current_scale_index: int = 2  # Default to 1x

# Targets that don't support zoom
var zoom_excluded_targets = ["ipsc_mini_rotate"]

# Preload the scenes for bootcamp targets
@onready var bullseye_scene: PackedScene = preload("res://scene/targets/bullseye.tscn")	

@onready var ipsc_mini_scene: PackedScene = preload("res://scene/ipsc_mini.tscn")
@onready var ipsc_mini_black_1_scene: PackedScene = preload("res://scene/ipsc_mini_black_1.tscn")
@onready var ipsc_mini_black_2_scene: PackedScene = preload("res://scene/ipsc_mini_black_2.tscn")
@onready var hostage_scene: PackedScene = preload("res://scene/targets/hostage.tscn")
@onready var ipsc_mini_rotate_scene: PackedScene = preload("res://scene/ipsc_mini_rotate.tscn")

@onready var idpa_scene: PackedScene = preload("res://scene/targets/idpa.tscn")
@onready var uspsa_scene: PackedScene = preload("res://scene/targets/uspsa.tscn")
@onready var idpa_ns_scene: PackedScene = preload("res://scene/targets/idpa_ns.tscn")
#@onready var idpa_rotate_scene: PackedScene = preload("res://scene/idpa_mini_rotation.tscn")
@onready var idpa_hard_cover_1_scene: PackedScene = preload("res://scene/targets/idpa_hard_cover_1.tscn")
@onready var idpa_hard_cover_2_scene: PackedScene = preload("res://scene/targets/idpa_hard_cover_2.tscn")

@onready var two_poppers_scene: PackedScene = preload("res://scene/targets/2poppers_simple.tscn")
@onready var three_paddles_scene: PackedScene = preload("res://scene/targets/3paddles_simple.tscn")
@onready var mozambique_scene: PackedScene = preload("res://scene/targets/mozambique.tscn")
@onready var double_tap_scene: PackedScene = preload("res://scene/targets/double_tap.tscn")
@onready var dueling_tree_scene: PackedScene = preload("res://scene/test_dueling_tree_composite.tscn")
@onready var texas_start_composite_scene: PackedScene = preload("res://scene/targets/texas_start_composite.tscn")

@onready var custom_target_scene: PackedScene = preload("res://scene/custom_target.tscn")

@onready var canvas_layer = $CanvasLayer
@onready var canvas_layer_stats = $CanvasLayerStats
@onready var shot_labels = []
@onready var clear_button = $CanvasLayer/Control/BottomContainer/CustomButton
@onready var clear_area = $ClearArea
@onready var background_node = $Background

const BACKGROUND_TEXTURE: Texture2D = preload("res://asset/drills_back.jpg")

# Scale indicator
@onready var scale_label = $ScaleIndicatorLayer/Control/ScaleIndicator/ScaleLabel
@onready var scale_progress_bar = $ScaleIndicatorLayer/Control/ScaleIndicator/ScaleProgressBar

# Statistics labels
@onready var a_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine1/A
@onready var c_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine1/C
@onready var d_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine1/D
@onready var ns_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine1/NS
@onready var miss_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine1/Miss
@onready var fastest_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine2/Fastest
@onready var average_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine2/Average
@onready var count_label = $CanvasLayerStats/Control/VBoxContainer/HBoxContainerLine2/Count

var shot_times = []
var drill_started = false  # Track if drill has been started
var game_start_requested = false  # Prevent multiple requests

# Statistics tracking
var shot_speeds = []  # Array of shot time differences in seconds
var a_zone_count = 0
var c_zone_count = 0  
var d_zone_count = 0
var miss_count = 0
var ns_zone_count = 0

func stop_all_background_music():
	"""Stop any background music that might still be playing from previous scenes"""
	# Find all AudioStreamPlayer nodes in the scene tree that might be playing background music
	var root = get_tree().root
	var audio_players = []
	
	# Recursively find all AudioStreamPlayer nodes
	_find_audio_stream_players(root, audio_players)
	
	for player in audio_players:
		if player.is_playing() and (player.name == "BackgroundMusic" or player.stream and "battle" in player.stream.resource_path.to_lower()):
			player.stop()
			if not DEBUG_DISABLED:
				print("[Bootcamp] Stopped background music from previous scene: ", player.name)

func _find_audio_stream_players(node: Node, result: Array):
	"""Recursively find all AudioStreamPlayer nodes"""
	if node is AudioStreamPlayer:
		result.append(node)
	
	for child in node.get_children():
		_find_audio_stream_players(child, result)

func _ready():
	# Stop any background music from previous scenes (like main menu)
	stop_all_background_music()
	
	# Load and apply current language setting from global settings
	load_language_from_global_settings()
	
	# Initialize but don't start the drill yet
	if not DEBUG_DISABLED:
		print("[Bootcamp] Initializing bootcamp, waiting for HTTP start game response...")
	
	# Targets are spawned dynamically when drill starts
	
	# Connect clear button
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	else:
		if not DEBUG_DISABLED:
			print("ERROR: ClearButton not found!")
	
	# Get all shot labels
	for i in range(1, 11):
		var label = get_node("CanvasLayer/Control/ShotIntervalsOverlay/Shot" + str(i))
		if label:
			shot_labels.append(label)
			label.text = ""
		else:
			if not DEBUG_DISABLED:
				print("ERROR: Shot" + str(i) + " not found!")
	
	# Update UI texts with translations
	update_ui_texts()

	# Update scale indicator
	update_scale_indicator()

	# Ensure the background texture is preloaded and not processing
	_prepare_background()
	
	# Set clear button as default focus
	clear_button.grab_focus()
	
	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Connecting to WebSocketListener.menu_control signal")
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] WebSocketListener singleton not found!")
	
	# Enable bullet spawning for bootcamp scene
	if ws_listener:
		ws_listener.set_bullet_spawning_enabled(true)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Enabled bullet spawning for bootcamp scene")

	# Send HTTP request to start the game and wait for response
	start_bootcamp_drill()

func _prepare_background() -> void:
	if not background_node:
		return
	if background_node is TextureRect:
		background_node.texture = BACKGROUND_TEXTURE
	elif background_node is Sprite2D:
		background_node.texture = BACKGROUND_TEXTURE
	background_node.set_process(false)
	background_node.set_physics_process(false)
	background_node.set_process_input(false)
	background_node.set_process_unhandled_input(false)
	background_node.set_process_unhandled_key_input(false)

func start_bootcamp_drill():
	"""Send HTTP start game request and wait for OK response before starting drill"""
	if game_start_requested:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Game start already requested, ignoring duplicate call")
		return
	
	game_start_requested = true
	if not DEBUG_DISABLED:
		print("[Bootcamp] Sending start game HTTP request for bootcamp...")
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		# Send start game request with bootcamp mode
		http_service.start_game(_on_start_game_response, "bootcamp")
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] ERROR: HttpService singleton not found! Starting drill anyway...")
		_start_drill_immediately()

func _on_start_game_response(result, response_code, _headers, body):
	"""Handle the HTTP start game response"""
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Start game HTTP response:", result, response_code, body_str)
	
	# Parse the JSON response
	var json = JSON.parse_string(body_str)
	if typeof(json) == TYPE_DICTIONARY and json.has("code") and json.code == 0:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Start game SUCCESS - starting bootcamp drill")
		_start_drill_immediately()
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Start game FAILED or invalid response - starting drill anyway")
		_start_drill_immediately()

func _start_drill_immediately():
	"""Actually start the bootcamp drill"""
	if drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill already started, ignoring duplicate call")
		return
	
	drill_started = true
	if not DEBUG_DISABLED:
		print("[Bootcamp] Bootcamp drill officially started! drill_started =", drill_started)
	
	# Initialize with the first target in sequence (bullseye)
	current_target_index = 0
	spawn_target_by_type(target_sequence[current_target_index])
	
	# Background music is stopped when entering bootcamp
	
	# Any additional drill initialization can go here
	# For bootcamp, the drill is already "active" since it's free practice

func _on_bullseye_time_diff(time_diff: float, hit_position: Vector2):
	"""Handle time difference signals from bullseye target for gun zeroing"""
	if not DEBUG_DISABLED:
		print("[Bootcamp] _on_bullseye_time_diff called with time_diff: ", time_diff, " hit_position: ", hit_position)
	
	# Only process if drill has started
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Bullseye time diff before drill started - ignoring")
		return
	
	# Always check if hit is in the ClearArea
	if hit_position and clear_area and clear_area.get_rect().has_point(hit_position):
		if not DEBUG_DISABLED:
			print("[Bootcamp] Bullseye hit detected in ClearArea at: ", hit_position)
		_on_clear_pressed()
		return
	
	# Only display time differences for actual target hits (time_diff >= 0)
	if time_diff >= 0:
		if time_diff > 0:
			shot_speeds.append(time_diff)
			_update_shot_list("+%.2fs" % time_diff)
		else:
			_update_shot_list("First shot")
	
	# Update statistics display
	update_statistics_display()

func _on_target_hit(_arg1, _arg2, _arg3, _arg4 = null, _arg5 = null, _arg6 = null):
	# Handle different signal signatures based on target type:
	# IPSC Mini: target_hit(zone, points, hit_position)
	# Poppers/Paddles: target_hit(id, zone, points, hit_position)
	# idpa (regular, ns, hard_cover): target_hit(zone, points, hit_position)
	# idpa Rotate: target_hit(position, score, area, is_hit, rotation, target_position)
	
	# Only process hits if drill has started
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Target hit before drill started - ignoring")
		return
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] _on_target_hit called with args:", _arg1, _arg2, _arg3, _arg4, _arg5, _arg6)
	
	# Determine target type to extract arguments correctly
	var current_target_type = target_sequence[current_target_index]
	var hit_position
	var zone
	var track_stats = _should_show_stats(current_target_type)
	
	if current_target_type == "idpa_rotate":
		# idpa Rotate: target_hit(position, score, area, is_hit, rotation, target_position)
		hit_position = _arg1
		zone = _arg3
	elif current_target_type in ["2poppers", "3paddles"]:
		# Poppers/Paddles: target_hit(id, zone, points, hit_position)
		hit_position = _arg4
		zone = _arg2
	else:
		# IPSC Mini and idpa variants: target_hit(zone, points, hit_position)
		hit_position = _arg3
		zone = _arg1
	
	# Check if hit is in the ClearArea
	if hit_position and clear_area and clear_area.get_rect().has_point(hit_position):
		if not DEBUG_DISABLED:
			print("[Bootcamp] Hit detected in ClearArea at: ", hit_position)
		_on_clear_pressed()
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	shot_times.append(current_time)
	
	if shot_times.size() > 1:
		var time_diff = shot_times[-1] - shot_times[-2]
		if track_stats:
			shot_speeds.append(time_diff)
		_update_shot_list("+%.2fs" % time_diff)
	else:
		_update_shot_list("First shot")
	
	if track_stats:
		zone = _normalize_zone_for_stats(zone, current_target_type)
		# Track zone statistics
		if zone == "AZone" or zone == "head-0" or zone == "heart-0":
			a_zone_count += 1
		elif zone == "CZone" or zone == "body-1":
			c_zone_count += 1
		elif zone == "DZone" or zone == "other-3":
			d_zone_count += 1
		elif zone == "miss" or zone == "barrel_miss":
			miss_count += 1
		elif zone == "NS":
			ns_zone_count += 1
	
	# Update statistics display
	update_statistics_display()

func _update_shot_list(new_text: String):
	# Shift the list
	for i in range(shot_labels.size() - 1, 0, -1):
		shot_labels[i].text = shot_labels[i-1].text
	shot_labels[0].text = new_text

func _on_clear_pressed():
	# Clear shot list
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Reset statistics
	shot_speeds.clear()
	a_zone_count = 0
	c_zone_count = 0
	d_zone_count = 0
	miss_count = 0
	ns_zone_count = 0
	update_statistics_display()
	
	# Check if current target is a popper or paddle (composition targets without bullet holes)
	var target_type = target_sequence[current_target_index]
	if target_type in ["2poppers", "3paddles", "mozambique", "double_tap"]:
		# For poppers, paddles, and specific drills, remove and respawn them
		if current_target_instance and is_instance_valid(current_target_instance):
			current_target_instance.queue_free()
			if not DEBUG_DISABLED:
				print("Removed ", target_type, " for respawning")
		# Respawn the target
		spawn_target_by_type(target_type)
	elif target_type in ["ipsc_mini","ipsc_mini_rotate", "ipsc_mini_black_1","ipsc_mini_black_2", "hostage","uspsa", "idpa", "idpa_ns", "idpa_hard_cover_1", "idpa_hard_cover_2", "bullseye", "custom_target"]:
		# For bullseye, just reset the target state if needed
		if current_target_instance and is_instance_valid(current_target_instance):
			# Call clear_all_bullet_holes if available on the target itself
			if current_target_instance.has_method("clear_all_bullet_holes"):
				current_target_instance.clear_all_bullet_holes()
			else:
				# Try to find a child node that implements the method (e.g., IPSCMini child)
				var cleared = false
				for child in current_target_instance.get_children():
					if child and child.has_method("clear_all_bullet_holes"):
						child.clear_all_bullet_holes()
						cleared = true
						break
				# Fallback: recursively collect and free bullet hole nodes
				if not cleared:
					var children_to_remove = []
					_collect_bullet_holes(current_target_instance, children_to_remove)
					for bullet_hole in children_to_remove:
						bullet_hole.queue_free()
	else:
		# For other targets (with bullet holes), clear the bullet holes recursively
		var children_to_remove = []
		if current_target_instance and is_instance_valid(current_target_instance):
			_collect_bullet_holes(current_target_instance, children_to_remove)
		
		# Remove all bullet holes
		for bullet_hole in children_to_remove:
			bullet_hole.queue_free()
			if not DEBUG_DISABLED:
				print("Removed bullet hole: ", bullet_hole.name)

func _collect_bullet_holes(node: Node, result: Array):
	"""Recursively collect all bullet holes in the node tree"""
	for child in node.get_children():
		# Check if it's a bullet hole (Sprite2D with bullet hole script)
		if child is Sprite2D and child.has_method("set_hole_position"):
			result.append(child)
		# Recursively search in child nodes
		_collect_bullet_holes(child, result)

func _normalize_zone_for_stats(zone: String, target_type: String) -> String:
	"""Translate rotation-specific area names into the standard zones used by the stats UI"""
	if target_type == "idpa_rotate":
		match zone:
			"head_heart":
				return "AZone"
			"body":
				return "CZone"
			"other":
				return "DZone"
			"cover", "paddle":
				return "miss"
			_: 
				return zone
	
	# IDPA specific normalization
	if _is_idpa_stats_target(target_type):
		if zone.begins_with("ns"):
			return "NS"
		if zone.begins_with("hard-cover"):
			return "miss"
	
	# IPSC specific normalization
	if _is_ipsc_ns_stats_target(target_type):
		if zone.begins_with("WhiteZone"):
			return "NS"
		if zone.begins_with("BlackZone"):
			return "miss"
	
	return zone

func _is_idpa_stats_target(target_type: String) -> bool:
	var idpa_targets = ["idpa", "idpa_ns", "idpa_rotate", "idpa_hard_cover_1", "idpa_hard_cover_2", "uspsa"]
	return target_type in idpa_targets

func _is_ipsc_stats_target(target_type: String) -> bool:
	var ipsc_targets = ["ipsc_mini", "ipsc_mini_black_1", "ipsc_mini_black_2", "hostage", "ipsc_mini_rotate"]
	return target_type in ipsc_targets

func _is_ipsc_ns_stats_target(target_type: String) -> bool:
	var ipsc_ns_targets = ["hostage", "ipsc_mini_black_1", "ipsc_mini_black_2"]
	return target_type in ipsc_ns_targets

func _is_ns_stats_target(target_type: String) -> bool:
	return _is_idpa_stats_target(target_type) or _is_ipsc_ns_stats_target(target_type)

func _should_show_stats(target_type: String) -> bool:
	"""Determine whether the stats overlay should be visible for this target"""
	return _is_idpa_stats_target(target_type) or _is_ipsc_stats_target(target_type)

func _hide_stats_labels() -> void:
	for label in [count_label, a_label, c_label, d_label, ns_label, miss_label, fastest_label, average_label]:
		if label:
			label.text = ""

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if not DEBUG_DISABLED:
		print("[Bootcamp] Received menu_control signal with directive: ", directive)
	match directive:
		"enter":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Enter pressed")
			_on_clear_pressed()
		"left":
			switch_to_previous_target()
		"right":
			switch_to_next_target()
		"homepage","back":
			if not DEBUG_DISABLED:
				print("[Bootcamp] homepage - navigating to main menu")
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "bootcamp"
				if not DEBUG_DISABLED:
					print("[Bootcamp] Set return_source to bootcamp")
			
			# Deactivate current target before exiting
			if current_target_instance and is_instance_valid(current_target_instance) and current_target_instance.has_method("set"):
				current_target_instance.set("drill_active", false)
				if not DEBUG_DISABLED:
					print("[Bootcamp] Deactivated target before exiting")
			
			if is_inside_tree():
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				if not DEBUG_DISABLED:
					print("[Bootcamp] Warning: Node not in tree, cannot change scene")
		"up":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Zoom in")
			zoom_in()
		"down":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Zoom out")
			zoom_out()
		"volume_up":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Volume up")
			volume_up()
		"volume_down":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Volume down")
			volume_down()
		"power":
			if not DEBUG_DISABLED:
				print("[Bootcamp] Power off")
			power_off()
		_:
			if not DEBUG_DISABLED:
				print("[Bootcamp] Unknown directive: ", directive)

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_up_response)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_up_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Volume up HTTP response:", result, response_code, body_str)

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_down_response)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] HttpService singleton not found!")

func _on_volume_down_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if not DEBUG_DISABLED:
		print("[Bootcamp] Volume down HTTP response:", result, response_code, body_str)

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

func zoom_in():
	"""Zoom in to the next higher scale level"""
	current_scale_index = min(current_scale_index + 1, 2)
	apply_current_scale()

func zoom_out():
	"""Zoom out to the next lower scale level"""
	current_scale_index = max(current_scale_index - 1, 0)
	apply_current_scale()

func apply_current_scale():
	"""Apply the current scale to the active target"""
	if current_target_instance and is_instance_valid(current_target_instance):
		var current_target_type = target_sequence[current_target_index]
		var scale_value = 1.0  # Default scale
		if not (current_target_type in zoom_excluded_targets):
			scale_value = scales[current_scale_index]
		current_target_instance.scale = Vector2(scale_value, scale_value)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Applied scale ", scale_value, "x to target: ", current_target_type)
	
	# Update scale indicator
	update_scale_indicator()

func update_scale_indicator():
	"""Update the scale indicator UI"""
	var current_target_type = target_sequence[current_target_index]
	if scale_label:
		if current_target_type in zoom_excluded_targets:
			scale_label.text = "Zoom: N/A"
		else:
			var scale_value = scales[current_scale_index]
			scale_label.text = "Zoom: %.1fx" % scale_value
	if scale_progress_bar:
		if current_target_type in zoom_excluded_targets:
			scale_progress_bar.visible = false
		else:
			scale_progress_bar.visible = true
			var scale_value = scales[current_scale_index]
			scale_progress_bar.value = scale_value * 100  # 50, 70, 100

func load_language_from_global_settings():
	# Read language setting from GlobalData.settings_dict
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Loaded language from GlobalData: ", language)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] GlobalData not found or no language setting, using default English")
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
		print("[Bootcamp] Set locale to: ", locale)

func update_ui_texts():
	# Update static UI elements with translations
	var intervals_label = get_node_or_null("CanvasLayer/Control/ShotIntervalsOverlay/IntervalsLabel")
	var background_instruction = get_node_or_null("Background/Label")
	var clear_area_label = get_node_or_null("ClearArea/Label")
	
	if intervals_label:
		intervals_label.text = get_localized_shots_text()
	
	if background_instruction:
		background_instruction.text = tr("switch_targets_instruction")
	
	if clear_area_label:
		clear_area_label.text = tr("shoot_to_reset")
	
	if clear_button:
		clear_button.text = tr("clear")
	
	# Update statistics labels with current translations
	update_statistics_display()

func get_localized_shots_text() -> String:
	# Since there's no specific "shots" translation key, create localized text based on locale
	var locale = TranslationServer.get_locale()
	match locale:
		"zh_CN":
			return "射击"
		"zh_TW":
			return "射擊"
		"ja":
			return "ショット"
		_:
			return "Shots"

func clear_stats():
	"""Clear all statistics and shot data"""
	# Clear shot list
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Reset statistics
	shot_speeds.clear()
	a_zone_count = 0
	c_zone_count = 0
	d_zone_count = 0
	miss_count = 0
	ns_zone_count = 0
	# Note: update_statistics_display() will be called after target switch

func switch_to_next_target():
	"""Switch to the next target in the sequence"""
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill not started yet, ignoring target switch")
		return
	
	# Clear stats when switching targets
	clear_stats()
	
	# Deactivate current target
	if current_target_instance and is_instance_valid(current_target_instance) and current_target_instance.has_method("set"):
		current_target_instance.set("drill_active", false)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Deactivated current target")
	
	# Move to next target
	current_target_index = (current_target_index + 1) % target_sequence.size()
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] Switching to next target: ", target_sequence[current_target_index], " (index: ", current_target_index, ")")
	
	spawn_target_by_type(target_sequence[current_target_index])
	
	# Update statistics display after target switch
	update_statistics_display()

func switch_to_previous_target():
	"""Switch to the previous target in the sequence"""
	if not drill_started:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Drill not started yet, ignoring target switch")
		return
	
	# Clear stats when switching targets
	clear_stats()
	
	# Deactivate current target
	if current_target_instance and is_instance_valid(current_target_instance) and current_target_instance.has_method("set"):
		current_target_instance.set("drill_active", false)
		if not DEBUG_DISABLED:
			print("[Bootcamp] Deactivated current target")
	
	# Move to previous target
	current_target_index = (current_target_index - 1 + target_sequence.size()) % target_sequence.size()
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] Switching to previous target: ", target_sequence[current_target_index], " (index: ", current_target_index, ")")
	
	spawn_target_by_type(target_sequence[current_target_index])
	
	# Update statistics display after target switch
	update_statistics_display()

func _on_target_disappeared(target_name: String):
	"""Handle when all poppers or paddles have disappeared - respawn them"""
	if not DEBUG_DISABLED:
		print("[Bootcamp] Target disappeared signal received: ", target_name)
	
	# Check if current target is a popper or paddle
	var target_type = target_sequence[current_target_index]
	if target_type in ["2poppers", "3paddles"]:
		# Call reset_scene if the target has this method
		if current_target_instance and is_instance_valid(current_target_instance) and current_target_instance.has_method("reset_scene"):
			current_target_instance.reset_scene()
			if not DEBUG_DISABLED:
				print("[Bootcamp] Reset scene for: ", target_type)
		else:
			# If no reset_scene method, respawn the target
			if not DEBUG_DISABLED:
				print("[Bootcamp] No reset_scene method, respawning target: ", target_type)
			_on_clear_pressed()

func spawn_target_by_type(target_type: String):
	"""Spawn a target of the specified type"""
	# Clear shots from the overlay when switching targets
	for label in shot_labels:
		label.text = ""
	shot_times.clear()
	
	# Clear current target
	if current_target_instance:
		current_target_instance.queue_free()
	
	var stats_visible = _should_show_stats(target_type)
	if canvas_layer_stats:
		canvas_layer_stats.visible = stats_visible
		if not DEBUG_DISABLED:
			if stats_visible:
				print("[Bootcamp] Stats visible for target:", target_type)
			else:
				print("[Bootcamp] Stats hidden for target:", target_type)
	# Hide/show canvas layers based on target type
	if canvas_layer:
		if target_type == "ipsc_mini_rotate":
			canvas_layer.visible = false  # Hide shot intervals for rotation targets
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden shot intervals but kept stats visible for rotation target")
		elif target_type == "custom_target":
			# Custom target may provide its own UI; hide shot interval overlay
			canvas_layer.visible = false
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden shot intervals for custom_target")
		elif target_type == "ipsc_mini":
			canvas_layer.visible = true  # Show shot intervals for IPSC mini
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for IPSC mini target")
		elif target_type == "idpa":
			canvas_layer.visible = true  # Show shot intervals for idpa
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for idpa target")
		elif target_type == "uspsa":
			canvas_layer.visible = true  # Show shot intervals for uspsa
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for uspsa target")
		elif target_type == "idpa_ns":
			canvas_layer.visible = true  # Show shot intervals for idpa NS
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for idpa NS target")
		elif target_type == "idpa_rotate":
			canvas_layer.visible = false  # Hide shot intervals for idpa rotation targets
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden shot intervals but kept stats visible for idpa rotation target")
		elif target_type == "idpa_hard_cover_1":
			canvas_layer.visible = true  # Show shot intervals for idpa hard cover 1
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for idpa hard cover 1 target")
		elif target_type == "idpa_hard_cover_2":
			canvas_layer.visible = true  # Show shot intervals for idpa hard cover 2
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown CanvasLayers and stats for idpa hard cover 2 target")
		elif target_type == "mozambique":
			canvas_layer.visible = false  # Hide shot intervals for mozambique
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden CanvasLayers for mozambique (uses its own drill logic)")
		elif target_type == "double_tap":
			canvas_layer.visible = false  # Hide shot intervals for Double Tap
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden CanvasLayers for Double Tap (uses its own drill logic)")
		elif target_type == "dueling_tree_composite" or target_type == "texas_start_composite":
			canvas_layer.visible = false  # Hide shot intervals for dueling tree composite (and Texas composite)
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden CanvasLayers for dueling_tree_composite")
		else:
			canvas_layer.visible = true  # Show shot intervals for other targets
			if not DEBUG_DISABLED:
				print("[Bootcamp] Shown shot intervals but hidden stats for non-IPSC target:", target_type)
	
	# Hide/show clear area based on target type
	if clear_area:
		if target_type == "mozambique" or target_type == "double_tap":
			clear_area.visible = false  # Hide clear area for mozambique and double tap
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden clear area for ", target_type)
		elif target_type == "dueling_tree_composite" or target_type == "texas_start_composite":
			clear_area.visible = false  # Hide clear area for dueling tree composite (and Texas composite)
			if not DEBUG_DISABLED:
				print("[Bootcamp] Hidden clear area for dueling_tree_composite")
		else:
			clear_area.visible = true  # Restore clear area for other targets
			if not DEBUG_DISABLED:
				print("[Bootcamp] Restored clear area for target: ", target_type)
	
	# Update statistics display
	update_statistics_display()
	
	var target_scene = null
	
	# Select the appropriate scene
	match target_type:
		"bullseye":
			target_scene = bullseye_scene
		"ipsc_mini":
			target_scene = ipsc_mini_scene
		"ipsc_mini_black_1":
			target_scene = ipsc_mini_black_1_scene
		"ipsc_mini_black_2":
			target_scene = ipsc_mini_black_2_scene
		"idpa":
			target_scene = idpa_scene
		"uspsa":
			target_scene = uspsa_scene
		"idpa_ns":
			target_scene = idpa_ns_scene
		# "idpa_rotate":
		# 	target_scene = idpa_rotate_scene
		"idpa_hard_cover_1":
			target_scene = idpa_hard_cover_1_scene
		"idpa_hard_cover_2":
			target_scene = idpa_hard_cover_2_scene
		"hostage":
			target_scene = hostage_scene
		"2poppers":
			target_scene = two_poppers_scene
		"3paddles":
			target_scene = three_paddles_scene
		"ipsc_mini_rotate":
			target_scene = ipsc_mini_rotate_scene
		"custom_target":
			target_scene = custom_target_scene
		"mozambique":
			target_scene = mozambique_scene
		"double_tap":
			target_scene = double_tap_scene
		"dueling_tree_composite":
			target_scene = dueling_tree_scene
		"texas_start_composite":
			target_scene = texas_start_composite_scene
		_:
			if not DEBUG_DISABLED:
				print("[Bootcamp] Unknown target type: ", target_type)
			return
	
	if target_scene:
		var target = target_scene.instantiate()
		add_child(target)
		current_target_instance = target
		
		# Set z_index to be above Background (z=0) but behind ClearArea and CanvasLayer
		# Background: z_index = 0 (default)
		# Target: z_index = 1 (above background)
		# ClearArea: z_index = 2 (above target)
		# CanvasLayer: z_index = 1 (by default, but CanvasLayers always render on top)
		target.z_index = 1
		
		# Center the target in the scene
		target.position = Vector2(360, 640)
		
		# Disable disappearing for bootcamp (set max_shots to high number)
		if target.has_method("set"):
			target.set("max_shots", 1000)
		
		# For composite targets, also set max_shots on child targets
		if target_type == "ipsc_mini_rotate":
			var inner_ipsc = target.get_node_or_null("RotationCenter/IPSCMini")
			if inner_ipsc and inner_ipsc.has_method("set"):
				inner_ipsc.set("max_shots", 1000)
				if not DEBUG_DISABLED:
					print("[Bootcamp] Set max_shots=1000 on inner IPSC mini for rotating target")
		
		# Reset any paddles in the newly spawned target
		var paddles_reset = _reset_all_paddles(target)
		if paddles_reset > 0 and not DEBUG_DISABLED:
			print("[Bootcamp] Reset ", paddles_reset, " paddle(s) for target type ", target_type)
		
		# Special positioning for rotating target (offset from center)
		if target_type == "ipsc_mini_rotate" || target_type == "idpa_rotate":
			target.position = Vector2(160, 740)  # Center (360,640) + offset (-200,100)
			# Z-index is set manually in the editor
		
		# Special scaling for bullseye target
		if target_type == "bullseye":
			target.scale = Vector2(0.9, 0.9)
		
		# Connect signals
		if target_type == "bullseye":
			# Bullseye uses shot_time_diff signal instead of target_hit
			if target.has_signal("shot_time_diff"):
				target.shot_time_diff.connect(_on_bullseye_time_diff)
				if not DEBUG_DISABLED:
					print("[Bootcamp] Connected shot_time_diff signal for bullseye")
			else:
				if not DEBUG_DISABLED:
					print("[Bootcamp] ERROR: Bullseye target does not have shot_time_diff signal")
		elif target.has_signal("target_hit"):
			target.target_hit.connect(_on_target_hit)
			if not DEBUG_DISABLED:
				print("[Bootcamp] Connected target_hit signal for:", target_type)
		
		# For poppers and paddles, connect to target_disappeared signal to auto-respawn
		if target.has_signal("target_disappeared"):
			target.target_disappeared.connect(_on_target_disappeared)
			if not DEBUG_DISABLED:
				print("[Bootcamp] Connected to target_disappeared signal for: ", target_type)
		
		# Enable the target
		if target.has_method("set"):
			target.set("drill_active", true)

			# Connect WebSocketListener.bullet_hit to target's websocket handler if present
			var ws_listener = get_node_or_null("/root/WebSocketListener")
			if ws_listener:
				# Prefer a child node named TexasStar (composite root) then the target itself
				var target_handler_node: Node = null
				if target.has_node("TexasStar"):
					target_handler_node = target.get_node("TexasStar")
				elif target.has_method("websocket_bullet_hit"):
					target_handler_node = target
					if target_handler_node and target_handler_node.has_method("websocket_bullet_hit"):
						var cb = Callable(target_handler_node, "websocket_bullet_hit")
						if not ws_listener.is_connected("bullet_hit", cb):
							ws_listener.bullet_hit.connect(cb)
							if not DEBUG_DISABLED:
								print("[Bootcamp] Connected WebSocketListener.bullet_hit to ", target_handler_node.name)
		
		# Apply current zoom scale
		apply_current_scale()
		
		if not DEBUG_DISABLED:
			print("[Bootcamp] Spawned and activated target: ", target_type, " at position: ", target.position)

func _reset_all_paddles(node: Node) -> int:
	var count = 0
	if node.has_method("reset_paddle"):
		node.reset_paddle()
		count += 1
	for child in node.get_children():
		count += _reset_all_paddles(child)
	return count

func update_statistics_display():
	"""Update the statistics labels with current session data"""
	var current_target_type = target_sequence[current_target_index] if current_target_index < target_sequence.size() else ""
	var show_stats = _should_show_stats(current_target_type)
	if not show_stats:
		if not DEBUG_DISABLED:
			print("[Bootcamp] Stats hidden for target type:", current_target_type)
		_hide_stats_labels()
		return
	
	var total_shots = a_zone_count + c_zone_count + d_zone_count + miss_count + ns_zone_count
	
	if not DEBUG_DISABLED:
		print("[Bootcamp] update_statistics_display() called")
		print("[Bootcamp] Updating stats - total_shots:", total_shots, " A:", a_zone_count, " C:", c_zone_count, " D:", d_zone_count, " Miss:", miss_count)
	
	# Update count label with total shots
	if count_label:
		count_label.text = tr("stats_count") % total_shots
		if not DEBUG_DISABLED:
			print("[Bootcamp] Set Count label to:", count_label.text)
	else:
		if not DEBUG_DISABLED:
			print("[Bootcamp] ERROR: Count label not found! count_label =", count_label)
	
	var is_idpa_target = _is_idpa_stats_target(current_target_type)
	var show_ns_stat = _is_ns_stats_target(current_target_type)
	
	if total_shots > 0:
		var a_percent = (float(a_zone_count) / total_shots) * 100
		var c_percent = (float(c_zone_count) / total_shots) * 100
		var d_percent = (float(d_zone_count) / total_shots) * 100
		var miss_percent = (float(miss_count) / total_shots) * 100
		
		if a_label:
			var a_label_text = "0: %.0f%%" % a_percent if is_idpa_target else tr("stats_a_zone") % a_percent
			a_label.text = a_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set A label to:", a_label.text)
		else:
			if not DEBUG_DISABLED:
				print("[Bootcamp] A label not found!")
				
		if c_label:
			var c_label_text = "-1: %.0f%%" % c_percent if is_idpa_target else tr("stats_c_zone") % c_percent
			c_label.text = c_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set C label to:", c_label.text)
		if d_label:
			var d_label_text = "-3: %.0f%%" % d_percent if is_idpa_target else tr("stats_d_zone") % d_percent
			d_label.text = d_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set D label to:", d_label.text)
		if miss_label:
			miss_label.text = tr("stats_miss") % miss_percent
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set Miss label to:", miss_label.text)
		if ns_label:
			if show_ns_stat:
				var ns_percent = (float(ns_zone_count) / total_shots) * 100
				ns_label.text = "NS: %.0f%%" % ns_percent
				if not DEBUG_DISABLED:
					print("[Bootcamp] Set NS label to:", ns_label.text)
			else:
				ns_label.text = "NS:--"
	else:
		# When no shots, show 0% for all zones
		if a_label:
			var a_label_text = "0: %.0f%%" % 0.0 if is_idpa_target else tr("stats_a_zone") % 0.0
			a_label.text = a_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set A label to: A:0.0%")
		if c_label:
			var c_label_text = "-1: %.0f%%" % 0.0 if is_idpa_target else tr("stats_c_zone") % 0.0
			c_label.text = c_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set C label to: C:0.0%")
		if d_label:
			var d_label_text = "-3: %.0f%%" % 0.0 if is_idpa_target else tr("stats_d_zone") % 0.0
			d_label.text = d_label_text
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set D label to: D:0.0%")
		if miss_label:
			miss_label.text = tr("stats_miss") % 0.0
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set Miss label to: Miss:0.0%")
		if ns_label:
			if show_ns_stat:
				ns_label.text = "NS: 0.0%"
			else:
				ns_label.text = "NS:--"
	
	if shot_speeds.size() > 0:
		var fastest = shot_speeds.min()
		var average = shot_speeds.reduce(func(acc, val): return acc + val, 0.0) / shot_speeds.size()
		
		if fastest_label:
			fastest_label.text = tr("stats_fastest") % fastest
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set Fastest label to:", fastest_label.text)
		if average_label:
			average_label.text = tr("stats_average") % average
			if not DEBUG_DISABLED:
				print("[Bootcamp] Set Average label to:", average_label.text)
	else:
		# Reset labels when no shots
		if fastest_label:
			fastest_label.text = tr("stats_fastest_no_data")
		if average_label:
			average_label.text = tr("stats_average_no_data")
