extends BaseGame

const Rules = preload("res://Games/chess/host/rules.gd")
const BoardMotion = preload("res://Games/chess/host/board_motion.gd")
const SIDE_COLORS := [Color("cf2337"), Color("195fc0")]
var rules := Rules.new()
var seats: Array = []
var missing: Dictionary = {}
var screen: GameScreen
var cells: Array[Button] = []
var pieces: Array[TextureRect] = []
var textures: Dictionary = {}
var score_cards: Array[Dictionary] = []
var material_labels: Array[Array] = []
var clock_labels: Array[Label] = []
var replay_button: Button
var session_scores: RichTextLabel
var history_log: RichTextLabel
var difficulty_choice: OptionButton
var mode_choice: OptionButton
var guidance_toggle: Button
var clock_toggle: Button
var clock_input: SpinBox
var clock_minutes := 10.0
var settings_hint: Label
var promotion_dialog: AcceptDialog
var promotion_move: Dictionary = {}
var guidance := true
var difficulty := Rules.Difficulty.MEDIUM
var host_plays := false
var session_started := false
var stopped := false
var result_sent := false
var selected := -1
var board_motion: Node
var celebration: GameCelebration
var sounds: Dictionary = {}
var shown_board: Array = []
var shown_round := -1
var shown_outcome := 0
var cached_revision := -1
var cached_moves: Array[Dictionary] = []
var ai_thread := Thread.new()
var ai_ticket := 0
var ai_running_ticket := -1
var ai_revision := -1
var ai_requested := false
var ai_after := 0
var last_tick := 0
var next_clock_sync := 0


func _ready() -> void:
	for side in [1, 2]:
		for kind in range(1, 7):
			textures[Rules.sign_for(side) * kind] = RuntimeAssets.texture("res://Games/chess/art/%s-%s.svg" % ["white" if side == 1 else "black", Rules.NAMES[kind]])
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("CHESS")
	screen.use_playful_style("res://Games/chess/art/royal-study", "royal")
	screen.add_title_art(RuntimeAssets.texture("res://Games/chess/art/title-v2.png"), 128)
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	var layout := screen.add_centered_layout(true)
	for index in 2:
		var parent: VBoxContainer = layout.left_sidebar if index == 0 else layout.sidebar
		var card := screen.add_score_card(parent, textures[Rules.sign_for(index + 1) * Rules.KING], SIDE_COLORS[index], "ledger")
		card.score.add_theme_font_size_override("font_size", 26)
		score_cards.append(card)
		var clock := screen.add_sidebar_text(card.content, "UNTIMED")
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clock.add_theme_font_size_override("font_size", 24)
		clock.add_theme_color_override("font_color", card.text_color)
		clock_labels.append(clock)
		var material := GridContainer.new()
		material.columns = 4
		material.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		material.add_theme_constant_override("h_separation", 4)
		material.add_theme_constant_override("v_separation", 2)
		card.content.add_child(material)
		var labels: Array = []
		for kind in range(1, 7):
			var icon := TextureRect.new()
			icon.texture = textures[Rules.sign_for(index + 1) * kind]
			icon.custom_minimum_size = Vector2(26, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			material.add_child(icon)
			var count := Label.new()
			material.add_child(count)
			count.add_theme_color_override("font_color", card.text_color)
			labels.append(count)
		material_labels.append(labels)
	var settings := screen.add_card(screen.add_details(layout.left_sidebar, "SETTINGS"))
	difficulty_choice = screen.add_choice_control(settings, "SOLO DIFFICULTY", ["Easy", "Medium", "Hard"])
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_select_difficulty)
	mode_choice = screen.add_choice_control(settings, "ONE CONNECTED PLAYER", ["Player vs Computer", "Host vs Player"])
	mode_choice.item_selected.connect(_select_mode)
	guidance_toggle = screen.add_toggle_control(settings, "MOVE GUIDANCE", true)
	guidance_toggle.toggled.connect(_select_guidance)
	clock_toggle = screen.add_toggle_control(settings, "CHESS CLOCK", false)
	clock_input = screen.add_number_control(settings, "TIME PER PLAYER", 0.1, 1440.0, 0.1, 10.0, "min")
	clock_toggle.toggled.connect(_select_clock)
	clock_input.value_changed.connect(_select_clock_minutes)
	settings_hint = screen.add_sidebar_text(settings, "")
	session_scores = screen.add_formatted_text(screen.add_card(screen.add_details(layout.sidebar, "SESSION & HISTORY")))
	history_log = screen.add_history_log(session_scores.get_parent())
	var center := CenterContainer.new()
	layout.playfield.add_child(center)
	var frame := PanelContainer.new()
	var wood := StyleBoxTexture.new()
	wood.texture = RuntimeAssets.texture("res://Games/chess/art/board-frame.svg")
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
		piece.offset_left = 3
		piece.offset_top = 3
		piece.offset_right = -3
		piece.offset_bottom = -3
		pieces.append(piece)
	frame.add_child(preload("res://Games/chess/host/board_coordinates.gd").new())
	board_motion = BoardMotion.new()
	board_motion.cells = cells
	board_motion.pieces = pieces
	board_motion.textures = textures
	board_motion.visual_parent = self
	add_child(board_motion)
	board_motion.settled.connect(_landed)
	celebration = GameCelebration.new()
	frame.add_child(celebration)
	replay_button = _action(layout.playfield, "PLAY AGAIN", _play_again)
	GameLook.action(replay_button)
	screen.center_board(frame, replay_button)
	var resize_board := func() -> void:
		if board_motion.busy:
			board_motion.reset(rules.position.board)
			_landed.call_deferred()
		var edge := clampf((screen.board_height_limit() - 32) / 8.0, 24, 72)
		var width := screen.available_size().x - (490 if screen.available_size().x >= 852 else 100)
		edge = minf(edge, maxf(24, width / 8.0))
		for button in cells:
			button.custom_minimum_size = Vector2(edge, edge)
	screen.resized.connect(resize_board)
	screen.board_space_changed.connect(resize_board)
	resize_board.call_deferred()
	promotion_dialog = AcceptDialog.new()
	promotion_dialog.title = "Choose promotion"
	promotion_dialog.get_ok_button().hide()
	add_child(promotion_dialog)
	var promotions := HBoxContainer.new()
	promotion_dialog.add_child(promotions)
	for kind in Rules.PROMOTIONS:
		_action(promotions, Rules.NAMES[kind].capitalize(), _promote.bind(kind))
	promotion_dialog.canceled.connect(func() -> void: promotion_move.clear())
	for effect in ["move", "capture", "crown", "win", "tie"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = RuntimeAssets.audio("res://Games/chess/audio/%s.wav" % effect)
		audio.bus = "Effects"
		audio.max_polyphony = 3
		add_child(audio)
		sounds[effect] = audio


func _action(parent: Control, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"difficulty": Rules.Difficulty.MEDIUM, "host_plays": false, "guidance": true, "clock_enabled": false, "clock_minutes": 10.0})
	difficulty = saved.difficulty if saved.difficulty in [0, 1, 2] else Rules.Difficulty.MEDIUM
	difficulty_choice.select(difficulty)
	guidance = saved.guidance
	guidance_toggle.set_pressed_no_signal(guidance)
	guidance_toggle.text = "MOVE GUIDANCE: " + ("ON" if guidance else "OFF")
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
		seats.append({"id": "computer", "display_name": "Computer", "color": "#195fc0"})
	difficulty_choice.get_parent().visible = context.players.is_empty()
	mode_choice.get_parent().visible = context.players.size() == 1
	mode_choice.select(1 if host_plays else 0)
	last_tick = Time.get_ticks_msec()


func start_game() -> void:
	_publish()
	_computer_turn()


func shutdown_game() -> void:
	stopped = true
	screen.background_media.set_active(false)
	_cancel_computer()
	if ai_thread.is_started():
		ai_thread.wait_to_finish()
	board_motion.reset(rules.position.board)
	celebration.clear()
	promotion_dialog.hide()
	for sound in sounds.values():
		sound.stop()


func _exit_tree() -> void:
	if ai_thread.is_started():
		ai_thread.wait_to_finish()


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
	if ai_thread.is_started() and not ai_thread.is_alive():
		var step: Dictionary = ai_thread.wait_to_finish()
		if ai_running_ticket == ai_ticket and ai_revision == rules.revision and not step.is_empty():
			_move(step.from, step.to, rules.position.turn, step.promotion)
	if ai_requested and not ai_thread.is_started() and not board_motion.busy and Time.get_ticks_msec() >= ai_after:
		ai_requested = false
		if rules.outcome or not missing.is_empty() or _player(rules.position.turn).id != "computer":
			return
		ai_revision = rules.revision
		ai_running_ticket = ai_ticket
		var level: int = difficulty if session.players.is_empty() else Rules.Difficulty.HARD
		ai_thread.start(Rules.computer_move.bind(rules.position.duplicate(true), level))
	if rules.clock_seconds > 0 and rules.clock_started and rules.outcome == 0 and Time.get_ticks_msec() >= next_clock_sync:
		next_clock_sync = Time.get_ticks_msec() + 250
		_publish()


func _cancel_computer() -> void:
	ai_ticket += 1
	ai_requested = false


func _computer_turn() -> void:
	if stopped or not missing.is_empty() or rules.outcome or seats.size() != 2 or _player(rules.position.turn).id != "computer":
		return
	ai_requested = true
	ai_after = Time.get_ticks_msec() + 350


func _player(side: int) -> Dictionary:
	return seats[rules.seat_for(side)]


func _host_side() -> int:
	return (1 if rules.white_seat == 0 else 2) if host_plays else 0


func _select_difficulty(index: int) -> void:
	if stopped or not session.players.is_empty() or index not in [0, 1, 2] or index == difficulty:
		difficulty_choice.select(difficulty)
		return
	_cancel_computer()
	difficulty = index
	save_game_settings({"difficulty": difficulty})
	shown_round = -1
	var old_revision: int = rules.revision
	var seconds: float = rules.clock_seconds
	rules = Rules.new()
	rules.configure_clock(seconds)
	rules.revision = old_revision + 1
	selected = -1
	result_sent = false
	session_started = false
	promotion_dialog.hide()
	promotion_move.clear()
	_publish()


func _select_mode(index: int) -> void:
	if stopped or session.players.size() != 1 or session_started or not missing.is_empty() or index not in [0, 1]:
		mode_choice.select(1 if host_plays else 0)
		return
	host_plays = index == 1
	save_game_settings({"host_plays": host_plays})
	seats = [session.solo_profile.duplicate(true), session.players[0].duplicate(true)] if host_plays else [session.players[0].duplicate(true), {"id": "computer", "display_name": "Computer", "color": "#195fc0"}]
	rules.revision += 1
	selected = -1
	_publish()


func _select_guidance(enabled: bool) -> void:
	if stopped:
		return
	guidance = enabled
	save_game_settings({"guidance": guidance})
	guidance_toggle.set_pressed_no_signal(enabled)
	guidance_toggle.text = "MOVE GUIDANCE: " + ("ON" if enabled else "OFF")
	rules.revision += 1
	_cancel_computer()
	_publish()
	_computer_turn()


func _select_clock(enabled: bool) -> void:
	_configure_clock(clock_input.value * 60.0 if enabled else 0.0)


func _select_clock_minutes(minutes: float) -> void:
	if stopped or not missing.is_empty() or (rules.outcome == 0 and not rules.moves.is_empty()) or not is_finite(minutes) or minutes < 0.1 or minutes > 1440.0:
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


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	if not session.players.any(func(p: Dictionary) -> bool: return p.id == player.get("id")):
		return
	_consume_clock()
	missing.erase(str(player.id))
	last_tick = Time.get_ticks_msec()
	_publish()
	_computer_turn()


func player_disconnected(player_id: String) -> void:
	if session.players.any(func(p: Dictionary) -> bool: return p.id == player_id):
		_consume_clock()
		missing[player_id] = true
		_cancel_computer()
		promotion_move.clear()
		promotion_dialog.hide()
		_publish()


static func _valid_integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) < maximum


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if stopped or not session.players.any(func(p: Dictionary) -> bool: return p.id == player_id):
		return
	var side := 0
	for candidate in [1, 2]:
		if _player(candidate).id == player_id:
			side = candidate
	if side == 0:
		return
	if message.get("action") == "sync":
		_publish()
		return
	_consume_clock()
	if not _valid_integer(message.get("revision"), 2147483647) or int(message.revision) != rules.revision or not missing.is_empty():
		_publish()
		return
	match message.get("action"):
		"move":
			if _valid_integer(message.get("from"), 64) and _valid_integer(message.get("to"), 64) and _valid_integer(message.get("promotion", 0), 7):
				_move(int(message.from), int(message.to), side, int(message.get("promotion", 0)))
				return
		"play_again", "next":
			_play_again()
			return
	_publish()
	_computer_turn()


func _host_cell(cell: int) -> void:
	if stopped or board_motion.busy or not missing.is_empty() or _host_side() != rules.position.turn or rules.outcome:
		return
	if selected >= 0:
		var matching := cached_moves.filter(func(step: Dictionary) -> bool: return step.from == selected and step.to == cell)
		if not matching.is_empty():
			if matching[0].promotion:
				promotion_move = {"from": selected, "to": cell, "revision": rules.revision}
				promotion_dialog.popup_centered()
			else:
				_submit_host_move(selected, cell, 0)
			return
	selected = cell if Rules.owner(rules.position.board[cell]) == _host_side() else -1
	_render_board()


func _promote(kind: int) -> void:
	promotion_dialog.hide()
	if promotion_move.get("revision") == rules.revision:
		_submit_host_move(promotion_move.from, promotion_move.to, kind)
	promotion_move.clear()


func _submit_host_move(from_cell: int, to_cell: int, promotion: int) -> void:
	_move(from_cell, to_cell, _host_side(), promotion)


func _move(from_cell: int, to_cell: int, side: int, promotion := 0) -> void:
	_consume_clock()
	if stopped or board_motion.busy or not missing.is_empty() or not rules.move(from_cell, to_cell, side, promotion):
		_publish()
		return
	selected = -1
	session_started = true
	_publish()
	_computer_turn()


func _play_again() -> void:
	if stopped or not missing.is_empty() or board_motion.busy or not rules.play_again():
		_publish()
		return
	_cancel_computer()
	result_sent = false
	selected = -1
	promotion_move.clear()
	promotion_dialog.hide()
	last_tick = Time.get_ticks_msec()
	_publish()
	_computer_turn()


func _history_text() -> String:
	var entries := PackedStringArray()
	for index in range(rules.history.size() - 1, -1, -1):
		var entry: Dictionary = rules.history[index]
		entries.append("Game %d: %s (%s)" % [entry.round, "Draw" if entry.winner < 0 else "%s wins" % seats[entry.winner].display_name, entry.reason])
	return "No completed games yet." if entries.is_empty() else "\n\n".join(entries)


func _status() -> String:
	if not missing.is_empty():
		return "Paused: waiting for a player to reconnect."
	if rules.outcome == 3:
		return "Draw! %s." % rules.result_reason
	if rules.outcome:
		return "%s wins! %s." % [_player(rules.outcome).display_name, rules.result_reason]
	var suffix := " Check!" if Rules.in_check(rules.position, rules.position.turn) else ""
	return "Game %d: %s's turn (%s).%s%s" % [rules.round_number, _player(rules.position.turn).display_name, "White" if rules.position.turn == 1 else "Black", suffix, " Thinking..." if _player(rules.position.turn).id == "computer" else ""]


func _render_board() -> void:
	var host_turn: bool = _host_side() == rules.position.turn and missing.is_empty() and rules.outcome == 0 and not board_motion.busy
	var checked: int = rules.position.board.find(Rules.sign_for(rules.position.turn) * Rules.KING) if Rules.in_check(rules.position, rules.position.turn) else -1
	for cell in 64:
		var destination := selected >= 0 and cached_moves.any(func(step: Dictionary) -> bool: return step.from == selected and step.to == cell)
		cells[cell].disabled = not host_turn
		var color := Color("f6d798") if (cell / 8 + cell % 8) % 2 == 0 else Color("633d2b")
		if cell in [rules.last_move.get("from", -1), rules.last_move.get("to", -1)]:
			color = color.lerp(Color("dda846"), 0.40)
		if cell == checked:
			color = Color("c55742")
		var highlighted: bool = host_turn and (cell == selected or (guidance and destination))
		var box := GameLook.box(color, Color("ffde55") if highlighted else color, 0, 3 if highlighted else 0)
		for style in ["normal", "disabled", "focus"]:
			cells[cell].add_theme_stylebox_override(style, box)
		cells[cell].add_theme_stylebox_override("hover", GameLook.box(color.lightened(0.12), Color("ffde55") if highlighted else color, 0, 3 if highlighted else 0))
		cells[cell].add_theme_stylebox_override("pressed", box)


func _landed() -> void:
	if stopped:
		return
	if not rules.last_move.is_empty():
		sounds["crown" if rules.last_move.promotion else ("capture" if rules.last_move.capture >= 0 else "move")].play()
	_show_result()
	_publish()


func _show_result() -> void:
	if rules.outcome and shown_outcome != rules.outcome:
		shown_outcome = rules.outcome
		if rules.outcome in [1, 2]:
			celebration.show_win([], "CHECKMATE!" if rules.result_reason == "Checkmate" else "VICTORY!", SIDE_COLORS[rules.outcome - 1], not session.reduced_motion)
			sounds.win.play()
		else:
			sounds.tie.play()


static func clock_text(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60] if total >= 3600 else "%d:%02d" % [total / 60, total % 60]


func _publish() -> void:
	if stopped or seats.size() != 2:
		return
	_consume_clock()
	if cached_revision != rules.revision:
		cached_revision = rules.revision
		cached_moves = rules.legal_moves()
	if shown_round != rules.round_number:
		shown_round = rules.round_number
		shown_board = []
		shown_outcome = 0
		celebration.clear()
		board_motion.reset(rules.position.board)
	if shown_board != rules.position.board:
		var animate := not shown_board.is_empty() and not rules.last_move.is_empty() and not session.reduced_motion
		if animate:
			board_motion.play(shown_board, rules.position.board, rules.last_move)
		else:
			board_motion.reset(rules.position.board)
			if not shown_board.is_empty() and not rules.last_move.is_empty():
				sounds["crown" if rules.last_move.promotion else ("capture" if rules.last_move.capture >= 0 else "move")].play()
		shown_board = rules.position.board.duplicate()
	if not board_motion.busy:
		_show_result()
	if rules.outcome:
		_cancel_computer()
		promotion_dialog.hide()
		if not result_sent:
			result_sent = true
			session_started = true
			if rules.outcome in [1, 2] and session.players.size() == 2:
				for side in [1, 2]:
					report_result(str(_player(side).profile_id), side == rules.outcome)
				award_points(str(_player(rules.outcome).profile_id), 1)
	screen.status.text = _status()
	for index in 2:
		var identity := _player(index + 1)
		score_cards[index].player.text = identity.display_name + ("\nWHITE" if index == 0 else "\nBLACK")
		screen.set_score_card_identity(score_cards[index], Color(str(identity.get("color", "#58d6ff"))))
		screen.set_score_card_active(score_cards[index], missing.is_empty() and rules.outcome == 0 and rules.position.turn == index + 1)
		var wins: int = rules.session_wins[rules.seat_for(index + 1)]
		score_cards[index].score.text = "%d %s" % [wins, "WIN" if wins == 1 else "WINS"]
		clock_labels[index].text = "UNTIMED" if rules.clock_seconds == 0 else clock_text(rules.remaining[index])
		for kind in range(1, 7):
			material_labels[index][kind - 1].text = "x %d" % rules.position.board.count(Rules.sign_for(index + 1) * kind)
	mode_choice.disabled = session_started or not missing.is_empty()
	clock_toggle.disabled = rules.outcome == 0 and not rules.moves.is_empty()
	clock_input.editable = not clock_toggle.disabled
	clock_toggle.set_pressed_no_signal(rules.clock_seconds > 0)
	clock_toggle.text = "CHESS CLOCK: " + ("ON" if rules.clock_seconds > 0 else "OFF")
	settings_hint.text = "Set time before the first move or between games." + ("\nChanging difficulty resets session wins." if session.players.is_empty() else "")
	replay_button.visible = rules.outcome != 0
	replay_button.disabled = not missing.is_empty() or board_motion.busy
	session_scores.text = "%s: %d wins\n%s: %d wins\nDraws: %d" % [seats[0].display_name, rules.session_wins[0], seats[1].display_name, rules.session_wins[1], rules.draws]
	history_log.text = _history_text()
	_render_board()
	var players: Array = [1, 2].map(func(side: int) -> Dictionary:
		var identity := _player(side)
		return {"id": identity.id, "display_name": identity.display_name, "color": identity.get("color", "#58d6ff")}
	)
	broadcast_state({"board": rules.position.board.duplicate(), "players": players, "turn": rules.position.turn, "legal_moves": cached_moves, "last_move": rules.last_move.duplicate(), "guidance": guidance, "outcome": rules.outcome, "result_reason": rules.result_reason, "paused": not missing.is_empty(), "animating": board_motion.busy, "revision": rules.revision, "round_id": str(rules.round_number), "session_wins": [rules.session_wins[rules.white_seat], rules.session_wins[1 - rules.white_seat]], "draws": rules.draws, "clock_seconds": rules.clock_seconds, "remaining": rules.remaining.duplicate(), "clock_running": rules.clock_started and not rules.outcome and missing.is_empty(), "check": Rules.in_check(rules.position, rules.position.turn), "history": _history_text(), "moves": rules.moves.duplicate(), "status": _status()})

