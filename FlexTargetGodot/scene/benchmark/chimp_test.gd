extends Control

const ChimpCell = preload("res://scene/benchmark/chimp_cell.tscn")

@export var grid_size: int = 4

var cells: Array = []
var sequence: Array = []
var current_sequence_index: int = 0
var is_sequence_phase: bool = true
var sequence_length: int = 4

@onready var grid_container: GridContainer = $GridContainer
@onready var flash_timer: Timer = $FlashTimer
@onready var status_label: Label = $StatusLabel
@onready var delay_timer: Timer = $DelayTimer

func _ready():
    setup_grid()
    delay_timer = Timer.new()
    delay_timer.one_shot = true
    delay_timer.timeout.connect(_on_delay_timeout)
    add_child(delay_timer)
    start_sequence_phase()

func setup_grid():
    grid_container.columns = grid_size
    for i in range(grid_size * grid_size):
        var cell = ChimpCell.instantiate()
        cell.main = self
        cell.cell_index = i
        grid_container.add_child(cell)
        cells.append(cell)
        cell.cell_clicked.connect(_on_cell_clicked)

func start_sequence_phase():
    is_sequence_phase = true
    status_label.text = "Watch the sequence"
    generate_sequence()
    current_sequence_index = 0
    flash_next_number()

func generate_sequence():
    sequence.clear()
    var available_indices = range(grid_size * grid_size)
    available_indices.shuffle()
    for i in range(sequence_length):
        sequence.append(available_indices[i])

func flash_next_number():
    if current_sequence_index >= sequence.size():
        transition_to_input_phase()
        return
    delay_timer.wait_time = 1.0
    delay_timer.start()

func _on_delay_timeout():
    var cell_index = sequence[current_sequence_index]
    var cell = cells[cell_index]
    cell.flash_number(current_sequence_index + 1)
    current_sequence_index += 1
    flash_timer.start()

func _on_flash_timer_timeout():
    flash_next_number()

func transition_to_input_phase():
    is_sequence_phase = false
    status_label.text = "Click in order"
    current_sequence_index = 0

func _on_cell_clicked(cell):
    if is_sequence_phase:
        return
    var expected_index = sequence[current_sequence_index]
    if cell.cell_index == expected_index:
        cell.glow(Color.GREEN)
        current_sequence_index += 1
        if current_sequence_index >= sequence.size():
            sequence_length += 1
            start_sequence_phase()
    else:
        cell.glow(Color.RED)
        status_label.text = "Wrong! Try again"