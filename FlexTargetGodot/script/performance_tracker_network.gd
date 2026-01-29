extends Node

# Performance optimization
const DEBUG_DISABLED = false  # Set to false for production release

# Target types with variable position/rotation (only these targets include rot and tgt_pos fields)
const VARIABLE_POSITION_TARGETS = ["rotation"]

func _ready():
	pass

func _get_target_type_from_instance(instance: Node, fallback_type: String) -> String:
	"""Get target type from instance metadata, with fallback to provided type parameter"""
	if instance and instance.has_meta("target_type"):
		var meta_type = instance.get_meta("target_type", null)
		if meta_type != null:
			return meta_type
	return fallback_type

func _on_target_hit(target_instance: Node, target_type: String, hit_position: Vector2, hit_area: String, rotation_angle: float, repeat: int, target_position: Vector2, t: int = 0):
	print("[PerformanceTrackerNetwork] _on_target_hit called with target_type=", target_type, ", hit_area=", hit_area, ", hit_position=", hit_position, ", t=", t)
	
	# Resolve target type using metadata if available (for CQB targets)
	var resolved_target_type = _get_target_type_from_instance(target_instance, target_type)
	
	# Build record with abbreviated keys and conditional fields
	# Abbreviations: cmd=command, tt=target_type, t=sensor_time_seconds, hp=hit_position, 
	#                ha=hit_area, rot=rotation_angle, std=shot_timer_delay, 
	#                tgt_pos=targetPos, rep=repeat
	var record = {
		"cmd": "shot",
		"tt": resolved_target_type,
		"td": round((t / 1000.0) * 100.0) / 100.0,  # Convert sensor time from milliseconds to seconds, rounded to 2 decimals
		"hp": {"x": "%.1f" % hit_position.x, "y": "%.1f" % hit_position.y},
		"ha": hit_area,
		"rep": repeat,
		"std": "%.2f" % 0.0  # Placeholder for shot_timer_delay
	}
	
	# Only include rotation and target position for variable-position targets (e.g., rotation targets)
	if resolved_target_type in VARIABLE_POSITION_TARGETS:
		record["rot"] = "%.2f" % rotation_angle
		record["tgt_pos"] = {"x": "%.1f" % target_position.x, "y": "%.1f" % target_position.y}
	
	# Send to websocket server
	_send_to_app(record)
	
	if not DEBUG_DISABLED:
		print("Performance record sent: ", record)

# Send message to websocket server
func _send_to_app(record: Dictionary):
	var http_service = get_node_or_null("/root/HttpService")
	if http_service:
		print("[PerformanceTrackerNetwork] Sending shot record to app: ", record)		
		http_service.netlink_forward_data(func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				print("[PerformanceTrackerNetwork] ✓ Successfully sent shot data via HTTP")
			else:
				print("[PerformanceTrackerNetwork] ✗ Failed to send shot data via HTTP: result=", result, " code=", response_code)
		, record)
	else:
		print("[PerformanceTrackerNetwork] ✗ HttpService not found at /root/HttpService - cannot send shot data")
