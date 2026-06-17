extends Control

const ChimpCell = preload("res://scene/benchmark/chimp_cell.tscn")

@export var rows: int = 6
@export var columns: int = 4
@export var base_reveal_time: float = 1.0
@export var reveal_time_per_item: float = 3
@export var max_reveal_time: float = 20.0

var cells: Array = []
var reveal_countdown_time: float = 0.0
var sequence: Array = []
var current_sequence_index: int = 0
var is_sequence_phase: bool = true
var sequence_length: int = 1

@onready var grid_container: GridContainer = $CenterContainer/GridContainer
@onready var flash_timer: Timer = $FlashTimer
@onready var status_label: Label = $HBoxContainerBottom/StatusLabel
@onready var delay_timer: Timer = $DelayTimer
@onready var title_label: Label = $HBoxContainerTop/TitleLabel
@onready var gameover_overlay: Panel = $GameoverOverly
@onready var countdown_label: Label = $GameoverOverly/VBoxContainer/CountDown
@onready var countdown_timer: Timer = $CountdownTimer
@onready var level_complete_overlay: Panel = $LevelCompleteOverlay
@onready var level_complete_result_label: Label = $LevelCompleteOverlay/VBoxContainer/Result
@onready var level_complete_countdown_label: Label = $LevelCompleteOverlay/VBoxContainer/CountDown
@onready var level_complete_timer: Timer = $LevelCompleteTimer
@onready var reveal_countdown_label: Label = $HBoxContainerBottom/RevealCountdownLabel
@onready var back_button: Button = $HBoxContainerTop/Button

var countdown_time: int = 5
var reveal_timer: SceneTreeTimer
var level_complete_countdown_time: int = 5
var ws_listener: Node
var remote_button_sound: AudioStream = preload("res://audio/remote_button_sound.mp3")
var audio_player: AudioStreamPlayer
var menu_controller: Node
var previous_bullet_spawning_enabled := true

func _ready():
	gameover_overlay.visible = false
	level_complete_overlay.visible = false
	setup_grid()
	# Setup audio player for button sound
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = remote_button_sound
	add_child(audio_player)
	# Enable UI click injection for this scene
	ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		previous_bullet_spawning_enabled = ws_listener.get_bullet_spawning_enabled()
		ws_listener.set_bullet_spawning_enabled(false)
		ws_listener.set_emit_click_for_ui(true)
		print("[ChimpTest] Enabled UI click injection and disabled gameplay bullet_hit emission")
	# Wire back button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		print("[ChimpTest] Wired back button")
	# Connect to MenuController for back and home buttons
	menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.back_pressed.connect(_on_back_pressed)
		menu_controller.homepage_pressed.connect(_on_homepage_pressed)
	start_sequence_phase()
	title_label.text = tr("chimp_level") + str(sequence_length)

func setup_grid():
	grid_container.columns = columns
	for i in range(rows * columns):
		var cell = grid_container.get_child(i)
		cell.main = self
		cell.cell_index = i
		cells.append(cell)
		cell.cell_clicked.connect(_on_cell_clicked)

func start_sequence_phase():
	is_sequence_phase = true
	status_label.text = tr("chimp_watch_sequence")
	_set_cells_interactive(false)
	generate_sequence()
	for i in range(sequence.size()):
		var cell_index = sequence[i]
		var cell = cells[cell_index]
		cell.show_number(i + 1)
	
	# Calculate reveal time using sublinear scaling: base_time + scale_factor * sqrt(sequence_length)
	# This provides more time for longer sequences without making them trivial
	var calculated_reveal_time = base_reveal_time + (reveal_time_per_item * sqrt(float(sequence_length)))
	reveal_countdown_time = minf(calculated_reveal_time, max_reveal_time)
	
	# Show and start countdown timer for visual feedback
	reveal_countdown_label.text = "(%.1fs)" % reveal_countdown_time
	reveal_countdown_label.visible = true
	
	# Create timer for hiding sequence
	reveal_timer = get_tree().create_timer(reveal_countdown_time)
	reveal_timer.timeout.connect(func():
		for cell_index in sequence:
			cells[cell_index].hide_number()
		reveal_countdown_label.visible = false
		transition_to_input_phase()
	)

func generate_sequence():
	sequence.clear()
	var available_indices = range(rows * columns)
	available_indices.shuffle()
	for i in range(sequence_length):
		sequence.append(available_indices[i])

func transition_to_input_phase():
	is_sequence_phase = false
	status_label.text = tr("chimp_shoot_order")
	current_sequence_index = 0
	_set_cells_interactive(true)

func _on_cell_clicked(cell):
	if is_sequence_phase:
		return
	var expected_index = sequence[current_sequence_index]
	if cell.cell_index == expected_index:
		cell.show_number(current_sequence_index + 1)
		_play_button_sound()
		current_sequence_index += 1
		if current_sequence_index >= sequence.size():
			status_label.text = tr("chimp_game_complete")
			title_label.text = tr("chimp_level") + str(sequence_length)
			level_complete_overlay.visible = true
			level_complete_countdown_time = 5
			level_complete_countdown_label.text = str(level_complete_countdown_time)
			level_complete_timer.start(1.0)
	else:
		gameover_overlay.visible = true
		countdown_time = 5
		countdown_label.text = str(countdown_time)
		countdown_timer.start(1.0)

func _on_websocket_bullet_hit(pos: Vector2, _a: int = 0, _t: int = 0):
	for cell in cells:
		if cell.get_global_rect().has_point(pos):
			_on_cell_clicked(cell)
			break

func _play_button_sound():
	# Play the remote button sound when a cell is hit correctly
	if audio_player and remote_button_sound:
		audio_player.play()

func _on_back_pressed():
	# Handle back button press - return to games menu
	_restore_websocket_input_state()
	get_tree().change_scene_to_file("res://scene/games/menu/menu.tscn")

func _on_homepage_pressed():
	# Handle home button press - return to main menu
	_restore_websocket_input_state()
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")

func _exit_tree():
	_restore_websocket_input_state()

func _restore_websocket_input_state():
	if ws_listener:
		ws_listener.set_emit_click_for_ui(false)
		ws_listener.set_bullet_spawning_enabled(previous_bullet_spawning_enabled)

func _on_countdown_timer_timeout():
	countdown_time -= 1
	if countdown_time > 0:
		countdown_label.text = str(countdown_time)
	else:
		countdown_timer.stop()
		gameover_overlay.visible = false
		restart_game()

func _on_level_complete_timer_timeout():
	level_complete_countdown_time -= 1
	if level_complete_countdown_time > 0:
		level_complete_countdown_label.text = str(level_complete_countdown_time)
	else:
		level_complete_timer.stop()
		level_complete_overlay.visible = false
		sequence_length += 1
		restart_game()

func restart_game():
	title_label.text = tr("chimp_level") + str(sequence_length)
	status_label.text = tr("chimp_status")
	current_sequence_index = 0
	is_sequence_phase = true
	for cell in cells:
		cell.hide_number()
	_set_cells_interactive(false)
	start_sequence_phase()

func _set_cells_interactive(enabled: bool) -> void:
	for cell in cells:
		if cell and cell.has_method("set_interactive_enabled"):
			cell.set_interactive_enabled(enabled)
