extends Area2D

# Reference to animated sprite
@onready var animated_sprite: AnimatedSprite2D = $player

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
	print("Player 1 collision disabled immediately")
	
	# Connect to area entered signal to detect collision with monkey
	area_entered.connect(_on_area_entered)
	
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
	
	print("Player 1: Game started, waiting 1 second before enabling collision...")
	# Wait 1 more second after game starts
	await get_tree().create_timer(1.0).timeout
	monitoring = true
	monitorable = true
	print("Player 1 collision re-enabled")

func _on_area_entered(area: Area2D):
	# Ignore the first collision only if monkey is on the right vine
	if not first_collision_ignored and monkey and monkey.current_vine == monkey.vine_right:
		first_collision_ignored = true
		print("Player 1: First collision ignored (monkey on right)")
		return
	
	# Check if collided with monkey or vine
	if not is_hit:
		var is_monkey = area.name == "Monkey"
		var is_vine = "Vine" in area.name
		
		if is_monkey or is_vine:
			is_hit = true
			var hit_by = "monkey" if is_monkey else "vine"
			print("Player 1 (Jiong) hit by ", hit_by, "! Area name: ", area.name)
			
			# Play hit animation
			if animated_sprite:
				animated_sprite.play("hit")
				await animated_sprite.animation_finished
			
			# Game over
			_game_over()

func _game_over():
	print("Game Over - Player 1 was hit!")
	player_hit.emit(1)
