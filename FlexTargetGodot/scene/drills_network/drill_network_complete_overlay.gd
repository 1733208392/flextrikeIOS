extends Control

# Simple overlay that just shows "Drill ENDs" when network drill completes

const DEBUG_ENABLED = false  # Set to false for production release

@onready var title_label = $VBoxContainer/MarginContainer/VBoxContainer/Title

func _ready():
	"""Initialize the drill network complete overlay"""
	# Make sure we're initially hidden
	visible = false

func show_completion(repeat_number: int = 0):
	"""Show the drill network completion overlay with repeat number"""
	# Update the title with repeat number
	if repeat_number > 0:
		title_label.text = tr("drill_repeat_ended") % repeat_number
	else:
		title_label.text = tr("drill_repeat_ends")
	
	visible = true
	if DEBUG_ENABLED:
		print("[drill_network_complete_overlay] Network drill completion overlay shown for repeat #%d" % repeat_number)

func hide_completion():
	"""Hide the drill network completion overlay"""
	visible = false
	if DEBUG_ENABLED:
		print("[drill_network_complete_overlay] Network drill completion overlay hidden")
