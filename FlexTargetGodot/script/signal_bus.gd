extends Node

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

signal wifi_connected(ssid: String)
signal network_started()
signal network_stopped()
signal monkey_landed()
signal settings_applied(start_side: String, growth_speed: float, duration: float)
signal download_progress(progress: float)
signal ota_upgrade_requested(address: String, checksum: String, version: String)

func emit_wifi_connected(ssid: String) -> void:
	wifi_connected.emit(ssid)

func emit_network_started() -> void:
	if not DEBUG_DISABLED:
		print("SignalBus: emit_network_started called")
	network_started.emit()

func emit_network_stopped() -> void:
	if not DEBUG_DISABLED:
		print("SignalBus: emit_network_stopped called")
	network_stopped.emit()

func emit_download_progress(progress: float) -> void:
	download_progress.emit(progress)

func emit_ota_upgrade_requested(address: String, checksum: String, version: String) -> void:
	ota_upgrade_requested.emit(address, checksum, version)
