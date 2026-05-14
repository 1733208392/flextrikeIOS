extends Node

# Find My Target — global overlay handler.
# Listens for greeting_received from WebSocketListener and plays a 3-second
# radar-beeping sound + full-screen red breathing (pulse) effect.
# Registered as an autoload so it works on every screen.

const DEBUG_DISABLED = true

const GREETING_DURATION: float = 3.0
const OVERLAY_COLOR: Color = Color(0.871, 0.220, 0.137, 0.0)  # red #de3823, starts fully transparent
const OVERLAY_PEAK_ALPHA: float = 0.65
const PULSE_HALF_PERIOD: float = 0.4  # seconds per fade-in or fade-out
const GREETING_SOUND = preload("res://audio/radar-beeping.mp3")

var is_active: bool = false

func _ready():
	var ws = get_node_or_null("/root/WebSocketListener")
	if ws and ws.has_signal("greeting_received"):
		ws.greeting_received.connect(_on_greeting_received)
		if not DEBUG_DISABLED:
			print("[GreetingOverlay] Connected to WebSocketListener.greeting_received")
	else:
		if not DEBUG_DISABLED:
			print("[GreetingOverlay] WebSocketListener or greeting_received signal not found")

func _on_greeting_received():
	if is_active:
		if not DEBUG_DISABLED:
			print("[GreetingOverlay] Greeting already active, ignoring duplicate")
		return

	if not DEBUG_DISABLED:
		print("[GreetingOverlay] Greeting received — starting Find My Target effect")

	is_active = true
	_show_overlay()

func _show_overlay():
	var scene_root = get_tree().current_scene
	if not scene_root:
		is_active = false
		return

	# Create a CanvasLayer so the overlay sits above all game content and the StatusBar
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	scene_root.add_child(canvas)

	# Full-screen color rect
	var rect = ColorRect.new()
	rect.color = OVERLAY_COLOR
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.size = Vector2(720, 1280)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)

	# Audio
	var audio = AudioStreamPlayer.new()
	audio.stream = GREETING_SOUND
	audio.volume_db = 0.0
	audio.autoplay = true
	canvas.add_child(audio)

	# Breathing tween — repeat pulses for the full duration
	var tween = canvas.create_tween()
	tween.set_loops()
	tween.tween_property(rect, "color:a", OVERLAY_PEAK_ALPHA, PULSE_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "color:a", 0.0, PULSE_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Auto-dismiss after GREETING_DURATION seconds
	await get_tree().create_timer(GREETING_DURATION).timeout

	tween.kill()
	canvas.queue_free()
	is_active = false

	if not DEBUG_DISABLED:
		print("[GreetingOverlay] Find My Target effect completed")
