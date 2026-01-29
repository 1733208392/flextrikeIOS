extends Node2D

# Menu state
var selected_option: int = 0  # Selected option
var main_menu_options: Array = []  # Main menu buttons (FruitCatcher, Monkey Duel, Mole Attack)

# Node references
var button_fruitcatcher: TextureButton
var button_monkeyduel: TextureButton
var button_mole_attack: TextureButton
var button_tictactoe: TextureButton
var button_painter: TextureButton
var fruitcatcher_label: Label
var monkeyduel_label: Label
var mole_attack_label: Label
var tictactoe_label: Label
var painter_label: Label

func _ready():
	# Hide global status bar when entering games
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = false
		print("[Games Menu] Hid global status bar: ", status_bar.name)
	
	# Get node references for game buttons
	button_fruitcatcher = get_node("Panel/VBoxContainer2/HBoxContainer/1Player")
	button_monkeyduel = get_node("Panel/VBoxContainer2/HBoxContainer2/2Players")
	button_mole_attack = get_node("Panel/VBoxContainer2/HBoxContainer3/wackamole")
	button_tictactoe = get_node("Panel/VBoxContainer2/HBoxContainer4/tictactoe")
	button_painter  = get_node("Panel/VBoxContainer2/HBoxContainer5/painter")

	# Get game name labels
	fruitcatcher_label = get_node("Panel/VBoxContainer2/HBoxContainer/Label")
	monkeyduel_label = get_node("Panel/VBoxContainer2/HBoxContainer2/Label")
	mole_attack_label = get_node("Panel/VBoxContainer2/HBoxContainer3/Label")
	tictactoe_label = get_node("Panel/VBoxContainer2/HBoxContainer4/Label")
	painter_label = get_node("Panel/VBoxContainer2/HBoxContainer5/Label")
	
	# Populate menu options arrays
	main_menu_options = [button_fruitcatcher, button_monkeyduel, button_mole_attack, button_tictactoe, button_painter]

	# Connect button signals
	button_fruitcatcher.pressed.connect(_on_fruitcatcher_pressed)
	button_monkeyduel.pressed.connect(_on_monkeyduel_pressed)
	button_mole_attack.pressed.connect(_on_mole_attack_pressed)
	button_tictactoe.pressed.connect(_on_tictactoe_pressed)
	button_painter.pressed.connect(_on_painter_pressed)

	# Connect to remote control directives
	var remote_control = get_node_or_null("/root/MenuController")
	if remote_control:
		remote_control.navigate.connect(_on_remote_navigate)
		remote_control.enter_pressed.connect(_on_remote_enter)
		remote_control.back_pressed.connect(_on_remote_back_pressed)
		print("[Menu] Connected to MenuController signals")
	else:
		print("[Menu] MenuController autoload not found!")

	# Set translated game names
	if fruitcatcher_label:
		fruitcatcher_label.text = tr("fruitcatcher")
	if monkeyduel_label:
		monkeyduel_label.text = tr("monkey_duel")
	if mole_attack_label:
		mole_attack_label.text = tr("mole_attack")
	if tictactoe_label:
		tictactoe_label.text = tr("tictactoe")
	if painter_label:
		painter_label.text = tr("shoot_painter")

	# Load last pressed selection from GlobalData if available, otherwise default to first button
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("last_games_menu_selection"):
		selected_option = int(global_data.settings_dict.get("last_games_menu_selection", 0))
		# Clamp to valid range
		if selected_option < 0 or selected_option >= main_menu_options.size():
			selected_option = 0
		# Apply focus to the saved option
		_update_selection()
		print("[Menu] Restored last menu selection from GlobalData: ", selected_option)
	else:
		# Default to FruitCatcher
		if button_fruitcatcher:
			button_fruitcatcher.grab_focus()
			selected_option = 0
			print("[Menu] FruitCatcher button has focus by default")


func _save_last_selection():
	"""Persist the last pressed menu selection into GlobalData.settings_dict"""
	var gd = get_node_or_null("/root/GlobalData")
	if gd:
		gd.settings_dict["last_games_menu_selection"] = selected_option
		print("[Menu] Saved last menu selection to GlobalData: ", selected_option)
	else:
		print("[Menu] GlobalData not found; cannot save last menu selection")

func _on_remote_navigate(direction: String):
	"""Handle navigation from remote control"""

	if direction == "left":
		selected_option -= 1
		if selected_option < 0:
			selected_option = main_menu_options.size() - 1
		_update_selection()

	elif direction == "right":
		selected_option += 1
		if selected_option >= main_menu_options.size():
			selected_option = 0
		_update_selection()

	elif direction == "down":
		selected_option += 1
		if selected_option >= main_menu_options.size():
			selected_option = 0
		_update_selection()

	elif direction == "up":
		selected_option -= 1
		if selected_option < 0:
			selected_option = main_menu_options.size() - 1
		_update_selection()

func _on_remote_enter():
	"""Handle enter press from remote control"""
	print("[Menu] Enter pressed - option: ", selected_option)
	if selected_option == 0:
		_on_fruitcatcher_pressed()
	elif selected_option == 1:
		_on_monkeyduel_pressed()
	elif selected_option == 2:
		_on_mole_attack_pressed()
	elif selected_option == 3:
		_on_tictactoe_pressed()
	elif selected_option == 4:
		_on_painter_pressed()

func _on_remote_back_pressed():
	"""Handle back press from remote control to return to main menu"""
	print("[Menu] Back pressed - returning to main menu")
	# Show global status bar when returning to main menu
	var status_bars = get_tree().get_nodes_in_group("status_bar")
	for status_bar in status_bars:
		status_bar.visible = true
		print("[Games Menu] Showed global status bar: ", status_bar.name)
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scene/main_menu/main_menu.tscn")

func _update_selection():
	"""Update the focus to the selected button"""
	if selected_option >= 0 and selected_option < main_menu_options.size():
		main_menu_options[selected_option].grab_focus()
	print("[Menu] Selection updated to option: ", selected_option)

func _on_fruitcatcher_pressed():
	"""Handle FruitCatcher button press"""
	print("[Menu] FruitCatcher selected")
	# Load the game scene
	selected_option = 0
	_save_last_selection()
	get_tree().change_scene_to_file("res://scene/games/fruitninja.tscn")

func _on_monkeyduel_pressed():
	"""Handle Monkey Duel button press"""
	print("[Menu] Monkey Duel selected")
	selected_option = 1
	_save_last_selection()
	get_tree().change_scene_to_file("res://scene/games/monkey/game_monkey.tscn")

func _on_mole_attack_pressed():
	"""Handle Mole Attack button press"""
	print("[Menu] Mole Attack selected")
	selected_option = 2
	_save_last_selection()
	get_tree().change_scene_to_file("res://scene/games/wack-a-mole/game_mole.tscn")

func _on_tictactoe_pressed():
	"""Handle tictactoe button press"""
	print("[Menu] Tictactoe selected")
	selected_option = 3
	_save_last_selection()
	get_tree().change_scene_to_file("res://scene/games/tictactoe/main.tscn")

func _on_painter_pressed():
	"""Handle painter button press"""
	print("[Menu] Painter selected")
	selected_option = 4
	_save_last_selection()
	get_tree().change_scene_to_file("res://games/shoot-painter/scene/painter.tscn")
