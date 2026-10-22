extends BaseGame

const Rules = preload("res://Games/four-in-a-row/host/rules.gd")
var rules := Rules.new()
var seats: Array = []
var missing: Dictionary = {}
var screen: GameScreen
var cells: Array[Button] = []
var stopped := false
var result_sent := false
const MARK_COLORS := [GameLook.RED, Color("a66300")]
var MARK_ICONS := [RuntimeAssets.texture("res://Games/four-in-a-row/art/red.svg"), RuntimeAssets.texture("res://Games/four-in-a-row/art/yellow.svg")]
var score_cards: Array[Dictionary] = []
var replay_button: Button
var session_scores: RichTextLabel
var history_log: RichTextLabel
var sounds: Dictionary = {}
var difficulty := Rules.Difficulty.MEDIUM
var difficulty_choice: OptionButton
var mode_choice: OptionButton
var host_plays := false
var match_started := false
var session_started := false
var settings_hint: Label
var settings_details: VBoxContainer
var pieces: Array[TextureRect] = []
var shown_board: Array = []
var shown_round := ""
var shown_winners: Array = []
var celebration: GameCelebration
var drop_tweens: Dictionary = {}
var drop_until := 0.0
var victory_tween: Tween
var column_preview: Control
var preview_column := 3
var preview_revision := -1



func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("FOUR IN A ROW")
	screen.use_playful_style("res://Games/four-in-a-row/art/vintage-arcade", "arcade")
	screen.add_title_art(RuntimeAssets.texture("res://Games/four-in-a-row/art/title-v2.png"), 160)
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	var layout := screen.add_centered_layout(true)
	score_cards.append(screen.add_score_card(layout.left_sidebar, MARK_ICONS[0], Color("ff304c")))
	score_cards.append(screen.add_score_card(layout.sidebar, MARK_ICONS[1], Color("ffc928")))
	var journal := screen.add_card(screen.add_details(layout.left_sidebar, "SESSION"))
	session_scores = screen.add_formatted_text(journal)
	session_scores.add_theme_font_size_override("normal_font_size", 14)
	history_log = screen.add_history_log(screen.add_card(screen.add_details(layout.sidebar, "HISTORY")))
	history_log.custom_minimum_size.y = 64
	history_log.add_theme_font_size_override("normal_font_size", 13)
	settings_details = screen.add_details(layout.sidebar, "SETTINGS")
	var settings := screen.add_card(settings_details)
	difficulty_choice = screen.add_choice_control(settings, "SOLO DIFFICULTY", ["Easy", "Medium", "Hard"])
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_select_difficulty)
	mode_choice = screen.add_choice_control(settings, "ONE CONNECTED PLAYER", ["Player vs Computer", "Host vs Player"])
	mode_choice.item_selected.connect(_select_mode)
	settings_hint = screen.add_sidebar_text(settings, "")
	settings_hint.add_theme_font_size_override("font_size", 14)
	var center := CenterContainer.new()
	layout.playfield.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var frame := PanelContainer.new()
	var board_style := StyleBoxTexture.new()
	board_style.texture = RuntimeAssets.texture("res://Games/four-in-a-row/art/board-frame.svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		board_style.set_texture_margin(side, 30)
		board_style.set_content_margin(side, 18)
	frame.add_theme_stylebox_override("panel", board_style)
	center.add_child(frame)
	frame.add_child(grid)
	celebration = GameCelebration.new()
	frame.add_child(celebration)
	for cell in 42:
		var button := Button.new()
		button.custom_minimum_size = Vector2(54, 54)
		_style_slot(button, false)
		button.pressed.connect(func() -> void: _host_move(cell % 7))
		button.mouse_entered.connect(_preview_column.bind(cell % 7))
		button.focus_entered.connect(_preview_column.bind(cell % 7))
		grid.add_child(button)
		cells.append(button)
		var piece := TextureRect.new()
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(piece)
		piece.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		piece.offset_left = 2
		piece.offset_top = 2
		piece.offset_right = -2
		piece.offset_bottom = -2
		piece.resized.connect(func() -> void: piece.pivot_offset = piece.size / 2.0)
		pieces.append(piece)
	column_preview = preload("res://Games/four-in-a-row/host/column_preview.gd").new()
	column_preview.cells = cells
	frame.add_child(column_preview)
	var resize_board := func() -> void:
		var edge := clampf((screen.board_height_limit() - 66) / 6.0, 24, 76)
		if screen.available_size().x < 860:
			edge = minf(edge, (screen.available_size().x - 140) / 7.0)
		for button in cells:
			button.custom_minimum_size = Vector2(edge, edge)
			button.add_theme_constant_override("icon_max_width", int(edge - 24))
	screen.resized.connect(resize_board)
	screen.board_space_changed.connect(resize_board)
	resize_board.call_deferred()
	replay_button = Button.new()
	replay_button.text = "PLAY AGAIN"
	GameLook.action(replay_button)
	replay_button.pressed.connect(_play_again)
	layout.playfield.add_child(replay_button)
	screen.center_board(frame, replay_button)
	for effect in ["move", "win", "tie"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = RuntimeAssets.audio("res://Games/four-in-a-row/audio/%s.wav" % effect)
		audio.bus = "Effects"
		audio.max_polyphony = 4
		add_child(audio)
		sounds[effect] = audio


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"difficulty": Rules.Difficulty.MEDIUM, "host_plays": false})
	difficulty = saved.difficulty if saved.difficulty in [0, 1, 2] else Rules.Difficulty.MEDIUM
	difficulty_choice.select(difficulty)
	host_plays = context.players.is_empty() or (context.players.size() == 1 and saved.host_plays)
	seats = context.players.duplicate(true)
	if context.players.size() == 1 and host_plays:
		seats = [context.solo_profile.duplicate(true), context.players[0].duplicate(true)]
	if seats.is_empty():
		seats.append(context.solo_profile.duplicate(true))
	if seats.size() == 1:
		seats.append({"id": "computer", "display_name": "Computer", "color": "#a9b7d8"})
	difficulty_choice.get_parent().visible = context.players.is_empty()
	mode_choice.get_parent().visible = context.players.size() == 1
	mode_choice.select(1 if host_plays else 0)
	settings_hint.get_parent().get_parent().visible = context.players.size() < 2
	settings_details.get_parent().visible = context.players.size() < 2


func _select_difficulty(index: int) -> void:
	if stopped or not session.players.is_empty() or index < Rules.Difficulty.EASY or index > Rules.Difficulty.HARD:
		difficulty_choice.select(difficulty)
		return
	if index == difficulty:
		return
	difficulty = index
	save_game_settings({"difficulty": difficulty})
	difficulty_choice.select(difficulty)
	var next_revision: int = rules.revision + 1
	rules = Rules.new()
	rules.revision = next_revision
	result_sent = false
	match_started = false
	session_started = false
	_publish()


func _select_mode(index: int) -> void:
	if stopped or session.players.size() != 1 or session_started or not missing.is_empty() or index not in [0, 1]:
		mode_choice.select(1 if host_plays else 0)
		return
	host_plays = index == 1
	save_game_settings({"host_plays": host_plays})
	if host_plays:
		seats = [session.solo_profile.duplicate(true), session.players[0].duplicate(true)]
	else:
		seats = [session.players[0].duplicate(true), {"id": "computer", "display_name": "Computer", "color": "#a9b7d8"}]
	mode_choice.select(index)
	rules.revision += 1
	_publish()


func _host_move(cell: int) -> void:
	if host_plays:
		_move(cell, 1)


func _preview_column(column: int) -> void:
	if cells[column].disabled:
		return
	preview_column = column
	_update_column_preview()


func _update_column_preview() -> void:
	if rules.revision != preview_revision:
		preview_column = 3
		preview_revision = rules.revision
	if cells[preview_column].disabled:
		column_preview.show_target(-1, null)
		for column in [3, 2, 4, 1, 5, 0, 6]:
			if not cells[column].disabled:
				preview_column = column
				break
		if cells[preview_column].disabled:
			return
	var target := preview_column
	for row in range(5, -1, -1):
		if rules.board[row * 7 + preview_column] == 0:
			target = row * 7 + preview_column
			break
	column_preview.show_target(target, MARK_ICONS[rules.turn - 1])


func start_game() -> void:
	_publish()


func shutdown_game() -> void:
	stopped = true
	column_preview.show_target(-1, null)
	screen.background_media.set_active(false)
	_clear_drops()
	for sound in sounds.values():
		sound.stop()
	celebration.clear()
	for piece in pieces:
		GameMotion.reset(piece)
	for card in score_cards:
		GameMotion.reset(card.score)


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	missing.erase(str(player.get("id", "")))
	_publish()


func player_disconnected(player_id: String) -> void:
	for player in session.players:
		if player["id"] == player_id:
			missing[player_id] = true
	_publish()


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if not session.players.any(func(player: Dictionary) -> bool: return player["id"] == player_id):
		return
	var mark := 0
	for index in seats.size():
		if seats[index]["id"] == player_id:
			mark = index + 1
	if mark == 0 or stopped:
		return
	if message.get("action") == "sync":
		_publish()
		return
	# Revision prevents delayed or repeated taps from becoming a later turn.
	if message.get("revision") != rules.revision:
		_publish()
		return
	if message.get("action") == "next":
		_next_round()
	elif message.get("action") == "play_again":
		_play_again()
	elif message.get("action") == "move":
		var cell: Variant = message.get("column")
		if (cell is int or cell is float) and is_finite(float(cell)) and float(cell) == floor(float(cell)) and float(cell) >= 0 and float(cell) < 7:
			_move(int(cell), mark)


func _move(cell: int, mark: int) -> void:
	if stopped or not missing.is_empty() or not drop_tweens.is_empty():
		_publish()
		return
	if not rules.move(cell, mark):
		return
	match_started = true
	session_started = true
	# Publish each move separately so the computer's disc follows the player's.
	_publish()
	_computer_turn()
	_publish()


func _computer_turn() -> void:
	if seats[1]["id"] == "computer" and rules.turn == 2 and rules.outcome == 0:
		var level: int = difficulty if session.players.is_empty() else Rules.Difficulty.HARD
		rules.move(Rules.computer_move(rules.board, 2, level), 2)
		match_started = true


func _next_round() -> void:
	_play_again()


func _play_again() -> void:
	if stopped or not missing.is_empty() or not drop_tweens.is_empty() or not rules.play_again():
		return
	result_sent = false
	match_started = false
	_computer_turn()
	_publish()


func _move_sound(outcome: int) -> void:
	sounds["move"].play()
	if outcome != 0:
		sounds["tie" if outcome == 3 else "win"].play()


func _history_text() -> String:
	var entries := PackedStringArray()
	for index in range(rules.history.size() - 1, -1, -1):
		var entry: Dictionary = rules.history[index]
		var result_text := "Tie" if entry.outcome == 3 else "%s wins" % seats[entry.outcome - 1]["display_name"]
		entries.append("Game %d: %s" % [entry.round, result_text])
	return "No completed games yet." if entries.is_empty() else "\n\n".join(entries)


func _status() -> String:
	if rules.champion != 0:
		return "FOUR IN A ROW!"
	if not missing.is_empty():
		return "Paused: waiting for a player to reconnect. The host can return to games."
	if rules.outcome == 3:
		return "Draw! No points awarded. Play again."
	if rules.outcome != 0:
		return "FOUR IN A ROW!"
	return "Game %d: %s's turn (%s)" % [rules.round_number, seats[rules.turn - 1]["display_name"], "Red" if rules.turn == 1 else "Yellow"]


func _publish() -> void:
	if stopped or seats.size() != 2:
		return
	difficulty_choice.disabled = not session.players.is_empty()
	mode_choice.disabled = session_started or not missing.is_empty()
	settings_hint.visible = session.players.size() < 2
	if session.players.is_empty():
		settings_hint.text = ["Easy: frequent mistakes.", "Medium: three-move lookahead.", "Hard: five-move lookahead."][difficulty] + " Changing difficulty resets the game and session scores."
	elif session.players.size() == 1:
		settings_hint.text = "Return to games to change opponents." if session_started else "Choose opponents before the first move."
	if rules.champion != 0 and not result_sent:
		result_sent = true
		# AI matches, like host solo sessions, do not affect saved standings.
		if session.players.size() == 2:
			for index in 2:
				report_result(str(seats[index]["id"]), rules.champion == index + 1)
				if rules.champion == index + 1:
					award_points(str(seats[index]["id"]), 1)
	screen.status.text = _status()
	if rules.outcome == 0 and missing.is_empty():
		screen.set_text_parts(screen.status, ["Game %d: %s's turn (" % [rules.round_number, seats[rules.turn - 1]["display_name"]], _mark_part(rules.turn), ")"])
	screen.set_text_parts(screen.scores, [_mark_part(1), "  %s  %d  :  %d  %s  " % [seats[0]["display_name"], rules.session_wins[0], rules.session_wins[1], seats[1]["display_name"]], _mark_part(2)])
	var round_id := "%d:%d:%d" % [rules.get_instance_id(), rules.match_number, rules.round_number]
	var winning_cells: Array = []
	var winning_lines: Array = []
	if rules.outcome in [1, 2]:
		for line in Rules.LINES:
			if line.all(func(cell: int) -> bool: return rules.board[cell] == rules.outcome):
				winning_lines.append(line.duplicate())
				for cell in line:
					if not winning_cells.has(cell):
						winning_cells.append(cell)
	var new_round := shown_round != round_id
	var new_win := not winning_cells.is_empty() and (new_round or shown_winners != winning_cells)
	if new_round:
		_clear_drops()
	var falling: Array[int] = []
	if not shown_board.is_empty() and not session.reduced_motion:
		for index in 42:
			if rules.board[index] != 0 and (new_round or shown_board[index] == 0):
				falling.append(index)
	var landing_delay := maxf(0.0, drop_until - Time.get_ticks_msec() / 1000.0)
	for index in falling:
		landing_delay += _drop_duration(index)
	if new_round or winning_cells.is_empty():
		celebration.clear()
	if new_win:
		var segments: Array = []
		for line in winning_lines:
			var from_cell: int = line[0]
			var to_cell: int = line[3]
			segments.append([Vector2((from_cell % 7 + 0.5) / 7.0, (int(from_cell / 7) + 0.5) / 6.0), Vector2((to_cell % 7 + 0.5) / 7.0, (int(to_cell / 7) + 0.5) / 6.0)])
		var color: Color = MARK_COLORS[rules.outcome - 1]
		var animate := not session.reduced_motion and not shown_board.is_empty()
		if landing_delay > 0.0 and animate:
			victory_tween = create_tween()
			victory_tween.tween_interval(landing_delay)
			victory_tween.tween_callback(func() -> void: celebration.show_win(segments, "FOUR IN A ROW!", color, true))
		else:
			celebration.show_win(segments, "FOUR IN A ROW!", color, animate)
	for index in 42:
		var mark: int = rules.board[index]
		cells[index].text = ""
		var changed: bool = new_round or shown_board.is_empty() or shown_board[index] != mark
		if changed:
			pieces[index].texture = null if mark == 0 else MARK_ICONS[mark - 1]
			GameMotion.reset(pieces[index])
		if changed or shown_winners != winning_cells:
			_style_slot(cells[index], winning_cells.has(index))
		if falling.has(index):
			_drop_piece(index)
		elif changed and mark != 0 and not shown_board.is_empty():
			_move_sound(rules.outcome)
		if not shown_board.is_empty() and new_win and winning_cells.has(index):
			GameMotion.play(pieces[index], session.reduced_motion, false, true, landing_delay + 0.08 * max(0, winning_cells.find(index)))
		if mark != 0:
			for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
				cells[index].add_theme_color_override(color_name, MARK_COLORS[mark - 1])
	# Evaluate after every new tween is queued, so the whole board stays locked.
	for index in 42:
		cells[index].disabled = not host_plays or not missing.is_empty() or not drop_tweens.is_empty() or rules.outcome != 0 or rules.turn != 1 or rules.board[index % 7] != 0
	_update_column_preview()
	for index in 2:
		score_cards[index].player.text = str(seats[index]["display_name"])
		screen.set_score_card_active(score_cards[index], rules.outcome == 0 and missing.is_empty() and rules.turn == index + 1)
		score_cards[index].score.text = str(rules.session_wins[index])
		score_cards[index].score.add_theme_color_override("font_color", GameLook.RED if index == 0 else Color("ffcf32"))
		if new_round:
			GameMotion.reset(score_cards[index].score)
		if new_win and rules.outcome == index + 1 and not shown_board.is_empty():
			GameMotion.play(score_cards[index].score, session.reduced_motion, false, true, landing_delay + 0.2)
	shown_board = rules.board.duplicate()
	shown_round = round_id
	shown_winners = winning_cells.duplicate()
	screen.set_text_parts(session_scores, ["THIS SESSION\n", _mark_part(1), "  %d wins\n" % rules.session_wins[0], _mark_part(2), "  %d wins\nDraws: %d" % [rules.session_wins[1], rules.draws]])
	history_log.text = _history_text()
	replay_button.visible = rules.outcome != 0
	replay_button.disabled = not missing.is_empty() or not drop_tweens.is_empty()
	broadcast_state({"animating": not drop_tweens.is_empty(), "round_id": round_id, "winning_cells": winning_cells, "winning_lines": winning_lines, "session_wins": rules.session_wins.duplicate(), "match_wins": rules.match_wins.duplicate(), "draws": rules.draws, "history": _history_text(), "board": rules.board.duplicate(), "wins": rules.wins.duplicate(), "players": seats.map(func(p: Dictionary) -> Dictionary: return {"id": p["id"], "display_name": p["display_name"], "color": p.get("color", "#58d6ff")}), "turn": rules.turn, "outcome": rules.outcome, "champion": rules.champion, "paused": not missing.is_empty(), "revision": rules.revision, "status": _status()})


func _mark_part(mark: int) -> Dictionary:
	return {"text": "Red" if mark == 1 else "Yellow", "color": MARK_COLORS[mark - 1]}


# Gravity belongs to this playfield. Shared GameMotion still owns win feedback.
func _drop_duration(index: int) -> float:
	return 0.20 * sqrt(float(index / 7 + 1)) + 0.14


func _drop_piece(index: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var delay := maxf(0.0, drop_until - now)
	var duration := _drop_duration(index)
	drop_until = now + delay + duration
	var piece := pieces[index]
	piece.modulate.a = 0.0
	_set_drop_progress(0.0, index)
	var tween := create_tween()
	drop_tweens[index] = tween
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: piece.modulate.a = 1.0)
	tween.tween_method(_set_drop_progress.bind(index), 0.0, 1.0, duration - 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_move_sound.bind(rules.outcome))
	tween.tween_method(_set_drop_progress.bind(index), 1.0, 0.97, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_drop_progress.bind(index), 0.97, 1.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		drop_tweens.erase(index)
		if drop_tweens.is_empty():
			drop_until = 0.0
			_publish()
	)


func _set_drop_progress(progress: float, index: int) -> void:
	# Read current layout each frame so resizing never changes the landing slot.
	var distance := cells[index].position.y - cells[index % 7].position.y + cells[index].size.y + 6.0
	pieces[index].position.y = 2.0 - distance * (1.0 - progress)


func _clear_drops() -> void:
	for tween in drop_tweens.values():
		tween.kill()
	drop_tweens.clear()
	drop_until = 0.0
	if victory_tween != null and victory_tween.is_valid():
		victory_tween.kill()
	for piece in pieces:
		piece.position.y = 2.0
		piece.modulate.a = 1.0


# Circular sockets are game-specific board geometry; chrome uses GameLook.
func _style_slot(button: Button, winning: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxTexture.new()
		style.texture = RuntimeAssets.texture("res://Games/four-in-a-row/art/%s.svg" % ("socket-win" if winning else "socket"))
		style.modulate_color = Color(1.2, 1.2, 1.2) if state == "hover" else Color.WHITE
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, Color.WHITE, 30, 3))
