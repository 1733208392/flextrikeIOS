extends Node2D

@onready var mesh_instance = $MeshInstance2D
@onready var audio_player = $AudioStreamPlayer

var texture: Texture2D
var grid_size = Vector2i(20, 20) # 20x20 = 400 pieces

func _ready():
	if texture:
		setup_explosion()
		explode()

func setup_explosion():
	var img_size = texture.get_size()
	
	# Create shader material
	var shader = preload("res://shader/explosion.gdshader")
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = shader
	shader_mat.set_shader_parameter("texture_size", img_size)
	shader_mat.set_shader_parameter("strength", 1.0)
	
	mesh_instance.material = shader_mat
	mesh_instance.texture = texture
	
	# Generate mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 1. Generate a grid of points with randomness (Jitter)
	# We need (grid_size.x + 1) * (grid_size.y + 1) points
	var points = []
	points.resize(grid_size.y + 1)
	
	for y in range(grid_size.y + 1):
		points[y] = []
		points[y].resize(grid_size.x + 1)
		for x in range(grid_size.x + 1):
			# Base normalized position (0.0 to 1.0)
			var u = float(x) / grid_size.x
			var v = float(y) / grid_size.y
			
			# Add jitter to internal points only (keep borders straight)
			if x > 0 and x < grid_size.x and y > 0 and y < grid_size.y:
				var jitter_x = (randf() - 0.5) * (0.8 / grid_size.x) # +/- 40% of cell width
				var jitter_y = (randf() - 0.5) * (0.8 / grid_size.y)
				u += jitter_x
				v += jitter_y
			
			points[y][x] = Vector2(u, v)
	
	# 2. Build triangles from the jittered grid
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			# Get the 4 corners for this cell
			var p00 = points[y][x]     # Top-Left
			var p10 = points[y][x+1]   # Top-Right
			var p01 = points[y+1][x]   # Bottom-Left
			var p11 = points[y+1][x+1] # Bottom-Right
			
			# Randomly flip the diagonal split for variety
			# Case A: Split / (Bottom-Left to Top-Right)
			# Case B: Split \ (Top-Left to Bottom-Right)
			var flip_diagonal = randf() > 0.5
			
			if flip_diagonal:
				# Triangle 1: p00, p10, p11 (Top-Right half)
				add_shard(st, [p00, p10, p11], img_size)
				# Triangle 2: p00, p11, p01 (Bottom-Left half)
				add_shard(st, [p00, p11, p01], img_size)
			else:
				# Triangle 1: p00, p10, p01 (Top-Left half)
				add_shard(st, [p00, p10, p01], img_size)
				# Triangle 2: p10, p11, p01 (Bottom-Right half)
				add_shard(st, [p10, p11, p01], img_size)
			
	mesh_instance.mesh = st.commit()

func add_shard(st: SurfaceTool, uvs: Array, img_size: Vector2):
	# Calculate centroid (center of the triangle)
	var center_uv = (uvs[0] + uvs[1] + uvs[2]) / 3.0
	
	# Random value for this shard (rotation/speed variation)
	var rnd = randf()
	
	# Color data passed to shader:
	# R, G = Center UV (for explosion origin)
	# B = Random seed
	var color = Color(center_uv.x, center_uv.y, rnd, 1.0)
	
	# Add the 3 vertices
	for uv in uvs:
		st.set_color(color)
		st.set_uv(uv)
		# Convert UV to local pixel position
		var pos = uv * img_size
		st.add_vertex(Vector3(pos.x, pos.y, 0))


func explode():
	audio_player.play()
	var tween = create_tween()
	# Use tween_method to animate the shader parameter reliably
	tween.tween_method(set_shader_progress, 0.0, 1.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func set_shader_progress(value: float):
	if mesh_instance and mesh_instance.material:
		mesh_instance.material.set_shader_parameter("progress", value)
