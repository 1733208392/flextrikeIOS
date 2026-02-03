extends Control

const DEBUG_DISABLED = true
const QR_CODE_GENERATOR = preload("res://script/qrcode.gd")
const QR_URL_BASE = "https://grwolf.com/pages/app-redirect"

@onready var greeting_label = $CenterContainer/NormalState/GreetingContainer/GreetingLabel
@onready var error_label = $ErroContainer/ErrorLabel
@onready var qr_texture_rect = $CenterContainer/NormalState/QRContainer/QRTextureRect
@onready var error_container = $ErroContainer
@onready var normal_state = $CenterContainer/NormalState

var forward_timer: Timer
var status_poll_timer: Timer
var typing_timer: Timer
var blinking_timer: Timer
var health_check_timer: Timer
var ble_name: String = "..."

func _ready():
	# Set default locale to English for translations
	TranslationServer.set_locale("en")
	
	# Initialize UI - hide normal state, show error container for health check
	normal_state.visible = false
	error_container.visible = true
	
	# Show health check message
	_start_health_check()
	
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
	
	# 4. Connect to WebSocketListener for provision_step signal
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.provision_step_received.connect(_on_provision_step_received)

func _start_health_check():
	# Display health check message in error container
	error_label.text = tr("onboarding_health_check_progress")
	error_label.visible_characters = -1  # Show all initially
	
	# Start animated dots for health check
	if blinking_timer:
		blinking_timer.queue_free()
	blinking_timer = Timer.new()
	blinking_timer.wait_time = 0.5
	blinking_timer.timeout.connect(_on_health_check_dot_timeout)
	add_child(blinking_timer)
	blinking_timer.start()
	
	# Start health check timeout (10 seconds)
	if health_check_timer:
		health_check_timer.queue_free()
	health_check_timer = Timer.new()
	health_check_timer.wait_time = 10.0
	health_check_timer.timeout.connect(_on_health_check_timeout)
	health_check_timer.one_shot = true
	add_child(health_check_timer)
	health_check_timer.start()

func _on_health_check_dot_timeout():
	# Animate dots for health check message
	var base_text = tr("onboarding_health_check_progress").trim_suffix(" ...")
	if error_label.text.ends_with("..."):
		error_label.text = base_text + " ."
	elif error_label.text.ends_with(".."):
		error_label.text = base_text + " ..."
	else:
		error_label.text = base_text + " .."

func _on_health_check_timeout():
	# Show error message if BLE name was not received
	if blinking_timer:
		blinking_timer.stop()
		blinking_timer.queue_free()
		blinking_timer = null
	
	error_label.text = "[color=orange]" + tr("onboarding_health_check_fault") + "[/color]"
	if not DEBUG_DISABLED:
		print("[Onboarding] Health check timeout - major fault detected")

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
			# Cancel health check timer
			if health_check_timer:
				health_check_timer.stop()
				health_check_timer.queue_free()
				health_check_timer = null
			# Stop blinking animation
			if blinking_timer:
				blinking_timer.stop()
				blinking_timer.queue_free()
				blinking_timer = null
			# Switch to normal state (show QR and greeting, hide error)
			error_container.visible = false
			normal_state.visible = true
			# Generate QR code and greeting with BLE name
			_generate_qr(ble_name)
			_update_greeting()
			if not DEBUG_DISABLED:
				print("[Onboarding] BLE name resolved: ", ble_name)

func _update_greeting():
	# Use BBCode for rich text formatting
	# Orange color for the BLE name
	var greeting_text = tr("onboarding_main_greeting").replace("{ble_name}", ble_name)
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
		# Check if this is the WiFi connection greeting
		if greeting_label.text == tr("onboarding_wifi_connection_greeting"):
			# Transition immediately to WiFi networks scene
			get_tree().change_scene_to_file("res://scene/wifi_networks.tscn")
			if not DEBUG_DISABLED:
				print("[Onboarding] Typing animation completed, transitioning to WiFi networks scene immediately")

func _generate_qr(ble_name: String = ""):
	var qr_url = QR_URL_BASE
	if not ble_name.is_empty():
		qr_url = "%s?ble_name=%s" % [QR_URL_BASE, ble_name]
	
	var qr = QR_CODE_GENERATOR.new()
	var image = qr.generate_image(qr_url, 8) # Bigger module size for big QR
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
	var complete_timer = Timer.new()
	add_child(complete_timer)
	complete_timer.wait_time = 3.0
	complete_timer.one_shot = true
	complete_timer.timeout.connect(func():
		complete_timer.queue_free()
		get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
	)
	complete_timer.start()

func _on_provision_step_received(step: String):
	"""Handle provision step received from mobile app"""
	if step == "wifi_connection":
		if not DEBUG_DISABLED:
			print("[Onboarding] Received wifi_connection provision step, preparing transition")
		
		# Update greeting text to indicate WiFi connection is needed
		greeting_label.text = tr("onboarding_wifi_connection_greeting")
		
		# Stop typing animation if it's running
		if typing_timer:
			typing_timer.stop()
		
		# Start typing animation for the new greeting
		_start_typing_animation()
		
		if not DEBUG_DISABLED:
			print("[Onboarding] Starting typing animation for WiFi connection greeting")
