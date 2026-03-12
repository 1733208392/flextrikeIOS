extends Node2D

var clay_target_scene = preload("res://scene/games/clay_target.tscn")
var coin_anim_scene = preload("res://scene/games/coin_anim.tscn")

var score = 0
var hit_count = 0
var miss_count = 0
var game_over = false

var shake_intensity = 0.0
var shake_duration = 0.0

@onready var score_label = $StatusBar/TopBar/Score
@onready var coin_icon = $StatusBar/TopBar/CoinIcon
@onready var game_over_panel = $GameOverLayer/GameOverPanel

var test_timer = 0.0
var test_interval = 5.0

func _ready():
	# Connect to WebSocket
	if WebSocketListener:
		WebSocketListener.netlink_forward.connect(_on_netlink_forward)
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
		WebSocketListener.menu_control.connect(_on_menu_control)
	
	# Initial UI
	score_label.text = str(score)
	game_over_panel.hide()
	
	# Let the app know we are ready
	HttpService.start_game(func(result, response_code, _headers, _body):
		print("Clay Pigeon started - Result: ", result)
	)

func _on_netlink_forward(data: Dictionary):
	# Handle commands from mobile app
	var cmd = data.get("cmd", "")
	if cmd == "launch" or cmd == "start":
		if data.get("direct") != null:
			var direct = data.get("direct")
			if direct is String:
				_launch_by_string_direction(direct)
			elif direct is Dictionary:
				var vx = direct.get("x", 0.0)
				var vy = direct.get("y", 0.0)
				launch_clay_custom(Vector2(vx, vy))
		else:
			launch_clay()
	elif cmd == "stop":
		_stop_game()

func _on_menu_control(directive: String):
	# Handle remote controller directives
	match directive:
		"shake":
			# Explode all active clay targets and shake camera
			shake_intensity = 15.0
			shake_duration = 0.5
			for child in get_children():
				if child is ClayTarget:
					child.hit()
		"enter":
			if game_over:
				# If game over, return to menu or restart
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				# Trigger a burst mode that launches 10 clay targets
				_burst_launch(10, 0.2)
		"back":
			# Stop the game and dismiss (go back)
			_stop_game()
		"up":
			if not game_over: _launch_by_string_direction("center")
		"left":
			if not game_over: _launch_by_string_direction("left")
		"right":
			if not game_over: _launch_by_string_direction("right")

func _burst_launch(count: int, delay: float):
	for i in range(count):
		if game_over: break
		launch_clay()
		if delay > 0:
			await get_tree().create_timer(delay).timeout

func _launch_by_string_direction(direction: String):
	var velocity = Vector2.ZERO
	match direction:
		"left":
			velocity = Vector2(-200, -800)
		"right":
			velocity = Vector2(200, -800)
		"center":
			velocity = Vector2(0, -900)
		_:
			velocity = Vector2(randf_range(-250, 250), -randf_range(1000, 1200))
	
	launch_clay_custom(velocity)

func _stop_game():
	if game_over:
		return
	game_over = true
	
	var results = {
		"game": "clay pigeon",
		"score": score,
		"hit": hit_count,
		"miss": miss_count
	}
	
	HttpService.forward_data(func(_r, _c, _h, _b):
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
	, results)

func _on_bullet_hit(hit_pos: Vector2, _a, _t):
	# This handles the "shot" from the target sensors
	# We can use it to check collision with active clays if the clay doesn't do it itself
	# However, hit detection is often better performed by the target if using Area2D
	pass

func launch_clay():
	# Standard launch logic (e.g. from bottom center, arc to side)
	var screen_size = get_viewport_rect().size
	var start_pos = Vector2(screen_size.x / 2, screen_size.y + 50)
	var velocity = Vector2(randf_range(-250, 250), -randf_range(1000, 1200))
	
	var target = clay_target_scene.instantiate()
	add_child(target)
	target.launch(start_pos, velocity)
	target.destroyed.connect(_on_target_destroyed)
	target.missed.connect(_on_target_missed)

func launch_clay_custom(velocity: Vector2):
	# Swipe-based launch or custom velocity
	var screen_size = get_viewport_rect().size
	var start_pos = Vector2(screen_size.x / 2, screen_size.y + 50)
	
	var target = clay_target_scene.instantiate()
	add_child(target)
	target.launch(start_pos, velocity)
	target.destroyed.connect(_on_target_destroyed)
	target.missed.connect(_on_target_missed)

func _on_target_destroyed(points):
	score += points
	hit_count += 1
	score_label.text = str(score)
	# Notify app if needed via HttpService.forward_data
	# Note: Not implemented here yet as we might want to batch or just report final

func _on_target_missed():
	miss_count += 1
	
func _process(delta):
	if shake_duration > 0:
		shake_duration -= delta
		$Camera2D.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity), 
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		$Camera2D.offset = Vector2.ZERO

func _input(event):
	# Desktop/Mouse debugging
	if event is InputEventMouseButton and event.pressed:
		if WebSocketListener:
			WebSocketListener.bullet_hit.emit(event.position, 0, 0)
