extends Node2D

signal target_hit(zone: String, points: int, hit_position: Vector2)

const DEBUG_DISABLED = false

# Bullet hole system (GPU-instanced only)

# GPU instanced bullet hole rendering (optional - faster at scale)
var bullet_hole_multimeshes: Array = []
var bullet_hole_textures: Array = []
var max_instances_per_texture: int = 32
var active_instances: Dictionary = {}

# Reusable Transform2D to avoid allocating a new Transform each shot
var _reusable_transform: Transform2D = Transform2D()

# Sound throttling for impact SFX (copied from ipsc_mini)
var last_sound_time: float = 0.0
var sound_cooldown: float = 0.05
var max_concurrent_sounds: int = 2
var active_sounds: int = 0

# Explosion effect
const SHOTS_TO_EXPLODE = 10
var hit_count: int = 0
var is_restoring: bool = false
const ExplosionEffectScene = preload("res://scene/explosion_effect.tscn")

# Image transfer state
var image_transfer_state = {
	"active": false,
	"image_name": "",
	"total_chunks": 0,
	"chunk_size": 0,
	"total_size": 0,
	"chunks_received": {},  # Dictionary to track which chunks have been received
	"image_data": ""  # Accumulated base64 data
}

@onready var image_display = $Target
@onready var question_mark = $Questionmark
@onready var mask_node = $Mask
@onready var status_label = $StatusLabel
@onready var instruction_label = $InstructionLabel
var default_image_texture: Texture = null

# NOTE: `restore_default_image_scaled` removed — project asset no longer needs scaling.
# Calls previously used to scale/center the default image are now replaced with a direct
# assignment to `image_display.texture = default_image_texture` where appropriate.

func _ready():
	# Initialize bullet hole pool for performance
	initialize_bullet_hole_pool()
	
	# Connect to WebSocketListener for netlink messages
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.data_received.connect(_on_websocket_message)
		# Connect to bullet hit signal for impact effects
		ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
		if not DEBUG_DISABLED:
			print("[CustomTarget] Connected to WebSocketListener")
			print("[CustomTarget] Connected to bullet_hit signal")
	else:
		if not DEBUG_DISABLED:
			print("[CustomTarget] WebSocketListener singleton not found!")
	
	# Initialize UI
	status_label.text = tr("custom_target_status_waiting")
	# Remember the editor-assigned/default texture so we can restore it
	default_image_texture = image_display.texture
	# Keep status hidden until a transfer starts
	status_label.visible = false
	# Localize instruction label
	if instruction_label:
		instruction_label.text = tr("custom_target_instruction")
	# Clear the displayed texture until we load a saved/custom image
	_set_image_texture(null)
	
	# Try to load a previously saved image from HttpService
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		# Request saved image (if any) with data_id "custom_target_image"
		http_service.load_game(Callable(self, "_on_load_image_response"), "custom_target_image")

# Initialize bullet hole pool for performance optimization
func initialize_bullet_hole_pool():
	"""Pre-instantiate bullet holes for performance optimization"""
	
	# --- Initialize GPU instanced MultiMesh system (preferred) ---
	load_bullet_hole_textures()

	# Clear any existing multimeshes
	for mm in bullet_hole_multimeshes:
		if is_instance_valid(mm):
			mm.queue_free()
	bullet_hole_multimeshes.clear()
	active_instances.clear()

	# Create a MultiMeshInstance2D for each texture so we can render many holes cheaply
	for i in range(bullet_hole_textures.size()):
		var multimesh_instance = MultiMeshInstance2D.new()
		add_child(multimesh_instance)
		multimesh_instance.z_index = 1

		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.instance_count = max_instances_per_texture
		multimesh.visible_instance_count = 0

		var mesh = create_bullet_hole_mesh(bullet_hole_textures[i])
		multimesh.mesh = mesh
		multimesh_instance.multimesh = multimesh

		# Try to propagate material/texture to the instance for compatibility across engine versions
		if mesh and mesh.material:
			for prop in multimesh_instance.get_property_list():
				if prop.name == "material":
					multimesh_instance.material = mesh.material
					if multimesh_instance.material is ShaderMaterial:
						multimesh_instance.material.set_shader_parameter("texture_albedo", bullet_hole_textures[i])
					break

		# Some engine versions expose a `texture` property on MultiMeshInstance2D
		for p in multimesh_instance.get_property_list():
			if p.name == "texture":
				multimesh_instance.set("texture", bullet_hole_textures[i])
				break

		bullet_hole_multimeshes.append(multimesh_instance)
		active_instances[i] = 0

	# (Legacy node pool removed) — MultiMesh is the only bullet hole system now


func load_bullet_hole_textures():
	"""Load bullet hole textures used for MultiMesh instancing"""
	bullet_hole_textures = [
		load("res://asset/bullet_hole1.png"),
		load("res://asset/bullet_hole2.png"),
		load("res://asset/bullet_hole3.png"),
		load("res://asset/bullet_hole4.png"),
		load("res://asset/bullet_hole5.png"),
		load("res://asset/bullet_hole6.png")
	]

	# Verify all textures loaded (silently fail if missing)
	for i in range(bullet_hole_textures.size()):
		if not bullet_hole_textures[i] and not DEBUG_DISABLED:
			print("[CustomTarget] Warning: Failed to load bullet hole texture ", i + 1)


func create_bullet_hole_mesh(texture: Texture2D) -> QuadMesh:
	"""Create a QuadMesh with a shader material for the provided texture"""
	var mesh = QuadMesh.new()
	mesh.size = texture.get_size()

	var shader_material = ShaderMaterial.new()
	var shader = load("res://shader/bullet_hole_instanced.gdshader")
	if shader:
		shader_material.shader = shader
		shader_material.set_shader_parameter("texture_albedo", texture)

	mesh.material = shader_material
	return mesh


func clear_all_bullet_holes() -> void:
	# Reset instanced MultiMesh counts
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0
	hit_count = 0

# Legacy node-pool removed; MultiMesh instancing is the only bullet hole system now.

func spawn_bullet_hole(local_position: Vector2):
	"""Spawn a bullet hole at the specified local position using object pool"""
	# Use GPU-instanced MultiMesh; if not available, silently ignore (no legacy nodes)
	if bullet_hole_multimeshes.size() == 0 or bullet_hole_textures.size() == 0:
		if not DEBUG_DISABLED:
			print("[CustomTarget] No MultiMesh bullet hole instances available; skipping spawn")
		return

	var texture_index = randi() % bullet_hole_textures.size()
	if texture_index >= bullet_hole_multimeshes.size():
		return

	var mm_inst = bullet_hole_multimeshes[texture_index]
	var multimesh = mm_inst.multimesh
	var current_count = active_instances.get(texture_index, 0)
	if current_count >= max_instances_per_texture:
		return

	# Reuse preallocated transform to avoid allocations
	var t = _reusable_transform
	var scale_factor = randf_range(0.6, 0.8)
	# Uniform scale (no rotation)
	t.x = Vector2(scale_factor, 0.0)
	t.y = Vector2(0.0, scale_factor)
	t.origin = local_position

	multimesh.set_instance_transform_2d(current_count, t)
	multimesh.visible_instance_count = current_count + 1
	active_instances[texture_index] = current_count + 1

# Handle incoming WebSocket messages
func _on_websocket_message(message: String):
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result != OK:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Error parsing JSON: ", message.substr(0, 200))
		return
	
	var parsed = json.get_data()
	
	if not parsed or parsed.is_empty():
		if not DEBUG_DISABLED:
			print("[CustomTarget] Empty or null parsed data")
		return
	
	# Check if this is a netlink type message
	if parsed.has("type") and parsed["type"] == "netlink" and parsed.has("data"):
		var data = parsed["data"]
		
		if not DEBUG_DISABLED:
			var command = data.get("command", "unknown")
			var chunk_idx = data.get("chunk_index", "N/A")
			print("[CustomTarget] Received netlink message - Command: %s, Chunk: %s" % [command, chunk_idx])
		
		# Handle image_transfer_start message
		if data.has("command") and data["command"] == "image_transfer_start":
			_handle_image_transfer_start(data)
			return
		
		# Handle image_chunk message
		if data.has("command") and data["command"] == "image_chunk":
			_handle_image_chunk(data)
			return
		
		# Handle image_transfer_complete message
		if data.has("command") and data["command"] == "image_transfer_complete":
			_handle_image_transfer_complete(data)
			return

		# Handle image_transfer_ready message (mobile app indicates it will start sending)
		if data.has("command") and data["command"] == "image_transfer_ready":
			# Send a simple ack back via HttpService.netlink_forward_data so the mobile app knows we're ready
			var http_service = get_node_or_null("/root/HttpService")
			if http_service:
				var content_dict = {"ack": "image_transfer_ready"}
				http_service.netlink_forward_data(func(result, response_code, _headers, _body):
					if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
						if not DEBUG_DISABLED:
							print("[CustomTarget] Sent image_transfer_ready ack successfully")
					else:
						if not DEBUG_DISABLED:
							print("[CustomTarget] Failed to send image_transfer_ready ack:", result, response_code)
				, content_dict)
			else:
				if not DEBUG_DISABLED:
					print("[CustomTarget] HttpService not available; cannot send image_transfer_ready ack")
			# Update UI to show we are ready to receive
			status_label.visible = true
			status_label.text = tr("custom_target_status_ready")
			return
		
		if not DEBUG_DISABLED:
			print("[CustomTarget] Unknown netlink command: ", data.get("command", "none"))

# Handle the image transfer start command
func _handle_image_transfer_start(data: Dictionary):
	if not DEBUG_DISABLED:
		print("[CustomTarget] Image transfer start: ", data)
	
	image_transfer_state["active"] = true
	image_transfer_state["image_name"] = data.get("image_name", "unknown")
	image_transfer_state["total_chunks"] = data.get("total_chunks", 0)
	image_transfer_state["chunk_size"] = data.get("chunk_size", 0)
	image_transfer_state["total_size"] = data.get("total_size", 0)
	image_transfer_state["chunks_received"] = {}
	image_transfer_state["chunks_data"] = {}  # Store individual chunks
	image_transfer_state["image_data"] = ""  # Keep for legacy compatibility
	
	# Update UI: show status when transfer starts
	status_label.visible = true
	status_label.text = tr("custom_target_status_receiving_total") % image_transfer_state["total_chunks"]
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Image transfer started: ", image_transfer_state["image_name"])
		print("  Total chunks: ", image_transfer_state["total_chunks"])
		print("  Chunk size: ", image_transfer_state["chunk_size"])
		print("  Total size: ", image_transfer_state["total_size"])

# Handle image chunk data
func _handle_image_chunk(data: Dictionary):
	if not image_transfer_state["active"]:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Received chunk but no active transfer")
		return
	
	var chunk_index = data.get("chunk_index", -1)
	var chunk_data = data.get("data", "")
	
	# Convert chunk_index to integer (JSON might send it as string or float)
	if chunk_index is String:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Converting chunk_index from string '%s' to integer" % chunk_index)
		chunk_index = int(chunk_index)
	elif chunk_index is float:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Converting chunk_index from float '%.1f' to integer" % chunk_index)
		chunk_index = int(chunk_index)
	
	if chunk_index == -1:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Invalid chunk index")
		return
	
	# Check for duplicate chunks
	if image_transfer_state["chunks_received"].has(chunk_index):
		if not DEBUG_DISABLED:
			print("[CustomTarget] ⚠️  DUPLICATE chunk %d received (chunk_data length: %d), ignoring" % [
				chunk_index,
				chunk_data.length()
			])
		return
	
	# Add chunk to accumulated data - store in order
	# Create ordered storage if needed
	if not image_transfer_state.has("chunks_data"):
		image_transfer_state["chunks_data"] = {}
	
	# Store the chunk data as-is (will handle padding during reconstruction)
	image_transfer_state["chunks_data"][chunk_index] = chunk_data
	image_transfer_state["chunks_received"][chunk_index] = true
	
	var received_count = image_transfer_state["chunks_received"].size()
	var expected_count = image_transfer_state["total_chunks"]
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Received chunk %d/%d (size: %d bytes, total so far: %d bytes)" % [
			chunk_index,
			expected_count - 1,
			chunk_data.length(),
			image_transfer_state["image_data"].length()
		])
	
	# Update status label while receiving
	status_label.visible = true
	status_label.text = tr("custom_target_status_receiving_progress") % [received_count, expected_count]
	
	# Check if all chunks have been received
	if received_count == expected_count:
		# Verify we have all chunks from 0 to total_chunks-1
		var all_chunks_present = true
		for i in range(expected_count):
			if not image_transfer_state["chunks_received"].has(i):
				all_chunks_present = false
				if not DEBUG_DISABLED:
					print("[CustomTarget] Missing chunk: %d" % i)
		
		# After checking all indices, handle result
		if all_chunks_present:
			if not DEBUG_DISABLED:
				print("[CustomTarget] All %d chunks received successfully!" % expected_count)
			_process_complete_image()
		else:
			if not DEBUG_DISABLED:
				print("[CustomTarget] Chunk count matches but some chunks are missing!")
				var received_indices = []
				for idx in image_transfer_state["chunks_received"].keys():
					received_indices.append(idx)
				received_indices.sort()
				print("[CustomTarget] Received chunk indices: ", received_indices)

# Handle image transfer complete command
func _handle_image_transfer_complete(data: Dictionary):
	if not DEBUG_DISABLED:
		print("[CustomTarget] Image transfer complete signal received")
		print("[CustomTarget] Status: ", data.get("status", "unknown"))
	
	# This is a signal that the server has finished sending all chunks
	# If we've already received all chunks, this is just confirmation
	# If we haven't, we should wait a bit or trigger processing
	var received_count = image_transfer_state["chunks_received"].size()
	var expected_count = image_transfer_state["total_chunks"]
	
	if received_count == expected_count:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Confirmed: all chunks received, processing...")
		_process_complete_image()
	else:
		if not DEBUG_DISABLED:
			print("[CustomTarget] ⚠️  Transfer complete but only received %d/%d chunks" % [received_count, expected_count])
		# Show incomplete transfer status
		status_label.visible = true
		status_label.text = tr("custom_target_status_transfer_complete") % [received_count, expected_count]

# Process the complete image once all chunks are received
func _process_complete_image():
	if not DEBUG_DISABLED:
		print("[CustomTarget] All chunks received! Processing image...")
	
	var decoded_bytes: PackedByteArray = PackedByteArray()
	
	# Reconstruct base64 string in correct order
	var base64_data = ""
	if image_transfer_state.has("chunks_data"):
		# First pass: collect all chunks and show their boundaries
		var chunk_boundaries = []
		var cumulative_length = 0
		
		for i in range(image_transfer_state["total_chunks"]):
			if image_transfer_state["chunks_data"].has(i):
				var chunk_data_str = image_transfer_state["chunks_data"][i]
				var chunk_start = cumulative_length
				var chunk_end = cumulative_length + chunk_data_str.length()
				chunk_boundaries.append({
					"index": i,
					"start": chunk_start,
					"end": chunk_end,
					"length": chunk_data_str.length(),
					"raw_first_20": chunk_data_str.substr(0, min(20, chunk_data_str.length())),
					"raw_last_20": chunk_data_str.substr(max(0, chunk_data_str.length() - 20)),
					"has_padding": chunk_data_str.contains("=")
				})
				cumulative_length += chunk_data_str.length()
		
		if not DEBUG_DISABLED and image_transfer_state["total_chunks"] <= 10:
			print("[CustomTarget] === CHUNK ANALYSIS ===")
			for cb in chunk_boundaries:
				print("[CustomTarget] Chunk %d: start=0x%04X, end=0x%04X, len=%d, padding=%s" % [
					cb["index"], cb["start"], cb["end"], cb["length"], cb["has_padding"]
				])
			print("[CustomTarget] Concatenated position map above shows where each chunk will be in final base64")
		
		# Second pass: decode each chunk to binary, then concatenate binary
		# This is the correct way to handle chunked base64 data
		var all_binary_data = PackedByteArray()
		
		for i in range(image_transfer_state["total_chunks"]):
			if image_transfer_state["chunks_data"].has(i):
				var chunk_base64 = image_transfer_state["chunks_data"][i]
				
				# Decode this chunk to binary
				var chunk_binary = Marshalls.base64_to_raw(chunk_base64)
				if chunk_binary == null or chunk_binary.is_empty():
					if not DEBUG_DISABLED:
						print("[CustomTarget] Error decoding chunk %d from base64" % i)
						status_label.visible = true
						status_label.text = tr("custom_target_status_error_decode_chunk") % i
					return
				
				# Append to accumulated binary
				all_binary_data.append_array(chunk_binary)
				
				if not DEBUG_DISABLED and i < 3:
					print("[CustomTarget] Chunk %d: base64_len=%d, binary_len=%d" % [
						i, chunk_base64.length(), chunk_binary.size()
					])
			else:
				if not DEBUG_DISABLED:
					print("[CustomTarget] Error: Chunk %d is missing during reconstruction!" % i)
					status_label.visible = true
					status_label.text = tr("custom_target_status_error_missing_chunk")
				return
		
		if not DEBUG_DISABLED:
			print("[CustomTarget] ✅ All chunks decoded to binary successfully")
			print("[CustomTarget] Total binary size: %d bytes" % all_binary_data.size())
		
		# Now we have the complete binary data - already decoded!
		decoded_bytes = all_binary_data
	
	if decoded_bytes == null:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Error: base64_to_raw returned null")
			print("[CustomTarget] Base64 data sample (first 100 chars): ", base64_data.substr(0, 100))
		status_label.visible = true
		status_label.text = tr("custom_target_status_error_base64_null")
		return
	
	if decoded_bytes.is_empty():
		if not DEBUG_DISABLED:
			print("[CustomTarget] Error: Decoded bytes are empty")
			print("[CustomTarget] Base64 length: %d, decoded length: 0" % base64_data.length())
			print("[CustomTarget] Base64 string starts with: '", base64_data.substr(0, 50), "'")
			print("[CustomTarget] Base64 string ends with: '", base64_data.substr(max(0, base64_data.length() - 50)), "'")
			# Check if base64 contains invalid characters
			var valid_base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
			var invalid_found = false
			for c in base64_data:
				if not c in valid_base64_chars:
					print("[CustomTarget] Invalid base64 character found: '", c, "' (ASCII: %d)" % c.unicode_at(0))
					invalid_found = true
					break
			if not invalid_found:
				print("[CustomTarget] Base64 string contains only valid characters")
		status_label.visible = true
		status_label.text = tr("custom_target_status_error_decode_image")
		return
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Successfully decoded %d bytes from base64 (length: %d)" % [
			decoded_bytes.size(),
			base64_data.length()
		])
		
		# Print byte diagnostics
		print("[CustomTarget] Decoded bytes (first 32 bytes): ", decoded_bytes.slice(0, 32).hex_encode())
		print("[CustomTarget] Decoded bytes (last 32 bytes): ", decoded_bytes.slice(max(0, decoded_bytes.size() - 32)).hex_encode())
		
		# Check for JPEG markers
		var is_jpeg = decoded_bytes.size() > 2 and decoded_bytes[0] == 0xFF and decoded_bytes[1] == 0xD8
		var has_eoi = decoded_bytes.size() > 2 and decoded_bytes[decoded_bytes.size() - 2] == 0xFF and decoded_bytes[decoded_bytes.size() - 1] == 0xD9
		print("[CustomTarget] Is JPEG (starts with FFD8): ", is_jpeg)
		print("[CustomTarget] Has EOI marker (ends with FFD9): ", has_eoi)
		
		# Scan for JPEG segment markers to check integrity
		if is_jpeg:
			_scan_jpeg_markers(decoded_bytes)
			
			# Additional check: look for corruption by checking where valid markers stop
			_find_corruption_point(decoded_bytes)
	
	# Convert bytes to Image
	var image = Image.new()
	var load_result = image.load_jpg_from_buffer(decoded_bytes)
	
	# If JPG fails, try PNG
	if load_result != OK:
		load_result = image.load_png_from_buffer(decoded_bytes)
	
	# If both fail and it looks like a truncated JPEG, try appending EOI marker
	if load_result != OK and decoded_bytes.size() > 2:
		var is_jpeg = decoded_bytes[0] == 0xFF and decoded_bytes[1] == 0xD8
		var has_eoi = decoded_bytes.size() > 2 and decoded_bytes[decoded_bytes.size() - 2] == 0xFF and decoded_bytes[decoded_bytes.size() - 1] == 0xD9
		
		if is_jpeg and not has_eoi:
			if not DEBUG_DISABLED:
				print("[CustomTarget] JPEG is missing EOI marker, attempting repair...")
			
			# Create new bytes with EOI appended
			var repaired_bytes = PackedByteArray()
			repaired_bytes.append_array(decoded_bytes)
			repaired_bytes.append(0xFF)
			repaired_bytes.append(0xD9)
			
			# Try loading repaired JPEG
			load_result = image.load_jpg_from_buffer(repaired_bytes)
			
			if load_result == OK:
				if not DEBUG_DISABLED:
					print("[CustomTarget] ✅ JPEG repair successful!")
			else:
				if not DEBUG_DISABLED:
					print("[CustomTarget] JPEG repair failed (code: %d), attempting PNG..." % load_result)
				load_result = image.load_png_from_buffer(repaired_bytes)
	
	if load_result != OK:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Error: Failed to load image from buffer (code: %d)" % load_result)
		status_label.visible = true
		status_label.text = tr("custom_target_status_error_load_code") % load_result
		return
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Image loaded successfully: %dx%d" % [image.get_width(), image.get_height()])
	
	# Show loading overlay via parent bootcamp
	var bootcamp = get_parent()
	if bootcamp and bootcamp.has_method("show_loading_overlay"):
		bootcamp.show_loading_overlay()
	
	# Convert Image to ImageTexture and display
	var texture = ImageTexture.create_from_image(image)
	_set_image_texture(texture)
	
	# Update status (then hide — transfer complete)
	status_label.text = tr("custom_target_status_image_received") % [
		image_transfer_state["image_name"],
		image.get_width(),
		image.get_height()
	]
	# Hide the status label now that transfer is complete
	status_label.visible = false
	
	# Mark transfer as complete
	image_transfer_state["active"] = false
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Image displayed successfully!")

	# Save the displayed image to server (as PNG base64) so it can be reloaded later
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		# Convert Image to PNG bytes and base64-encode
		var png_bytes = image.save_png_to_buffer()
		if png_bytes and png_bytes.size() > 0:
			var b64 = Marshalls.raw_to_base64(png_bytes)
			if b64:
				http_service.save_game(Callable(self, "_on_save_image_response"), "custom_target_image", b64)

# Scan JPEG for segment markers to check structural integrity
func _scan_jpeg_markers(data: PackedByteArray):
	var marker_count = 0
	var i = 0
	
	print("[CustomTarget] === JPEG Segment Scan ===")
	
	while i < data.size() - 1:
		if data[i] == 0xFF:
			var marker = data[i + 1]
			
			# Skip RST markers (D0-D7) and fill bytes
			if marker == 0x00:
				i += 1
				continue
			
			# Known JPEG markers
			var marker_name = ""
			match marker:
				0xD8: marker_name = "SOI (Start of Image)"
				0xD9: marker_name = "EOI (End of Image)"
				0xE0: marker_name = "APP0"
				0xE1: marker_name = "APP1 (EXIF)"
				0xE2: marker_name = "APP2"
				0xDB: marker_name = "DQT (Quantization Table)"
				0xC0: marker_name = "SOF0 (Start of Frame)"
				0xC1: marker_name = "SOF1"
				0xC2: marker_name = "SOF2"
				0xC4: marker_name = "DHT (Huffman Table)"
				0xDA: marker_name = "SOS (Start of Scan)"
				0xDD: marker_name = "DRI (Restart Interval)"
				0xFE: marker_name = "COM (Comment)"
				_:
					if marker >= 0xD0 and marker <= 0xD7:
						marker_name = "RSTx (Restart)"
					else:
						marker_name = "Unknown"
			
			print("[CustomTarget] Marker at offset 0x%04X: FF%02X (%s)" % [i, marker, marker_name])
			marker_count += 1
			
			# For markers with length field, try to read it
			if marker != 0xD8 and marker != 0xD9 and marker >= 0xD0 and marker <= 0xD7:
				# RST markers have no length
				i += 2
			elif marker == 0xD8 or marker == 0xD9 or (marker >= 0xD0 and marker <= 0xD7):
				# SOI, EOI, RST have no length
				i += 2
			elif i + 3 < data.size():
				# Read segment length (big-endian)
				var length = (data[i + 2] << 8) | data[i + 3]
				print("[CustomTarget]   → Length: %d bytes" % length)
				i += 2 + length
			else:
				i += 2
		else:
			i += 1
	
	print("[CustomTarget] Total markers found: %d" % marker_count)
	print("[CustomTarget] === End Scan ===")

# Find where the JPEG corruption starts
func _find_corruption_point(data: PackedByteArray):
	print("[CustomTarget] === Corruption Analysis ===")
	
	var i = 0
	var marker_sequence = []
	
	# Build actual marker sequence
	while i < data.size() - 1:
		if data[i] == 0xFF and data[i + 1] != 0x00:
			marker_sequence.append(data[i + 1])
			
			# If we hit SOS (0xDA), we're in compressed image data
			if data[i + 1] == 0xDA:
				print("[CustomTarget] Found SOS (Start of Scan) at offset 0x%04X" % i)
				print("[CustomTarget] Image data begins after SOS")
				
				# Check the next few bytes after SOS
				if i + 10 < data.size():
					var after_sos = data.slice(i, min(i + 30, data.size()))
					print("[CustomTarget] Bytes after SOS: ", after_sos.hex_encode())
				break
			i += 2
		else:
			i += 1
	
	print("[CustomTarget] Marker sequence: ", marker_sequence)
	
	# Check if we have critical markers
	var has_sof = 0xC0 in marker_sequence or 0xC1 in marker_sequence or 0xC2 in marker_sequence
	var has_dht = 0xC4 in marker_sequence
	var has_dqt = 0xDB in marker_sequence
	var has_sos = 0xDA in marker_sequence
	
	print("[CustomTarget] Has SOF (Start of Frame): ", has_sof)
	print("[CustomTarget] Has DHT (Huffman Tables): ", has_dht)
	print("[CustomTarget] Has DQT (Quantization Tables): ", has_dqt)
	print("[CustomTarget] Has SOS (Start of Scan): ", has_sos)
	print("[CustomTarget] === End Analysis ===")

# Get the current transfer status
func get_transfer_status() -> Dictionary:
	return {
		"active": image_transfer_state["active"],
		"image_name": image_transfer_state["image_name"],
		"chunks_received": image_transfer_state["chunks_received"].size(),
		"total_chunks": image_transfer_state["total_chunks"],
		"progress_percent": int((image_transfer_state["chunks_received"].size() / float(max(image_transfer_state["total_chunks"], 1))) * 100)
	}

# Get detailed diagnostics about transfer status
func get_transfer_diagnostics() -> Dictionary:
	var received_indices = []
	for idx in image_transfer_state["chunks_received"].keys():
		received_indices.append(idx)
	received_indices.sort()
	
	var missing_indices = []
	for i in range(image_transfer_state["total_chunks"]):
		if not image_transfer_state["chunks_received"].has(i):
			missing_indices.append(i)
	
	return {
		"active": image_transfer_state["active"],
		"image_name": image_transfer_state["image_name"],
		"total_chunks": image_transfer_state["total_chunks"],
		"chunks_received_count": image_transfer_state["chunks_received"].size(),
		"received_chunk_indices": received_indices,
		"missing_chunk_indices": missing_indices,
		"base64_data_length": image_transfer_state["image_data"].length(),
		"expected_total_size": image_transfer_state["total_size"],
		"all_chunks_received": image_transfer_state["chunks_received"].size() == image_transfer_state["total_chunks"] and missing_indices.is_empty()
	}


func _set_image_texture(tex: Texture) -> void:
	"""Set the texture on the target display and show/hide the question mark accordingly.
	Passing `null` will clear the texture and show the question mark.
	"""
	if image_display:
		image_display.texture = tex
	# If a texture is present, hide the question mark; otherwise show it
	if question_mark:
		question_mark.visible = tex == null
	# Hide the mask when a texture is set, show it when cleared
	if mask_node:
		mask_node.visible = tex == null

# Handle websocket bullet hit - spawn impact effects and bullet holes
func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0) -> void:
	if not DEBUG_DISABLED:
		print("[CustomTarget] Bullet hit received at position: ", pos)
	
	# Block hits during restoration delay
	if is_restoring:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Hit blocked during restoration")
		return
	
	# Block hits during loading period (check parent bootcamp's is_loading flag)
	var bootcamp = get_parent()
	if bootcamp and "is_loading" in bootcamp and bootcamp.is_loading:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Hit blocked during loading period")
		return
	
	# Convert world position to local coordinates (relative to this target)
	var local_pos = to_local(pos)
	
	# Check if the hit is within the target bounds AND a valid texture is loaded
	# Don't spawn holes or count hits when image is loading or after explosion (no texture)
	if image_display and image_display.texture and image_display.get_rect().has_point(local_pos):
		# Spawn bullet hole at local position
		spawn_bullet_hole(local_pos)
		
		# Increment hit count and check for explosion
		hit_count += 1
		if hit_count >= SHOTS_TO_EXPLODE:
			explode_target()
			hit_count = 0
			return

	# Emit a generic target_hit signal so bootcamp / drills can process this hit
	emit_signal("target_hit", "hit", 0, pos)
	
	# Always spawn bullet impact effects (smoke, sparks, sound) at world position
	spawn_bullet_impact_effects(pos)

# Spawn bullet impact effects (smoke, sparks, sound)
func spawn_bullet_impact_effects(world_pos: Vector2):
	"""Spawn bullet impact effects at the given world position"""
	
	# Load the impact effect scene
	var bullet_impact_scene = preload("res://scene/bullet_impact.tscn")
	
	if not bullet_impact_scene:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Error: bullet_impact scene not found")
		return
	
	# Find the scene root for effects
	var scene_root = get_tree().current_scene
	var effects_parent = scene_root if scene_root else get_parent()
	
	# Instantiate and position the impact effect
	var impact = bullet_impact_scene.instantiate()
	impact.global_position = world_pos
	effects_parent.add_child(impact)
	
	if not DEBUG_DISABLED:
		print("[CustomTarget] Spawned bullet impact at: ", world_pos)

	# Play impact sound with throttling
	var time_stamp = Time.get_ticks_msec() / 1000.0
	play_impact_sound_at_position_throttled(world_pos, time_stamp)


func play_impact_sound_at_position_throttled(world_pos: Vector2, current_time: float):
	"""Play impact sound with basic throttling and concurrent sound limiting"""
	# Time-based throttling
	if (current_time - last_sound_time) < sound_cooldown:
		return

	# Concurrent sound limiting
	if active_sounds >= max_concurrent_sounds:
		return

	# Prefer metal impact sound if available
	var impact_sound = preload("res://audio/paper_hit.ogg")

	if impact_sound:
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = impact_sound
		audio_player.volume_db = -5
		audio_player.pitch_scale = randf_range(0.95, 1.05)

		var scene_root = get_tree().current_scene
		var audio_parent = scene_root if scene_root else get_parent()
		audio_parent.add_child(audio_player)
		audio_player.global_position = world_pos
		audio_player.play()

		last_sound_time = current_time
		active_sounds += 1

		# Clean up after finished
		audio_player.finished.connect(func():
			active_sounds = max(active_sounds - 1, 0)
			audio_player.queue_free()
		)


func _on_save_image_response(result, response_code, _headers, body):
	if not DEBUG_DISABLED:
		print("[CustomTarget] Save image response:", result, response_code, body.get_string_from_utf8())


func _on_load_image_response(_result, response_code, _headers, body):
	# Response from HttpService.load_game; expect JSON with `data` field that contains base64 image
	if response_code != 200:
		if not DEBUG_DISABLED:
			print("[CustomTarget] No saved image found or load failed (code: ", response_code, ")")
		# Restore editor default texture if available
		if default_image_texture:
			image_display.texture = default_image_texture
		status_label.visible = false
		return

	var body_str = body.get_string_from_utf8()
	var parsed = JSON.parse_string(body_str)
	if not parsed:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Failed to parse load response: ", body_str)
		return

	if parsed.has("data"):
		var data = parsed["data"]
		# If data is a non-empty string, treat it as base64 image and load it
		if typeof(data) == TYPE_STRING and data.length() > 0:
			# data is expected to be base64-encoded PNG bytes
			var raw = Marshalls.base64_to_raw(data)
			if raw and raw.size() > 0:
				var img = Image.new()
				var ok = img.load_png_from_buffer(raw)
				if ok != OK:
					# try jpg
					ok = img.load_jpg_from_buffer(raw)
				if ok == OK:
					# Show loading overlay via parent bootcamp
					var bootcamp = get_parent()
					if bootcamp and bootcamp.has_method("show_loading_overlay"):
						bootcamp.show_loading_overlay()
					
					var tex = ImageTexture.create_from_image(img)
					_set_image_texture(tex)
					# Show loaded image message
					# status_label.visible = true
					# status_label.text = tr("Loaded saved image: %s (%dx%d)") % [image_transfer_state.get("image_name", "saved"), img.get_width(), img.get_height()]
					# if not DEBUG_DISABLED:
					# 	print("[CustomTarget] Loaded saved image from server")
					# Ensure transfer state shows image present
					image_transfer_state["active"] = false
					return
				else:
					if not DEBUG_DISABLED:
						print("[CustomTarget] Failed to load image buffer from saved data")
					# Restore editor default texture when saved data cannot be used
					if default_image_texture:
						_set_image_texture(default_image_texture)
					status_label.visible = false
					return
			else:
				if not DEBUG_DISABLED:
					print("[CustomTarget] No raw data in saved image")
				# Restore editor default texture
					if default_image_texture:
						_set_image_texture(default_image_texture)
				status_label.visible = false
				return
		else:
			if not DEBUG_DISABLED:
				print("[CustomTarget] Loaded data is not a string or empty: ", typeof(data))
			# No saved image present; restore default texture
			if default_image_texture:
				image_display.texture = default_image_texture
			status_label.visible = false
			return
	else:
		if not DEBUG_DISABLED:
			print("[CustomTarget] Load response has no data field: ", body_str)
		# No saved data — ensure editor default texture is shown
		if default_image_texture:
			image_display.texture = default_image_texture
		status_label.visible = false

func explode_target():
	if not image_display or not image_display.texture:
		return
		
	if not DEBUG_DISABLED:
		print("[CustomTarget] Exploding target!")

	# Create explosion effect
	if ExplosionEffectScene:
		var explosion = ExplosionEffectScene.instantiate()
		explosion.texture = image_display.texture
		explosion.position = image_display.position
		explosion.scale = image_display.scale
		
		add_child(explosion)
	
	# Hide the target
	image_display.visible = false
	# Mask visibility is handled in _set_image_texture(); avoid redundant changes here
	
	# Also clear any GPU-instanced MultiMesh bullet holes and pooled nodes
	# This ensures all visual bullet holes are removed when the image shatters
	clear_all_bullet_holes()
	
	# Restore after delay (block hits during this period)
	is_restoring = true
	get_tree().create_timer(1.0).timeout.connect(restore_target)

func restore_target():
	if not DEBUG_DISABLED:
		print("[CustomTarget] Restoring target")
	
	# Clear restoration flag to allow hits again
	is_restoring = false
	
	# Show loading overlay via parent bootcamp if texture exists
	if image_display and image_display.texture:
		var bootcamp = get_parent()
		if bootcamp and bootcamp.has_method("show_loading_overlay"):
			bootcamp.show_loading_overlay()
	
	if image_display:
		image_display.visible = true
		# Ensure mask visibility matches whether a texture is set (avoid forcing mask to show)
		_set_image_texture(image_display.texture)
	
	# Clear bullet holes
	# (legacy pooled nodes removed) — clear instanced counts below

	# Reset instanced MultiMesh visible instance counts if present
	for texture_index in range(bullet_hole_multimeshes.size()):
		var mm_inst = bullet_hole_multimeshes[texture_index]
		if mm_inst and mm_inst.multimesh:
			mm_inst.multimesh.visible_instance_count = 0
			active_instances[texture_index] = 0
