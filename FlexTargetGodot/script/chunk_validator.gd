extends Node

# Helper script to validate and check chunk completeness

func check_all_chunks_present() -> bool:
	var ct = get_node_or_null("/root/CustomTarget")
	if not ct:
		print("[ChunkValidator] CustomTarget not found")
		return false
	
	var diag = ct.get_transfer_diagnostics()
	
	print("\n" + "=".repeat(70))
	print("CHUNK COMPLETENESS CHECK")
	print("=".repeat(70))
	
	print("Total chunks expected: ", diag["total_chunks"])
	print("Chunks received: ", diag["chunks_received_count"])
	
	if diag["total_chunks"] == 0:
		print("⚠️  No transfer in progress")
		print("=".repeat(70) + "\n")
		return false
	
	if diag["chunks_received_count"] < diag["total_chunks"]:
		print("❌ INCOMPLETE: Missing %d chunks" % (diag["total_chunks"] - diag["chunks_received_count"]))
		print("Missing indices: ", diag["missing_chunk_indices"])
		print("=".repeat(70) + "\n")
		return false
	
	if not diag["missing_chunk_indices"].is_empty():
		print("❌ INCOMPLETE: Gaps in chunk indices")
		print("Missing indices: ", diag["missing_chunk_indices"])
		print("Received indices: ", diag["received_chunk_indices"])
		print("=".repeat(70) + "\n")
		return false
	
	print("✅ ALL CHUNKS PRESENT")
	print("Received indices: ", diag["received_chunk_indices"])
	print("Base64 data length: ", diag["base64_data_length"], " bytes")
	print("Expected size: ", diag["expected_total_size"], " bytes")
	
	if diag["base64_data_length"] > 0:
		var size_match = diag["base64_data_length"] >= (diag["expected_total_size"] * 0.75)  # Base64 is ~33% larger
		if size_match:
			print("✅ Size check passed")
		else:
			print("⚠️  Size may be incomplete")
	
	print("=".repeat(70) + "\n")
	return true


func get_chunk_statistics() -> Dictionary:
	var ct = get_node_or_null("/root/CustomTarget")
	if not ct:
		return {}
	
	var diag = ct.get_transfer_diagnostics()
	var total = diag["total_chunks"]
	
	if total == 0:
		return {"status": "no_transfer"}
	
	var received = diag["chunks_received_count"]
	var missing_count = total - received
	var completion_percent = int((received / float(total)) * 100) if total > 0 else 0
	
	return {
		"status": "active" if diag["active"] else "complete",
		"total_chunks": total,
		"received_chunks": received,
		"missing_chunks": missing_count,
		"completion_percent": completion_percent,
		"image_name": diag["image_name"],
		"base64_length": diag["base64_data_length"],
		"expected_size": diag["expected_total_size"],
		"all_chunks_received": diag["all_chunks_received"],
		"missing_indices": diag["missing_chunk_indices"]
	}


func print_chunk_map() -> void:
	var ct = get_node_or_null("/root/CustomTarget")
	if not ct:
		print("[ChunkValidator] CustomTarget not found")
		return
	
	var diag = ct.get_transfer_diagnostics()
	var total = diag["total_chunks"]
	
	if total == 0:
		print("No active transfer")
		return
	
	print("\n" + "=".repeat(70))
	print("CHUNK MAP (%d total)" % total)
	print("=".repeat(70))
	
	var received_set = {}
	for idx in diag["received_chunk_indices"]:
		received_set[idx] = true
	
	var line = ""
	var line_count = 0
	
	for i in range(total):
		var status = "✓" if received_set.has(i) else "✗"
		line += status
		line_count += 1
		
		if line_count >= 50:
			print(line)
			line = ""
			line_count = 0
	
	if line_count > 0:
		print(line)
	
	print("\n✓ = Received, ✗ = Missing")
	print("Missing count: ", diag["missing_chunk_indices"].size())
	print("=".repeat(70) + "\n")


# Call this to get a simple true/false answer
func is_transfer_complete() -> bool:
	var ct = get_node_or_null("/root/CustomTarget")
	if not ct:
		return false
	
	var diag = ct.get_transfer_diagnostics()
	return diag["all_chunks_received"] and not diag["active"]
