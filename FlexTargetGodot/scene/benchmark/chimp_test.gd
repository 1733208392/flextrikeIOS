extends Control

const ChimpCell = preload("res://scene/benchmark/chimp_cell.tscn")

@export var rows: int = 6
@export var columns: int = 4

var cells: Array = []
var sequence: Array = []
var current_sequence_index: int = 0
var is_sequence_phase: bool = true
var sequence_length: int = 1

@onready var grid_container: GridContainer = $CenterContainer/GridContainer
@onready var flash_timer: Timer = $FlashTimer
@onready var status_label: Label = $StatusLabel
@onready var delay_timer: Timer = $DelayTimer
@onready var title_label: Label = $TitleLabel
@onready var gameover_overlay: Panel = $GameoverOverly
@onready var countdown_label: Label = $GameoverOverly/VBoxContainer/CountDown
@onready var countdown_timer: Timer = $CountdownTimer
@onready var level_complete_overlay: Panel = $LevelCompleteOverlay
@onready var level_complete_result_label: Label = $LevelCompleteOverlay/VBoxContainer/Result
@onready var level_complete_countdown_label: Label = $LevelCompleteOverlay/VBoxContainer/CountDown
@onready var level_complete_timer: Timer = $LevelCompleteTimer

var countdown_time: int = 5
var level_complete_countdown_time: int = 5

func _ready():
	gameover_overlay.visible = false
	level_complete_overlay.visible = false
	setup_grid()
	start_sequence_phase()
	title_label.text = "LEVEL " + str(sequence_length)

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
	status_label.text = "WATCH THE SEQUENCE"
	generate_sequence()
	for i in range(sequence.size()):
		var cell_index = sequence[i]
		var cell = cells[cell_index]
		cell.show_number(i + 1)
	var reveal_timer = get_tree().create_timer(5.0)
	reveal_timer.timeout.connect(func():
		for cell_index in sequence:
			cells[cell_index].hide_number()
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
	status_label.text = "SHOOT IN ORDER"
	current_sequence_index = 0

func _on_cell_clicked(cell):
	if is_sequence_phase:
		return
	var expected_index = sequence[current_sequence_index]
	if cell.cell_index == expected_index:
		cell.show_number(current_sequence_index + 1)
		current_sequence_index += 1
		if current_sequence_index >= sequence.size():
			status_label.text = "GAME COMPLETE!"
			title_label.text = "YOUR IQ IS " + str(sequence_length)
			level_complete_overlay.visible = true
			level_complete_countdown_time = 5
			level_complete_countdown_label.text = str(level_complete_countdown_time)
			level_complete_timer.start(1.0)
	else:
		gameover_overlay.visible = true
		countdown_time = 5
		countdown_label.text = str(countdown_time)
		countdown_timer.start(1.0)

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
	title_label.text = "LEVEL " + str(sequence_length)
	status_label.text = "STATUS"
	current_sequence_index = 0
	is_sequence_phase = true
	for cell in cells:
		cell.hide_number()
	start_sequence_phase()
