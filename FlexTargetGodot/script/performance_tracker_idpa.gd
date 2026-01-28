extends Node

# Performance optimization
const DEBUG_DISABLED = true  # Set to true for verbose debugging

# Scoring rules are now loaded dynamically from settings_dict.target_rule

# Performance tracking variables
var records = []
var last_shot_time_usec = 0  # Changed to microseconds for better precision
var fastest_time_diff = 999.0  # Initialize with a large value
var first_shot = true  # Track if this is the first shot of the drill
var total_elapsed_time = 0.0  # Store the total elapsed time for the drill
var pending_drill_data = null
var minimum_shot_interval = 0.01  # 10ms minimum realistic shot interval
var shot_timer_delay = 0.0  # Store the shot timer delay duration

func _ready():
	pass

func _on_target_hit(target_type: String, hit_position: Vector2, hit_area: String, score: int, rotation_angle: float = 0.0, target_position: Vector2 = Vector2.ZERO):
	var current_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	var time_diff = 0.0  # Initialize to 0
	
	if first_shot:
		# First shot of the drill - calculate time from drill start (reset_shot_timer)
		var total_time = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		# Subtract shot timer delay to get actual reaction time after beep
		time_diff = total_time - shot_timer_delay
		# Ensure time_diff is not negative (in case of very fast reaction)
		if time_diff < 0:
			time_diff = 0.0
		first_shot = false
		
		# Update fastest time if this first shot is realistic (using the adjusted reaction time)
		if time_diff >= minimum_shot_interval and time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if not DEBUG_DISABLED:
			print("PERFORMANCE TRACKER IDPA: First shot - total time:", total_time, "s, shot timer delay:", shot_timer_delay, "s, reaction time:", time_diff, "s")
	else:
		# Subsequent shots - calculate interval with microsecond precision
		time_diff = (current_time_usec - last_shot_time_usec) / 1000000.0  # Convert to seconds
		
		# Apply minimum time threshold to prevent unrealistic 0.0s intervals
		if time_diff < minimum_shot_interval:
			if not DEBUG_DISABLED:
				print("PERFORMANCE TRACKER IDPA: Shot interval too fast (", time_diff, "s), clamping to minimum (", minimum_shot_interval, "s)")
			time_diff = minimum_shot_interval
		
		# Update fastest time if this is faster (but still realistic)
		if time_diff < fastest_time_diff:
			fastest_time_diff = time_diff
		
		if not DEBUG_DISABLED:
			print("PERFORMANCE TRACKER IDPA: Shot interval:", time_diff, "seconds, fastest:", fastest_time_diff)
	
	# Update last shot time for next calculation
	last_shot_time_usec = current_time_usec
	
	var record = {
		"target_type": target_type,
		"time_diff": round(time_diff * 100.0) / 100.0,
		"hit_position": {"x": round(hit_position.x * 10.0) / 10.0, "y": round(hit_position.y * 10.0) / 10.0},
		"target_position": {"x": round(target_position.x * 10.0) / 10.0, "y": round(target_position.y * 10.0) / 10.0},
		"hit_area": hit_area,
		"score": score,
		"rotation_angle": round(rotation_angle * 100.0) / 100.0,
		"shot_timer_delay": round(shot_timer_delay * 100.0) / 100.0
	}
	
	records.append(record)
	if not DEBUG_DISABLED:
		print("Performance record added: ", record)

# Signal handler for drills finished
func _on_drills_finished():
	if records.size() == 0:
		return
	
	if not DEBUG_DISABLED:
		print("Performance records for this drill: ", records)
	
	# Create the summary data
	var fastest_value = null
	if fastest_time_diff < 999.0:
		fastest_value = fastest_time_diff
	
	var drill_summary = {
		"total_elapsed_time": total_elapsed_time,
		"fastest_shot_interval": snappedf(fastest_value, 0.01) if fastest_value != null else 0.0,
		"total_shots": records.size(),
		"timestamp": snappedf(Time.get_unix_time_from_system(), 0.01)
	}
	
	# Create the final data structure
	var drill_data = {
		"drill_summary": drill_summary,
		"records": records.duplicate()  # Copy the records array
	}
	
	pending_drill_data = drill_data
	
	# Store latest performance data in GlobalData for immediate access
	var global_data = get_node("/root/GlobalData")
	if global_data:
		global_data.latest_performance_data = drill_data.duplicate()
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] Stored latest performance data in GlobalData")
	
	var http_service = get_node("/root/HttpService")
	if http_service:
		# var json_string = JSON.stringify(pending_drill_data)
		# Implement circular buffer: cycle through indices 1-20
		var current_index = int(global_data.settings_dict.get("max_index_idpa", 0)) if global_data else 0
		var next_index = (current_index % 20) + 1  # Circular buffer: 1-20
		var data_id = "performance_idpa_" + str(next_index)
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] Saving drill data to file: ", data_id, " (previous index: ", current_index, ", next index: ", next_index, ")")
		#var json_data = JSON.stringify(pending_drill_data)
		http_service.save_game(_on_performance_saved, data_id, pending_drill_data)
	else:
		if not DEBUG_DISABLED:
			print("HttpService not found")

# Get the fastest time difference recorded
func get_fastest_time_diff() -> float:
	return fastest_time_diff

# Reset the fastest time for a new drill
func reset_fastest_time():
	fastest_time_diff = 999.0

# Reset the shot timer for accurate first shot measurement
func reset_shot_timer():
	last_shot_time_usec = Time.get_ticks_usec()  # Use microsecond precision
	first_shot = true  # Reset first shot flag for new drill

# Reset all performance tracking data for a new drill
func reset_all():
	records.clear()
	fastest_time_diff = 999.0
	first_shot = true
	total_elapsed_time = 0.0
	pending_drill_data = null
	shot_timer_delay = 0.0
	if not DEBUG_DISABLED:
		print("PERFORMANCE TRACKER IDPA: All data reset for new drill")

# Set the total elapsed time for the drill
func set_total_elapsed_time(time_seconds: float):
	total_elapsed_time = time_seconds
	if not DEBUG_DISABLED:
		print("PERFORMANCE TRACKER IDPA: Total elapsed time set to:", total_elapsed_time, "seconds")

# Set the shot timer delay
func set_shot_timer_delay(delay: float):
	shot_timer_delay = round(delay * 100.0) / 100.0  # Ensure 2 decimal precision
	if not DEBUG_DISABLED:
		print("PERFORMANCE TRACKER IDPA: Shot timer delay set to:", shot_timer_delay, "seconds")

func _on_settings_saved(_result, response_code, _headers, _body):
	if response_code == 200:
		if not DEBUG_DISABLED:
			print("Settings saved")
		var fastest_display = "N/A"
		if fastest_time_diff < 999.0:
			fastest_display = "%.2f" % fastest_time_diff
		if not DEBUG_DISABLED:
			print("Drill summary - Total time:", total_elapsed_time, "seconds, Fastest shot:", fastest_display)
		records.clear()
		pending_drill_data = null
	else:
		if not DEBUG_DISABLED:
			print("Failed to save settings")

func _on_performance_saved(_result, response_code, _headers, _body):
	if response_code == 200:
		if not DEBUG_DISABLED:
			print("Performance data saved")
		var http_service = get_node("/root/HttpService")
		if http_service:
			# Update max_index_idpa with circular buffer logic: cycle 1-20
			var global_data = get_node_or_null("/root/GlobalData")
			var next_index = 1
			
			if global_data and global_data.settings_dict != null:
				var current_index = int(global_data.settings_dict.get("max_index_idpa", 0))
				next_index = (current_index % 20) + 1
				global_data.settings_dict["max_index_idpa"] = next_index
				if not DEBUG_DISABLED:
					print("[PerformanceTrackerIDPA] Updated max_index_idpa from ", current_index, " to ", next_index, " (circular buffer 1-20)")
				# Preserve all existing settings, only update max_index_idpa
			
			var settings_json = JSON.stringify(global_data.settings_dict)
			http_service.save_game(_on_settings_saved, "settings", settings_json)
			
			# Save/update leaderboard index
			_save_leaderboard_index(next_index)
		else:
			if not DEBUG_DISABLED:
				print("HttpService not found")
	else:
		if not DEBUG_DISABLED:
			print("Failed to save performance data")# Save/update leaderboard index with current drill performance

func _save_leaderboard_index(drill_index: int):
	if not pending_drill_data:
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] No pending drill data for leaderboard index")
		return
	
	var http_service = get_node("/root/HttpService")
	if not http_service:
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] HttpService not found for leaderboard index update")
		return
	
	# Calculate performance metrics from pending drill data
	var drill_summary = pending_drill_data.get("drill_summary", {})
	var drill_records = pending_drill_data.get("records", [])
	
	# Calculate total score (down points)
	var total_score = 0
	for record in drill_records:
		if record.has("score"):
			total_score += record["score"]
	
	# Get raw time
	var total_time = drill_summary.get("total_elapsed_time", 0.0)
	
	# Get fastest shot interval
	var fastest_shot = drill_summary.get("fastest_shot_interval", null)
	var fastest_shot_time = 0.0
	if fastest_shot != null:
		fastest_shot_time = fastest_shot
	
	# Create leaderboard entry with IDPA format
	var leaderboard_entry = {
		"index": int(drill_index),  # Ensure index is always an integer
		"down_points": abs(int(total_score)),  # Down points (positive count of penalties)
		"raw_time": round(total_time * 10) / 10.0,  # Raw time, round to 1 decimal place
		"final_score": round((total_time + total_score) * 10) / 10.0,  # Final Score = raw time + penalties
		"fastest_shot": round(fastest_shot_time * 100) / 100.0  # Round to 2 decimal places
	}
	
	if not DEBUG_DISABLED:
		print("[PerformanceTrackerIDPA] Creating leaderboard index entry: ", leaderboard_entry)
	
	# Try to load existing idpa_leader_board_index.json or create new one if it doesn't exist
	http_service.load_game(func(result, response_code, headers, body): _on_index_file_loaded(leaderboard_entry, result, response_code, headers, body), "idpa_leader_board_index")

func _on_index_file_loaded(new_entry: Dictionary, _result, response_code, _headers, body):
	var http_service = get_node("/root/HttpService")
	if not http_service:
		return
	
	var index_data = []
	
	# If idpa_leader_board_index.json exists, load existing data for appending
	if response_code == 200:
		var body_str = body.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(body_str)
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("data") and response_data["code"] == 0:
				# Check if data is empty dictionary indicating file doesn't exist
				if typeof(response_data["data"]) == TYPE_DICTIONARY and response_data["data"].is_empty():
					# File doesn't exist - create new one
					if not DEBUG_DISABLED:
						print("[PerformanceTrackerIDPA] idpa_leader_board_index.json doesn't exist, creating new file")
				elif typeof(response_data["data"]) == TYPE_ARRAY:
					index_data = response_data["data"]
					# Normalize existing data to ensure correct types
					for i in range(index_data.size()):
						var entry = index_data[i]
						if entry.has("index"):
							entry["index"] = int(entry["index"])  # Ensure index is integer
						if entry.has("score"):
							entry["score"] = int(entry["score"])  # Ensure score is integer
						if entry.has("time"):
							entry["time"] = round(float(entry["time"]) * 10) / 10.0  # Ensure time is float with 1 decimal
						if entry.has("final_score"):
							entry["final_score"] = round(float(entry["final_score"]) * 10) / 10.0  # Ensure final_score is float with 1 decimal
						if entry.has("fastest_shot"):
							entry["fastest_shot"] = round(float(entry["fastest_shot"]) * 100) / 100.0  # Ensure fastest_shot is float with 2 decimals
						else:
							# Add fastest_shot field if missing (for backward compatibility)
							entry["fastest_shot"] = 0.0
						if not DEBUG_DISABLED:
							print("[PerformanceTrackerIDPA] Loaded existing idpa_leader_board_index.json with ", index_data.size(), " entries")
				else:
					# Assume it's a JSON string
					var index_json = JSON.new()
					var index_parse = index_json.parse(str(response_data["data"]))
					if index_parse == OK:
						index_data = index_json.data
						# Normalize existing data to ensure correct types
						for i in range(index_data.size()):
							var entry = index_data[i]
							if entry.has("index"):
								entry["index"] = int(entry["index"])  # Ensure index is integer
							if entry.has("score"):
								entry["score"] = int(entry["score"])  # Ensure score is integer
							if entry.has("time"):
								entry["time"] = round(float(entry["time"]) * 10) / 10.0  # Ensure time is float with 1 decimal
							if entry.has("final_score"):
								entry["final_score"] = round(float(entry["final_score"]) * 10) / 10.0  # Ensure final_score is float with 1 decimal
							if entry.has("fastest_shot"):
								entry["fastest_shot"] = round(float(entry["fastest_shot"]) * 100) / 100.0  # Ensure fastest_shot is float with 2 decimals
							else:
								# Add fastest_shot field if missing (for backward compatibility)
								entry["fastest_shot"] = 0.0
						if not DEBUG_DISABLED:
							print("[PerformanceTrackerIDPA] Loaded and normalized existing idpa_leader_board_index.json with ", index_data.size(), " entries")
	else:
		# Unexpected response code - create new file
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] Unexpected response code ", response_code, ", creating new file")
	
	# Find if entry with same index exists and update it, otherwise append new entry
	var entry_updated = false
	for i in range(index_data.size()):
		if int(index_data[i].get("index")) == int(new_entry["index"]):
			index_data[i] = new_entry
			entry_updated = true
			if not DEBUG_DISABLED:
				print("[PerformanceTrackerIDPA] Updated existing entry at index ", new_entry["index"])
			break
	
	# If entry with this index doesn't exist, append the new entry
	if not entry_updated:
		index_data.append(new_entry)
		if not DEBUG_DISABLED:
			print("[PerformanceTrackerIDPA] Appended new entry at index ", new_entry["index"])
	
	# Sort index data by final_score in ascending order (lower score is better)
	index_data.sort_custom(func(a, b): return a.get("final_score", 0.0) < b.get("final_score", 0.0))
	
	# Save updated idpa_leader_board_index.json
	var leaderboard_json = JSON.stringify(index_data)
	http_service.save_game(_on_index_file_saved, "idpa_leader_board_index", leaderboard_json)

func _on_index_file_saved(_result, response_code, _headers, _body):
		if response_code == 200:
			if not DEBUG_DISABLED:
				print("[PerformanceTrackerIDPA] idpa_leader_board_index.json saved successfully")
		else:
			if not DEBUG_DISABLED:
				print("[PerformanceTrackerIDPA] Failed to save idpa_leader_board_index.json - Response code: ", response_code)
