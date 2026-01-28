extends Node

# Debugging script to monitor CustomTarget image transfer status

@onready var custom_target = get_node_or_null("/root/CustomTarget")

func _ready():
	print("[ImageTransferDebugger] Started")
	set_process(true)

func _process(_delta):
	if custom_target:
		if Input.is_action_just_pressed("ui_accept"):
			print_diagnostics()

func print_diagnostics():
	if not custom_target:
		print("[ImageTransferDebugger] CustomTarget not found!")
		return
	
	var diagnostics = custom_target.get_transfer_diagnostics()
	
	print("\n" + "=".repeat(60))
	print("[ImageTransferDebugger] IMAGE TRANSFER DIAGNOSTICS")
	print("=".repeat(60))
	print("Active: ", diagnostics["active"])
	print("Image Name: ", diagnostics["image_name"])
	print("Total Chunks: ", diagnostics["total_chunks"])
	print("Chunks Received: ", diagnostics["chunks_received_count"])
	print("Progress: ", diagnostics["chunks_received_count"], "/", diagnostics["total_chunks"])
	
	if diagnostics["total_chunks"] > 0:
		var percent = int((diagnostics["chunks_received_count"] / float(diagnostics["total_chunks"])) * 100)
		print("Progress %: ", percent, "%")
	
	print("\nReceived Chunk Indices: ", diagnostics["received_chunk_indices"])
	
	if not diagnostics["missing_chunk_indices"].is_empty():
		print("⚠️  MISSING CHUNK INDICES: ", diagnostics["missing_chunk_indices"])
	else:
		print("✅ All chunks received")
	
	print("\nBase64 Data Length: ", diagnostics["base64_data_length"], " bytes")
	print("Expected Total Size: ", diagnostics["expected_total_size"], " bytes")
	print("All Chunks Received: ", diagnostics["all_chunks_received"])
	
	print("=".repeat(60) + "\n")

# Called from console to debug
func debug_missing_chunks():
	print_diagnostics()

# Manual chunk arrival simulation for testing
func test_receive_chunks():
	print("[ImageTransferDebugger] Testing chunk reception...")
	
	var start_msg = JSON.stringify({
		"type": "netlink",
		"data": {
			"command": "image_transfer_start",
			"total_chunks": 3,
			"chunk_size": 100,
			"image_name": "debug_test.jpg",
			"total_size": 300
		}
	})
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.data_received.emit(start_msg)
		await get_tree().create_timer(0.1).timeout
		
		# Simulate chunks arriving out of order
		var chunk_2_msg = JSON.stringify({
			"type": "netlink",
			"data": {
				"command": "image_chunk",
				"chunk_index": 2,
				"data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
			}
		})
		ws_listener.data_received.emit(chunk_2_msg)
		await get_tree().create_timer(0.1).timeout
		
		var chunk_0_msg = JSON.stringify({
			"type": "netlink",
			"data": {
				"command": "image_chunk",
				"chunk_index": 0,
				"data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
			}
		})
		ws_listener.data_received.emit(chunk_0_msg)
		await get_tree().create_timer(0.1).timeout
		
		print_diagnostics()
		print("Currently missing chunk 1, waiting for it...")
		
		await get_tree().create_timer(2.0).timeout
		
		var chunk_1_msg = JSON.stringify({
			"type": "netlink",
			"data": {
				"command": "image_chunk",
				"chunk_index": 1,
				"data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
			}
		})
		ws_listener.data_received.emit(chunk_1_msg)
		await get_tree().create_timer(0.1).timeout
		
		print_diagnostics()
