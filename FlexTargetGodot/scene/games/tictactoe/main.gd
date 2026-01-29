extends Control

const Cell = preload("res://scene/games/tictactoe/cell.tscn")

@export_enum("Human", "AI") var play_with : String = "AI"
@export_enum("Easy", "Medium", "Hard") var ai_difficulty : String = "Hard"

var cells : Array = []
var turn : int = 0

var is_game_end : bool = false
@onready var btn_ai = $PlayModeContainer/AI
@onready var btn_human = $PlayModeContainer/Human
@onready var difficulty_row = $HBoxContainerDifficultLevel

# Difficulty buttons for remote focus navigation
@onready var btn_easy = $HBoxContainerDifficultLevel/Easy
@onready var btn_medium = $HBoxContainerDifficultLevel/Medium
@onready var btn_hard = $HBoxContainerDifficultLevel/Hard
var _difficulty_buttons: Array = []
var _focus_index: int = 0  # 0 = Easy, 1 = Medium, 2 = Hard
var _difficulty_modes: Array = ["Easy", "Medium", "Hard"]
const _difficulty_label_keys: Array = ["difficulty_easy", "difficulty_medium", "difficulty_hard"]
const _play_mode_label_keys: Dictionary = {
	"AI": "play_mode_ai",
	"Human": "play_mode_human"
}
const FOCUS_SECTION_PLAY_MODE: int = 0
const FOCUS_SECTION_DIFFICULTY: int = 1
var _focus_section: int = FOCUS_SECTION_PLAY_MODE
var _play_mode_buttons: Array = []
var _play_mode_focus_index: int = 0  # 0 = AI, 1 = Human
var _suppress_play_mode_toggled: bool = false


func _ready():
	for cell_count in range(9):
		var cell = Cell.instantiate()
		cell.main = self
		$Cells.add_child(cell)
		cells.append(cell)
		cell.cell_updated.connect(_on_cell_updated)
	_setup_play_mode_buttons()
	_difficulty_buttons = [btn_easy, btn_medium, btn_hard]
	_focus_index = 0
	_set_difficulty_button_states()
	_apply_play_mode(play_with)

	# Connect to WebSocket bullet hits if available so physical shots can update the board
	var ws_listener = get_node_or_null("/root/WebSocketListener")
	if ws_listener:
		if ws_listener.has_signal("bullet_hit"):
			ws_listener.bullet_hit.connect(_on_websocket_bullet_hit)
			print("[TicTacToe] Connected to WebSocketListener bullet_hit")
		else:
			print("[TicTacToe] WebSocketListener found but no bullet_hit signal")
	else:
		print("[TicTacToe] No WebSocketListener singleton found - live shots disabled")

	# Load persisted difficulty (if any). If HttpService is present this is async
	# and the load callback will call _apply_focus; otherwise the sync fallback
	# will call _apply_focus immediately.
	_load_difficulty_setting()
	_translate_difficulty_buttons()
	_translate_play_mode_buttons()
	_translate_restart_button()

	# Connect to MenuController navigate for remote left/right directives
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller:
		menu_controller.navigate.connect(_on_menu_navigate)
		if menu_controller.has_signal("enter_pressed"):
			menu_controller.enter_pressed.connect(Callable(self, "_on_menu_enter"))
		if menu_controller.has_signal("back_pressed"):
			menu_controller.back_pressed.connect(Callable(self, "_on_menu_back_pressed"))
		if menu_controller.has_signal("homepage_pressed"):
			menu_controller.homepage_pressed.connect(Callable(self, "_on_menu_back_pressed"))
		print("[TicTacToe] Connected to MenuController.navigate for remote directives")

	# Connect difficulty buttons to change AI difficulty when pressed
	for i in range(_difficulty_buttons.size()):
		var b = _difficulty_buttons[i]
		if is_instance_valid(b) and b.has_signal("pressed"):
			b.pressed.connect(Callable(self, "_on_difficulty_button_pressed_focus").bind(i))

	# Notify HttpService that this mini-game has started (mirrors the main game implementation)
	var http_service = get_node_or_null("/root/HttpService")
	if http_service and http_service.has_method("start_game"):
		http_service.start_game(func(result, response_code, _headers, _body):
			print("[TicTacToe] Game started - Result: ", result, ", Response Code: ", response_code)
		)

func _setup_play_mode_buttons() -> void:
	_play_mode_buttons.clear()
	if is_instance_valid(btn_ai):
		_play_mode_buttons.append(btn_ai)
		btn_ai.toggled.connect(Callable(self, "_on_play_mode_button_toggled").bind("AI"))
	if is_instance_valid(btn_human):
		_play_mode_buttons.append(btn_human)
		btn_human.toggled.connect(Callable(self, "_on_play_mode_button_toggled").bind("Human"))

func _update_difficulty_controls() -> void:
	var ai_active = play_with == "AI"
	for btn in _difficulty_buttons:
		if is_instance_valid(btn):
			btn.disabled = not ai_active

func _update_difficulty_visibility_by_focus() -> void:
	if not is_instance_valid(difficulty_row):
		return
	var should_show = play_with == "AI" and (_focus_section == FOCUS_SECTION_DIFFICULTY or (_focus_section == FOCUS_SECTION_PLAY_MODE and _play_mode_focus_index == 0))
	difficulty_row.visible = should_show

func _apply_play_mode(mode: String) -> void:
	if mode != "AI" and mode != "Human":
		return
	play_with = mode
	_play_mode_focus_index = _play_mode_index_for_mode(mode)
	_update_difficulty_controls()
	_apply_play_mode_toggles(mode)
	_focus_section = FOCUS_SECTION_PLAY_MODE
	_update_difficulty_visibility_by_focus()
	call_deferred("_apply_focus")

func _on_play_mode_button_toggled(is_pressed: bool, mode: String) -> void:
	if _suppress_play_mode_toggled or not is_pressed:
		return
	_apply_play_mode(mode)

func _apply_play_mode_toggles(mode: String) -> void:
	_suppress_play_mode_toggled = true
	if is_instance_valid(btn_ai):
		btn_ai.set_pressed(mode == "AI")
	if is_instance_valid(btn_human):
		btn_human.set_pressed(mode == "Human")
	_suppress_play_mode_toggled = false

func _play_mode_index_for_mode(mode: String) -> int:
	return 0 if mode == "AI" else 1

func _on_cell_updated(_cell):
	if is_game_end:
		return

	var match_result = check_match()
	print(match_result)

	if match_result:
		is_game_end = true
		start_win_animation(match_result)

	elif play_with == "AI" and turn == 1:
		# AI's turn (plays O). Choose move based on difficulty.
		var idx = choose_ai_move()
		if idx >= 0 and cells[idx].cell_value == "":
			cells[idx].draw_cell()

func _on_websocket_bullet_hit(pos: Vector2, a: int = 0, t: int = 0) -> void:
	"""Handle incoming bullet hit positions and map them to a tic-tac-toe cell.
	Attempts to match the incoming global/screen `pos` to each cell's global rect
	and triggers the cell update if an empty cell was hit.
	"""
	# Try direct match against each cell's global rect
	# First check if the Restart button was hit (higher priority)
	var restart_btn = get_node_or_null("RestartButton")
	if restart_btn:
		var rrect: Rect2 = Rect2()
		if restart_btn.has_method("get_global_rect"):
			rrect = restart_btn.get_global_rect()
		else:
			var rgp = null
			if restart_btn.has_method("get_global_position"):
				rgp = restart_btn.get_global_position()
			elif "global_position" in restart_btn:
				rgp = restart_btn.global_position
			var rsize = Vector2()
			if "rect_size" in restart_btn:
				rsize = restart_btn.rect_size
			elif "size" in restart_btn:
				rsize = restart_btn.size
			if rgp != null:
				rrect = Rect2(rgp, rsize)
		if rrect.has_point(pos):
			print("[TicTacToe] WebSocket hit matched RestartButton")
			_on_restart_button_pressed()
			return
	for cell in cells:
		if not is_instance_valid(cell):
			continue
		# Prefer Control.get_global_rect() if available (returns a Rect2)
		var rect: Rect2 = Rect2()
		if cell.has_method("get_global_rect"):
			rect = cell.get_global_rect()
		else:
			# Fallback: try common properties used by different Godot versions
			var gp = null
			if cell.has_method("get_global_position"):
				gp = cell.get_global_position()
			elif "global_position" in cell:
				gp = cell.global_position
			elif "rect_global_position" in cell and "rect_size" in cell:
				rect = Rect2(cell.rect_global_position, cell.rect_size)
			# If we have a global position, construct rect from that and size if available
			if gp != null:
				var rect_size_vec = Vector2()
				if "rect_size" in cell:
					rect_size_vec = cell.rect_size
				elif "size" in cell:
					rect_size_vec = cell.size
				rect = Rect2(gp, rect_size_vec)
		if rect.has_point(pos):
			print("[TicTacToe] WebSocket hit matched cell index %d" % cells.find(cell))
			# Only update if the cell is empty
			if cell.cell_value == "":
				cell.draw_cell()
			else:
				print("[TicTacToe] Cell already occupied: %s" % cell.cell_value)
			return

	# If no direct match, log for debugging. Coordinate systems may differ (world vs UI).
	print("[TicTacToe] WebSocket hit did not match any cell rect: %s" % pos)

func _translate_difficulty_buttons() -> void:
	for i in range(_difficulty_buttons.size()):
		var btn = _difficulty_buttons[i]
		if btn and btn is Button and i < _difficulty_label_keys.size():
			btn.text = tr(_difficulty_label_keys[i])

func _set_difficulty_button_states() -> void:
	for i in range(_difficulty_buttons.size()):
		var btn = _difficulty_buttons[i]
		if btn and btn is Button:
			btn.set_pressed(i == _focus_index)

func _translate_play_mode_buttons() -> void:
	if is_instance_valid(btn_ai):
		btn_ai.text = tr(_play_mode_label_keys.get("AI", "AI"))
	if is_instance_valid(btn_human):
		btn_human.text = tr(_play_mode_label_keys.get("Human", "Human"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_translate_difficulty_buttons()
		_translate_play_mode_buttons()

func _translate_restart_button() -> void:
	var restart_btn = get_node_or_null("RestartButton")
	if restart_btn and restart_btn is Button:
		restart_btn.text = tr("restart")

func _apply_focus() -> void:
	if _focus_section == FOCUS_SECTION_DIFFICULTY and play_with == "AI" and _difficulty_buttons.size() > 0:
		_focus_index = clamp(_focus_index, 0, _difficulty_buttons.size() - 1)
		var difficulty_btn = _difficulty_buttons[_focus_index]
		if is_instance_valid(difficulty_btn) and difficulty_btn.has_method("grab_focus"):
			difficulty_btn.grab_focus()
			print("[TicTacToe] Difficulty focus set to index %d" % _focus_index)
			_update_difficulty_visibility_by_focus()
		return

	# Fallback focus stays on the play mode buttons
	_focus_section = FOCUS_SECTION_PLAY_MODE
	if _play_mode_buttons.size() == 0:
		return
	_play_mode_focus_index = clamp(_play_mode_focus_index, 0, _play_mode_buttons.size() - 1)
	var play_mode_btn = _play_mode_buttons[_play_mode_focus_index]
	if is_instance_valid(play_mode_btn) and play_mode_btn.has_method("grab_focus"):
		play_mode_btn.grab_focus()
		print("[TicTacToe] Play mode button focused")
	_update_difficulty_visibility_by_focus()

func _on_difficulty_button_pressed_focus(index: int) -> void:
	# Local mouse/touch press should set focus to the button index row
	_focus_section = FOCUS_SECTION_DIFFICULTY
	_focus_index = index
	_set_difficulty_button_states()
	_apply_focus()
	print("[TicTacToe] Difficulty button focused by local press, index= %d" % index)

func _on_menu_enter() -> void:
	if _focus_section == FOCUS_SECTION_PLAY_MODE:
		var mode = "AI" if _play_mode_focus_index == 0 else "Human"
		_apply_play_mode(mode)
		return
	_apply_selected_difficulty()

func _apply_selected_difficulty() -> void:
	if _difficulty_buttons.size() == 0:
		return
	var focus_owner = get_viewport().gui_get_focus_owner()
	var index = _focus_index
	for i in range(_difficulty_buttons.size()):
		if is_instance_valid(_difficulty_buttons[i]) and _difficulty_buttons[i] == focus_owner:
			index = i
			break
	index = clamp(index, 0, _difficulty_buttons.size() - 1)
	match index:
		0:
			ai_difficulty = "Easy"
		1:
			ai_difficulty = "Medium"
		2:
			ai_difficulty = "Hard"
	print("[TicTacToe] Remote Enter applied difficulty: %s (index %d)" % [ai_difficulty, index])
	_focus_index = index
	_set_difficulty_button_states()
	_save_difficulty_setting()
	_on_restart_button_pressed()

func _difficulty_index_from_string(d: String) -> int:
	match d:
		"Easy":
			return 0
		"Medium":
			return 1
		"Hard":
			return 2
	return 2

func _apply_saved_difficulty(entry: Dictionary) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	if not entry.has("ai_difficulty"):
		return false
	ai_difficulty = str(entry["ai_difficulty"])
	_focus_index = _difficulty_index_from_string(ai_difficulty)
	_set_difficulty_button_states()
	print("[TicTacToe] Restored difficulty from GlobalData: %s (focus index %d)" % [ai_difficulty, _focus_index])
	call_deferred("_apply_focus")
	return true

func _save_difficulty_setting() -> void:
	var global_data = get_node_or_null("/root/GlobalData")
	if not global_data:
		print("[TicTacToe] Warning: GlobalData not available, cannot save difficulty")
		return

	var tictactoe_entry = {}
	if global_data.settings_dict.has("tictactoe"):
		var existing = global_data.settings_dict.get("tictactoe")
		if typeof(existing) == TYPE_DICTIONARY:
			tictactoe_entry = existing.duplicate(true)

	tictactoe_entry["ai_difficulty"] = ai_difficulty
	global_data.settings_dict["tictactoe"] = tictactoe_entry

	var http = get_node_or_null("/root/HttpService")
	if http and http.has_method("save_game"):
		var settings_snapshot = global_data.settings_dict.duplicate(true)
		var content = JSON.stringify(settings_snapshot)
		http.save_game(Callable(self, "_on_http_save_game_result"), "settings", content)
	else:
		print("[TicTacToe] Warning: HttpService.save_game not available, difficulty persisted only in GlobalData")

func _load_difficulty_setting() -> void:
	var global_data = get_node_or_null("/root/GlobalData")
	if global_data and global_data.settings_dict.has("tictactoe"):
		var entry = global_data.settings_dict.get("tictactoe")
		if _apply_saved_difficulty(entry):
			return

	# Prefer HttpService.load_game to read settings.json when GlobalData entry is missing
	var http = get_node_or_null("/root/HttpService")
	if http and http.has_method("load_game"):
		http.load_game(Callable(self, "_on_http_load_game_result"), "settings")
		# Async; callback will call _apply_focus when loaded (or on failure)
		return

	# Nothing else available, fall back to defaults
	_focus_index = 0
	call_deferred("_apply_focus")

func _on_http_load_game_result(result, response_code, _headers, body) -> void:
	# Callback for HttpService.load_game
	if response_code != 200 or result != HTTPRequest.RESULT_SUCCESS:
		print("[TicTacToe] HttpService.load_game failed, code= %s, result= %s" % [str(response_code), str(result)])
		# On failure, ensure default focus is Easy
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	if not json:
		print("[TicTacToe] HttpService.load_game: JSON parse failed")
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	if not json.has("data"):
		print("[TicTacToe] HttpService.load_game: no data field")
		_focus_index = 0
		call_deferred("_apply_focus")
		return
	var data = json["data"]
	var parsed = null
	if typeof(data) == TYPE_STRING:
		parsed = JSON.parse_string(data)
		if not parsed:
			parsed = null
	elif typeof(data) == TYPE_DICTIONARY:
		parsed = data
	if parsed and typeof(parsed) == TYPE_DICTIONARY and parsed.has("tictactoe"):
		var t = parsed["tictactoe"]
		if typeof(t) == TYPE_DICTIONARY and t.has("ai_difficulty"):
			ai_difficulty = str(t["ai_difficulty"])
			_focus_index = _difficulty_index_from_string(ai_difficulty)
			print("[TicTacToe] Loaded persisted difficulty from HttpService: %s (focus index %d)" % [ai_difficulty, _focus_index])
			var global_data = get_node_or_null("/root/GlobalData")
			if global_data:
				global_data.settings_dict["tictactoe"] = t
			# Now that we have loaded the persisted setting, apply focus to that button
			call_deferred("_apply_focus")
			return
	# No valid persisted difficulty found — default to Easy
	_focus_index = 0
	call_deferred("_apply_focus")

func _on_http_save_game_result(result, response_code, _headers, _body) -> void:
	# Callback for HttpService.save_game
	if response_code != 200 or result != HTTPRequest.RESULT_SUCCESS:
		print("[TicTacToe] HttpService.save_game failed, code= %s, result= %s" % [str(response_code), str(result)])
	else:
		print("[TicTacToe] Difficulty persisted to HttpService settings")

func _on_menu_navigate(direction: String) -> void:
	match direction:
		"up":
			if _focus_section == FOCUS_SECTION_DIFFICULTY:
				_focus_section = FOCUS_SECTION_PLAY_MODE
				_apply_focus()
		"down":
			if _focus_section == FOCUS_SECTION_PLAY_MODE and play_with == "AI" and difficulty_row.visible:
				_focus_section = FOCUS_SECTION_DIFFICULTY
				_apply_focus()
		"left", "right":
			if _focus_section == FOCUS_SECTION_PLAY_MODE:
				_navigate_play_mode(direction)
			elif _focus_section == FOCUS_SECTION_DIFFICULTY:
				_navigate_difficulty(direction)

func _navigate_play_mode(direction: String) -> void:
	if _play_mode_buttons.size() == 0:
		return
	var step = -1 if direction == "left" else 1
	_play_mode_focus_index = (_play_mode_focus_index + step + _play_mode_buttons.size()) % _play_mode_buttons.size()
	_apply_focus()
	_play_cursor_sound()

func _navigate_difficulty(direction: String) -> void:
	if _difficulty_buttons.size() == 0:
		return
	var step = -1 if direction == "left" else 1
	_focus_index = (_focus_index + step + _difficulty_buttons.size()) % _difficulty_buttons.size()
	_apply_focus()
	_play_cursor_sound()

func _play_cursor_sound() -> void:
	var menu_controller = get_node_or_null("/root/MenuController")
	if menu_controller and menu_controller.has_method("play_cursor_sound"):
		menu_controller.play_cursor_sound()

func _unhandled_input(event: InputEvent) -> void:
	# Allow keyboard Enter to trigger the remote Enter behavior
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_menu_enter()

func _on_menu_back_pressed() -> void:
	print("[TicTacToe] Remote back/home pressed, returning to menu")
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	# Change to the shared menu scene
	var target = "res://scene/games/menu/menu.tscn"
	if ResourceLoader.exists(target):
		get_tree().change_scene_to_file(target)
	else:
		print("[TicTacToe] Menu scene not found: %s" % target)

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func check_match():
	for h in range(3):
		if cells[0+3*h].cell_value == "X" and cells[1+3*h].cell_value == "X" and cells[2+3*h].cell_value == "X":
			return ["X", 1+3*h, 2+3*h, 3+3*h]
	for v in range(3):
		if cells[0+v].cell_value == "X" and cells[3+v].cell_value == "X" and cells[6+v].cell_value == "X":
			return ["X", 1+v, 4+v, 7+v]
	if cells[0].cell_value == "X" and cells[4].cell_value == "X" and cells[8].cell_value == "X":
		return ["X", 1, 5, 9]
	elif cells[2].cell_value == "X" and cells[4].cell_value == "X" and cells[6].cell_value == "X":
		return ["X", 3, 5, 7]

	for h in range(3):
		if cells[0+3*h].cell_value == "O" and cells[1+3*h].cell_value == "O" and cells[2+3*h].cell_value == "O":
			return ["O", 1+3*h, 2+3*h, 3+3*h]
	for v in range(3):
		if cells[0+v].cell_value == "O" and cells[3+v].cell_value == "O" and cells[6+v].cell_value == "O":
			return ["O", 1+v, 4+v, 7+v]
	if cells[0].cell_value == "O" and cells[4].cell_value == "O" and cells[8].cell_value == "O":
		return ["O", 1, 5, 9]
	elif cells[2].cell_value == "O" and cells[4].cell_value == "O" and cells[6].cell_value == "O":
		return ["O", 3, 5, 7]

	var full = true
	for cell in cells:
		if cell.cell_value == "":
			full = false

	if full: return["Draw", 0, 0, 0]

func start_win_animation(match_result: Array):
	var color: Color

	if match_result[0] == "X":
		color = Color.BLUE
	elif match_result[0] == "O":
		color = Color.RED

	for c in range(3):
		cells[match_result[c+1]-1].glow(color)

# -----------------------
# AI / Difficulty helpers
# -----------------------

func board_array_from_cells() -> Array:
	var b = []
	for c in cells:
		b.append(c.cell_value)
	return b

func available_moves(board: Array) -> Array:
	var moves = []
	for i in range(board.size()):
		if board[i] == "":
			moves.append(i)
	return moves

func check_winner_on_board(board: Array):
	var wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]
	for w in wins:
		var a = board[w[0]]
		if a != "" and a == board[w[1]] and a == board[w[2]]:
			return a
	var full = true
	for v in board:
		if v == "":
			full = false
	if full:
		return "Draw"
	return null

func evaluate_board(board: Array) -> int:
	var winner = check_winner_on_board(board)
	if winner == "O":
		return 10
	elif winner == "X":
		return -10
	return 0

func minimax(board: Array, depth: int, is_maximizing: bool, alpha: int, beta: int) -> int:
	var score = evaluate_board(board)
	if score == 10 or score == -10:
		return score
	if check_winner_on_board(board) == "Draw":
		return 0

	if is_maximizing:
		var best = -1000
		for i in available_moves(board):
			board[i] = "O"
			var val = minimax(board, depth+1, false, alpha, beta)
			board[i] = ""
			best = max(best, val)
			alpha = max(alpha, best)
			if beta <= alpha:
				break
		return best
	else:
		var best = 1000
		for i in available_moves(board):
			board[i] = "X"
			var val = minimax(board, depth+1, true, alpha, beta)
			board[i] = ""
			best = min(best, val)
			beta = min(beta, best)
			if beta <= alpha:
				break
		return best

func find_best_move() -> int:
	var board = board_array_from_cells()
	var best_val = -1000
	var best_move = -1
	for i in available_moves(board):
		board[i] = "O"
		var move_val = minimax(board, 0, false, -1000, 1000)
		board[i] = ""
		if move_val > best_val:
			best_val = move_val
			best_move = i
	return best_move

func choose_ai_move() -> int:
	randomize()
	var board = board_array_from_cells()
	var moves = available_moves(board)
	if moves.size() == 0:
		return -1

	match ai_difficulty:
		"Easy":
			return moves[randi() % moves.size()]
		"Medium":
			# 50% optimal, 50% random
			if randi() % 100 < 50:
				return moves[randi() % moves.size()]
			return find_best_move()
		"Hard":
			# Mostly optimal, small chance to pick a suboptimal move
			if randi() % 100 < 10:
				return moves[randi() % moves.size()]
			return find_best_move()
	return find_best_move()
