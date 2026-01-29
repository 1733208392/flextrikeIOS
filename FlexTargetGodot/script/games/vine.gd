extends Node2D

# Properties
@export_range(352, 952, 1) var vine_length: float = 352:  # Current display height of vine
	set(value):
		vine_length = value
		_update_vine_region()
@export var min_length: float = 352
@export var max_length: float = 952
@export var growth_speed: float = 0.5 # Growth speed per frame
@export var total_texture_height: float = 1152  # Total height of vine texture

# State
var is_monkey_landing: bool = true
var landing_spot: Vector2 = Vector2.ZERO
var is_growing: bool = true  # Track if vine is growing or shrinking
var initial_length: float = 0.0  # Store the initial vine length

# Reference to the Sprite2D node and CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready():
	print("the node name is:" + name)
	
	# Connect to the monkey_landed signal
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("monkey_landed"):
			signal_bus.monkey_landed.connect(_on_monkey_landed)
		else:
			print("Warning: monkey_landed signal not found in SignalBus")
		
		# Connect to settings_applied signal
		if signal_bus.has_signal("settings_applied"):
			signal_bus.settings_applied.connect(_on_settings_applied)
		else:
			print("Warning: settings_applied signal not found in SignalBus")
	else:
		print("Warning: SignalBus autoload not found")
	
	# Initialize the vine length
	_update_vine_region()

func _ready_initialize_vine_state(monkey_start_side: String):
	# Detect which vine this is based on node name and set initial state based on monkey start side
	if "Left" in name:
		if monkey_start_side == "left":
			# Monkey starts on left vine: starts at min length, landing, growing
			initial_length = min_length
			vine_length = min_length
			is_monkey_landing = true
			is_growing = true
		else:
			# Monkey starts on right vine: starts at max length, not landing, shrinking
			initial_length = max_length
			vine_length = max_length
			is_monkey_landing = false
			is_growing = false
	elif "Right" in name:
		if monkey_start_side == "right":
			# Monkey starts on right vine: starts at min length, landing, growing
			initial_length = min_length
			vine_length = min_length
			is_monkey_landing = true
			is_growing = true
		else:
			# Monkey starts on left vine: starts at max length, not landing, shrinking
			initial_length = max_length
			vine_length = max_length
			is_monkey_landing = false
			is_growing = false
	else:
		# Default behavior for other vines (like VineHorizon)
		initial_length = vine_length
	
	# Connect to the monkey_landed signal
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("monkey_landed"):
			signal_bus.monkey_landed.connect(_on_monkey_landed)
		else:
			print("Warning: monkey_landed signal not found in SignalBus")
		
		# Connect to settings_applied signal
		if signal_bus.has_signal("settings_applied"):
			signal_bus.settings_applied.connect(_on_settings_applied)
		else:
			print("Warning: settings_applied signal not found in SignalBus")
	else:
		print("Warning: SignalBus autoload not found")
	
	# Initialize the vine length
	_update_vine_region()

func _process(_delta):
	# Only update if game is running
	if get_parent().current_state != get_parent().GameState.RUNNING:
		return
	
	# Continuously check if monkey is on this vine
	_check_monkey_position()
	
	# Grow when monkey is on this vine, shrink when not
	if is_monkey_landing:
		# Grow the vine when monkey is on it
		vine_length += growth_speed
		if vine_length >= max_length:
			vine_length = max_length
			# Stop growing when max is reached
	else:
		# Shrink the vine when monkey has left
		vine_length -= growth_speed
		if vine_length <= min_length:
			vine_length = min_length
			# Stop shrinking when min is reached
	
	# Update the sprite region
	_update_vine_region()

func _check_monkey_position():
	"""Continuously check if monkey is on this vine"""
	var parent = get_parent()
	if not parent:
		return
	
	var monkey = parent.get_node_or_null("Monkey")
	if not monkey:
		return
	
	# Check if monkey is closer to this vine than to other vines
	var distance_to_monkey = abs(global_position.x - monkey.global_position.x)
	var should_be_landing = distance_to_monkey < 100  # Within 100 pixels
	
	# Update landing state based on actual monkey position
	var was_landing = is_monkey_landing
	is_monkey_landing = should_be_landing
	
	if is_monkey_landing and not was_landing:
		# Monkey just landed on this vine - start growing
		is_growing = true
		print(name, ": Monkey landed, start growing")
	elif not is_monkey_landing and was_landing:
		# Monkey just left this vine - start shrinking
		is_growing = false
		print(name, ": Monkey left, start shrinking")

func _update_vine_region():
	# Get sprite reference (works in editor and runtime)
	var sprite_node = sprite if sprite else get_node_or_null("Sprite2D")
	if sprite_node:
		var current_region = sprite_node.region_rect
		
		# Ensure sprite is not centered so we can control position from top
		sprite_node.centered = false
		
		# Calculate Y position based on total texture height
		var region_y = total_texture_height - vine_length
		
		# Update the region rect (Y stays based on vine_length)
		sprite_node.region_rect = Rect2(current_region.position.x, region_y, current_region.size.x, vine_length)
	
	# Update collision shape position at the tip (bottom) of the vine
	if collision_shape:
		# Position the collision shape at the bottom of the vine
		# Since vine draws from top at (0, 0), the tip is at (0, vine_length)
		collision_shape.position = Vector2(0, vine_length)

func _on_monkey_landed():
	# This signal is now redundant since _check_monkey_position() handles continuous updates
	# But keep it for safety in case monkey lands very quickly
	_check_monkey_position()
	print(name, ": monkey_landed signal received, is_monkey_landing = ", is_monkey_landing)

func _on_settings_applied(start_side: String, new_growth_speed: float, _duration: float):
	"""Update vine growth speed and initial state from settings"""
	growth_speed = new_growth_speed
	
	# Set both vines to the same middle length
	var middle_length = (max_length + min_length) / 2
	vine_length = middle_length
	
	# Update initial state based on start_side
	if "Left" in name:
		if start_side == "left":
			# Monkey starts on left vine: landing, growing
			is_monkey_landing = true
			is_growing = true
		else:
			# Monkey starts on right vine: not landing, not growing
			is_monkey_landing = false
			is_growing = false
	elif "Right" in name:
		if start_side == "right":
			# Monkey starts on right vine: landing, growing
			is_monkey_landing = true
			is_growing = true
		else:
			# Monkey starts on left vine: not landing, not growing
			is_monkey_landing = false
			is_growing = false
	
	_update_vine_region()
	print("[", name, "] Settings applied: growth_speed = ", growth_speed, ", start_side = ", start_side, ", vine_length = ", vine_length)
