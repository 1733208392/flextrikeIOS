extends Control

@onready var orange_button = $VBoxContainer/OrangeButton
@onready var dark_button = $VBoxContainer/DarkButton
@onready var yellow_button = $VBoxContainer/YellowButton
@onready var grey_button = $VBoxContainer/GreyButton
@onready var cycle_button = $VBoxContainer/CycleButton

func _ready():
	# Set different themes for each button
	orange_button.set_theme_mode(CustomButton.ThemeMode.ORANGE)
	dark_button.set_theme_mode(CustomButton.ThemeMode.DARK)
	yellow_button.set_theme_mode(CustomButton.ThemeMode.YELLOW)
	grey_button.set_theme_mode(CustomButton.ThemeMode.GREY)
	
	# Connect signals
	orange_button.pressed.connect(_on_button_pressed.bind("Orange"))
	dark_button.pressed.connect(_on_button_pressed.bind("Dark"))
	yellow_button.pressed.connect(_on_button_pressed.bind("Yellow"))
	grey_button.pressed.connect(_on_button_pressed.bind("Grey"))
	cycle_button.pressed.connect(_on_cycle_button_pressed)

func _on_button_pressed(theme_name: String):
	print("Pressed ", theme_name, " button")

func _on_cycle_button_pressed():
	cycle_button.cycle_theme()
	print("Current theme: ", cycle_button.get_theme_name())