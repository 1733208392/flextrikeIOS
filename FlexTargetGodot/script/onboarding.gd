extends Control

const DEBUG_DISABLED = true
const QR_CODE_GENERATOR = preload("res://script/qrcode.gd")
const QR_URL = "https://grwolf.com/pages/app-redirect"

@onready var greeting_label = $CenterContainer/VBoxContainer/GreetingLabel
@onready var qr_texture_rect = $CenterContainer/VBoxContainer/QRTextureRect

var forward_timer: Timer
var status_poll_timer: Timer
var typing_timer: Timer
var blinking_timer: Timer
var ble_name: String = "..."

func _ready():
	# Initial UI update
	_set_initial_greeting()
	_generate_qr()

	# 1. Setup periodic forward data (every 5s)
	forward_timer = Timer.new()
	forward_timer.wait_time = 5.0
	forward_timer.timeout.connect(_on_forward_timer_timeout)
	add_child(forward_timer)
	forward_timer.start()
	_on_forward_timer_timeout() # Send immediately

	# 2. Setup status polling timer (every 2s to catch BLE name faster)
	status_poll_timer = Timer.new()
	status_poll_timer.wait_time = 2.0
	status_poll_timer.timeout.connect(_on_status_poll_timer_timeout)
	add_child(status_poll_timer)
	status_poll_timer.start()

	# 3. Connect to GlobalData signal
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.netlink_status_loaded.connect(_on_netlink_status_loaded)
		if global_data.netlink_status and global_data.netlink_status.has("bluetooth_name"):
			_on_netlink_status_loaded()

func _set_initial_greeting():
	# Set initial text with blinking dot
	greeting_label.text = "Hello, my name is [color=orange].[/color]"
	greeting_label.visible_characters = -1  # Show all initially
	_start_blinking()

func _start_blinking():
	if blinking_timer:
		blinking_timer.queue_free()
	blinking_timer = Timer.new()
	blinking_timer.wait_time = 0.5  # Blink every 0.5 seconds
	blinking_timer.timeout.connect(_on_blinking_timer_timeout)
	add_child(blinking_timer)
	blinking_timer.start()

func _on_blinking_timer_timeout():
	# Toggle the dot visibility
	if greeting_label.text.ends_with("[/color]"):
		greeting_label.text = "Hello, my name is [color=orange][/color]"
	else:
		greeting_label.text = "Hello, my name is [color=orange].[/color]"

func _on_forward_timer_timeout():
	var content = {
			"provision_status": "incomplete"
	}
	HttpService.forward_data(Callable(), content)
	if not DEBUG_DISABLED:
		print("[Onboarding] Sent provision_status: incomplete")

func _on_status_poll_timer_timeout():
	# Explicitly request status to ensure we get BLE name as soon as possible
	HttpService.netlink_status(func(_result, _response_code, _headers, _body):
		# No need to parse here, GlobalData will handle it via it's own polling or manual updates
		# but since we want it faster, we can also parse it if we want.
		# Actually GlobalData has its own timer (60s), so we poll faster here.
		if _response_code == 200:
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.update_netlink_status_from_response(_result, _response_code, _headers, _body)
	)

func _on_netlink_status_loaded():
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		return
	
	var status = global_data.netlink_status
	if status.has("bluetooth_name"):
		var new_name = str(status["bluetooth_name"])
		if not new_name.is_empty() and new_name != ble_name:
			ble_name = new_name
			# Stop blinking and start typing animation
			if blinking_timer:
				blinking_timer.stop()
				blinking_timer.queue_free()
			_update_greeting()
			if not DEBUG_DISABLED:
				print("[Onboarding] BLE name resolved: ", ble_name)

func _update_greeting():
	# Use BBCode for rich text formatting
	# Orange color for the BLE name
	var greeting_text = "\"Hello, my name is [color=orange]%s[/color], as this is the first time we met, please scan the QR code to download a mobile APP to control me and explore what I can do for you.\"" % ble_name
	greeting_label.text = greeting_text
	_start_typing_animation()

func _start_typing_animation():
	greeting_label.visible_characters = 0
	if typing_timer:
		typing_timer.queue_free()
	typing_timer = Timer.new()
	typing_timer.wait_time = 0.05  # Typing speed: 0.05 seconds per character
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(typing_timer)
	typing_timer.start()

func _on_typing_timer_timeout():
	if greeting_label.visible_characters < greeting_label.text.length():
		greeting_label.visible_characters += 1
	else:
		typing_timer.stop()

func _generate_qr():
	var qr = QR_CODE_GENERATOR.new()
	var image = qr.generate_image(QR_URL, 8) # Bigger module size for big QR
	if image:
		qr_texture_rect.texture = ImageTexture.create_from_image(image)

func _complete_onboarding():
	# Mark as complete in GlobalData
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		global_data.settings_dict["first_run_complete"] = true
		
		# Save settings to server
		var settings_data = global_data.settings_dict.duplicate()
		HttpService.save_game(Callable(), "settings", settings_data)
	
	if not DEBUG_DISABLED:
		print("[Onboarding] Onboarding complete, transitioning to main menu in 3 seconds")
	
	# Transition after a short delay
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
