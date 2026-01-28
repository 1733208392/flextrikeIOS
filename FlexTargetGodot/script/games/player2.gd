extends Area2D

# Reference to animated sprite
@onready var animated_sprite: AnimatedSprite2D = $Xuyang

# Game state
var is_hit: bool = false
var first_collision_ignored: bool = false

# Reference to monkey
@onready var monkey: Node2D = get_parent().get_node("Monkey")

signal player_hit(player_id: int)

func _ready():
	# Disable collision immediately (before countdown ends)
	monitoring = false
	monitorable = false
	print("Player 2 collision disabled immediately")
	
	# Connect to area entered signal to detect collision with monkey
	area_entered.connect(_on_area_entered)
	print("Player2 ready, collision monitoring enabled: ", monitoring)
	print("Player2 collision layer: ", collision_layer, ", mask: ", collision_mask)
	
	# Play idle animation by default
	if animated_sprite:
		animated_sprite.play("idle")
	
	# Wait for game to start and then re-enable after 1 second
	_wait_for_game_start_and_reenable_collision()

func _wait_for_game_start_and_reenable_collision():
	"""Wait for game to start then re-enable collision after 1 second"""
	# Wait for game to start (when tree is unpaused)
	while get_tree().paused:
		await get_tree().create_timer(0.1).timeout
	
	print("Player 2: Game started, waiting 1 second before enabling collision...")
	# Wait 1 more second after game starts
	await get_tree().create_timer(1.0).timeout
	monitoring = true
	monitorable = true
	print("Player 2 collision re-enabled")

func _on_area_entered(area: Area2D):
	print("Player2 _on_area_entered called! Collided with: ", area.name, " (type: ", area.get_class(), ")")
	
	# Ignore the first collision only if monkey is on the left vine
	if not first_collision_ignored and monkey and monkey.current_vine == monkey.vine_left:
		first_collision_ignored = true
		print("First collision ignored (monkey on left)")
		return
	
	# Check if collided with monkey or vine
	if not is_hit:
		var is_monkey = area.name == "Monkey"
		var is_vine = "Vine" in area.name
		
		print("Is monkey: ", is_monkey, ", Is vine: ", is_vine, ", is_hit: ", is_hit)
		
		if is_monkey or is_vine:
			is_hit = true
			var hit_by = "monkey" if is_monkey else "vine"
			print("Player 2 (Xuyang) HIT by ", hit_by, "! Area name: ", area.name)
			
			# Play hit animation and wait for it to finish before game over
			if animated_sprite:
				print("Playing hit animation...")
				animated_sprite.play("hit")
				# Wait for animation in a separate call to avoid blocking
				_wait_for_animation_and_game_over()
			else:
				# No animation, game over immediately
				_game_over()
	else:
		print("Already hit, ignoring collision")

func _wait_for_animation_and_game_over():
	# Wait for animation to finish before pausing
	# The "hit" animation is set to loop=true in the scene, so it won't emit animation_finished
	# Use a timer instead to show the animation for a bit
	print("Waiting for hit animation to play...")
	
	# Wait 1 second to show the hit animation (5 frames at 5fps = 1 second)
	await get_tree().create_timer(1.0).timeout
	
	print("Animation time elapsed, proceeding to game over")
	_game_over()

func _game_over():
	print("Game Over - Player 2 was hit!")
	player_hit.emit(2)
