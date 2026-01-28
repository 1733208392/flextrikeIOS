extends CanvasLayer

@onready var ok_button = $CenterContainer/PanelContainer/VBoxContainer/OKButton
@onready var text_label = $CenterContainer/PanelContainer/VBoxContainer/TextLabel
var alert_text = ""

const DEBUG_ENABLED = false  # Set to false for production release

func _ready():
	if DEBUG_ENABLED:
		print("[PowerOffDialog] Ready called")
	
	if ok_button == null:
		if DEBUG_ENABLED:
			print("[PowerOffDialog] ERROR: ok_button is null!")
		return
	
	ok_button.pressed.connect(_on_ok_pressed)
	ok_button.grab_focus()
	if DEBUG_ENABLED:
		print("[PowerOffDialog] Button connected and focused")
	
	# Connect to WebSocketListener for remote control
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.menu_control.connect(_on_menu_control)
		if DEBUG_ENABLED:
			print("[PowerOffDialog] Connected to WebSocketListener")
	else:
		if DEBUG_ENABLED:
			print("[PowerOffDialog] WebSocketListener not found")

func set_alert_text(text: String):
	alert_text = text
	if text_label:
		text_label.text = text
	else:
		if DEBUG_ENABLED:
			print("[PowerOffDialog] text_label not ready, will set later")
		call_deferred("set_text_deferred", text)

func set_text_deferred(text: String):
	if has_node("CenterContainer/PanelContainer/VBoxContainer/TextLabel"):
		$CenterContainer/PanelContainer/VBoxContainer/TextLabel.text = text
		if DEBUG_ENABLED:
			print("[PowerOffDialog] Text set: ", text)

func _on_ok_pressed():
	queue_free()

func _on_menu_control(directive: String):
	# Only handle enter/power directives
	match directive:
		"enter":
			if DEBUG_ENABLED:
				print("[PowerOffDialog] Enter pressed, closing dialog")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			_on_ok_pressed()
		"power":
			if DEBUG_ENABLED:
				print("[PowerOffDialog] Power pressed, closing dialog")
			var menu_controller = get_node("/root/MenuController")
			if menu_controller:
				menu_controller.play_cursor_sound()
			_on_ok_pressed()
		_:
			if DEBUG_ENABLED:
				print("[PowerOffDialog] Ignoring directive: ", directive)
