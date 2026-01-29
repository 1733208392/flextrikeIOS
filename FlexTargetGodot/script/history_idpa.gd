extends Control

# Performance optimization - disable debug prints in production
const DEBUG_PRINTS = false

@onready var list_container = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# History data structure to store drill results
var history_data = []
var current_focused_index = 0

# Sorting mode control - for IDPA, we sort by total score ascending (lower is better)
var sort_by_total_score = true

# Loading overlay components
var loading_overlay: Control
var loading_label: Label
var loading_timer: Timer
var dots_count = 0

# Loading state variables
var is_loading = false
var files_to_load = []
var current_file_index = 0
var max_index = 0
var consecutive_404s = 0  # Track consecutive 404 errors for early termination
const MAX_CONSECUTIVE_404S = 10  # Stop after 10 consecutive missing files (for 20-record buffer)

func _ready():
	# Load and apply current language setting from global settings
	load_language_from_global_settings()

	# Connect back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Create loading overlay
	create_loading_overlay()

	# Update UI texts with translations
	update_ui_texts()

	# Connect to WebSocketListener
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_PRINTS:
			print("[HistoryIDPA] Connecting to WebSocketListener.menu_control signal")
	else:
		if DEBUG_PRINTS:
			print("[HistoryIDPA] WebSocketListener singleton not found!")

	# Start loading history data
	load_drill_data()

func _input(event):
	"""Handle direct keyboard input for sorting toggle"""
	if event is InputEventKey and event.pressed:
		# Toggle sort mode with 'S' or 'H' key
		if event.keycode == KEY_S or event.keycode == KEY_H:
			toggle_sort_mode()
			get_viewport().set_input_as_handled()  # Prevent further processing

func load_drill_data():
	# Load drill data from idpa_leader_board_index.json instead of individual files
	history_data.clear()
	current_focused_index = 0

	if DEBUG_PRINTS:
		print("[HistoryIDPA] Loading drill data from idpa_leader_board_index.json")

	# Show loading overlay and start loading
	show_loading_overlay()
	is_loading = true

	# Load the leaderboard index file
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.load_game(_on_leaderboard_index_loaded, "idpa_leader_board_index")
	else:
		if DEBUG_PRINTS:
			print("[HistoryIDPA] HttpService not found")
		hide_loading_overlay()
		populate_list()
		setup_clickable_items()

func _on_leaderboard_index_loaded(result, response_code, _headers, body):
	# Process the loaded idpa_leader_board_index.json file
	if DEBUG_PRINTS:
		print("[HistoryIDPA] Leaderboard index load response - Result: ", result, ", Code: ", response_code)

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)

		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data") and response_data["code"] == 0:
				var leaderboard_data = null
				if response_data["data"] is Array:
					# Data is already parsed as Array (leaderboard index format)
					leaderboard_data = response_data["data"]
					process_leaderboard_data(leaderboard_data)
				elif response_data["data"] is String:
					# Data is a JSON string that needs parsing
					var index_json = JSON.new()
					var index_parse = index_json.parse(response_data["data"])
					if index_parse == OK:
						leaderboard_data = index_json.data
						process_leaderboard_data(leaderboard_data)
					else:
						if DEBUG_PRINTS:
							print("[HistoryIDPA] Failed to parse leaderboard index data")
						finish_loading()
				else:
					if DEBUG_PRINTS:
						print("[HistoryIDPA] Unexpected data type for leaderboard index: ", typeof(response_data["data"]))
					finish_loading()
			else:
				if DEBUG_PRINTS:
					print("[HistoryIDPA] No data field in leaderboard index response")
				finish_loading()
		else:
			if DEBUG_PRINTS:
				print("[HistoryIDPA] Failed to parse leaderboard index response JSON")
			finish_loading()
	else:
		if response_code == 404:
			if DEBUG_PRINTS:
				print("[HistoryIDPA] idpa_leader_board_index.json not found (404) - no drill data available")
		else:
			if DEBUG_PRINTS:
				print("[HistoryIDPA] Failed to load idpa_leader_board_index.json - Response code: ", response_code)
		finish_loading()

func process_leaderboard_data(leaderboard_data: Array):
	# Convert IDPA leaderboard data format to history data format
	if DEBUG_PRINTS:
		print("[HistoryIDPA] Processing IDPA leaderboard data with ", leaderboard_data.size(), " entries")

	for entry in leaderboard_data:
		# Extract data from IDPA leaderboard entry format:
		# {"index": 1, "score": 5, "time": 28.1, "final_score": 33.1, "fastest_shot": 0.45}
		var drill_number = int(entry.get("index", 0))
		var down_points = entry.get("down_points", 0)  # Down points (penalty points)
		var raw_time = entry.get("raw_time", 0.0)  # Raw time
		var final_score = raw_time + down_points  # Total score (time + down points)
		var fastest_shot = entry.get("fastest_shot", 0.0)

		# Convert to expected history data format for IDPA
		var drill_data = {
			"drill_number": drill_number,
			"raw_time": "%.1fs" % raw_time,
			"down_points": str(down_points),
			"fastest_shot": "%.2fs" % fastest_shot if fastest_shot > 0.0 else "N/A",
			"total_score": "%.1f" % final_score,
			"records": []  # Empty records array since we don't have individual shot data
		}

		history_data.append(drill_data)
		if DEBUG_PRINTS:
			print("[HistoryIDPA] Converted entry - Drill: ", drill_number, ", Raw Time: ", raw_time, ", Down Points: ", down_points, ", Final Score: ", final_score)

	if DEBUG_PRINTS:
		print("[HistoryIDPA] Converted ", history_data.size(), " IDPA leaderboard entries to history format")

	finish_loading()

func load_next_file():
	if current_file_index >= files_to_load.size():
		# All files processed, finish up
		finish_loading()
		return

	var file_id = files_to_load[current_file_index]
	if DEBUG_PRINTS:
		print("[HistoryIDPA] Loading file ", current_file_index + 1, "/", files_to_load.size(), ": ", file_id)

	# Update loading progress
	update_loading_progress()

	# Load the file via HttpService
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.load_game(_on_file_loaded, file_id)
	else:
		if DEBUG_PRINTS:
			print("[HistoryIDPA] HttpService not found, skipping file: ", file_id)
		current_file_index += 1
		load_next_file()

func finish_loading():
	# Complete the loading process and update UI
	if DEBUG_PRINTS:
		print("[HistoryIDPA] Loading finished - found ", history_data.size(), " drill records")

	# Sort history data based on current sort mode (for IDPA, sort by total score ascending)
	sort_history_data()
	hide_loading_overlay()
	populate_list()
	setup_clickable_items()
	update_score_header_visual()  # Update header visual indicator for IDPA

func _on_file_loaded(result, response_code, _headers, body):
	var file_id = files_to_load[current_file_index]
	if DEBUG_PRINTS:
		print("[HistoryIDPA] File load response for ", file_id, " - Result: ", result, ", Code: ", response_code)

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		consecutive_404s = 0  # Reset 404 counter on successful load
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)

		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data"):
				var content_str = response_data["data"]
				var content_json = JSON.new()
				var content_parse_result = content_json.parse(content_str)

				if content_parse_result == OK:
					var data = content_json.data
					process_loaded_data(data, file_id)
				else:
					if DEBUG_PRINTS:
						print("[HistoryIDPA] Failed to parse content JSON for ", file_id)
			else:
				if DEBUG_PRINTS:
					print("[HistoryIDPA] No data field in response for ", file_id)
		else:
			if DEBUG_PRINTS:
				print("[HistoryIDPA] Failed to parse response JSON for ", file_id)
	else:
		# Handle 404 and other errors
		if response_code == 404:
			consecutive_404s += 1
			if DEBUG_PRINTS:
				print("[HistoryIDPA] File not found (404) for ", file_id, " - consecutive 404s: ", consecutive_404s)

			# Early termination if too many consecutive 404s
			if consecutive_404s >= MAX_CONSECUTIVE_404S:
				if DEBUG_PRINTS:
					print("[HistoryIDPA] Too many consecutive 404s (", consecutive_404s, "), stopping load early")
				finish_loading()
				return
		else:
			consecutive_404s = 0  # Reset on non-404 errors
			if DEBUG_PRINTS:
				print("[HistoryIDPA] Failed to load file ", file_id, " - skipping")

	# Move to next file
	current_file_index += 1
	load_next_file()

func process_loaded_data(data: Dictionary, file_id: String):
	# Extract the drill number from file_id (e.g., "performance_1" -> 1)
	if DEBUG_PRINTS:
		print("[HistoryIDPA] Processing file_id: ", file_id)

	var drill_number: int
	if file_id.begins_with("performance_"):
		# IDPA naming scheme: "performance_1" -> 1
		drill_number = int(file_id.replace("performance_", ""))
	else:
		# Fallback for any legacy files
		drill_number = int(file_id)

	if DEBUG_PRINTS:
		print("[HistoryIDPA] Extracted drill_number: ", drill_number)

	if data.has("drill_summary") and data.has("records"):
		var drill_summary = data["drill_summary"]
		var records = data["records"]

		var total_down_points = 0
		for record in records:
			if record.has("score"):
				total_down_points += record["score"]

		var raw_time = drill_summary.get("total_elapsed_time", 0.0)
		var final_score = raw_time + abs(total_down_points) # IDPA final score = time + down_points (since down_points is negative)

		var drill_data = {
			"drill_number": drill_number,
			"raw_time": "%.1fs" % raw_time,
			"down_points": str(total_down_points),
			"fastest_shot": "%.2fs" % (drill_summary.get("fastest_shot_interval", 0.0) if drill_summary.get("fastest_shot_interval") != null else 0.0),
			"total_score": "%.1f" % final_score,
			"records": records
		}
		history_data.append(drill_data)
		if DEBUG_PRINTS:
			print("[HistoryIDPA] Created drill_data: ", drill_data)
			print("[HistoryIDPA] history_data now has ", history_data.size(), " items")
	else:
		if DEBUG_PRINTS:
			print("[HistoryIDPA] Invalid data structure in file ", file_id)

func create_loading_overlay():
	# Create loading overlay similar to splash_loading
	loading_overlay = Control.new()
	loading_overlay.name = "LoadingOverlay"
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block mouse input

	# Background panel
	var bg_panel = Panel.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)  # Semi-transparent black
	bg_panel.add_theme_stylebox_override("panel", style)
	loading_overlay.add_child(bg_panel)

	# Center container
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.add_child(center_container)

	# VBox for content
	var vbox = VBoxContainer.new()
	center_container.add_child(vbox)

	# Loading label
	loading_label = Label.new()
	loading_label.text = tr("loading")
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(loading_label)

	# Add to scene
	add_child(loading_overlay)
	loading_overlay.visible = false

	# Setup loading animation timer - reduced frequency for better performance
	loading_timer = Timer.new()
	loading_timer.wait_time = 1.0  # Reduced from 0.5 to 1.0 second
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	add_child(loading_timer)

func show_loading_overlay():
	if loading_overlay:
		loading_overlay.visible = true
		dots_count = 0
		loading_timer.start()

func hide_loading_overlay():
	if loading_overlay:
		loading_overlay.visible = false
		loading_timer.stop()
		is_loading = false

func update_loading_progress():
	if loading_label:
		loading_label.text = tr("loading")

func _on_loading_timer_timeout():
	if not is_loading:
		return

	dots_count = (dots_count + 1) % 4
	var dots = ""
	for i in range(dots_count):
		dots += "."

	var base_text = tr("loading")
	loading_label.text = base_text + dots

func populate_list():
	if not list_container:
		return

	# Clear existing items
	for child in list_container.get_children():
		child.queue_free()

	# Create items dynamically
	for i in range(history_data.size()):
		var data = history_data[i]
		var item = HBoxContainer.new()
		item.layout_mode = 2

		# No label - use sorted position (i+1) instead of drill_number
		var no_label = Label.new()
		no_label.layout_mode = 2
		no_label.size_flags_horizontal = 3
		no_label.text = str(i + 1)  # Use sorted position: 1, 2, 3, etc.
		no_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_label.add_theme_font_size_override("font_size", 24)
		item.add_child(no_label)

		# VSeparator
		var sep1 = VSeparator.new()
		sep1.layout_mode = 2
		item.add_child(sep1)

		# Raw Time label
		var time_label = Label.new()
		time_label.layout_mode = 2
		time_label.size_flags_horizontal = 3
		time_label.text = data["raw_time"]
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", 24)
		item.add_child(time_label)

		# VSeparator
		var sep2 = VSeparator.new()
		sep2.layout_mode = 2
		item.add_child(sep2)

		# Down Points label
		var points_label = Label.new()
		points_label.layout_mode = 2
		points_label.size_flags_horizontal = 3
		points_label.text = data["down_points"]
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		points_label.add_theme_font_size_override("font_size", 24)
		item.add_child(points_label)

		# VSeparator
		var sep3 = VSeparator.new()
		sep3.layout_mode = 2
		item.add_child(sep3)

		# Fastest Shot label
		var fast_label = Label.new()
		fast_label.layout_mode = 2
		fast_label.size_flags_horizontal = 3
		fast_label.text = data["fastest_shot"]
		fast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fast_label.add_theme_font_size_override("font_size", 24)
		item.add_child(fast_label)

		# VSeparator
		var sep4 = VSeparator.new()
		sep4.layout_mode = 2
		item.add_child(sep4)

		# Total Score label (with ↑ indicator for ascending sort)
		var score_label = Label.new()
		score_label.layout_mode = 2
		score_label.size_flags_horizontal = 3
		score_label.text = data["total_score"] + "↑"
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.add_theme_font_size_override("font_size", 24)
		item.add_child(score_label)

		list_container.add_child(item)

func sort_history_data():
	# Sort history data by total score ascending (lower scores are better for IDPA)
	if sort_by_total_score:
		history_data.sort_custom(func(a, b):
			var score_a = float(a["total_score"].replace("↑", ""))
			var score_b = float(b["total_score"].replace("↑", ""))
			return score_a < score_b  # Ascending order
		)
	else:
		# Fallback to drill number sorting
		history_data.sort_custom(func(a, b): return a["drill_number"] < b["drill_number"])

func toggle_sort_mode():
	# For IDPA, we only sort by total score ascending
	sort_by_total_score = !sort_by_total_score
	sort_history_data()
	populate_list()
	setup_clickable_items()
	update_score_header_visual()

func update_score_header_visual():
	# Update header visual to show current sort mode for IDPA
	# This would need to be implemented based on the UI structure
	pass

func find_latest_record_index() -> int:
	"""Find the index of the latest record (highest drill number) in the current sorted list"""
	if history_data.size() == 0:
		return 0
	
	var latest_drill_number = -1
	var latest_index = 0
	
	for i in range(history_data.size()):
		var drill_number = history_data[i]["drill_number"]
		if drill_number > latest_drill_number:
			latest_drill_number = drill_number
			latest_index = i
	
	if DEBUG_PRINTS:
		print("[History] Latest record found at index ", latest_index, " with drill number ", latest_drill_number)
	
	return latest_index

func setup_clickable_items():
	# Convert each HBoxContainer item to clickable buttons
	if not list_container:
		return
	
	for i in range(list_container.get_child_count()):
		var item = list_container.get_child(i)
		if item is HBoxContainer:
			# Make the item focusable
			item.focus_mode = Control.FOCUS_ALL
			# Make the item clickable by detecting mouse input
			item.gui_input.connect(_on_item_clicked.bind(i))
			# Add visual feedback for hover
			item.mouse_entered.connect(_on_item_hover_enter.bind(item))
			item.mouse_exited.connect(_on_item_hover_exit.bind(item))
			# Add focus feedback
			item.focus_entered.connect(_on_item_focus_enter.bind(item))
			item.focus_exited.connect(_on_item_focus_exit.bind(item))
			# Connect resize signal to update panel sizes
			item.resized.connect(_on_item_resized.bind(item))
	
	# Set focus to latest record by default
	if list_container.get_child_count() > 0:
		var latest_index = find_latest_record_index()
		if latest_index < list_container.get_child_count():
			var latest_item = list_container.get_child(latest_index)
			if latest_item is HBoxContainer:
				latest_item.grab_focus()
				current_focused_index = latest_index
				if DEBUG_PRINTS:
					print("[History] Focused on latest record at index ", latest_index)
		else:
			# Fallback to first item if latest index is out of bounds
			var first_item = list_container.get_child(0)
			if first_item is HBoxContainer:
				first_item.grab_focus()
				current_focused_index = 0

func _on_item_clicked(event: InputEvent, item_index: int):
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode == KEY_ENTER and event.pressed):
		if DEBUG_PRINTS:
			print("History item ", item_index + 1, " selected")
		
		# Store drill data in GlobalData instead of creating temp file
		if item_index < history_data.size():
			var drill_data = history_data[item_index]
			if DEBUG_PRINTS:
				print("[History] Storing drill data in GlobalData for drill ", drill_data["drill_number"])
			var global_data = get_node("/root/GlobalData")
			if global_data:
				global_data.selected_drill_data = drill_data
				global_data.upper_level_scene = "res://scene/history_idpa.tscn"
		
		# Navigate to drill_replay scene
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func _on_item_hover_enter(item: HBoxContainer):
	# Add visual feedback when hovering over items
	var panel = Panel.new()
	panel.name = "HighlightPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Semi-transparent dark background
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.7, 0.7, 1.0)  # Light border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Remove existing highlight if any
	var existing_panel = item.get_node_or_null("HighlightPanel")
	if existing_panel:
		existing_panel.queue_free()
	
	item.add_child(panel)
	item.move_child(panel, 0)  # Move to back
	# Size the panel to cover the entire item
	call_deferred("_size_panel", panel, item)

func _on_item_hover_exit(item: HBoxContainer):
	# Remove visual feedback when not hovering
	var panel = item.get_node_or_null("HighlightPanel")
	if panel:
		panel.queue_free()

func _on_item_focus_enter(item: HBoxContainer):
	# Add visual feedback when focusing on items
	var panel = Panel.new()
	panel.name = "FocusPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.7)  # Semi-transparent darker background for focus
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 1.0, 1.0, 1.0)  # White border for focus
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Remove existing focus highlight if any
	var existing_panel = item.get_node_or_null("FocusPanel")
	if existing_panel:
		existing_panel.queue_free()
	
	item.add_child(panel)
	item.move_child(panel, 0)  # Move to back
	# Size the panel to cover the entire item
	call_deferred("_size_panel", panel, item)

func _on_item_focus_exit(item: HBoxContainer):
	# Remove visual feedback when not focusing
	var panel = item.get_node_or_null("FocusPanel")
	if panel:
		panel.queue_free()

func _on_item_resized(item: HBoxContainer):
	# Update panel sizes when item is resized
	var hover_panel = item.get_node_or_null("HighlightPanel")
	if hover_panel:
		hover_panel.size = item.size
	
	var focus_panel = item.get_node_or_null("FocusPanel")
	if focus_panel:
		focus_panel.size = item.size

func _size_panel(panel: Panel, item: HBoxContainer):
	# Size the panel to cover the entire item
	if panel and item and is_instance_valid(panel) and is_instance_valid(item):
		# Use a small delay to ensure layout is complete
		var tree = get_tree()
		if tree:
			await tree.create_timer(0.01).timeout
			if panel and item and is_instance_valid(panel) and is_instance_valid(item):
				panel.size = item.size
				panel.position = Vector2.ZERO
		else:
			# Fallback if tree is not available
			if panel and item and is_instance_valid(panel) and is_instance_valid(item):
				panel.size = item.size
				panel.position = Vector2.ZERO

func _on_back_pressed():
	# Navigate back to the previous scene (intro or main menu)
	if DEBUG_PRINTS:
		print("Back button pressed - returning to intro")
	get_tree().change_scene_to_file("res://scene/intro.tscn")

func _on_menu_control(directive: String):
	if has_visible_power_off_dialog():
		return
	if DEBUG_PRINTS:
		print("[History] Received menu_control signal with directive: ", directive)
	match directive:
		"volume_up":
			if DEBUG_PRINTS:
				print("[History] Volume up")
			volume_up()
		"volume_down":
			if DEBUG_PRINTS:
				print("[History] Volume down")
			volume_down()
		"power":
			if DEBUG_PRINTS:
				print("[History] Power off")
			power_off()
		
		"up":
			if DEBUG_PRINTS:
				print("[History] Moving focus up")
			navigate_up()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"down":
			if DEBUG_PRINTS:
				print("[History] Moving focus down")
			navigate_down()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"back":
			if DEBUG_PRINTS:
				print("[History] Back - navigating to sub menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "history"
				if DEBUG_PRINTS:
					print("[History] Set return_source to history")
			
			get_tree().change_scene_to_file("res://scene/sub_menu/sub_menu.tscn")
		"homepage":
			if DEBUG_PRINTS:
				print("[History] Homepage - navigating to main menu")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			
			# Set return source for focus management
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.return_source = "leaderboard"
				if DEBUG_PRINTS:
					print("[History] Set return_source to leaderboard")
			
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
	
		"enter":
			if DEBUG_PRINTS:
				print("[History] Enter pressed")
			select_current_item()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		"sort", "toggle_sort":
			if DEBUG_PRINTS:
				print("[History] Sort mode toggle")
			toggle_sort_mode()
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
		_:
			if DEBUG_PRINTS:
				print("[History] Unknown directive: ", directive)

func navigate_up():
	if list_container.get_child_count() == 0:
		return
	current_focused_index = (current_focused_index - 1 + list_container.get_child_count()) % list_container.get_child_count()
	var item = list_container.get_child(current_focused_index)
	if item is HBoxContainer:
		item.grab_focus()

func navigate_down():
	if list_container.get_child_count() == 0:
		return
	current_focused_index = (current_focused_index + 1) % list_container.get_child_count()
	var item = list_container.get_child(current_focused_index)
	if item is HBoxContainer:
		item.grab_focus()

func select_current_item():
	if current_focused_index < history_data.size():
		if DEBUG_PRINTS:
			print("History item ", current_focused_index + 1, " selected via keyboard")
		
		# Store drill data in GlobalData instead of creating temp file
		var drill_data = history_data[current_focused_index]
		if DEBUG_PRINTS:
			print("[History] Storing drill data in GlobalData for drill ", drill_data["drill_number"])
		var global_data = get_node("/root/GlobalData")
		if global_data:
			global_data.selected_drill_data = drill_data
			global_data.upper_level_scene = "res://scene/history_idpa.tscn"
		
		# Navigate to drill_replay scene
		get_tree().change_scene_to_file("res://scene/drill_replay.tscn")

func volume_up():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_PRINTS:
			print("[History] Sending volume up HTTP request...")
		http_service.volume_up(_on_volume_response)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService singleton not found!")

func volume_down():
	var http_service = get_node("/root/HttpService")
	if http_service:
		if DEBUG_PRINTS:
			print("[History] Sending volume down HTTP request...")
		http_service.volume_down(_on_volume_response)
	else:
		if DEBUG_PRINTS:
			print("[History] HttpService singleton not found!")

func _on_volume_response(result, response_code, _headers, body):
	var body_str = body.get_string_from_utf8()
	if DEBUG_PRINTS:
		print("[History] Volume HTTP response:", result, response_code, body_str)


func load_language_from_global_settings():
	# Load language setting from GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
	else:
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

func update_ui_texts():
	# Update static UI elements with translations
	var title_label = get_node_or_null("MarginContainer/VBoxContainer/TitleLabel")
	var no_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/NoLabel")
	var time_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/RawTimeLabel")
	var down_points_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/DownPointsLabel")
	var fast_shot_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/FastShotLabel")
	var score_label = get_node_or_null("MarginContainer/VBoxContainer/HeaderContainer/TotalScoreLabel")
	var back_btn = get_node_or_null("MarginContainer/VBoxContainer/BackButton")
	
	if title_label:
		title_label.text = tr("idpa_drill_history")
	if no_label:
		no_label.text = tr("no")
	if time_label:
		time_label.text = tr("time")
	if down_points_label:
		down_points_label.text = tr("down_points")
	if fast_shot_label:
		fast_shot_label.text = tr("fastest_t")
	if score_label:
		score_label.text = tr("score") + "↑"
	if back_btn:
		back_btn.text = tr("back_button")

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
