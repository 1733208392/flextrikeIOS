extends Node2D

@onready var score_label: Label = $VBoxContainer/HBoxContainer/Score
@onready var star_label: Label = $VBoxContainer/HBoxContainer/StarContainer/StarLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/MoleProgressBar/HBoxContainer/ProgressBar
@onready var timer_label: Label = $VBoxContainer/TimerContainer/TimerLabel
@onready var level_label: Label = $VBoxContainer/HBoxContainer/Level

var star_count: int = 0

func _ready() -> void:
	score_label.text = "score: 0"
	star_label.text = "0"
	
	# Initialize progress bar to 0
	if progress_bar:
		progress_bar.value = 0
	
	# Initialize timer label
	if timer_label:
		timer_label.text = "00:30"
	
	# Initialize level label
	if level_label:
		level_label.text = "Level 1"
		print("Level label initialized to: ", level_label.text)
	else:
		print("Warning: level_label not found at path $VBoxContainer/HBoxContainer/LevelLabel")

func update_score(new_score: int) -> void:
	score_label.text = "score: %d" % new_score

func update_level(new_level: int) -> void:
	"""Update the level number display"""
	print("update_level called with level: ", new_level)
	if level_label:
		level_label.text = "Level %d" % new_level
		print("Level label updated to: ", level_label.text)
	else:
		print("Warning: level_label is null, cannot update")

func increment_stars() -> void:
	star_count += 1
	star_label.text = str(star_count)

func update_time_progress(progress: float) -> void:
	"""Update progress bar based on time elapsed (0.0 to 1.0)"""
	if progress_bar:
		progress_bar.value = clamp(progress * 100.0, 0.0, 100.0)
	
	# Update timer display (count down from 30 to 0)
	if timer_label:
		var time_remaining = 30.0 * (1.0 - progress)
		var total_seconds: int = int(time_remaining)
		var minutes: int = total_seconds / 60
		var seconds: int = total_seconds % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]
