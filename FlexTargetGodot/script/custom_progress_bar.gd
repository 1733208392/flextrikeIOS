extends Control

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

@onready var skew_shader = preload("res://shader/skew_shader.gdshader")
@onready var progress_segments = $ProgressContainer/ProgressSegments

# Progress configuration
@export var total_targets: int = 7
@export var segments_per_target: PackedInt32Array = PackedInt32Array([2, 2, 2, 2, 2, 2, 3])

var total_segments: int

# Colors for progress states
const ACTIVE_COLOR = Color(1.0, 0.6, 0.0, 1.0)  # Orange
const INACTIVE_COLOR = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray

func _ready():
	# Apply skew shader to all SkewedBar nodes
	for segment in progress_segments.get_children():
		if segment.name.begins_with("Segment"):
			for child in segment.get_children():
				if child.name.begins_with("SkewedBar"):
					var shader_material = ShaderMaterial.new()
					shader_material.shader = skew_shader
					shader_material.set_shader_parameter("skew_amount", -0.3)  # Increased skew amount for more angle
					child.material = shader_material
	
	# Initialize with all segments inactive
	update_progress(0)

func update_progress(targets_completed: int):
	"""Update progress bar based on number of targets completed"""
	# Calculate total segments
	total_segments = 0
	for seg in segments_per_target:
		total_segments += seg
	
	# Calculate total active segments based on completed targets
	var active_segments = 0
	for i in range(min(targets_completed, total_targets)):
		active_segments += segments_per_target[i]
	
	active_segments = min(active_segments, total_segments)
	
	# Update each segment's color based on progress
	for i in range(total_segments):
		var segment = progress_segments.get_child(i)
		if segment and segment.name.begins_with("Segment"):
			var bar_node = segment.get_node("SkewedBar" + str(i + 1))
			if bar_node:
				if i < active_segments:
					bar_node.color = ACTIVE_COLOR  # Active/completed
				else:
					bar_node.color = INACTIVE_COLOR  # Inactive/not completed
	
	# Debug output with segment breakdown
	if DEBUG_DISABLED and targets_completed >= 0:
		var segment_breakdown = []
		var cumulative = 0
		for i in range(total_targets):
			cumulative += segments_per_target[i]
			segment_breakdown.append("Target %d: %d segments (total: %d)" % [i, segments_per_target[i], cumulative])
		if not DEBUG_DISABLED:
			print("Progress updated: ", targets_completed, "/", total_targets, " targets (", active_segments, "/", total_segments, " segments)")
			print("Segment breakdown: ", segment_breakdown)

func reset_progress():
	"""Reset progress bar to empty state"""
	update_progress(0)
