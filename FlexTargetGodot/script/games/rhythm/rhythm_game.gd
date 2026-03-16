extends Node2D

const DEBUG_DISABLED = true

# Game constants
const NOTES = [
	"E4", "F4", "G4",
	"B3", "C4", "D4",
	"F3", "G3", "A3",
	"C3", "D3", "E3"
]
const MAX_NOTES = 8

const NOTES_TO_MIDI = {
	"C3": 48, "D3": 50, "E3": 52, "F3": 53, "G3": 55, "A3": 57, "B3": 59,
	"C4": 60, "D4": 62, "E4": 64, "F4": 65, "G4": 68, "A4": 69, "B4": 71
}

# Musical Theory: Define chords compatible with each melody note
# Format: Note -> [Midi offsets relative to melody note]
const CHORD_MAPPING = {
	"C": [0, -8, -5],   # C Major root position
	"D": [0, -9, -5],   # G Major second inversion
	"E": [0, -8, -4],   # C Major first inversion
	"F": [0, -9, -5],   # F Major root position
	"G": [0, -8, -5],   # G Major root position
	"A": [0, -9, -5],   # F Major first inversion
	"B": [0, -9, -5]    # G Major first inversion
}

# Popular Melody Library
const MELODY_LIBRARY = {
	"Twinkle Twinkle": ["C3", "C3", "G3", "G3", "A3", "A3", "G3", "F3"],
	"Mary Had A Little Lamb": ["E4", "D4", "C4", "D4", "E4", "E4", "E4", "E4"],
	"Hot Cross Buns": ["E4", "D4", "C4", "E4", "D4", "C4", "C4", "C4"],
	"London Bridge": ["G4", "F4", "G4", "F4", "E4", "F4", "G4", "D4"],
	"Ode to Joy": ["E4", "E4", "F4", "G4", "G4", "F4", "E4", "D4"],
	"Jingle Bells": ["E4", "E4", "E4", "E4", "E4", "E4", "E4", "G4"],
	"Brother John": ["C4", "D4", "E4", "C4", "C4", "D4", "E4", "C4"],
	"Old MacDonald": ["G4", "G4", "G4", "D4", "E4", "E4", "D4", "B3"],
	"Itsy Bitsy Spider": ["G3", "C4", "C4", "C4", "D4", "E4", "E4", "E4"],
	"Yankee Doodle": ["C4", "C4", "D4", "E4", "C4", "E4", "D4", "G3"]
}

# Game state
var bpm: float = 60.0
var score: int = 0
var combo: int = 0
var current_beat: int = 0
var collected_notes: Array = []
var active_tile_index: int = -1
var game_running: bool = false
var current_melody_name: String = ""
var current_melody_notes: Array = []
var current_melody_index: int = -1

# Audio synthesis variables
var playback: AudioStreamGeneratorPlayback
var sample_hz: float = 44100.0
var pulse_hz: float = 0.0
var phase: float = 0.0
var target_hz: float = 0.0
var amplitude: float = 0.0
var decay_rate: float = 0.1

# Metronome/Beat variables
var beat_hz_low: Array = [130.81, 164.81, 196.00] # C3 Major triad (C-E-G)
var beat_hz_mid: Array = [196.00, 246.94, 293.66] # G3 Major triad (G-B-D)
var beat_hz_high: Array = [261.63, 329.63, 392.00] # C4 Major triad (C-E-G)
var current_chord_hz: Array = []
var phases: Array = [0.0, 0.0, 0.0] # Individual phases for chord notes

# Node references
@onready var grid_container: GridContainer = $UI/CenterContainer/GridContainer
@onready var beat_timer: Timer = $BeatTimer
@onready var combo_label: Label = $UI/TopBar/ComboLabel
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var bpm_label: Label = $UI/BPMLabel
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var staff_display: Control = $UI/StaffDisplay
@onready var melody_player: AudioStreamPlayer = $MelodyPlayer

var tile_scene = preload("res://scene/games/rhythm/rhythm_tile.tscn")
var tiles: Array = []

func _ready() -> void:
	# Set up AudioStreamGenerator
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = sample_hz
	generator.buffer_length = 0.1
	melody_player.stream = generator
	melody_player.play()
	playback = melody_player.get_stream_playback()
	
	# Global UI Setup
	var global_status_bar = get_node_or_null("/root/StatusBar")
	if global_status_bar:
		global_status_bar.hide()
	
	# Connect MenuController
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.back_pressed.connect(_on_back_pressed)
	
	# Connect WebSocket Listener for bullet hits
	var websocket_listener = get_node_or_null("/root/WebSocketListener")
	if websocket_listener:
		websocket_listener.bullet_hit.connect(_on_bullet_hit)
		print("[RhythmGame] Connected to WebSocketListener for bullet_hit signals")
	else:
		print("[RhythmGame] WARNING: WebSocketListener not found at /root/WebSocketListener")
	
	# Start game via HTTP service
	var http_service = get_node_or_null("/root/HttpService")
	if http_service and http_service.has_method("start_game"):
		http_service.start_game(func(result, response_code, headers, body):
			print("[RhythmGame] Game started via HTTP. Response code: ", response_code)
		)
		print("[RhythmGame] HTTP Game start request sent")
	else:
		print("[RhythmGame] WARNING: HttpService not found or missing start_game method")
	
	# Initialize Grid
	_setup_grid()
	
	# Initialize Game
	_reset_round()
	_start_game()

func _setup_grid() -> void:
	for i in range(12):
		var tile = tile_scene.instantiate()
		if tile == null:
			print("[RhythmGame] FATAL: Tile scene failed to instantiate!")
			continue
		grid_container.add_child(tile)
		if tile.has_method("setup"):
			tile.setup(NOTES[i])
		else:
			print("[RhythmGame] ERROR: Tile instance missing setup method!")
		tile.tile_hit.connect(_on_tile_hit)
		tiles.append(tile)

func _start_game() -> void:
	game_running = true
	_update_labels()
	_update_bpm()
	beat_timer.start()

func _update_bpm() -> void:
	beat_timer.wait_time = 60.0 / bpm
	bpm_label.text = "BPM: %d" % int(bpm)

func _on_beat_timer_timeout() -> void:
	if not game_running: return
	
	current_beat = (current_beat + 1) % 4
	
	# Variation: 
	# Beat 0: Downbeat (Strong Low)
	# Beat 1: Upbeat (Weak Mid)
	# Beat 2: Middle Beat (Mid)
	# Beat 3: Accent/Spawn (Sharp High)
	
	if current_beat < 3:
		# Beat 0, 1, 2: Pulse all tiles
		for tile in tiles:
			tile.pulse(1.2 if current_beat == 0 else 1.1)
		
		match current_beat:
			0: _play_beat_sound(0) # Downbeat
			1: _play_beat_sound(1) # Upbeat
			2: _play_beat_sound(2) # Middle
	else:
		# Beat 3: Spawn active tile
		_play_beat_sound(3) # Accent Spawn
		_handle_beat_3()

func _handle_beat_3() -> void:
	# Check for miss from previous measure if tile was still active
	if active_tile_index != -1:
		_handle_miss()
	
	# Following the melody sequence instead of random
	if collected_notes.size() < current_melody_notes.size():
		var target_note = current_melody_notes[collected_notes.size()]
		active_tile_index = NOTES.find(target_note)
		
		# Fallback if note isn't in current grid
		if active_tile_index == -1:
			active_tile_index = randi() % 12
	else:
		# Fallback to random if sequence is somehow finished
		active_tile_index = randi() % 12
		
	tiles[active_tile_index].set_active(true)

func _on_tile_hit(note: String) -> void:
	if active_tile_index == -1: return
	
	tiles[active_tile_index].set_active(false)
	tiles[active_tile_index].flash_hit()
	active_tile_index = -1
	
	collected_notes.append(note)
	combo += 1
	score += 10 * max(1, combo)
	_update_labels()
	staff_display.queue_redraw()
	
	# Sound feedback (instant)
	_play_note_sound(note)
	
	if collected_notes.size() >= MAX_NOTES:
		_play_melody_sequence()

func _on_bullet_hit(pos: Vector2, a: int, t: int) -> void:
	"""
	Handle bullet hit signals from WebSocket.
	Parameters:
	- pos: Vector2 - The transformed hit position (game coordinates)
	- a: int - Shot identifier or frame number
	- t: int - Timestamp
	"""
	if not game_running or active_tile_index == -1:
		return
	
	# Get the currently active tile
	if active_tile_index >= 0 and active_tile_index < tiles.size():
		var active_tile = tiles[active_tile_index]
		var active_note = active_tile.note_name
		
		# Get the active tile's global rect for boundary checking
		var tile_rect = active_tile.get_global_rect()
		
		# Check if hit position is within the active tile's bounds
		if tile_rect.has_point(pos):
			# Hit is within tile bounds - trigger the hit
			_on_tile_hit(active_note)
			print("[RhythmGame] Bullet hit DETECTED on tile: ", active_note, " at position ", pos, " (a=", a, ", t=", t, ")")
		else:
			# Hit is outside tile bounds - miss
			print("[RhythmGame] Bullet hit MISSED! Hit at ", pos, " but active tile is at ", tile_rect, " (a=", a, ", t=", t, ")")
	else:
		print("[RhythmGame] Bullet hit received but no active tile to check")

func _handle_miss() -> void:
	if active_tile_index != -1:
		tiles[active_tile_index].set_active(false)
		tiles[active_tile_index].flash_miss()
		active_tile_index = -1
	
	combo = 0
	_update_labels()

func _update_labels() -> void:
	combo_label.text = "COMBO: %d" % combo
	score_label.text = "SCORE: %d" % score

func _process(_delta: float) -> void:
	_fill_audio_buffer()
	# Simple volume envelope using decay_rate set by beat/note
	amplitude = lerp(amplitude, 0.0, decay_rate)

func _fill_audio_buffer() -> void:
	if not playback: return
	
	var frames_available = playback.get_frames_available()
	
	for i in range(frames_available):
		var v = 0.0
		
		# Enhanced synthesis: Add vibrato and harmonics
		var vibrato = sin(Time.get_ticks_msec() * 0.008) * 2.0
		
		if current_chord_hz.size() > 0:
			for n in range(current_chord_hz.size()):
				var hz = current_chord_hz[n] + (vibrato if amplitude > 0.4 else 0.0)
				var increment = hz / sample_hz
				# Add a small amount of 2nd harmonic for richness
				v += sin(phases[n] * TAU) 
				v += sin(phases[n] * TAU * 2.0) * 0.2
				phases[n] = fmod(phases[n] + increment, 1.0)
			v = (v / (current_chord_hz.size() * 1.2)) * amplitude
		else:
			var hz = pulse_hz + vibrato
			var increment = hz / sample_hz
			v = sin(phase * TAU)
			v += sin(phase * TAU * 2.0) * 0.2
			phase = fmod(phase + increment, 1.0)
			v = v * amplitude
			
		playback.push_frame(Vector2(v, v))

func _play_beat_sound(beat_type: int) -> void:
	match beat_type:
		0: # Downbeat (Beat 1 of measure) - Strong Low
			current_chord_hz = beat_hz_low
			amplitude = 0.25
			decay_rate = 0.12
		1: # Upbeat (Beat 2) - Soft Mid
			current_chord_hz = beat_hz_mid
			amplitude = 0.12
			decay_rate = 0.2
		2: # Middle (Beat 3) - Normal Mid
			current_chord_hz = beat_hz_mid
			amplitude = 0.18
			decay_rate = 0.15
		3: # Accent (Beat 4) - Sharp High
			current_chord_hz = beat_hz_high
			amplitude = 0.35
			decay_rate = 0.1
	
	pulse_hz = 0.0 # Force chord mode synthesis from chord_hz array

func _play_note_sound(note: String) -> void:
	var midi = NOTES_TO_MIDI.get(note, 60)
	target_hz = 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	
	current_chord_hz = [] # Return to single note mode
	pulse_hz = target_hz
		
	amplitude = 0.5 
	decay_rate = 0.08 

func _play_melody_sequence() -> void:
	game_running = false
	beat_timer.stop()
	
	# Wait a beat before starting
	await get_tree().create_timer(60.0/bpm).timeout
	
	var index = 0
	for note in collected_notes:
		# Add a subtle visual bounce to the staff during playback
		var tween = create_tween()
		tween.tween_property(staff_display, "scale", Vector2(1.02, 1.02), 0.1)
		tween.tween_property(staff_display, "scale", Vector2(1.0, 1.0), 0.1)
		
		# Flash the tiles in sequence with the melody
		for t in tiles:
			if t.note_name == note:
				t.flash_hit()
		
		_play_harmonized_note(note)
		index += 1
		await get_tree().create_timer(60.0/bpm).timeout
	
	# Visual Countdown for 5s
	countdown_label.show()
	# Ensure it's in front of other UI elements
	countdown_label.z_index = 10
	for i in range(5, 0, -1):
		countdown_label.text = str(i)
		# Pulse the countdown number
		countdown_label.pivot_offset = countdown_label.size / 2
		countdown_label.scale = Vector2.ONE * 1.5
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout
	
	countdown_label.hide()
	
	# Increase difficulty and restart
	bpm += 5.0
	_reset_round()
	_start_game()

func _play_harmonized_note(note: String) -> void:
	var root_midi = NOTES_TO_MIDI.get(note, 60)
	var letter = note.substr(0, 1)
	var offsets = CHORD_MAPPING.get(letter, [0, -5, -8])
	
	var chord_hzes = []
	for offset in offsets:
		var midi = root_midi + offset
		var hz = 440.0 * pow(2.0, (midi - 69.0) / 12.0)
		chord_hzes.append(hz)
	
	current_chord_hz = chord_hzes
	pulse_hz = 0.0 # Force chord mode synthesis
	amplitude = 0.6
	decay_rate = 0.06 # Longer sustain for melody playback
	
func _reset_round() -> void:
	collected_notes.clear()
	current_beat = -1 # Start fresh on next beat
	active_tile_index = -1
	staff_display.queue_redraw()
	
	# Round-robin selection from melody library
	var keys = MELODY_LIBRARY.keys()
	current_melody_index = (current_melody_index + 1) % keys.size()
	current_melody_name = keys[current_melody_index]
	current_melody_notes = MELODY_LIBRARY[current_melody_name]
	print("[RhythmGame] New Round Melody (Round-Robin): ", current_melody_name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")
