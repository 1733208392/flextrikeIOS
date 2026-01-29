extends Node2D

# Property to identify this node as a truck
var is_truck: bool = true

# Health properties
var max_health: float = 100.0
var current_health: float = 100.0
var fruit_damage: float = 10.0

# Trunk fruit counter
var trunk_fruit_count: int = 0
var trunk_capacity: int = 5

# Signals
signal trunk_full()
signal truck_crashed()

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var hit_sound = $HitSound
@onready var crash_sound = $CrashSound
@onready var run_sound = $RunSound
@onready var health_bar = $ProgressBar
@onready var truck_collision_area = $Truck

func _ready():
	print("Truck ready with is_truck property: ", is_truck)
	
	# Set is_truck property on all child collision bodies
	var truck_body = get_node_or_null("TruckBody")
	if truck_body:
		truck_body.set_meta("is_truck", true)
		print("Set is_truck meta on TruckBody")
	
	if truck_collision_area:
		truck_collision_area.set_meta("is_truck", true)
		print("Set is_truck meta on TruckCollisionArea")
		# Connect truck collision area to detect fruits and bombs hitting the truck body
		truck_collision_area.body_entered.connect(_on_truck_body_entered)
		print("TruckCollisionArea collision detection connected")
	
	# Initialize health
	current_health = max_health
	update_health_bar()

# Reduce health when hit by fruit, play hit animation and sound
func fruit_hit():
	current_health -= fruit_damage
	current_health = max(0, current_health)  # Clamp to 0
	
	# Update health bar
	update_health_bar()
	
	# Play hit animation
	if animated_sprite:
		animated_sprite.play("hit")
	
	# Play hit sound effect
	if hit_sound and not hit_sound.playing:
		hit_sound.play()
	
	print("Truck hit by fruit! Health: ", current_health)
	
	# Check if truck is destroyed
	if current_health <= 0:
		bomb_hit()

# Reduce health to 0 when hit by bomb, play crash animation and sound
func bomb_hit():
	current_health = 0
	
	# Update health bar
	update_health_bar()
	
	# Play crash animation
	if animated_sprite:
		animated_sprite.play("crash")
	
	# Play crash sound effect
	if crash_sound and not crash_sound.playing:
		crash_sound.play()
	
	print("Truck hit by bomb! Crashed!")
	
	# Emit truck crashed signal
	truck_crashed.emit()


# Play run animation and sound effect
func run():
	# Play run animation
	if animated_sprite:
		animated_sprite.play("run")
	
	# Play run sound effect (looping)
	if run_sound and not run_sound.playing:
		run_sound.play()
	
	print("Truck running!")

# Update the health bar display
func update_health_bar():
	if health_bar:
		health_bar.value = current_health

# Handle fruits and bombs entering the main truck collision area
func _on_truck_body_entered(body: Node):
	print("Object hit truck body: ", body.name)
	
	# Check if it's a bomb
	if body.get("is_bomb") == true:
		print("Bomb hit truck body: ", body.name)
		#trigger bomb explode
		body.explode()
		bomb_hit()

	# Check if it's a fruit
	elif body.get("is_fruit") == true:
		print("Fruit hit truck body: ", body.name)
		fruit_hit()
		# Destroy the fruit after hitting the truck
		body.queue_free()

