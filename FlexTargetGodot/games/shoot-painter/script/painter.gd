extends Control

func _ready() -> void:
	# Hide global status bar
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.hide()
	
	# Enable UI click injection for this scene
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_emit_click_for_ui(true)
		print("[Painter] Enabled UI click injection for painter game")
	else:
		print("[Painter] No WebSocketListener singleton found")
	
	# Wire back button to return to menu
	var back_button = get_node_or_null("HBoxContainer/BackButton")
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		print("[Painter] Wired back button")
	
	# Wire restart button
	var restart_button = get_node_or_null("HBoxContainer/RestartButton")
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
		print("[Painter] Wired restart button")

func _on_back_button_pressed() -> void:
	print("[Painter] Back button pressed, returning to menu")
	_return_to_main_menu()

func _on_restart_button_pressed() -> void:
	print("[Painter] Restart button pressed")
	get_tree().reload_current_scene()

func _return_to_main_menu() -> void:
	# Disable UI click injection before leaving
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_emit_click_for_ui(false)
	
	# Return to games menu
	var target = "res://scene/games/menu/menu.tscn"
	if ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	else:
		print("[Painter] Menu scene not found: %s" % target)
