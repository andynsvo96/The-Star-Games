extends BaseGame

const Rules = preload("res://Games/checkers/host/rules.gd")
const BoardMotion = preload("res://Games/checkers/host/board_motion.gd")
var PIECES := [RuntimeAssets.texture("res://Games/checkers/art/red.svg"), RuntimeAssets.texture("res://Games/checkers/art/black.svg"), RuntimeAssets.texture("res://Games/checkers/art/red-king.svg"), RuntimeAssets.texture("res://Games/checkers/art/black-king.svg")]
const SIDE_COLORS := [GameLook.RED, Color("39435a")]
var rules := Rules.new()
var seats: Array = []
var missing: Dictionary = {}
var screen: GameScreen
var cells: Array[Button] = []
var pieces: Array[TextureRect] = []
var selection_rings: Array[GameSelectionRing] = []
var score_cards: Array[Dictionary] = []
var material_labels: Array[Label] = []
var clock_labels: Array[Label] = []
var replay_button: Button
var session_scores: RichTextLabel
var history_log: RichTextLabel
var difficulty_choice: OptionButton
var mode_choice: OptionButton
var settings_hint: Label
var settings_details: VBoxContainer
var force_jump_toggle: Button
var clock_toggle: Button
var clock_input: SpinBox
var clock_minutes := 10.0
var difficulty := Rules.Difficulty.MEDIUM
var host_plays := false
var session_started := false
var stopped := false
var result_sent := false
var selected := -1
var shown_round := ""
var shown_revision := -1
var shown_outcome := 0
var shown_board: Array = []
var board_motion: Node
var sounds: Dictionary = {}
var celebration: GameCelebration
var ai_pending := false
var ai_ticket := 0
var last_tick := 0
var next_clock_sync := 0


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("CHECKERS")
	screen.use_playful_style("res://Games/checkers/art/tournament-hall", "royal")
	screen.add_title_art(RuntimeAssets.texture("res://Games/checkers/art/title-v2.png"), 128)
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	var layout := screen.add_centered_layout(true)
	for index in 2:
		var parent: VBoxContainer = layout.left_sidebar if index == 0 else layout.sidebar
		var card := screen.add_score_card(parent, PIECES[index], SIDE_COLORS[index], "ledger")
		card.score.add_theme_font_size_override("font_size", 27)
		score_cards.append(card)
		var clock := screen.add_sidebar_text(card.content, "")
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.add_theme_color_override("font_color", card.text_color)
		clock.hide()
		clock_labels.append(clock)
		var material := GridContainer.new()
		material.columns = 2
		material.add_theme_constant_override("h_separation", 10)
		material.add_theme_constant_override("v_separation", 8)
		card.content.add_child(material)
		for king in [false, true]:
			var icon := TextureRect.new()
			icon.texture = PIECES[index + (2 if king else 0)]
			icon.custom_minimum_size = Vector2(36, 36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			material.add_child(icon)
			var count := Label.new()
			count.add_theme_color_override("font_color", GameLook.SCROLL_INK)
			count.add_theme_font_size_override("font_size", 19)
			material.add_child(count)
			material_labels.append(count)
	var journal := screen.add_card(screen.add_details(layout.left_sidebar, "SESSION & HISTORY"))
	session_scores = screen.add_formatted_text(journal)
	session_scores.add_theme_font_size_override("normal_font_size", 14)
	history_log = screen.add_history_log(journal)
	history_log.custom_minimum_size.y = 80
	history_log.add_theme_font_size_override("normal_font_size", 13)
	settings_details = screen.add_details(layout.sidebar, "SETTINGS")
	var settings := screen.add_card(settings_details)
	difficulty_choice = screen.add_choice_control(settings, "SOLO DIFFICULTY", ["Easy", "Medium", "Hard"])
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_select_difficulty)
	mode_choice = screen.add_choice_control(settings, "ONE CONNECTED PLAYER", ["Player vs Computer", "Host vs Player"])
	mode_choice.item_selected.connect(_select_mode)
	force_jump_toggle = screen.add_toggle_control(settings, "FORCE JUMP", rules.force_jump)
	force_jump_toggle.toggled.connect(_select_force_jump)
	clock_toggle = screen.add_toggle_control(settings, "TURN TIMER", false)
	clock_input = screen.add_number_control(settings, "TIME PER PLAYER", 0.1, 1440.0, 0.1, 10.0, "min")
	clock_toggle.toggled.connect(_select_clock)
	clock_input.value_changed.connect(_select_clock_minutes)
	settings_hint = screen.add_sidebar_text(settings, "")
	settings_hint.add_theme_font_size_override("font_size", 14)
	var center := CenterContainer.new()
	layout.playfield.add_child(center)
	var frame := PanelContainer.new()
	var wood := StyleBoxTexture.new()
	wood.texture = RuntimeAssets.texture("res://Games/checkers/art/board-frame.svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		wood.set_texture_margin(side, 32)
		wood.set_content_margin(side, 16)
	frame.add_theme_stylebox_override("panel", wood)
	center.add_child(frame)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	frame.add_child(grid)
	for cell in 64:
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 48)
		button.pressed.connect(_host_cell.bind(cell))
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
		var ring := GameSelectionRing.new()
		button.add_child(ring)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		selection_rings.append(ring)
		_style_cell(cell, false, false, false)
	celebration = GameCelebration.new()
	frame.add_child(celebration)
	board_motion = BoardMotion.new()
	board_motion.cells = cells
	board_motion.pieces = pieces
	board_motion.textures = PIECES
	board_motion.visual_parent = self
	add_child(board_motion)
	board_motion.landed.connect(_piece_landed)
	board_motion.settled.connect(_movement_settled)
	var resize_board := func() -> void:
		if board_motion.busy:
			board_motion.reset(rules.board)
			_render_board.call_deferred()
		var edge := clampf((screen.board_height_limit() - 32) / 8.0, 24, 72)
		var available := screen.available_size().x - (490 if screen.available_size().x >= 852 else 100)
		edge = minf(edge, maxf(24, available / 8.0))
		for button in cells:
			button.custom_minimum_size = Vector2(edge, edge)
	screen.resized.connect(resize_board)
	screen.board_space_changed.connect(resize_board)
	resize_board.call_deferred()
	replay_button = Button.new()
	replay_button.text = "PLAY AGAIN"
	GameLook.action(replay_button)
	replay_button.pressed.connect(_play_again)
	layout.playfield.add_child(replay_button)
	screen.center_board(frame, replay_button)
	for effect in ["move", "capture", "crown", "win", "tie"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = RuntimeAssets.audio("res://Games/checkers/audio/%s.wav" % effect)
		audio.bus = "Effects"
		audio.max_polyphony = 3
		add_child(audio)
		sounds[effect] = audio


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"difficulty": Rules.Difficulty.MEDIUM, "host_plays": false, "force_jump": true, "clock_enabled": false, "clock_minutes": 10.0})
	difficulty = saved.difficulty if saved.difficulty in [0, 1, 2] else Rules.Difficulty.MEDIUM
	difficulty_choice.select(difficulty)
	rules.force_jump = saved.force_jump
	clock_minutes = saved.clock_minutes if saved.clock_minutes >= 0.1 and saved.clock_minutes <= 1440.0 else 10.0
	clock_input.set_value_no_signal(clock_minutes)
	if saved.clock_enabled:
		rules.configure_clock(clock_minutes * 60.0)
	host_plays = context.players.is_empty() or (context.players.size() == 1 and saved.host_plays)
	seats = context.players.duplicate(true)
	if context.players.size() == 1 and host_plays:
		seats = [context.solo_profile.duplicate(true), context.players[0].duplicate(true)]
	if seats.is_empty():
		seats.append(context.solo_profile.duplicate(true))
	if seats.size() == 1:
		seats.append({"id": "computer", "display_name": "Computer", "color": "#39435a"})
	difficulty_choice.get_parent().visible = context.players.is_empty()
	mode_choice.get_parent().visible = context.players.size() == 1
	mode_choice.select(1 if host_plays else 0)


func start_game() -> void:
	last_tick = Time.get_ticks_msec()
	_publish()
	_computer_turn()


func shutdown_game() -> void:
	stopped = true
	for ring in selection_rings:
		ring.hide()
	screen.background_media.set_active(false)
	_cancel_computer()
	celebration.clear()
	board_motion.reset(rules.board)
	for sound in sounds.values():
		sound.stop()
	for piece in pieces:
		GameMotion.reset(piece)


func _cancel_computer() -> void:
	ai_ticket += 1
	ai_pending = false


func _consume_clock() -> bool:
	var now := Time.get_ticks_msec()
	var elapsed := (now - last_tick) / 1000.0
	last_tick = now
	return rules.advance_clock(elapsed) if missing.is_empty() and not stopped else false


func _process(_delta: float) -> void:
	if stopped or session == null:
		return
	if _consume_clock():
		_cancel_computer()
		_publish()
	if rules.clock_seconds > 0 and rules.clock_started and rules.outcome == 0 and Time.get_ticks_msec() >= next_clock_sync:
		next_clock_sync = Time.get_ticks_msec() + 250
		_publish()


func _select_clock(enabled: bool) -> void:
	_configure_clock(clock_input.value * 60.0 if enabled else 0.0)


func _select_clock_minutes(minutes: float) -> void:
	if stopped or not missing.is_empty() or (rules.outcome == 0 and not rules.last_move.is_empty()) or not is_finite(minutes) or minutes < 0.1 or minutes > 1440.0:
		clock_input.set_value_no_signal(clock_minutes)
		return
	if clock_toggle.button_pressed:
		_configure_clock(minutes * 60.0)
	else:
		clock_minutes = minutes
		save_game_settings({"clock_minutes": clock_minutes})


func _configure_clock(seconds: float) -> void:
	if stopped or not missing.is_empty() or not rules.configure_clock(seconds):
		clock_toggle.set_pressed_no_signal(rules.clock_seconds > 0)
		clock_input.set_value_no_signal(clock_minutes)
		return
	if seconds > 0:
		clock_minutes = seconds / 60.0
		clock_input.set_value_no_signal(clock_minutes)
	save_game_settings({"clock_enabled": seconds > 0, "clock_minutes": clock_minutes})
	_cancel_computer()
	last_tick = Time.get_ticks_msec()
	_publish()
	_computer_turn()


func _select_difficulty(index: int) -> void:
	if stopped or not session.players.is_empty() or index < Rules.Difficulty.EASY or index > Rules.Difficulty.HARD:
		difficulty_choice.select(difficulty)
		return
	if index == difficulty:
		return
	_cancel_computer()
	difficulty = index
	save_game_settings({"difficulty": difficulty})
	difficulty_choice.select(index)
	var revision: int = rules.revision + 1
	var require_jump: bool = rules.force_jump
	var seconds: float = rules.clock_seconds
	rules = Rules.new()
	if seconds > 0:
		rules.configure_clock(seconds)
	rules.revision = revision
	rules.force_jump = require_jump
	last_tick = Time.get_ticks_msec()
	selected = -1
	result_sent = false
	session_started = false
	_publish()


func _select_force_jump(enabled: bool) -> void:
	if stopped or not missing.is_empty() or rules.forced_from >= 0:
		force_jump_toggle.set_pressed_no_signal(rules.force_jump)
		force_jump_toggle.text = "FORCE JUMP: " + ("ON" if rules.force_jump else "OFF")
		return
	if not rules.set_force_jump(enabled):
		return
	save_game_settings({"force_jump": rules.force_jump})
	_cancel_computer()
	selected = -1
	_publish()
	_computer_turn()


func _select_mode(index: int) -> void:
	if stopped or session.players.size() != 1 or session_started or not missing.is_empty() or index not in [0, 1]:
		mode_choice.select(1 if host_plays else 0)
		return
	host_plays = index == 1
	save_game_settings({"host_plays": host_plays})
	seats = [session.solo_profile.duplicate(true), session.players[0].duplicate(true)] if host_plays else [session.players[0].duplicate(true), {"id": "computer", "display_name": "Computer", "color": "#39435a"}]
	mode_choice.select(index)
	selected = -1
	rules.revision += 1
	_publish()


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	if not session.players.any(func(p: Dictionary) -> bool: return p["id"] == player.get("id")):
		return
	_consume_clock()
	missing.erase(str(player["id"]))
	last_tick = Time.get_ticks_msec()
	_publish()
	_computer_turn()


func player_disconnected(player_id: String) -> void:
	if session.players.any(func(p: Dictionary) -> bool: return p["id"] == player_id):
		_consume_clock()
		missing[player_id] = true
		_cancel_computer()
		_publish()


static func _valid_integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) < maximum


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if stopped or not session.players.any(func(p: Dictionary) -> bool: return p["id"] == player_id):
		return
	var mark := 0
	for index in seats.size():
		if seats[index]["id"] == player_id:
			mark = index + 1
	if mark == 0:
		return
	if message.get("action") == "sync":
		_publish()
		return
	# JSON numbers may be floats; booleans and fractional revisions are rejected.
	if not _valid_integer(message.get("revision"), 2147483647) or int(message["revision"]) != rules.revision:
		_publish()
		return
	match message.get("action"):
		"move":
			if _valid_integer(message.get("from"), 64) and _valid_integer(message.get("to"), 64):
				_move(int(message["from"]), int(message["to"]), mark)
			else:
				_publish()
		"next":
			_next_round()
		"play_again":
			_play_again()


func _host_cell(cell: int) -> void:
	if stopped or board_motion.busy or not host_plays or not missing.is_empty() or rules.turn != 1 or rules.outcome != 0:
		return
	if selected >= 0:
		for step in rules.legal_moves():
			if step.from == selected and step.to == cell:
				_move(selected, cell, 1)
				return
	if rules.forced_from < 0:
		selected = cell if rules.legal_moves().any(func(step: Dictionary) -> bool: return step.from == cell) else -1
		_render_board()


func _move(from_cell: int, to_cell: int, mark: int) -> void:
	_consume_clock()
	if stopped or not missing.is_empty():
		_publish()
		return
	if not rules.move(from_cell, to_cell, mark):
		_publish()
		return
	selected = -1
	session_started = true
	_publish()
	_computer_turn()


func _computer_turn() -> void:
	if stopped or ai_pending or not missing.is_empty() or seats.size() != 2 or seats[1]["id"] != "computer" or rules.turn != 2 or rules.outcome != 0:
		return
	ai_pending = true
	var ticket := ai_ticket
	var revision: int = rules.revision
	await get_tree().create_timer(0.38).timeout
	if stopped or ticket != ai_ticket:
		return
	ai_pending = false
	if not missing.is_empty() or revision != rules.revision or rules.turn != 2 or rules.outcome != 0:
		return
	var level: int = difficulty if session.players.is_empty() else Rules.Difficulty.HARD
	var step: Dictionary = Rules.computer_move(rules.board, 2, level, rules.forced_from, rules.force_jump)
	if not step.is_empty():
		_move(step.from, step.to, 2)


func _next_round() -> void:
	_play_again()


func _play_again() -> void:
	_consume_clock()
	if stopped or not missing.is_empty() or not rules.play_again():
		_publish()
		return
	result_sent = false
	last_tick = Time.get_ticks_msec()
	selected = -1
	_publish()
	_computer_turn()


func _history_text() -> String:
	var entries := PackedStringArray()
	for index in range(rules.history.size() - 1, -1, -1):
		var entry: Dictionary = rules.history[index]
		var result := "Draw" if entry.outcome == 3 else "%s wins" % seats[entry.outcome - 1]["display_name"]
		var reason: String = entry.get("reason", "")
		entries.append("Game %d: %s%s" % [entry.round, result, " (" + reason + ")" if not reason.is_empty() else ""])
	return "No completed games yet." if entries.is_empty() else "\n\n".join(entries)


func _status() -> String:
	if not missing.is_empty():
		return "Paused: waiting for a player to reconnect."
	if rules.outcome == 3:
		return "Draw! %s Play again." % rules.draw_reason
	if rules.outcome != 0:
		return "%s wins!%s" % [seats[rules.outcome - 1]["display_name"], " Time expired." if rules.result_reason == "Time expired" else ""]
	var name: String = seats[rules.turn - 1]["display_name"]
	var instruction := "Keep jumping." if rules.forced_from >= 0 else ("Capture required!" if rules.force_jump and rules.legal_moves().any(func(step: Dictionary) -> bool: return step.capture >= 0) else "Select a piece.")
	if seats[rules.turn - 1]["id"] == "computer":
		instruction = "Thinking..."
	return "Game %d: %s's turn (%s). %s" % [rules.round_number, name, "Red" if rules.turn == 1 else "Black", instruction]


func _render_board() -> void:
	if stopped or seats.size() != 2:
		return
	if rules.forced_from >= 0:
		selected = rules.forced_from
	var legal := rules.legal_moves()
	var round_id := "%d:%d:%d" % [rules.get_instance_id(), rules.match_number, rules.round_number]
	var new_round := shown_round != round_id
	var moved: bool = not new_round and shown_board.size() == 64 and shown_board != rules.board and not rules.last_move.is_empty() and shown_board[rules.last_move.from] != 0 and rules.board[rules.last_move.to] != 0
	if new_round or (shown_board != rules.board and not moved):
		board_motion.reset(rules.board)
	elif moved:
		if session.reduced_motion:
			board_motion.reset(rules.board)
		else:
			board_motion.enqueue(rules.board, rules.last_move, shown_board[rules.last_move.from], rules.outcome)
	var can_play: bool = not board_motion.busy and host_plays and missing.is_empty() and rules.turn == 1 and rules.outcome == 0
	for cell in 64:
		var source := legal.any(func(step: Dictionary) -> bool: return step.from == cell)
		var destination := selected >= 0 and legal.any(func(step: Dictionary) -> bool: return step.from == selected and step.to == cell)
		var last := not rules.last_move.is_empty() and cell in [rules.last_move.from, rules.last_move.to]
		var winning := rules.outcome in [1, 2] and Rules.owner(rules.board[cell]) == rules.outcome
		_style_cell(cell, selected == cell and can_play, destination and can_play, last, winning)
		cells[cell].disabled = not can_play or not (source or destination)
	if new_round or rules.outcome == 0:
		celebration.clear()
	if rules.outcome in [1, 2] and (new_round or shown_outcome != rules.outcome):
		if not board_motion.busy:
			celebration.show_win([], "KING OF THE BOARD!", SIDE_COLORS[rules.outcome - 1], not new_round and not session.reduced_motion)
	if moved and session.reduced_motion:
		_piece_landed(rules.last_move, rules.outcome)
	shown_round = round_id
	shown_revision = rules.revision
	shown_outcome = rules.outcome
	shown_board = rules.board.duplicate()


func _movement_settled() -> void:
	_render_board()
	if not stopped and rules.result_reason == "Time expired" and rules.outcome in [1, 2]:
		celebration.show_win([], "KING OF THE BOARD!", SIDE_COLORS[rules.outcome - 1], not session.reduced_motion)


func _piece_landed(step: Dictionary, outcome: int) -> void:
	if stopped:
		return
	sounds["capture" if step.capture >= 0 else "move"].play()
	if step.promoted:
		sounds["crown"].play()
	if outcome != 0:
		sounds["tie" if outcome == 3 else "win"].play()
		if outcome in [1, 2]:
			celebration.show_win([], "KING OF THE BOARD!", SIDE_COLORS[outcome - 1], not session.reduced_motion)


func _publish() -> void:
	if stopped or seats.size() != 2:
		return
	_consume_clock()
	if rules.outcome != 0:
		_cancel_computer()
	difficulty_choice.disabled = not session.players.is_empty()
	mode_choice.disabled = session_started or not missing.is_empty()
	force_jump_toggle.disabled = not missing.is_empty() or rules.forced_from >= 0
	force_jump_toggle.set_pressed_no_signal(rules.force_jump)
	force_jump_toggle.text = "FORCE JUMP: " + ("ON" if rules.force_jump else "OFF")
	clock_toggle.disabled = not missing.is_empty() or (rules.outcome == 0 and not rules.last_move.is_empty())
	clock_input.editable = not clock_toggle.disabled
	clock_toggle.set_pressed_no_signal(rules.clock_seconds > 0)
	clock_toggle.text = "TURN TIMER: " + ("ON" if rules.clock_seconds > 0 else "OFF")
	if session.players.is_empty():
		settings_hint.text = ["Easy: relaxed random play.", "Medium: three-turn lookahead.", "Hard: five-turn lookahead."][difficulty] + " Changing difficulty resets session scores.\n"
	elif session.players.size() == 1:
		settings_hint.text = ("Return to games to change opponents." if session_started else "Choose opponents before the first move.") + "\n"
	else:
		settings_hint.text = ""
	settings_hint.text += "Captures are %s. Finish any jump chain with the same piece." % ("required" if rules.force_jump else "optional")
	settings_hint.text += "\nSet time before the first move or between games."
	if rules.champion != 0 and not result_sent:
		result_sent = true
		if rules.result_reason == "Time expired":
			sounds.win.play()
		if session.players.size() == 2:
			for index in 2:
				report_result(str(seats[index]["id"]), rules.champion == index + 1)
				if rules.champion == index + 1:
					award_points(str(seats[index]["id"]), 1)
	screen.status.text = _status()
	_render_board()
	var material: Array = []
	for index in 2:
		var count := Rules.counts(rules.board, index + 1)
		material.append(count)
		score_cards[index].player.text = str(seats[index]["display_name"])
		screen.set_score_card_identity(score_cards[index], Color(str(seats[index].get("color", "#58d6ff"))))
		screen.set_score_card_active(score_cards[index], rules.outcome == 0 and missing.is_empty() and rules.turn == index + 1)
		score_cards[index].score.text = "%d %s" % [rules.session_wins[index], "WIN" if rules.session_wins[index] == 1 else "WINS"]
		material_labels[index * 2].text = "x %d PIECES" % count.men
		material_labels[index * 2 + 1].text = "x %d KINGS" % count.kings
		clock_labels[index].visible = rules.clock_seconds > 0
		clock_labels[index].text = clock_text(rules.remaining[index])
	screen.set_text_parts(session_scores, ["THIS SESSION\n", "Red: %d wins\n" % rules.session_wins[0], "Black: %d wins\nDraws: %d" % [rules.session_wins[1], rules.draws]])
	history_log.text = _history_text()
	replay_button.visible = rules.outcome != 0
	replay_button.disabled = not missing.is_empty()
	broadcast_state({"board": rules.board.duplicate(), "legal_moves": rules.legal_moves(), "forced_from": rules.forced_from, "force_jump": rules.force_jump, "last_move": rules.last_move.duplicate(), "counts": material, "players": seats.map(func(p: Dictionary) -> Dictionary: return {"id": p["id"], "display_name": p["display_name"], "color": p.get("color", "#58d6ff")}), "turn": rules.turn, "outcome": rules.outcome, "champion": rules.champion, "result_reason": rules.result_reason, "paused": not missing.is_empty(), "revision": rules.revision, "round_id": shown_round, "wins": rules.wins.duplicate(), "session_wins": rules.session_wins.duplicate(), "match_wins": rules.match_wins.duplicate(), "draws": rules.draws, "clock_seconds": rules.clock_seconds, "remaining": rules.remaining.duplicate(), "clock_running": rules.clock_started and rules.outcome == 0 and missing.is_empty(), "history": _history_text(), "status": _status()})


static func clock_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60] if total >= 3600 else "%d:%02d" % [total / 60, total % 60]


# Square colors, legal target dots, and the wood frame belong to this playfield.
func _style_cell(cell: int, chosen: bool, destination: bool, last: bool, winning := false) -> void:
	var dark := Rules.playable(cell)
	var fill := Color("633d2b") if dark else Color("f6d798")
	if last:
		fill = Color("957747") if dark else fill
	if destination:
		fill = Color("8ba84b")
	if winning:
		fill = Color("957747")
	selection_rings[cell].visible = chosen and rules.board[cell] != 0
	var border := Color("ffde55") if destination or winning else Color("8f6237")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill.lightened(0.15) if state == "hover" else fill
		style.border_color = border
		style.set_border_width_all(3 if destination or winning else 0)
		cells[cell].add_theme_stylebox_override(state, style)
	cells[cell].add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, Color.WHITE, 0, 3))
	cells[cell].text = "•" if destination and rules.board[cell] == 0 else ""
	cells[cell].add_theme_font_size_override("font_size", 28)
	cells[cell].add_theme_color_override("font_disabled_color", GameLook.CREAM)
	cells[cell].add_theme_color_override("font_color", GameLook.CREAM)
