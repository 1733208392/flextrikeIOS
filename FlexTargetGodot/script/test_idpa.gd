extends Node2D

@onready var idpa_target = $IDPA

func _ready():
	# Enable the target for testing by setting drill_active to true
	if idpa_target:
		idpa_target.drill_active = true
		print("[Test IDPA] Enabled drill_active for testing")
