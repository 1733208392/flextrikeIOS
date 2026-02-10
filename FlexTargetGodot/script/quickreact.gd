extends Node2D

@onready var background = $Background
@onready var label = $Background/Label
@onready var timer = $Timer
@onready var icon = $Background/Icon
@onready var best_score_label = $Background/BestScore

var waiting_for_shoot = false
var start_time = 0
var best_reaction_time = INF

func _ready():
	randomize()  # Seed random number generator once
	timer.timeout.connect(_on_timer_timeout)
	
	# Connect to WebSocket for bullet hits
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		print("WebSocketListener found, connecting bullet_hit")
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
	else:
		print("WebSocketListener not found")

	# Connect to MenuController for back and home directives
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.back_pressed.connect(_on_back_pressed)
		menu_controller.home_pressed.connect(_on_back_pressed)
		print("MenuController found, connected back and home")
	else:
		print("MenuController not found")

			# Start the game via HTTP service
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		http_service.start_game(func(_result, response_code, _headers, _body): 
			if response_code == 200:
				print("Game started successfully")
			else:
				print("Failed to start game: ", response_code)
		)
	
	start_reaction_test()

func on_click():
	var reaction_time = Time.get_ticks_msec() - start_time
	background.color = Color(0xde3823ff)
	label.add_theme_color_override("font_color", Color(0x191919ff))
	icon.texture = load("res://asset/bolt-icon.png")
	background.color = Color(0xde3823ff)
	var reaction_time_sec = reaction_time / 1000.0
	if reaction_time_sec < best_reaction_time:
		best_reaction_time = reaction_time_sec
	label.text = "%.3f s" % reaction_time_sec
	waiting_for_shoot = false
	# Optional: Restart after 5 seconds
	await get_tree().create_timer(3.0).timeout
	start_reaction_test()

func _on_websocket_bullet_hit(_arg1=null, _arg2=null, _arg3=null):
	print("Bullet hit signal received")
	if waiting_for_shoot:
		on_click()

func start_reaction_test():
	waiting_for_shoot = false
	background.color = Color(0x1e1e1eff)  # Red (original)
	label.text = "WAITING FOR GREEN"
	best_score_label.visible = true
	icon.texture = load("res://asset/ellipsis-icon.png")
	label.add_theme_color_override("font_color", Color(0xde3823ff))
	if best_reaction_time == INF:
		best_score_label.text = "RECORD: --"
	else:
		best_score_label.text = "RECORD: %.3f s" % best_reaction_time
	timer.wait_time = randf_range(2.0, 5.0)
	timer.start()

func _on_timer_timeout():
	background.color = Color.GREEN
	label.text = "SHOOT"
	label.add_theme_color_override("font_color", Color.WHITE)
	icon.texture = load("res://asset/clock-icon.png")
	best_score_label.visible = false
	waiting_for_shoot = true
	start_time = Time.get_ticks_msec()

func _input(event):
	if ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or 
		(event is InputEventScreenTouch and event.pressed)) and waiting_for_shoot:
		on_click()

func _on_back_pressed():
	"""Handle back or home press to return to games menu"""
	print("Back/Home pressed - returning to games menu")
	# Show global status bar when returning to menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		print("Showed global status bar: ", status_bar.name)
	
	# Return to games menu
	get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
