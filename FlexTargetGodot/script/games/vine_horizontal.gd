extends Node2D

# Properties
@export var vine_width: float = 400  # Fixed width of horizontal vine
@export var min_x: float = 0  # 
@export var max_x: float = 1600  # 
@export var change_speed: float = 0.5  # Change speed per frame
@export var total_texture_height: float = 2000  # Total width of vine texture

# State
var current_x: float = 800  # Current x position in texture
var is_monkey_on_left: bool = true  # Track which vine the monkey is on

# Reference to the Sprite2D node
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Connect to the monkey_landed signal
	if has_node("/root/SignalBus"):
		var signal_bus = get_node("/root/SignalBus")
		if signal_bus.has_signal("monkey_landed"):
			signal_bus.monkey_landed.connect(_on_monkey_landed)
			print("VineHorizontal: Connected to monkey_landed signal")
		else:
			print("Warning: monkey_landed signal not found in SignalBus")
		
		# Connect to settings_applied signal
		if signal_bus.has_signal("settings_applied"):
			signal_bus.settings_applied.connect(_on_settings_applied)
			print("VineHorizontal: Connected to settings_applied signal")
		else:
			print("Warning: settings_applied signal not found in SignalBus")
	else:
		print("Warning: SignalBus autoload not found")
	
	# Initialize the vine region
	_update_vine_region()

func _initialize_vine_state(monkey_start_side: String):
	
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
	
	# Initialize the vine region
	_update_vine_region()

func _process(_delta):
	# Only update if game is running
	if get_parent().current_state != get_parent().GameState.RUNNING:
		return
	
	# Move towards the monkey's current vine
	var should_move_left = is_monkey_on_left
	
	if should_move_left:
		current_x += change_speed
		if current_x >= max_x:
			current_x = max_x
	else:
		current_x -= change_speed
		if current_x <= min_x:
			current_x = min_x

	#print("VineHorizontal: current_x = ", current_x, ", should_move_left = ", should_move_left)
	
	# Update the sprite region
	_update_vine_region()

func _on_monkey_landed():
	# Check which vine the monkey is on by getting monkey's current_vine
	var parent = get_parent()
	if not parent:
		return
	
	var monkey = parent.get_node_or_null("Monkey")
	if not monkey:
		return
	
	# Update based on monkey's current vine
	is_monkey_on_left = (monkey.current_vine == monkey.vine_left)
	
	print("VineHorizontal: Monkey landed on ", "left" if is_monkey_on_left else "right", " vine")

func _update_vine_region():
	# Get sprite reference (works in editor and runtime)
	var sprite_node = sprite if sprite else get_node_or_null("Sprite2D")
	if sprite_node:
		var current_region = sprite_node.region_rect
		
		# Ensure sprite is not centered so we can control position from top
		sprite_node.centered = false
		
		# Update the region rect with fixed height, changing Y position
		sprite_node.region_rect = Rect2(current_x, current_region.position.y, current_region.size.x, vine_width)

func _on_settings_applied(start_side: String, new_change_speed: float, _duration: float):
	"""Update vine change speed and initial position from settings"""
	change_speed = new_change_speed
	
	# Update initial position based on start_side
	if start_side == "left":
		current_x = min_x
		is_monkey_on_left = true
	else:
		current_x = max_x
		is_monkey_on_left = false
	
	_update_vine_region()
	print("[VineHorizontal] Settings applied: change_speed = ", change_speed, ", start_side = ", start_side)
