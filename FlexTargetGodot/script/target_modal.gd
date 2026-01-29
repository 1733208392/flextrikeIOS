extends Control

@onready var title_label = $MarginContainer/Panel/VBoxContainer/HeaderContainer/TitleLabel
@onready var target_image = $MarginContainer/Panel/VBoxContainer/ContentContainer/TargetImageContainer/TargetImage
@onready var fastest_shot_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/FastestShotValue
@onready var total_time_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/TotalTimeValue
@onready var shots_count_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/ShotsCountValue
@onready var average_time_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/AverageTimeValue
@onready var accuracy_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/AccuracyValue
@onready var points_value = $MarginContainer/Panel/VBoxContainer/ContentContainer/StatsContainer/StatsGrid/PointsValue

signal modal_closed

var target_data: Dictionary = {}

func _ready():
	# Connect background click to close modal
	$ModalBackground.gui_input.connect(_on_background_input)

func setup_modal(target_name: String, data: Dictionary):
	target_data = data
	title_label.text = target_name + " Details"
	
	# Update statistics with provided data
	fastest_shot_value.text = data.get("fastest_shot", "0.0s")
	total_time_value.text = data.get("total_time", "0.0s")
	shots_count_value.text = str(data.get("shots_count", 0))
	average_time_value.text = data.get("average_time", "0.0s")
	accuracy_value.text = data.get("accuracy", "0%")
	points_value.text = data.get("points", "0/0")
	
	# Set target image if provided
	if data.has("image_texture"):
		target_image.texture = data.image_texture
	else:
		# Use placeholder or default image
		target_image.texture = null

func _on_close_button_pressed():
	modal_closed.emit()
	queue_free()

func _on_back_button_pressed():
	modal_closed.emit()
	queue_free()

func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed:
		modal_closed.emit()
		queue_free()
