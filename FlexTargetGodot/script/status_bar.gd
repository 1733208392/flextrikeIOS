extends CanvasLayer

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

const WIFI_IDLE := preload("res://asset/wifi.fill.idle.png")
const WIFI_CONNECTED := preload("res://asset/wifi.fill.connect.png")
const NET_IDLE := preload("res://asset/connectivity.idle.png")
const NET_CONNECTED := preload("res://asset/connectivity.active.png")
const BT_MASTER := preload("res://asset/bluetooth-icon.png")  # Placeholder, replace with actual Bluetooth master icon

@onready var wifi_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/WifiIcon")
@onready var network_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/ConnectivityIcon")
@onready var bluetooth_icon: TextureRect = get_node_or_null("Root/Panel/HBoxContainer/BluetoothIcon")
@onready var root_control: Control = get_node_or_null("Root")

func _ready() -> void:
	# print("StatusBar: _ready() called")
	add_to_group("status_bar")
	_set_wifi_connected(false)
	_set_network_started(false)
	_set_bluetooth_master(false)
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

	# Listen for netlink status updates so UI can reflect started state
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data:
		var cb = Callable(self, "_on_netlink_status_loaded")
		if not global_data.is_connected("netlink_status_loaded", cb):
			global_data.connect("netlink_status_loaded", cb)
			# print("StatusBar: Connected to GlobalData.netlink_status_loaded signal")

	# Request netlink status after signal connections are established
	# print("StatusBar: Requesting netlink status from HttpService")
	HttpService.netlink_status(Callable(self, "_on_netlink_status_response"))

	# Update size after frame
	call_deferred("_update_size")
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _enter_tree() -> void:
	# Called earlier than _ready, but we'll request netlink status in _ready instead
	# to ensure signal bus connections are established first
	pass

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

func _set_bluetooth_master(is_master: bool) -> void:
	# print("StatusBar: _set_bluetooth_master called, is_master=", is_master)
	if bluetooth_icon:
		if is_master:
			bluetooth_icon.texture = BT_MASTER
			bluetooth_icon.visible = true
		else:
			bluetooth_icon.visible = false

func _on_netlink_status_response(result, response_code, headers, body):
	# print("StatusBar: netlink_status response - code:", response_code)
	# Forward to GlobalData to parse and store
	if has_node("/root/GlobalData"):
		GlobalData.update_netlink_status_from_response(result, response_code, headers, body)

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
		
		# Set Bluetooth status based on work_mode field
		var work_mode = str(s.get("work_mode", "slave")).to_lower()
		var is_master = (work_mode == "master")
		_set_bluetooth_master(is_master)
		# print("StatusBar: work_mode=", work_mode, ", is_master=", is_master)
