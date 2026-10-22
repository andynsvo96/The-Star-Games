extends BaseGame

const Rules = preload("res://Games/quoridor/host/rules.gd")
const Board = preload("res://Games/quoridor/host/board.gd")
var rules := Rules.new()
var screen: GameScreen
var board: Control
var board_frame: CenterContainer
var celebration: GameCelebration
var seats: Array = []
var missing: Dictionary = {}
var score_cards: Array[Dictionary] = []
var wall_labels: Array[Label] = []
var replay_button: Button
var move_button: Button
var wall_button: Button
var rotate_button: Button
var confirm_button: Button
var controls: HFlowContainer
var difficulty_choice: OptionButton
var player_choice: OptionButton
var computer_choice: OptionButton
var host_toggle: Button
var apply_button: Button
var history_log: RichTextLabel
var settings_hint: Label
var host_plays := false
var stopped := false
var result_sent := false
var difficulty := Rules.Difficulty.MEDIUM
var player_count := 2
var computer_count := 1
var staged_players := 2
var staged_computers := 1
var staged_host := false
var staged_difficulty := Rules.Difficulty.MEDIUM
var disconnected: Dictionary = {}
var wall_mode := false
var orientation := "h"
var preview: Dictionary = {}
var cached_revision := -1
var cached_walls: Array = []
var shown_round := ""
var shown_revision := -1
var shown_outcome := 0
var motion_until := 0
var sounds: Dictionary = {}
var ai_thread := Thread.new()
var ai_ticket := 0
var ai_running_ticket := -1
var ai_revision := -1
var ai_side := 0
var ai_requested := false
var ai_after := 0


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("QUORIDOR")
	screen.use_playful_style("res://Games/quoridor/art/courtyard", "garden")
	screen.add_title_art(RuntimeAssets.texture("res://Games/quoridor/art/title.svg"), 56, false, true)
	GameLook.illustrated_control(screen.back_button, RuntimeAssets.texture("res://ui/playful/control-back.svg"), false, true, true)
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	var layout := screen.add_centered_layout(true, true)
	for index in 4:
		var parent: VBoxContainer = layout.left_sidebar if index % 2 == 0 else layout.sidebar
		var card := screen.add_score_card(parent, null, Color("25b3ab"), "ornate")
		score_cards.append(card)
		var counter := screen.add_score_stat(card, RuntimeAssets.texture("res://ui/playful/stat-walls.svg"), "10 WALLS")
		wall_labels.append(counter)
		card.panel.visible = index < 2
	board_frame = CenterContainer.new()
	layout.playfield.add_child(board_frame)
	board = Board.new()
	board.custom_minimum_size = Vector2(400, 400)
	board_frame.add_child(board)
	board.cell_pressed.connect(_host_cell)
	board.anchor_pressed.connect(_host_anchor)
	board.settled.connect(func() -> void:
		if not stopped:
			_render()
	)
	celebration = GameCelebration.new()
	board.add_child(celebration)
	controls = HFlowContainer.new()
	controls.alignment = FlowContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 2)
	layout.playfield.add_child(controls)
	move_button = _button(controls, "MOVE", func() -> void: _set_wall_mode(false))
	wall_button = _button(controls, "WALL", func() -> void: _set_wall_mode(true))
	move_button.toggle_mode = true
	wall_button.toggle_mode = true
	confirm_button = _button(controls, "PLACE", _confirm_wall)
	confirm_button.hide()
	rotate_button = _button(controls, "ROTATE", _rotate)
	replay_button = _button(layout.playfield, "PLAY AGAIN", _play_again)
	replay_button.hide()
	screen.center_board(board_frame, replay_button, controls, 0.5, true)
	var details := screen.add_corner_details(["SETTINGS", "HISTORY"], Callable(), false, false, true)
	player_choice = screen.add_choice_control(details[0], "TOTAL PLAYERS", ["2", "4"], true)
	player_choice.item_selected.connect(_select_players)
	computer_choice = screen.add_choice_control(details[0], "COMPUTER PLAYERS", [], true)
	computer_choice.item_selected.connect(_select_computers)
	host_toggle = screen.add_toggle_control(details[0], "HOST PLAYS", false)
	host_toggle.toggled.connect(_select_host)
	difficulty_choice = screen.add_choice_control(details[0], "AI DIFFICULTY", ["Easy", "Medium", "Hard"], true)
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_select_difficulty)
	apply_button = Button.new()
	apply_button.text = "APPLY"
	details[0].add_child(apply_button)
	GameLook.action(apply_button, true)
	apply_button.pressed.connect(_apply_settings)
	settings_hint = screen.add_sidebar_text(details[0], "")
	var help := screen.add_details(details[0], "HOW TO PLAY")
	screen.add_sidebar_text(help, "Reach any square on the edge opposite your starting side first. Each turn, move your pawn or place a wall. Two players have ten walls each; four players have five each and take turns clockwise.\n\nMove one square up, down, left or right. Jump one adjacent pawn if the square behind it is open. If a wall, edge or another pawn blocks that jump, move to an open square beside it. Never jump two pawns or land on an occupied square.\n\nWalls span two square edges. They cannot overlap, cross, or seal any player's route to their goal.\n\nChoose WALL, tap a glowing junction, ROTATE if needed, then PLACE. Choose MOVE to cancel the preview.")
	history_log = screen.add_history_log(details[1], true)
	screen.resized.connect(_resize_board)
	screen.board_space_changed.connect(_resize_board)
	_resize_board.call_deferred()
	for effect in ["move", "wall", "win"]:
		var sound := AudioStreamPlayer.new()
		sound.stream = RuntimeAssets.audio("res://Games/quoridor/audio/%s.wav" % effect)
		sound.bus = "Effects"
		add_child(sound)
		sounds[effect] = sound


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	var icon_name := "move" if text == "MOVE" else "wall" if text in ["WALL", "PLACE"] else "rotate"
	GameLook.illustrated_control(button, RuntimeAssets.texture("res://ui/playful/control-%s.svg" % icon_name), text in ["MOVE", "PLACE", "PLAY AGAIN"], false, true)
	button.pressed.connect(callback)
	return button


func _resize_board() -> void:
	var available := screen.available_size()
	var compact := available.x < 700 or available.y < 580
	for button in [move_button, wall_button, confirm_button, rotate_button, replay_button]:
		GameLook.fit_illustrated_control(button, compact, true)
	controls.custom_minimum_size = Vector2(move_button.custom_minimum_size.x + maxf(wall_button.custom_minimum_size.x, confirm_button.custom_minimum_size.x) + rotate_button.custom_minimum_size.x + 12, 60 if compact else 76)
	var width := available.x - (490 if available.x >= 852 else 64)
	var edge := maxf(90, minf(620, minf(screen.board_height_limit(), width)))
	board.custom_minimum_size = Vector2.ONE * edge


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var default_players := 4 if context.players.size() > 2 else 2
	var default_difficulty := Rules.Difficulty.MEDIUM if context.players.is_empty() else Rules.Difficulty.HARD
	var saved := load_game_settings({"host_plays": context.players.is_empty(), "player_count": default_players, "computer_count": default_players - maxi(1, context.players.size()), "difficulty": default_difficulty})
	host_plays = context.players.is_empty() or saved.host_plays
	player_count = saved.player_count if saved.player_count in [2, 4] else default_players
	var minimum := maxi(0, player_count - context.players.size() - int(host_plays))
	computer_count = clampi(saved.computer_count, minimum, player_count - 1)
	difficulty = saved.difficulty if saved.difficulty in [0, 1, 2] else default_difficulty
	staged_players = player_count
	staged_computers = computer_count
	staged_host = host_plays
	staged_difficulty = difficulty
	_build_seats()
	rules = Rules.new(player_count)
	_update_settings()


func _build_seats() -> void:
	seats = [session.solo_profile.duplicate(true)] if host_plays else []
	var phone_count := player_count - computer_count - seats.size()
	seats.append_array(session.players.slice(0, phone_count).duplicate(true))
	var palette := ["#e8794b", "#24afa5", "#8f62cc", "#e3b831", "#2463eb", "#db5284", "#68a646", "#744b32"]
	for index in computer_count:
		var color: String = palette.filter(func(option: String) -> bool: return not seats.any(func(player: Dictionary) -> bool: return str(player.color).to_lower() == option))[0]
		seats.append({"id": "computer" if index == 0 else "computer-%d" % (index + 1), "display_name": "Computer" if computer_count == 1 else "Computer %d" % (index + 1), "color": color, "computer": true})
	missing.clear()
	for player in seats:
		if disconnected.has(str(player.id)):
			missing[str(player.id)] = true


func _is_computer(side: int) -> bool:
	return side >= 1 and side <= seats.size() and seats[side - 1].get("computer", false)


func start_game() -> void:
	_publish()
	_computer_turn()


func shutdown_game() -> void:
	stopped = true
	_cancel_computer()
	if ai_thread.is_started():
		ai_thread.wait_to_finish()
	board.settle_motion()
	celebration.clear()
	screen.background_media.set_active(false)
	for sound in sounds.values():
		sound.stop()


func _exit_tree() -> void:
	if ai_thread.is_started():
		ai_thread.wait_to_finish()


func _busy() -> bool:
	return Time.get_ticks_msec() < motion_until or (board != null and board.busy)


func _process(_delta: float) -> void:
	if stopped or session == null:
		return
	if motion_until > 0 and not _busy():
		motion_until = 0
		_publish()
		_computer_turn()
	if ai_thread.is_started() and not ai_thread.is_alive():
		var input: Dictionary = ai_thread.wait_to_finish()
		if ai_ticket == ai_running_ticket and ai_revision == rules.revision and missing.is_empty() and not _busy():
			_submit(input, ai_side)
	if ai_requested and not ai_thread.is_started() and not _busy() and Time.get_ticks_msec() >= ai_after:
		ai_requested = false
		if rules.outcome or not missing.is_empty() or not _is_computer(rules.turn):
			return
		ai_revision = rules.revision
		ai_running_ticket = ai_ticket
		ai_side = rules.turn
		ai_thread.start(Rules.computer_move.bind(rules.position(), difficulty))


func _cancel_computer() -> void:
	ai_ticket += 1
	ai_requested = false


func _computer_turn() -> void:
	if stopped or not missing.is_empty() or rules.outcome or not _is_computer(rules.turn):
		return
	ai_requested = true
	ai_after = Time.get_ticks_msec() + 320


func _can_host_play() -> bool:
	return not stopped and host_plays and missing.is_empty() and not _busy() and not board.busy and rules.outcome == 0 and rules.turn == 1


func _set_wall_mode(enabled: bool) -> void:
	if not _can_host_play():
		return
	wall_mode = enabled and rules.remaining[0] > 0 and not cached_walls.is_empty()
	preview.clear()
	_render()


func _rotate() -> void:
	if not _can_host_play() or not wall_mode:
		return
	orientation = "v" if orientation == "h" else "h"
	if not preview.is_empty():
		preview.orientation = orientation
		if not cached_walls.has(preview):
			preview.clear()
	_render()


func _host_cell(cell: int) -> void:
	if _can_host_play() and not wall_mode:
		_submit({"action": "move", "to": cell}, 1)


func _host_anchor(row: int, col: int) -> void:
	if not _can_host_play() or not wall_mode:
		return
	var candidate := {"row": row, "col": col, "orientation": orientation}
	if cached_walls.has(candidate):
		preview = candidate
		_render()


func _confirm_wall() -> void:
	if not preview.is_empty() and _can_host_play():
		var input := preview.duplicate()
		input.action = "wall"
		_submit(input, 1)


static func _valid_integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) < maximum


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if stopped or not session.players.any(func(player: Dictionary) -> bool: return player.id == player_id):
		return
	var side := 0
	for index in seats.size():
		if seats[index].id == player_id:
			side = index + 1
	if message.get("action") == "sync":
		_publish()
		return
	if side == 0:
		return
	if not _valid_integer(message.get("revision"), 2147483647) or int(message.revision) != rules.revision or not missing.is_empty():
		_publish()
		return
	if message.get("action") in ["play_again", "next"]:
		_play_again()
		return
	if message.get("action") == "move" and _valid_integer(message.get("to"), 81):
		_submit({"action": "move", "to": int(message.to)}, side)
	elif message.get("action") == "wall" and _valid_integer(message.get("row"), 8) and _valid_integer(message.get("col"), 8) and message.get("orientation") is String and message.orientation in ["h", "v"]:
		_submit({"action": "wall", "row": int(message.row), "col": int(message.col), "orientation": message.orientation}, side)


func _submit(input: Dictionary, side: int) -> void:
	if stopped or not missing.is_empty() or _busy() or side != rules.turn:
		return
	var accepted := false
	if input.get("action") == "move":
		accepted = rules.move(input.to, side)
	elif input.get("action") == "wall":
		accepted = rules.place_wall(input.row, input.col, input.orientation, side)
	if not accepted:
		_publish()
		return
	wall_mode = false
	preview.clear()
	if not session.reduced_motion:
		motion_until = Time.get_ticks_msec() + (260 if input.action == "move" else 180)
	sounds["move" if input.action == "move" else "wall"].play()
	_publish()
	if not _busy():
		_computer_turn()


func _select_difficulty(index: int) -> void:
	if stopped or not missing.is_empty() or index not in [0, 1, 2]:
		_update_settings()
		return
	staged_difficulty = index
	_update_settings()


func _select_players(index: int) -> void:
	if stopped or not missing.is_empty() or index not in [0, 1]:
		_update_settings()
		return
	staged_players = 2 if index == 0 else 4
	_update_settings()


func _select_computers(index: int) -> void:
	if stopped or not missing.is_empty() or index < 0 or index >= computer_choice.item_count:
		_update_settings()
		return
	staged_computers = computer_choice.get_item_id(index)
	_update_settings()


func _select_host(enabled: bool) -> void:
	if stopped or not missing.is_empty() or (not enabled and session.players.is_empty()):
		_update_settings()
		return
	staged_host = enabled
	staged_computers = maxi(0, staged_players - session.players.size() - int(enabled))
	_update_settings()


func _settings_changed() -> bool:
	return staged_players != player_count or staged_computers != computer_count or staged_host != host_plays or staged_difficulty != difficulty


func _update_settings() -> void:
	var available_humans := session.players.size() + int(staged_host)
	var minimum := maxi(0, staged_players - available_humans)
	staged_computers = clampi(staged_computers, minimum, staged_players - 1)
	player_choice.select(0 if staged_players == 2 else 1)
	if computer_choice.item_count != staged_players - minimum or computer_choice.get_item_id(0) != minimum:
		computer_choice.clear()
		for count in range(minimum, staged_players):
			computer_choice.add_item(str(count), count)
	computer_choice.select(staged_computers - minimum)
	host_toggle.set_pressed_no_signal(staged_host)
	host_toggle.text = "HOST PLAYS: ON" if staged_host else "HOST PLAYS: OFF"
	difficulty_choice.select(staged_difficulty)
	var paused := not missing.is_empty()
	player_choice.disabled = paused
	computer_choice.disabled = paused or computer_choice.item_count == 1
	host_toggle.disabled = paused or session.players.is_empty()
	difficulty_choice.disabled = paused or staged_computers == 0
	apply_button.disabled = paused or not _settings_changed()
	var humans := staged_players - staged_computers
	settings_hint.text = "%d %s + %d %s.\nHumans: host first when enabled, then phones in lobby order. Extra phones watch.\nApply starts a fresh session and clears wins/history." % [humans, "human" if humans == 1 else "humans", staged_computers, "computer" if staged_computers == 1 else "computers"]


func _apply_settings() -> void:
	if stopped or not missing.is_empty() or not _settings_changed():
		return
	_cancel_computer()
	board.settle_motion()
	celebration.clear()
	for sound in sounds.values():
		sound.stop()
	player_count = staged_players
	computer_count = staged_computers
	host_plays = staged_host
	difficulty = staged_difficulty
	save_game_settings({"player_count": player_count, "computer_count": computer_count, "host_plays": host_plays, "difficulty": difficulty})
	_build_seats()
	var next_revision: int = rules.revision + 1
	rules = Rules.new(player_count)
	rules.revision = next_revision
	result_sent = false
	motion_until = 0
	wall_mode = false
	orientation = "h"
	preview.clear()
	_publish()
	_computer_turn()


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	if not session.players.any(func(admitted: Dictionary) -> bool: return admitted.id == player.get("id")):
		return
	missing.erase(str(player.id))
	disconnected.erase(str(player.id))
	_publish()
	_computer_turn()


func player_disconnected(player_id: String) -> void:
	if session.players.any(func(player: Dictionary) -> bool: return player.id == player_id):
		disconnected[player_id] = true
	if seats.any(func(player: Dictionary) -> bool: return player.id == player_id):
		missing[player_id] = true
		_cancel_computer()
		preview.clear()
		board.settle_motion()
		_publish()


func _play_again() -> void:
	if stopped or not missing.is_empty() or _busy() or not rules.play_again():
		return
	_cancel_computer()
	result_sent = false
	wall_mode = false
	preview.clear()
	_publish()
	_computer_turn()


func _status() -> String:
	if not missing.is_empty():
		return "Paused: waiting for a player to reconnect."
	if rules.outcome:
		return "%s wins!" % seats[rules.outcome - 1].display_name
	if _is_computer(rules.turn):
		return "%s is thinking..." % seats[rules.turn - 1].display_name
	return "Your turn" if host_plays and rules.turn == 1 else "%s's turn" % seats[rules.turn - 1].display_name


func _history_text() -> String:
	var entries := PackedStringArray()
	for index in range(rules.history.size() - 1, -1, -1):
		var entry: Dictionary = rules.history[index]
		entries.append("Game %d: %s wins" % [entry.round, seats[entry.outcome - 1].display_name])
	return "No completed games yet." if entries.is_empty() else "\n\n".join(entries)


func _snapshot() -> Dictionary:
	if cached_revision != rules.revision:
		cached_walls = rules.legal_walls()
		cached_revision = rules.revision
	return {"pawns": rules.pawns.duplicate(), "walls": rules.walls.duplicate(true), "remaining": rules.remaining.duplicate(), "legal_moves": rules.legal_moves(), "legal_walls": cached_walls.duplicate(true), "turn": rules.turn, "outcome": rules.outcome, "revision": rules.revision, "round_id": "%d:%d" % [rules.get_instance_id(), rules.round_number], "last_action": rules.last_action.duplicate(), "players": seats.map(func(player: Dictionary) -> Dictionary: return {"id": player.id, "display_name": player.display_name, "color": player.get("color", "#25b3ab"), "computer": player.get("computer", false)}), "player_count": player_count, "computer_count": computer_count, "difficulty": difficulty, "paused": not missing.is_empty(), "animating": _busy(), "reduced_motion": session.reduced_motion, "session_wins": rules.session_wins.duplicate(), "history": _history_text(), "status": _status()}


func _render() -> void:
	screen.status.text = _status()
	var state := _snapshot()
	var new_round: bool = shown_round != state.round_id
	var animate: bool = not new_round and shown_revision != rules.revision and not session.reduced_motion and missing.is_empty()
	board.update_view(state, _can_host_play(), wall_mode, cached_walls.filter(func(wall: Dictionary) -> bool: return wall.orientation == orientation), preview, animate)
	if new_round or not rules.outcome:
		celebration.clear()
	if rules.outcome and not _busy() and (shown_outcome != rules.outcome or new_round):
		celebration.show_win([], "GOAL REACHED!", Color(str(seats[rules.outcome - 1].color)), not new_round and not session.reduced_motion)
	shown_round = state.round_id
	shown_revision = rules.revision
	if not _busy():
		shown_outcome = rules.outcome
	var can_play := _can_host_play()
	controls.visible = host_plays and rules.outcome == 0
	GameLook.set_illustrated_control_disabled(move_button, not can_play)
	GameLook.set_illustrated_control_disabled(wall_button, not can_play or rules.remaining[0] <= 0 or cached_walls.is_empty())
	GameLook.set_illustrated_control_disabled(rotate_button, not can_play or not wall_mode)
	move_button.theme_type_variation = "Button" if wall_mode else "GamePrimaryButton"
	wall_button.theme_type_variation = "GamePrimaryButton" if wall_mode else "Button"
	confirm_button.visible = wall_mode and not preview.is_empty()
	wall_button.visible = not confirm_button.visible
	GameLook.set_illustrated_control_disabled(confirm_button, not can_play or preview.is_empty())
	move_button.set_pressed_no_signal(not wall_mode)
	wall_button.set_pressed_no_signal(wall_mode)
	if wall_mode and can_play:
		screen.status.text = ("%s wall ready to place" if not preview.is_empty() else "Choose a %s wall junction") % ("Horizontal" if orientation == "h" else "Vertical")


func _publish() -> void:
	if stopped or seats.size() not in [2, 4]:
		return
	if rules.outcome and not result_sent:
		result_sent = true
		sounds.win.play()
		_cancel_computer()
		if not host_plays and computer_count == 0:
			for index in seats.size():
				report_result(str(seats[index].id), rules.outcome == index + 1)
				if rules.outcome == index + 1:
					award_points(str(seats[index].id), 1)
	screen.status.text = _status()
	_render()
	for index in 4:
		score_cards[index].panel.visible = index < seats.size()
		if index >= seats.size():
			continue
		screen.set_score_card_compact(score_cards[index], seats.size() == 4)
		var color := Color(str(seats[index].get("color", "#25b3ab")))
		score_cards[index].player.text = str(seats[index].display_name)
		screen.set_score_card_identity(score_cards[index], color)
		screen.set_score_card_active(score_cards[index], not rules.outcome and missing.is_empty() and rules.turn == index + 1)
		score_cards[index].score.text = "%d %s" % [rules.session_wins[index], "WIN" if rules.session_wins[index] == 1 else "WINS"]
		wall_labels[index].text = "%d %s" % [rules.remaining[index], "WALL" if rules.remaining[index] == 1 else "WALLS"]
	replay_button.visible = rules.outcome != 0
	GameLook.set_illustrated_control_disabled(replay_button, not missing.is_empty() or _busy())
	_update_settings()
	screen.set_history_text(history_log, _history_text())
	broadcast_state(_snapshot())
