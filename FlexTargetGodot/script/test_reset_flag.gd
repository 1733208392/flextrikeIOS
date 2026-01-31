extends Control

@onready var status_label = $VBoxContainer/StatusLabel

func _ready():
	status_label.text = "Press button to reset first_run_complete flag"

func _on_reset_button_pressed():
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		status_label.text = "Error: GlobalData not found"
		return
	
	global_data.settings_dict["first_run_complete"] = false
	
	status_label.text = "Resetting on server..."
	
	HttpService.save_game(
		func(result, response_code, _headers, _body):
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
				status_label.text = "Flag reset successfully! Restarting..."
				await get_tree().create_timer(1.5).timeout
				get_tree().change_scene_to_file("res://scene/splash_loading.tscn")
			else:
				status_label.text = "Failed to reset flag. Code: " + str(response_code), "settings", global_data.settings_dict
	)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")
