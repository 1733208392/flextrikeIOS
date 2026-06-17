extends Node2D

var clay_target_scene = preload("res://scene/games/clay_target.tscn")

var score = 0
var hit_count = 0
var miss_count = 0
var game_over = false
var showing_howtoplay = true

@onready var score_label = $StatusBar/TopBar/Score
@onready var coin_icon = $StatusBar/TopBar/CoinIcon
@onready var howtoplay_layer = $HowtoplayOverlay
@onready var howtoplay_button = $HowtoplayOverlay/Button
@onready var game_background = $Background
@onready var back_button = $BackButton

var test_timer = 0.0
var test_interval = 5.0
const CLAY_SPEED_MULTIPLIER: float = 0.8

var _is_shaking = false
var _is_navigating_to_menu = false

func _ready():
	# Connect to WebSocket
	if WebSocketListener:
		WebSocketListener.netlink_forward.connect(_on_netlink_forward)
		WebSocketListener.bullet_hit.connect(_on_bullet_hit)
		if not WebSocketListener.menu_control.is_connected(_on_menu_control):
			WebSocketListener.menu_control.connect(_on_menu_control)

	_setup_howtoplay()

	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

	# Hide the ammo progress bar — not used in clay pigeon
	var ammo_container = get_node_or_null("StatusBar/TopBar/AmmoContainer")
	if ammo_container:
		ammo_container.visible = false

	# Initial UI
	score_label.text = str(score)

func _setup_howtoplay():
	# Show how to play overlay with specific background color
	if howtoplay_layer:
		howtoplay_layer.show()
		# Add a solid color background if it doesn't have one, or set its color
		var bg_color_rect = howtoplay_layer.get_node_or_null("BackgroundColor")
		if not bg_color_rect:
			bg_color_rect = ColorRect.new()
			bg_color_rect.name = "BackgroundColor"
			bg_color_rect.color = Color("#191919")
			bg_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			howtoplay_layer.add_child(bg_color_rect)
			howtoplay_layer.move_child(bg_color_rect, 0) # Ensure it's at the back
		else:
			bg_color_rect.color = Color("#191919")
			bg_color_rect.show()
	
	# Hide game background while instructions are shown
	if game_background:
		game_background.hide()
	
	if howtoplay_button:
		howtoplay_button.pressed.connect(_on_howtoplay_dismissed)
		# Delay focus to ensure button is ready
		await get_tree().process_frame
		howtoplay_button.grab_focus()

func _on_howtoplay_dismissed():
	showing_howtoplay = false
	if howtoplay_layer:
		howtoplay_layer.hide()

	# Show game background when dismissed
	if game_background:
		game_background.show()

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
		"shake", "compose":
			# Explode all active clay targets and shake camera
			if _is_shaking:
				print("[ClayPigeon] Shake ignored (throttled)")
				return
				
			print("[ClayPigeon] Shake directive received")
			_shake_camera(60.0, 0.6) # Even higher intensity
			_play_lightning_effect() # Visual flash
			for child in get_children():
				if child.has_method("hit"):
					child.hit()
		"enter":
			if showing_howtoplay:
				_on_howtoplay_dismissed()
				return
				
			if game_over:
				# If game over, return to menu or restart
				get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
			else:
				# Trigger a burst mode that launches 10 clay targets
				_burst_launch(10, 0.2)
		"back":
			if showing_howtoplay:
				_on_howtoplay_dismissed()
				return
			# Stop the game and dismiss (go back)
			_stop_game()
		"up":
			if not game_over and not showing_howtoplay: _launch_by_string_direction("center")
		"left":
			if not game_over and not showing_howtoplay: _launch_by_string_direction("left")
		"right":
			if not game_over and not showing_howtoplay: _launch_by_string_direction("right")

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
			velocity = Vector2(-200, -600) * CLAY_SPEED_MULTIPLIER
		"right":
			velocity = Vector2(200, -600) * CLAY_SPEED_MULTIPLIER
		"center":
			velocity = Vector2(0, -700) * CLAY_SPEED_MULTIPLIER
		_:
			velocity = Vector2(randf_range(-250, 250), -randf_range(600, 800)) * CLAY_SPEED_MULTIPLIER
	
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
	# Manual bullet-hit detection for overlay/menu buttons; no UI click injection.
	if _is_bullet_hit_on_howtoplay_start_button(hit_pos):
		_on_howtoplay_dismissed()
		return

	if showing_howtoplay:
		return

	if _is_bullet_hit_on_back_button(hit_pos):
		_go_to_game_menu()

func _on_back_button_pressed():
	_go_to_game_menu()

func _is_bullet_hit_on_back_button(hit_pos: Vector2) -> bool:
	if not back_button or not is_instance_valid(back_button):
		return false
	if not back_button.visible:
		return false
	var back_rect = back_button.get_global_rect()
	return back_rect.has_point(hit_pos)

func _is_bullet_hit_on_howtoplay_start_button(hit_pos: Vector2) -> bool:
	if not showing_howtoplay:
		return false
	if not howtoplay_layer or not howtoplay_layer.visible:
		return false
	if not howtoplay_button or not is_instance_valid(howtoplay_button):
		return false
	if not howtoplay_button.visible:
		return false
	var start_rect = howtoplay_button.get_global_rect()
	return start_rect.has_point(hit_pos)

func _go_to_game_menu():
	if _is_navigating_to_menu:
		return
	_is_navigating_to_menu = true
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scene/games/menu/menu.tscn")

func _exit_tree():
	# Restore the ammo progress bar for other scenes that use this status bar
	var ammo_container = get_node_or_null("StatusBar/TopBar/AmmoContainer")
	if ammo_container:
		ammo_container.visible = true

func launch_clay():
	# Standard launch logic (e.g. from bottom center, arc to side)
	var screen_size = get_viewport_rect().size
	var start_pos = Vector2(screen_size.x / 2, screen_size.y + 50)
	var velocity = Vector2(randf_range(-250, 250), -randf_range(600, 800)) * CLAY_SPEED_MULTIPLIER
	
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
	
func _shake_camera(intensity: float = 10.0, duration: float = 0.5):
	"""Shake the camera with specified intensity and duration"""
	if _is_shaking:
		return
	_is_shaking = true
	
	print("_shake_camera called! Intensity: ", intensity, ", Duration: ", duration)
	var camera = get_node_or_null("Camera2D")
	if not camera:
		print("ERROR: Camera2D not found!")
		_is_shaking = false
		return
	print("Camera found: ", camera)
	
	# Ensure the camera is active
	camera.make_current()
	
	var original_offset = camera.offset
	var original_pos = self.position
	var shake_timer = 0.0
	
	# Use a while loop to perform the shake over time
	while shake_timer < duration:
		var shake_amount = intensity * (1.0 - shake_timer / duration)
		var offset_pos = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		
		# Move the entire root node for a guaranteed shake
		self.position = original_pos + offset_pos
		
		# Also shake camera for good measure
		camera.offset = original_offset + offset_pos
		
		shake_timer += get_process_delta_time()
		await get_tree().process_frame
	
	# Reset position to exactly what it was before this specific shake started
	self.position = original_pos
	camera.offset = original_offset
	_is_shaking = false
	print("Camera shake complete")

func _play_lightning_effect():
	"""Play a lightning bolt animation across the sky (Visual confirmation)"""
	var lightning = ColorRect.new()
	lightning.name = "Lightning"
	lightning.color = Color.WHITE
	lightning.color.a = 0.0
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(lightning)
	
	var viewport_size = get_viewport_rect().size
	lightning.position = Vector2.ZERO
	lightning.size = viewport_size
	
	var tween = create_tween()
	for i in range(3):
		tween.tween_property(lightning, "color:a", 0.6, 0.05)
		tween.tween_property(lightning, "color:a", 0.0, 0.05)
		if i < 2:
			tween.tween_callback(func(): await get_tree().create_timer(0.1).timeout)
	
	tween.tween_callback(canvas_layer.queue_free)

func _input(event):
	# Desktop/Mouse debugging
	if event is InputEventMouseButton and event.pressed:
		if WebSocketListener:
			WebSocketListener.bullet_hit.emit(event.position, 0, 0)
