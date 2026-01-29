extends Node

func get_points_for_hit_area(hit_area: String, default_points: int = 0) -> int:
    # Read scoring rules from GlobalData.settings_dict.target_rule if available
    var global_data = get_node_or_null("/root/GlobalData")
    if global_data and global_data.settings_dict.has("target_rule"):
        var target_rule = global_data.settings_dict["target_rule"]
        var area_key = hit_area
        # Normalize common aliases
        if hit_area == "Miss":
            area_key = "miss"
        elif hit_area == "Paddle":
            area_key = "paddles"
        elif hit_area == "Popper":
            area_key = "popper"

        if typeof(target_rule) == TYPE_DICTIONARY and target_rule.has(area_key):
            return int(target_rule[area_key])

    # Fallback mapping (kept conservative)
    var fallback = {
        "AZone": 5,
        "CZone": 3,
        "DZone": 1,
        "WhiteZone": -10,
        "miss": 0,
        "Paddle": 5,
        "Popper": 5
    }
    if fallback.has(hit_area):
        return int(fallback[hit_area])

    return int(default_points)
