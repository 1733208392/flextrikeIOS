extends CanvasLayer

const DEBUG_DISABLED = true  # Set to true to disable debug prints for production

var previous_emit_click_for_ui := false  # Track previous UI click injection state

func _ready():
	# Enable UI click injection for game_over_overlay
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		previous_emit_click_for_ui = ws_listener.get_emit_click_for_ui()
		ws_listener.set_emit_click_for_ui(true)
		if not DEBUG_DISABLED:
			print("[GameOverOverlay] Enabled UI click injection, previous state was: ", previous_emit_click_for_ui)
	else:
		if not DEBUG_DISABLED:
			print("[GameOverOverlay] WebSocketListener not found for UI click injection")

func _exit_tree():
	# Disable UI click injection when exiting game_over_overlay
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.set_emit_click_for_ui(false)
		if not DEBUG_DISABLED:
			print("[GameOverOverlay] Disabled UI click injection on exit")
