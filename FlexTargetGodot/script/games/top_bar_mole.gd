extends Node2D

@onready var score_label: Label = $VBoxContainer/HBoxContainer/Score
@onready var star_label: Label = $VBoxContainer/HBoxContainer/StarContainer/StarLabel
@onready var level_label: Label = $VBoxContainer/HBoxContainer/Level
@onready var ammo_container: HBoxContainer = $VBoxContainer/AmmoContainer

var star_count: int = 0
var ammo_icons: Array[TextureRect] = []
var max_ammo: int = 10

func _ready() -> void:
	score_label.text = "SCORE: 0"
	star_label.text = "0"

	if ammo_container:
		for child in ammo_container.get_children():
			if child is TextureRect:
				ammo_icons.append(child)
		max_ammo = ammo_icons.size()
		_update_ammo_display(max_ammo)
	
	# Initialize level label
	if level_label:
		level_label.text = "LEVEL 1"
		print("Level label initialized to: ", level_label.text)
	else:
		print("Warning: level_label not found at path $VBoxContainer/HBoxContainer/LevelLabel")

func update_score(new_score: int) -> void:
	score_label.text = "SCORE: %d" % new_score

func update_level(new_level: int) -> void:
	"""Update the level number display"""
	print("update_level called with level: ", new_level)
	if level_label:
		level_label.text = "LEVEL %d" % new_level
		print("Level label updated to: ", level_label.text)
	else:
		print("Warning: level_label is null, cannot update")

func increment_stars() -> void:
	star_count += 1
	star_label.text = str(star_count)

func _update_ammo_display(remaining: int) -> void:
	for i in range(ammo_icons.size()):
		ammo_icons[i].visible = i < remaining

func update_ammo_progress(shots_fired: int, total_shots: int) -> void:
	var total: int = max(1, total_shots)
	var remaining: int = clamp(total - shots_fired, 0, total)
	if total != max_ammo and ammo_icons.size() > 0:
		max_ammo = ammo_icons.size()
	remaining = min(remaining, max_ammo)
	_update_ammo_display(remaining)
