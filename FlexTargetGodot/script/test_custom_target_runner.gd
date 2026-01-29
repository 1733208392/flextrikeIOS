extends Node

# Quick test to verify custom_target receives messages correctly

func _ready():
	print("[TestCustomTarget] Test scene ready")
	
	# Simulate the message that would come from server
	test_image_transfer_start()
	await get_tree().create_timer(1.0).timeout
	test_image_chunk_0()
	await get_tree().create_timer(0.5).timeout
	test_image_chunk_1()

func test_image_transfer_start():
	print("[TestCustomTarget] Sending simulated image_transfer_start message")
	
	var message = JSON.stringify({
		"type": "netlink",
		"data": {
			"command": "image_transfer_start",
			"total_chunks": 2,
			"chunk_size": 200,
			"image_name": "test_image.jpg",
			"total_size": 400
		}
	})
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.data_received.emit(message)
	else:
		print("[TestCustomTarget] WebSocketListener not found")

func test_image_chunk_0():
	print("[TestCustomTarget] Sending simulated image_chunk 0")
	
	var message = JSON.stringify({
		"type": "netlink",
		"data": {
			"command": "image_chunk",
			"chunk_index": 0,
			"data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
		}
	})
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.data_received.emit(message)

func test_image_chunk_1():
	print("[TestCustomTarget] Sending simulated image_chunk 1")
	
	var message = JSON.stringify({
		"type": "netlink",
		"data": {
			"command": "image_chunk",
			"chunk_index": 1,
			"data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
		}
	})
	
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		ws_listener.data_received.emit(message)
