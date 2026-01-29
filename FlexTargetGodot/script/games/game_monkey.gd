extends Node2D

enum GameState { SETTINGS, COUNTDOWN, RUNNING, PAUSED, GAME_OVER }

var current_state = GameState.SETTINGS

var countdown_label: Label
var countdown_overlay: CanvasLayer
var countdown_value: int = 5
var countdown_timer: Timer
var game_started: bool = false
var game_duration_timer: Timer
var game_duration: float = 60.0  # Default 60 seconds
var game_over_overlay_scene: PackedScene
var game_over_overlay: CanvasLayer
var vine_horizontal: Node
var timer_label: Label
var display_timer: Timer
var pause_overlay: CanvasLayer
var remote_control: Node
var _gameover_replay_button: Button = null
var _gameover_back_button: Button = null
var _gameover_buttons_connected: bool = false
var _focus_owner_id: String = ""

func _ready():
	print("[GameMonkey] Game started in SETTINGS state")
	
	# Load language setting from GlobalData (like option.gd does)
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("language"):
		var language = global_data.settings_dict.get("language", "English")
		set_locale_from_language(language)
		print("[GameMonkey] Loaded language from GlobalData: ", language)
	else:
		print("[GameMonkey] GlobalData not found or no language setting, using default English")
		set_locale_from_language("English")
	
	# Enable input processing
	set_process_input(true)
	
	# Get references to countdown nodes
	countdown_overlay = get_node_or_null("CountdownOverlay")
	countdown_label = get_node_or_null("CountdownOverlay/CountdownLabel")
	
	if not countdown_label or not countdown_overlay:
		print("[GameMonkey] Error: Countdown nodes not found!")
		return
	
	# Get timer label
	timer_label = get_node_or_null("TimerLabel")
	if not timer_label:
		print("[GameMonkey] Warning: TimerLabel not found!")
	
	# Get pause overlay
	pause_overlay = get_node_or_null("PauseOverlay")
	if not pause_overlay:
		print("[GameMonkey] Warning: PauseOverlay not found!")
	else:
		pause_overlay.visible = false
		var play_button = pause_overlay.get_node("Control/PlayButton")
		if play_button:
			play_button.connect("pressed", _resume_game)
	
	# Get MenuController
	remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.enter_pressed.connect(_on_enter_pressed)
		remote_control.back_pressed.connect(_on_back_pressed)
		if remote_control.has_signal("homepage_pressed"):
			remote_control.homepage_pressed.connect(_on_homepage_pressed)
			print("[GameMonkey] Connected to MenuController homepage_pressed signal")
		print("[GameMonkey] Connected to MenuController signals")
	else:
		print("[GameMonkey] MenuController not found")
	
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
	TranslationServer.set_locale(locale)

	# Hide countdown overlay initially
	if countdown_overlay:
		countdown_overlay.visible = false
	
	# Connect settings signal to self and children via SignalBus
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("settings_applied"):
			signal_bus.settings_applied.connect(self._on_settings_applied)
			var monkey = get_node_or_null("Monkey")
			if monkey:
				signal_bus.settings_applied.connect(monkey._on_settings_applied)
			
			var vine_left = get_node_or_null("VineLeft")
			if vine_left:
				signal_bus.settings_applied.connect(vine_left._on_settings_applied)
			
			var vine_right = get_node_or_null("VineRight")
			if vine_right:
				signal_bus.settings_applied.connect(vine_right._on_settings_applied)
			
			vine_horizontal = get_node_or_null("VineHorizon")
			if vine_horizontal:
				signal_bus.settings_applied.connect(vine_horizontal._on_settings_applied)
		else:
			print("[GameMonkey] settings_applied signal not found on SignalBus")
	else:
		print("[GameMonkey] SignalBus not found")
	
	# Load game over overlay
	game_over_overlay_scene = load("res://scene/games/monkey/game_over_overlay.tscn")
	
	# Connect to player hit signals
	var player1 = get_node_or_null("Jiong")
	if player1:
		player1.player_hit.connect(_on_player_hit)
	
	var player2 = get_node_or_null("xuyang")
	if player2:
		player2.player_hit.connect(_on_player_hit)

func _update_timer_display():
	if timer_label and game_duration_timer:
		var remaining = game_duration_timer.time_left
		var minutes = int(remaining / 60)
		var seconds = int(remaining) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_player_hit(hit_player_id: int):
	var winner_id = 2 if hit_player_id == 1 else 1
	_show_game_over(winner_id)

func _on_settings_applied(_start_side: String, _growth_speed: float, duration: float):
	game_duration = duration
	print("[GameMonkey] Settings applied: duration = ", game_duration)

func _on_enter_pressed():
	if current_state == GameState.RUNNING:
		_pause_game()
	elif current_state == GameState.PAUSED:
		_resume_game()

func _on_back_pressed():
	print("[GameMonkey] Back pressed, current state: ", current_state)
	# Allow back button to work during any state to return to menu
	_return_to_menu()

func _on_homepage_pressed():
	print("[GameMonkey] Homepage pressed, current state: ", current_state)
	# Allow homepage button to work during any state to return to menu
	_return_to_menu()

func _input(event):
	if current_state in [GameState.RUNNING, GameState.PAUSED]:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ENTER:
				if current_state == GameState.RUNNING:
					_pause_game()
				elif current_state == GameState.PAUSED:
					_resume_game()
			elif event.keycode == KEY_BACK or event.keycode == KEY_HOME:
				_return_to_menu()

func _pause_game():
	if pause_overlay:
		pause_overlay.visible = true
	current_state = GameState.PAUSED
	# Pause timers
	if display_timer:
		display_timer.paused = true
	if game_duration_timer:
		game_duration_timer.paused = true
	print("[GameMonkey] Game paused")

func _resume_game():
	if pause_overlay:
		pause_overlay.visible = false
	current_state = GameState.RUNNING
	# Resume timers
	if display_timer:
		display_timer.paused = false
	if game_duration_timer:
		game_duration_timer.paused = false
	print("[GameMonkey] Game resumed")

func _return_to_menu():
	print("[GameMonkey] Returning to menu scene")
	if get_tree():
		var error = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
		if error != OK:
			print("[GameMonkey] Failed to change scene: ", error)
		else:
			print("[GameMonkey] Scene change initiated")
	else:
		print("[GameMonkey] Cannot return to menu: SceneTree not available")

func _show_game_over(winner_id: int):
	if game_over_overlay_scene:
		game_over_overlay = game_over_overlay_scene.instantiate()
		add_child(game_over_overlay)
		game_over_overlay.visible = true
		
		# Hide pause overlay if visible
		if pause_overlay:
			pause_overlay.visible = false
		
		# Update avatar and name
		var avatar_sprite = game_over_overlay.get_node("Panel/HBoxContainerAvatars/LeftSide/AvatarSprite")
		var name_label = game_over_overlay.get_node("Panel/HBoxContainerAvatars/LeftSide/NameLabel")
		var result_label = game_over_overlay.get_node("Panel/HBoxContainerAvatars/RightSide/ResultLabel")
		
		if result_label:
			result_label.text = tr("Winner")
		
		if winner_id == 1:
			if name_label:
				name_label.text = tr("Jiong")
			if avatar_sprite:
				avatar_sprite.texture = load("res://asset/games/jiong-avatar.png")
		else:
			if name_label:
				name_label.text = tr("Xuyang")
			if avatar_sprite:
				avatar_sprite.texture = load("res://asset/games/xuyang-avatar.png")
		
		# Stop the vines
		var vine_left = get_node_or_null("VineLeft")
		if vine_left:
			vine_left.is_growing = false
		var vine_right = get_node_or_null("VineRight")
		if vine_right:
			vine_right.is_growing = false
		if vine_horizontal:
			vine_horizontal.change_speed = 0
		
		# Cancel the timeout timer
		if game_duration_timer:
			game_duration_timer.stop()
			game_duration_timer.queue_free()
			game_duration_timer = null
		
		# Set game state to GAME_OVER
		current_state = GameState.GAME_OVER
		
		# Update timer display to 00:00
		if timer_label:
			timer_label.text = "00:00"
		
		# Stop display timer
		if display_timer:
			display_timer.stop()
			display_timer.queue_free()
			display_timer = null
		
		# Play the sound
		var audio = game_over_overlay.get_node("AudioStreamPlayer")
		if audio:
			audio.play()
		
		# Call HttpService to stop the game
		if has_node("/root/HttpService"):
			var http_service = get_node("/root/HttpService")
			if http_service.has_method("stop_game"):
				var callback = func(_result, response_code, _headers, _body):
					print("[GameMonkey] Game stopped response - Code: ", response_code)
				http_service.stop_game(callback)
				print("[GameMonkey] Called HttpService.stop_game()")
			else:
				print("[GameMonkey] HttpService does not have stop_game method")
		else:
			print("[GameMonkey] HttpService autoload not found")
		
		print("[GameMonkey] Game over! Winner: Player ", winner_id)

		# Wire game over buttons (these are nodes inside the instantiated overlay)
		if game_over_overlay:
			_gameover_replay_button = game_over_overlay.get_node_or_null("Panel/HBoxContainerButtons/ReplayButton")
			_gameover_back_button = game_over_overlay.get_node_or_null("Panel/HBoxContainerButtons/BackButton")
			if _gameover_replay_button:
				_gameover_replay_button.text = tr("restart")
				_gameover_replay_button.pressed.connect(_on_gameover_replay_pressed)
				# Ensure the button can receive focus from code/remote navigation
				_gameover_replay_button.focus_mode = Control.FOCUS_ALL
			if _gameover_back_button:
				_gameover_back_button.text = tr("back_button")
				_gameover_back_button.pressed.connect(_on_gameover_back_pressed)
				_gameover_back_button.focus_mode = Control.FOCUS_ALL
			# Default focus to Replay
			if _gameover_replay_button:
				_gameover_replay_button.grab_focus()
			# Connect MenuController navigation/enter/back while overlay is active
				var rc = remote_control if remote_control else get_node_or_null("/root/MenuController")
				if rc and not _gameover_buttons_connected:
					# Claim exclusive navigation focus (so other UI won't handle left/right)
					_focus_owner_id = str(get_path())
					if rc.has_method("claim_focus"):
						rc.claim_focus(_focus_owner_id)
					# Prefer the claimed navigate signal if present
					if rc.has_signal("navigate_claimed"):
						rc.navigate_claimed.connect(_on_gameover_remote_navigate_claimed)
					elif rc.has_signal("navigate"):
						rc.navigate.connect(_on_gameover_remote_navigate)
					if rc.has_signal("enter_pressed"):
						rc.enter_pressed.connect(_on_gameover_enter_pressed)
					if rc.has_signal("back_pressed"):
						rc.back_pressed.connect(_on_gameover_back_pressed)
					_gameover_buttons_connected = true

func _on_gameover_replay_pressed() -> void:
	print("[GameMonkey] Replay pressed - restarting game")
	# Clean up connections and overlay
	_cleanup_gameover_controls()
	# Reload current scene to restart
	if get_tree():
		var err = get_tree().reload_current_scene()
		if err != OK:
			print("[GameMonkey] Failed to reload scene: ", err)

func _on_gameover_back_pressed() -> void:
	print("[GameMonkey] GameOver Back pressed - returning to menu")
	_cleanup_gameover_controls()
	if get_tree():
		var err = get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
		if err != OK:
			print("[GameMonkey] Failed to change to menu: ", err)

func _on_gameover_enter_pressed() -> void:
	# Trigger the button corresponding to focus
	if _gameover_replay_button and _gameover_replay_button.has_focus():
		_on_gameover_replay_pressed()
	elif _gameover_back_button and _gameover_back_button.has_focus():
		_on_gameover_back_pressed()

func _on_gameover_remote_navigate(direction: String) -> void:
	# Toggle focus between replay and back on left/right navigation
	# If buttons are not present, nothing to do
	if not _gameover_replay_button or not _gameover_back_button:
		return

	# If neither button currently has focus, assign a sensible default
	var replay_focused = _gameover_replay_button.has_focus()
	var back_focused = _gameover_back_button.has_focus()
	if not replay_focused and not back_focused:
		# No focus: choose default based on direction
		if direction == "left":
			_gameover_back_button.grab_focus()
		else:
			_gameover_replay_button.grab_focus()
		return

	# Normal toggling when one of the buttons has focus
	if direction == "left":
		if replay_focused:
			_gameover_back_button.grab_focus()
		else:
			_gameover_replay_button.grab_focus()
	elif direction == "right":
		if back_focused:
			_gameover_replay_button.grab_focus()
		else:
			_gameover_back_button.grab_focus()

func _on_gameover_remote_navigate_claimed(_owner: String, direction: String) -> void:
	# Only handle if the claimed owner matches us
	if _owner != _focus_owner_id:
		return

	# Delegate to existing handler logic
	_on_gameover_remote_navigate(direction)

func _cleanup_gameover_controls() -> void:
	# Disconnect remote signals and clear button references
	var rc = remote_control if remote_control else get_node_or_null("/root/MenuController")
	if rc and _gameover_buttons_connected:
		# Release claimed focus so other UI can receive navigation
		if rc.has_method("release_focus"):
			rc.release_focus(_focus_owner_id)
		# Safely disconnect connected signals using the signal objects and Callables
		if rc.has_signal("navigate") and rc.navigate.is_connected(_on_gameover_remote_navigate):
			rc.navigate.disconnect(_on_gameover_remote_navigate)
		if rc.has_signal("navigate_claimed") and rc.navigate_claimed.is_connected(_on_gameover_remote_navigate_claimed):
			rc.navigate_claimed.disconnect(_on_gameover_remote_navigate_claimed)
		if rc.has_signal("enter_pressed") and rc.enter_pressed.is_connected(_on_gameover_enter_pressed):
			rc.enter_pressed.disconnect(_on_gameover_enter_pressed)
		if rc.has_signal("back_pressed") and rc.back_pressed.is_connected(_on_gameover_back_pressed):
			rc.back_pressed.disconnect(_on_gameover_back_pressed)
		_gameover_buttons_connected = false

	# Free overlay buttons container if it exists
	if _gameover_replay_button and is_instance_valid(_gameover_replay_button):
		_gameover_replay_button.queue_free()
	if _gameover_back_button and is_instance_valid(_gameover_back_button):
		_gameover_back_button.queue_free()
	_gameover_replay_button = null
	_gameover_back_button = null

 

func start_countdown():
	"""Public function to start the countdown, called from settings"""
	print("[GameMonkey] Starting countdown from settings")
	current_state = GameState.COUNTDOWN
	if countdown_overlay:
		countdown_overlay.visible = true
		print("[GameMonkey] Countdown overlay shown")
	
	# Call HttpService to start the game
	if has_node("/root/HttpService"):
		var http_service = get_node("/root/HttpService")
		if http_service.has_method("start_game"):
			# Callback to handle the response
			var callback = func(_result, response_code, _headers, _body):
				print("[GameMonkey] Game started response - Code: ", response_code)
			http_service.start_game(callback)
			print("[GameMonkey] Called HttpService.start_game()")
		else:
			print("[GameMonkey] HttpService does not have start_game method")
	else:
		print("[GameMonkey] HttpService autoload not found")
	
	_start_countdown()

func _start_countdown():
	countdown_timer = Timer.new()
	countdown_timer.process_mode = PROCESS_MODE_ALWAYS
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	add_child(countdown_timer)
	countdown_timer.timeout.connect(_on_countdown_tick)
	countdown_timer.start()
	print("[GameMonkey] Countdown timer started")

func _on_countdown_tick():
	countdown_value -= 1
	if countdown_label:
		countdown_label.text = str(countdown_value)
		print("[GameMonkey] Countdown: ", countdown_value)
	
	if countdown_value <= 0:
		# Countdown finished, stop timer and start the game
		if countdown_timer:
			countdown_timer.stop()
			countdown_timer.queue_free()
			countdown_timer = null
		print("[GameMonkey] Countdown complete! Starting game...")
		_start_game()

func _start_game():
	# Hide countdown overlay
	if countdown_overlay:
		countdown_overlay.visible = false
	
	current_state = GameState.RUNNING
	print("[GameMonkey] Game state changed to RUNNING")
	
	# Start game duration timer
	game_duration_timer = Timer.new()
	game_duration_timer.process_mode = PROCESS_MODE_ALWAYS
	game_duration_timer.wait_time = game_duration
	game_duration_timer.one_shot = true
	add_child(game_duration_timer)
	game_duration_timer.timeout.connect(_on_game_duration_timeout)
	game_duration_timer.start()
	print("[GameMonkey] Game duration timer started: ", game_duration, " seconds")
	
	# Start display timer
	display_timer = Timer.new()
	display_timer.wait_time = 1.0
	display_timer.one_shot = false
	add_child(display_timer)
	display_timer.timeout.connect(_update_timer_display)
	display_timer.start()
	_update_timer_display()  # Set initial display

func _on_game_duration_timeout():
	"""Handle game duration timeout"""
	print("[GameMonkey] Game duration timeout! Determining winner by vine lengths...")
	
	# Get vine lengths
	var vine_left = get_node_or_null("VineLeft")
	var vine_right = get_node_or_null("VineRight")
	
	if vine_left and vine_right:
		var left_length = vine_left.vine_length
		var right_length = vine_right.vine_length
		var winner_id = 1 if left_length < right_length else 2
		print("[GameMonkey] Vine lengths - Left: ", left_length, ", Right: ", right_length, " -> Winner: Player ", winner_id)
		_show_game_over(winner_id)
	else:
		print("[GameMonkey] Error: Could not find vines!")
		# Fallback, change to menu scene
		if get_tree():
			get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
		else:
			print("[GameMonkey] Cannot change scene: SceneTree not available")
	
	# Clean up timer
	if game_duration_timer:
		game_duration_timer.stop()
		game_duration_timer.queue_free()
		game_duration_timer = null
