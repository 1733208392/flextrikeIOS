extends Button

class_name CustomButton

enum ThemeMode {
	ORANGE,
	DARK,
	YELLOW,
	GREY
}

var current_theme_mode: ThemeMode = ThemeMode.ORANGE

# Style boxes for different themes
var orange_styles = {}
var dark_styles = {}
var yellow_styles = {}
var grey_styles = {}

func _ready():
	initialize_styles()
	set_theme_mode(current_theme_mode)

func initialize_styles():
	# Orange theme styles
	orange_styles["normal"] = create_style_box(Color(1, 0.6, 0.2, 1), Color(0.8, 0.4, 0.1, 1))
	orange_styles["hover"] = create_enhanced_style_box(Color(1, 0.8, 0.4, 1), Color(1, 1, 1, 1))
	orange_styles["pressed"] = create_style_box(Color(0.8, 0.5, 0.1, 1), Color(0.6, 0.3, 0.05, 1))
	orange_styles["focus"] = create_enhanced_style_box(Color(1, 0.75, 0.35, 1), Color(0, 1, 1, 1))
	
	# Dark theme styles
	dark_styles["normal"] = create_style_box(Color(0.3, 0.3, 0.3, 1), Color(0.5, 0.5, 0.5, 1))
	dark_styles["hover"] = create_enhanced_style_box(Color(0.5, 0.5, 0.5, 1), Color(1, 1, 1, 1))
	dark_styles["pressed"] = create_style_box(Color(0.2, 0.2, 0.2, 1), Color(0.4, 0.4, 0.4, 1))
	dark_styles["focus"] = create_enhanced_style_box(Color(0.45, 0.45, 0.45, 1), Color(0, 1, 1, 1))
	
	# Yellow theme styles
	yellow_styles["normal"] = create_style_box(Color(1, 0.9, 0.2, 1), Color(0.8, 0.7, 0.1, 1))
	yellow_styles["hover"] = create_enhanced_style_box(Color(1, 0.95, 0.4, 1), Color(1, 1, 1, 1))
	yellow_styles["pressed"] = create_style_box(Color(0.8, 0.7, 0.1, 1), Color(0.6, 0.5, 0.05, 1))
	yellow_styles["focus"] = create_enhanced_style_box(Color(1, 0.92, 0.35, 1), Color(0, 1, 1, 1))
	
	# Grey theme styles
	grey_styles["normal"] = create_style_box(Color(0.6, 0.6, 0.6, 1), Color(0.4, 0.4, 0.4, 1))
	grey_styles["hover"] = create_enhanced_style_box(Color(0.8, 0.8, 0.8, 1), Color(1, 1, 1, 1))
	grey_styles["pressed"] = create_style_box(Color(0.5, 0.5, 0.5, 1), Color(0.3, 0.3, 0.3, 1))
	grey_styles["focus"] = create_enhanced_style_box(Color(0.75, 0.75, 0.75, 1), Color(0, 1, 1, 1))

func create_style_box(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func create_enhanced_style_box(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func set_theme_mode(mode: ThemeMode):
	current_theme_mode = mode
	var styles_to_use = {}
	
	match mode:
		ThemeMode.ORANGE:
			styles_to_use = orange_styles
			modulate = Color.WHITE
		ThemeMode.DARK:
			styles_to_use = dark_styles
			modulate = Color.WHITE
		ThemeMode.YELLOW:
			styles_to_use = yellow_styles
			modulate = Color.WHITE
		ThemeMode.GREY:
			styles_to_use = grey_styles
			modulate = Color.WHITE
	
	# Apply the styles
	add_theme_stylebox_override("normal", styles_to_use["normal"])
	add_theme_stylebox_override("hover", styles_to_use["hover"])
	add_theme_stylebox_override("pressed", styles_to_use["pressed"])
	add_theme_stylebox_override("focus", styles_to_use["focus"])
	
	# Set text colors based on theme
	match mode:
		ThemeMode.ORANGE, ThemeMode.YELLOW:
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("font_hover_color", Color.WHITE)
			add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
		ThemeMode.DARK, ThemeMode.GREY:
			add_theme_color_override("font_color", Color.WHITE)
			add_theme_color_override("font_hover_color", Color.WHITE)
			add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.8))
	
	# Add outline for better text visibility
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 2)

func cycle_theme():
	var next_mode = (current_theme_mode + 1) % ThemeMode.size()
	set_theme_mode(next_mode)

func get_theme_name() -> String:
	match current_theme_mode:
		ThemeMode.ORANGE:
			return "Orange"
		ThemeMode.DARK:
			return "Dark"
		ThemeMode.YELLOW:
			return "Yellow"
		ThemeMode.GREY:
			return "Grey"
		_:
			return "Unknown"
