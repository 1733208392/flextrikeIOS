extends CanvasLayer

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

const WIFI_IDLE := preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED := preload("res://asset/wifi.fill.connect.png")
const NET_IDLE := preload("res://asset/connectivity.idle.png")
const NET_CONNECTED := preload("res://asset/connectivity.active.png")
const MAIN_MENU_SCENE_PATH := "res://scene/main_menu/main_menu.tscn"

@onready var wifi_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/WifiIcon")
@onready var network_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/ConnectivityIcon")
@onready var root_control: Control = get_node_or_null("Root")
@onready var back_button: Button = get_node_or_null("Root/Panel/Back")

func _ready() -> void:
	# print("StatusBar: _ready() called")
	add_to_group("status_bar")
	_set_wifi_connected(false)
	_set_network_started(false)

	var signal_bus = get_node_or_null("/root/SignalBus")
	if signal_bus:
		if not signal_bus.wifi_connected.is_connected(_on_wifi_connected):
			signal_bus.wifi_connected.connect(_on_wifi_connected)
			# print("StatusBar: Connected to SignalBus wifi_connected signal")
		
		if not signal_bus.network_started.is_connected(_on_network_started):
			signal_bus.network_started.connect(_on_network_started)
			# print("StatusBar: Connected to SignalBus network_started signal")
		
		if not signal_bus.network_stopped.is_connected(_on_network_stopped):
			signal_bus.network_stopped.connect(_on_network_stopped)
			# print("StatusBar: Connected to SignalBus network_stopped signal")
	
	# Update size after frame
	call_deferred("_update_size")
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)

	# Handle explicit UI click from status bar back button
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_update_back_button_visibility()

	# Listen for netlink status updates so UI can reflect started state
	# (GlobalData handles all netlink_status requests — we just react to signals)
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if not global_data.is_connected("netlink_status_loaded", cb):
			global_data.connect("netlink_status_loaded", cb)

func _exit_tree() -> void:
	var signal_bus = get_node_or_null("/root/SignalBus")
	
	if signal_bus and signal_bus.wifi_connected.is_connected(_on_wifi_connected):
		signal_bus.wifi_connected.disconnect(_on_wifi_connected)

	if signal_bus and signal_bus.network_started.is_connected(_on_network_started):
		signal_bus.network_started.disconnect(_on_network_started)
	
	if signal_bus and signal_bus.network_stopped.is_connected(_on_network_stopped):
		signal_bus.network_stopped.disconnect(_on_network_stopped)

	# Disconnect GlobalData signal
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if global_data.is_connected("netlink_status_loaded", cb):
			global_data.disconnect("netlink_status_loaded", cb)

	if get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.disconnect(_on_scene_changed)

func _on_viewport_size_changed() -> void:
	_update_size()

func _update_size() -> void:
	var window_size = DisplayServer.window_get_size()
	root_control.size.x = window_size.x
	root_control.size.y = 72.0
	# print("StatusBar: Updated size to ", root_control.size)

func _on_wifi_connected(_ssid: String) -> void:
	# print("StatusBar: Received wifi_connected signal for SSID: ", _ssid)
	_set_wifi_connected(true)

func _set_wifi_connected(connected: bool) -> void:
	if wifi_icon:
		wifi_icon.texture = WIFI_CONNECTED if connected else WIFI_IDLE

func _on_network_started() -> void:
	# print("StatusBar: Received network started signal")
	_set_network_started(true)

func _on_network_stopped() -> void:
	# print("StatusBar: Received network stopped signal")
	_set_network_started(false)

func _set_network_started(connected: bool) -> void:
	# print("StatusBar: _set_network_started called, connected=", connected)
	if network_icon:
		network_icon.texture = NET_CONNECTED if connected else NET_IDLE

func _on_netlink_status_loaded():
	# print("StatusBar: Received GlobalData.netlink_status_loaded signal")
	var gd = get_node_or_null("/root/GlobalData")
	if not gd:
		# print("StatusBar: GlobalData not found in _on_netlink_status_loaded")
		return

	var s = gd.netlink_status
	if s and typeof(s) == TYPE_DICTIONARY:
		# Set wifi status based on wifi_status field
		var wifi_status = bool(s.get("wifi_status", false))
		_set_wifi_connected(wifi_status)
		# print("StatusBar: wifi_status=", wifi_status)
		
		# Set network status based on started field
		var started = bool(s.get("started", false))
		_set_network_started(started)
		# print("StatusBar: netlink started=", started)

func _on_scene_changed() -> void:
	_update_back_button_visibility()

func _update_back_button_visibility() -> void:
	if not back_button:
		return

	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_scene_file_path"):
		back_button.visible = current_scene.scene_file_path != MAIN_MENU_SCENE_PATH
		return

	back_button.visible = true

func _on_back_pressed() -> void:
	# Triggered only when the button receives GUI click input.
	var err = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != OK and not DEBUG_DISABLED:
		print("StatusBar: Failed to change scene to main_menu.tscn, error=", err)
		
