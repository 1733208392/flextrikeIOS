extends "res://script/ipsc_mini.gd"

# Treat this as two IPSC mini targets: 4 valid hits required.
const DOUBLE_TARGET_REQUIRED_HITS: int = 4

func _ready():
	super._ready()
	max_shots = DOUBLE_TARGET_REQUIRED_HITS

func is_point_in_zone(zone_name: String, point: Vector2) -> bool:
	var zone_node = get_node_or_null(zone_name)
	if zone_node and zone_node is CollisionPolygon2D:
		var polygon = zone_node.polygon
		var transformed_polygon = PackedVector2Array()
		for vertex in polygon:
			transformed_polygon.append(vertex + zone_node.position)
		return Geometry2D.is_point_in_polygon(point, transformed_polygon)
	return false

func handle_websocket_bullet_hit_fast(world_pos: Vector2, t: int = 0):
	if is_disappearing:
		return

	var local_pos = to_local(world_pos)
	var zone_hit = ""
	var points = 0
	var is_target_hit = false

	# Check the bottom panel first because both panels overlap in world space.
	if is_point_in_zone("AZone2", local_pos):
		zone_hit = "AZone1"
		points = ScoreUtils.new().get_points_for_hit_area("AZone", 5)
		is_target_hit = true
	elif is_point_in_zone("CZone2", local_pos):
		zone_hit = "CZone1"
		points = ScoreUtils.new().get_points_for_hit_area("CZone", 3)
		is_target_hit = true
	elif is_point_in_zone("DZone2", local_pos):
		zone_hit = "DZone1"
		points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
		is_target_hit = true
	elif is_point_in_zone("AZone", local_pos):
		zone_hit = "AZone"
		points = ScoreUtils.new().get_points_for_hit_area("AZone", 5)
		is_target_hit = true
	elif is_point_in_zone("CZone", local_pos):
		zone_hit = "CZone"
		points = ScoreUtils.new().get_points_for_hit_area("CZone", 3)
		is_target_hit = true
	elif is_point_in_zone("DZone", local_pos):
		zone_hit = "DZone"
		points = ScoreUtils.new().get_points_for_hit_area("DZone", 1)
		is_target_hit = true
	else:
		zone_hit = "miss"
		points = ScoreUtils.new().get_points_for_hit_area("miss", 0)

	if is_target_hit:
		spawn_bullet_hole(local_pos)
		var time_stamp = Time.get_ticks_msec() / 1000.0
		play_impact_sound_at_position_throttled(world_pos, time_stamp)
	else:
		spawn_bullet_effects_at_position(world_pos, false)

	total_score += points
	target_hit.emit(zone_hit, points, world_pos, t)

	if is_target_hit:
		shot_count += 1
		if shot_count >= max_shots:
			play_disappearing_animation()

func play_disappearing_animation():
	is_disappearing = true

	var animation_player = get_node_or_null("AnimationPlayer")
	if animation_player:
		if not animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
		animation_player.play("disappear")

	# Fade second panel as well.
	var animation_player_2 = get_node_or_null("AnimationPlayer2")
	if animation_player_2:
		animation_player_2.play("disappear")

func reset_target():
	super.reset_target()
	var sprite2 = get_node_or_null("TargetSprite2")
	if sprite2:
		sprite2.modulate = Color.WHITE
		sprite2.rotation = 0.0
		sprite2.scale = Vector2.ONE
