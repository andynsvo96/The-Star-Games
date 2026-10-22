extends BaseGame

const Rules = preload("res://Games/battleship/host/rules.gd")
const FleetBoard = preload("res://Games/battleship/host/fleet_board.gd")
const FleetConsole = preload("res://Games/battleship/host/fleet_console.gd")
const BRIDGE_SIZE := Vector2(1672, 941)
const CONSOLE_AREAS := [Rect2(0.02, 0.30, 0.20, 0.45), Rect2(0.78, 0.30, 0.20, 0.45)]
const CONSOLE_ANGLES := [0.0, 0.0]
var rules := Rules.new()
var screen: GameScreen
var seats: Array = []
var missing: Dictionary = {}
var boards: Array = []
var board_row: GridContainer
var board_frame: PanelContainer
var setup_toolbar: HFlowContainer
var ship_choice: OptionButton
var auto_button: Button
var clear_button: Button
var ready_button: Button
var replay_button: Button
var view_choice: OptionButton
var difficulty_choice: OptionButton
var mode_choice: OptionButton
var settings_hint: Label
var history_log: RichTextLabel
var score_cards: Array = []
var sounds: Dictionary = {}
var celebration: GameCelebration
var ai_timer: Timer
var shot_tween: Tween
var difficulty := Rules.Difficulty.MEDIUM
var selected_ship := 0
var vertical := false
var host_plays := false
var session_started := false
var result_sent := false
var animating := false
var stopped := false
var shown_win := 0
var notices: Dictionary = {}
var console_layer: Control
var console_row: GridContainer
var console_slots: Array[Control] = []
var fleet_consoles: Array = []
var setup_controls: VBoxContainer
var setup_actions: HBoxContainer
var deck_docked := false
var details_bodies: Array[VBoxContainer] = []


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("BATTLESHIP")
	screen.use_playful_style("res://Games/battleship/art/command-bridge", "admiral")
	screen.add_title_art(RuntimeAssets.texture("res://Games/battleship/art/title-v2.png"), 150)
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	setup_toolbar = HFlowContainer.new()
	setup_toolbar.alignment = FlowContainer.ALIGNMENT_CENTER
	screen.content.add_child(setup_toolbar)
	view_choice = screen.add_choice_control(screen.content, "FLEET VIEW", ["Player Fleet", "Enemy Fleet"])
	view_choice.item_selected.connect(func(_index: int) -> void: _resize_boards())
	var center := CenterContainer.new()
	screen.content.add_child(center)
	var playfield := VBoxContainer.new()
	center.add_child(playfield)
	board_frame = PanelContainer.new()
	board_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	playfield.add_child(board_frame)
	board_row = GridContainer.new()
	board_row.columns = 2
	board_row.add_theme_constant_override("h_separation", 16)
	board_frame.add_child(board_row)
	for index in 2:
		var board := FleetBoard.new()
		board.cell_pressed.connect(func(cell: int) -> void: _host_cell(index, cell))
		board.ship_held.connect(func(cell: int) -> void: _host_hold(index, cell))
		board_row.add_child(board)
		boards.append(board)
	celebration = GameCelebration.new()
	board_frame.add_child(celebration)
	replay_button = _button(playfield, "PLAY AGAIN", _play_again)
	GameLook.action(replay_button)
	screen.center_board(board_frame, replay_button, setup_toolbar)
	screen.resized.connect(_resize_boards)
	screen.board_space_changed.connect(_resize_boards)
	console_layer = Control.new()
	console_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console_layer.theme = screen.theme
	console_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(console_layer)
	console_row = GridContainer.new()
	console_row.columns = 2
	console_row.add_theme_constant_override("h_separation", 14)
	screen.content.add_child(console_row)
	for index in 2:
		var slot := Control.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		console_row.add_child(slot)
		console_slots.append(slot)
		var monitor := FleetConsole.new()
		monitor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(monitor)
		fleet_consoles.append(monitor)
	setup_controls = VBoxContainer.new()
	setup_controls.add_theme_constant_override("separation", 4)
	setup_toolbar.add_child(setup_controls)
	ship_choice = OptionButton.new()
	ship_choice.fit_to_longest_item = false
	ship_choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for index in 5:
		ship_choice.add_item("%s (%d)" % [Rules.NAMES[index], Rules.LENGTHS[index]])
	setup_controls.add_child(ship_choice)
	ship_choice.item_selected.connect(func(index: int) -> void: selected_ship = index; _render_host())
	auto_button = _button(setup_controls, "AUTO PLACE", func() -> void: _setup_action(1, "auto"))
	setup_actions = HBoxContainer.new()
	setup_actions.add_theme_constant_override("separation", 4)
	setup_controls.add_child(setup_actions)
	clear_button = _button(setup_actions, "CLEAR", func() -> void: _setup_action(1, "clear"))
	ready_button = _button(setup_actions, "READY", func() -> void: _setup_action(1, "ready"))
	GameLook.action(ready_button)
	for button in [clear_button, ready_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_bodies = screen.add_board_details(["SETTINGS", "SESSION & HISTORY"])
	var options := details_bodies[0]
	difficulty_choice = screen.add_choice_control(options, "SOLO DIFFICULTY", ["Easy", "Medium", "Hard"])
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_select_difficulty)
	mode_choice = screen.add_choice_control(options, "ONE CONNECTED PLAYER", ["Player vs Computer", "Host vs Player"])
	mode_choice.item_selected.connect(_select_mode)
	settings_hint = screen.add_sidebar_text(options, "")
	var journal := details_bodies[1]
	for index in 2:
		score_cards.append(screen.add_session_score(journal))
	history_log = screen.add_history_log(journal)
	history_log.custom_minimum_size.y = 130
	for effect in ["place", "cannon", "miss", "hit", "sunk", "win"]:
		var audio := AudioStreamPlayer.new()
		audio.stream = RuntimeAssets.audio("res://Games/battleship/audio/%s.wav" % effect)
		audio.bus = "Effects"
		audio.max_polyphony = 3
		add_child(audio)
		sounds[effect] = audio
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	ai_timer.wait_time = 0.65
	ai_timer.timeout.connect(_computer_turn)
	add_child(ai_timer)
	_resize_boards.call_deferred()


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	return button


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
		seats.append({"id": "computer", "display_name": "Computer", "color": "#e53935"})
	difficulty_choice.get_parent().visible = context.players.is_empty()
	mode_choice.get_parent().visible = context.players.size() == 1
	mode_choice.select(1 if host_plays else 0)
	_prepare_computer_fleet()


func start_game() -> void:
	_publish()


func shutdown_game() -> void:
	stopped = true
	_clear_motion()
	screen.background_media.set_active(false)


func _clear_motion() -> void:
	ai_timer.stop()
	if shot_tween != null and shot_tween.is_valid():
		shot_tween.kill()
	animating = false
	for board in boards:
		board.clear_motion()
	for sound in sounds.values():
		sound.stop()
	celebration.clear()
	for card in score_cards:
		GameMotion.reset(card.score)


func _resize_boards() -> void:
	if screen == null or boards.is_empty() or console_slots.is_empty():
		return
	_layout_consoles()
	var narrow := screen.available_size().x < 700
	view_choice.get_parent().visible = narrow and (session == null or rules.phase != "setup" or not host_plays)
	var selected := view_choice.selected
	if host_plays and rules.phase == "setup":
		selected = 0
	board_row.columns = 1 if narrow else 2
	var available := screen.available_size()
	var width_limit := available.x - 66
	if deck_docked:
		width_limit = minf(width_limit, 2 * minf(available.x / 2 - console_slots[0].get_rect().end.x, console_slots[1].position.x - available.x / 2) - 32)
	var minimum := 104.0 if rules.phase == "setup" and available.y < 560 else 140.0
	var edge := maxf(minimum, minf(screen.board_height_limit() / FleetBoard.ASPECT, (width_limit - (0 if narrow else 16)) / (1 if narrow else 2)))
	for index in 2:
		boards[index].visible = not narrow or index == selected
		boards[index].custom_minimum_size = Vector2(edge, edge * FleetBoard.ASPECT)


func _layout_consoles() -> void:
	var available := screen.available_size()
	var covered := BRIDGE_SIZE * maxf(available.x / BRIDGE_SIZE.x, available.y / BRIDGE_SIZE.y)
	var offset := (available - covered) / 2
	var rects: Array[Rect2] = []
	for area in CONSOLE_AREAS:
		rects.append(Rect2(offset + area.position * covered, area.size * covered))
	deck_docked = available.x >= 1100 and Rect2(Vector2.ZERO, available).encloses(rects[0]) and Rect2(Vector2.ZERO, available).encloses(rects[1]) and rects[0].size.x >= 148 and rects[0].size.y >= 96
	var setup := rules.phase == "setup"
	console_row.visible = not deck_docked and not setup
	setup_controls.visible = setup and host_plays
	setup_toolbar.visible = setup and host_plays and not deck_docked
	for index in 2:
		var slot := console_slots[index]
		var parent: Control = console_layer if deck_docked else console_row
		if slot.get_parent() != parent:
			slot.reparent(parent)
		slot.visible = not setup or (index == 0 and host_plays and deck_docked)
		slot.custom_minimum_size = Vector2.ZERO if deck_docked else Vector2(180, 135)
		if deck_docked:
			slot.position = rects[index].position
			slot.size = rects[index].size
			slot.pivot_offset = slot.size / 2
			slot.rotation_degrees = CONSOLE_ANGLES[index]
		else:
			slot.rotation = 0
		fleet_consoles[index].docked = deck_docked
		fleet_consoles[index].show_status = not setup
		fleet_consoles[index].queue_redraw()
	var control_parent: Control = console_slots[0] if deck_docked else setup_toolbar
	if setup_controls.get_parent() != control_parent:
		setup_controls.reparent(control_parent)
	for control in [ship_choice, auto_button, clear_button, ready_button]:
		GameLook.compact_control(control, deck_docked or available.y < 560)
	setup_controls.custom_minimum_size.x = 0 if deck_docked else minf(280, available.x - 60)
	if deck_docked:
		var height := setup_controls.get_combined_minimum_size().y
		# The complete group inherits the monitor's tilt, including its click targets.
		setup_controls.position = Vector2(18, (rects[0].size.y - height) / 2)
		setup_controls.size = Vector2(rects[0].size.x - 36, height)


func _rotate_ship() -> void:
	if stopped or not host_plays or rules.phase != "setup" or rules.ready[0] or not missing.is_empty():
		return
	if boards[0].preview >= 0:
		_host_hold(0, boards[0].preview)
		return
	vertical = not vertical
	_render_host()


func _host_hold(board: int, cell: int) -> void:
	if board != 0 or not host_plays or stopped or rules.phase != "setup" or rules.ready[0] or not missing.is_empty():
		return
	var existing: Array = rules.fleets[0].filter(func(ship: Dictionary) -> bool: return ship.cells.has(cell))
	if existing.is_empty():
		vertical = not vertical
		boards[0].preview = cell
		notices.erase(1)
		_render_host()
	else:
		_rotate_placed_ship(1, cell)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_rotate_ship()


func _select_difficulty(index: int) -> void:
	if stopped or not session.players.is_empty() or index not in [0, 1, 2] or index == difficulty:
		return
	difficulty = index
	save_game_settings({"difficulty": difficulty})
	_clear_motion()
	var next_revision: int = rules.revision + 1
	rules = Rules.new()
	rules.revision = next_revision
	session_started = false
	result_sent = false
	shown_win = 0
	selected_ship = 0
	notices.clear()
	_prepare_computer_fleet()
	_publish()


func _select_mode(index: int) -> void:
	if stopped or session.players.size() != 1 or session_started or not missing.is_empty() or index not in [0, 1]:
		mode_choice.select(1 if host_plays else 0)
		return
	if host_plays == (index == 1):
		return
	host_plays = index == 1
	save_game_settings({"host_plays": host_plays})
	seats = [session.solo_profile.duplicate(true), session.players[0].duplicate(true)] if host_plays else [session.players[0].duplicate(true), {"id": "computer", "display_name": "Computer", "color": "#e53935"}]
	var next_revision: int = rules.revision + 1
	rules = Rules.new()
	rules.revision = next_revision
	notices.clear()
	_prepare_computer_fleet()
	_publish()


func _prepare_computer_fleet() -> void:
	if seats.size() == 2 and seats[1].id == "computer":
		rules.auto_place(2)
		rules.lock_fleet(2)


func _seat_for(player_id: String) -> int:
	for index in seats.size():
		if str(seats[index].id) == player_id:
			return index + 1
	return 0


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	missing.erase(str(player.get("id", "")))
	_publish()
	_queue_computer()


func player_disconnected(player_id: String) -> void:
	if session.players.any(func(player: Dictionary) -> bool: return str(player.id) == player_id):
		missing[player_id] = true
		ai_timer.stop()
	_publish()


static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if stopped or not session.players.any(func(player: Dictionary) -> bool: return str(player.id) == player_id):
		return
	var seat := _seat_for(player_id)
	if seat == 0:
		return
	if message.get("action") == "sync":
		send_state(player_id, _snapshot(seat))
		return
	if not _valid_integer(message.get("revision"), rules.revision, rules.revision):
		send_state(player_id, _snapshot(seat))
		return
	if not missing.is_empty() or animating:
		return
	match message.get("action"):
		"place":
			if _valid_integer(message.get("ship"), 0, 4) and _valid_integer(message.get("cell"), 0, 99) and message.get("vertical") is bool:
				_place_ship(seat, int(message.ship), int(message.cell), message.vertical)
		"rotate":
			if _valid_integer(message.get("cell"), 0, 99):
				_rotate_placed_ship(seat, int(message.cell))
		"auto", "clear", "ready":
			_setup_action(seat, message.action)
		"fire":
			if _valid_integer(message.get("cell"), 0, 99):
				_fire(seat, int(message.cell))
		"play_again", "next":
			_play_again()


func _host_cell(board: int, cell: int) -> void:
	if not host_plays or stopped:
		return
	if rules.phase == "setup" and board == 0:
		_place_ship(1, selected_ship, cell, vertical)
	elif rules.phase == "battle" and board == 1:
		_fire(1, cell)


func _place_ship(seat: int, ship: int, cell: int, upright: bool) -> void:
	if stopped or not missing.is_empty() or animating:
		return
	if not rules.place_ship(seat, ship, cell, upright):
		notices[seat] = "Choose a clear position inside the grid."
		_publish()
		return
	session_started = true
	notices.erase(seat)
	sounds.place.play()
	if seat == 1 and host_plays:
		var unplaced := range(5).filter(func(index: int) -> bool: return not rules.fleets[0].any(func(p: Dictionary) -> bool: return p.ship == index))
		if not unplaced.is_empty():
			selected_ship = unplaced[0]
	_publish()


func _rotate_placed_ship(seat: int, cell: int) -> void:
	if stopped or not missing.is_empty() or animating:
		return
	var existing: Array = rules.fleets[seat - 1].filter(func(ship: Dictionary) -> bool: return ship.cells.has(cell))
	if not rules.rotate_ship(seat, cell):
		notices[seat] = "Not enough clear space to rotate this ship."
		_publish()
		return
	session_started = true
	notices.erase(seat)
	sounds.place.play()
	if seat == 1 and host_plays:
		selected_ship = existing[0].ship
		vertical = not existing[0].vertical
		boards[0].preview = -1
	_publish()


func _setup_action(seat: int, action: String) -> void:
	if stopped or not missing.is_empty() or animating or rules.phase != "setup":
		return
	var accepted := false
	match action:
		"auto": accepted = rules.auto_place(seat)
		"clear": accepted = rules.clear_fleet(seat)
		"ready": accepted = rules.lock_fleet(seat)
	if not accepted:
		return
	session_started = true
	notices.erase(seat)
	if action == "auto":
		sounds.place.play()
	if rules.phase == "battle" and host_plays:
		view_choice.select(1)
	_publish()
	_queue_computer()


func _fire(seat: int, cell: int) -> void:
	if stopped or not missing.is_empty() or animating or not rules.fire(seat, cell):
		return
	session_started = true
	sounds.cannon.play()
	animating = not session.reduced_motion
	if host_plays and screen.available_size().x < 700:
		view_choice.select(2 - seat)
	_publish()
	for index in 2:
		boards[index].animate_fire(rules.last_shot, index == seat - 1)
	if session.reduced_motion:
		_impact_sound()
		if host_plays and rules.phase == "battle" and rules.turn == 1:
			view_choice.select(1)
			_render_host()
		_queue_computer()
		return
	shot_tween = create_tween()
	shot_tween.tween_interval(0.48)
	shot_tween.tween_callback(_impact_sound)
	shot_tween.tween_interval(0.77)
	shot_tween.tween_callback(func() -> void:
		animating = false
		if host_plays and rules.phase == "battle" and rules.turn == 1:
			view_choice.select(1)
		_publish()
		_queue_computer()
	)


func _impact_sound() -> void:
	if not stopped and not rules.last_shot.is_empty():
		sounds[["miss", "hit", "sunk"][rules.last_shot.result - 1]].play()


func _queue_computer() -> void:
	if not stopped and missing.is_empty() and not animating and rules.phase == "battle" and rules.turn == 2 and seats[1].id == "computer" and ai_timer.is_stopped():
		ai_timer.start()


func _computer_turn() -> void:
	if stopped or not missing.is_empty() or animating or rules.phase != "battle" or rules.turn != 2 or seats[1].id != "computer":
		return
	var level := difficulty if session.players.is_empty() else Rules.Difficulty.HARD
	_fire(2, Rules.computer_target(rules.shots[1], rules.remaining_lengths(2), level))


func _play_again() -> void:
	if stopped or not missing.is_empty() or animating or not rules.play_again():
		return
	_clear_motion()
	result_sent = false
	shown_win = 0
	selected_ship = 0
	vertical = false
	view_choice.select(0)
	notices.clear()
	_prepare_computer_fleet()
	_publish()


func _history_text() -> String:
	var lines := PackedStringArray()
	for index in range(rules.history.size() - 1, -1, -1):
		var entry: Dictionary = rules.history[index]
		lines.append("Game %d: %s wins (%d shots)" % [entry.round, seats[entry.winner - 1].display_name, entry.shots[entry.winner - 1]])
	return "No completed games yet." if lines.is_empty() else "\n\n".join(lines)


func _status(viewer: int) -> String:
	if not missing.is_empty():
		return "Paused: waiting for a player to reconnect."
	if animating:
		return "CANNON FIRE!"
	if rules.phase == "finished":
		return "FLEET SUNK! %s wins." % seats[rules.outcome - 1].display_name
	if rules.phase == "setup":
		if viewer in [1, 2]:
			if notices.has(viewer):
				return notices[viewer]
			if rules.ready[viewer - 1]:
				return "Fleet ready. Waiting for the opposing fleet."
			return "Deploy your fleet: %d of 5 ships placed." % rules.fleets[viewer - 1].size()
		return "Fleet setup: %d of 2 captains ready." % (int(rules.ready[0]) + int(rules.ready[1]))
	var feedback := ""
	if not rules.last_shot.is_empty():
		feedback = ["MISS!  ", "HIT!  ", "%s SUNK!  " % Rules.NAMES[maxi(0, rules.last_shot.ship)].to_upper()][rules.last_shot.result - 1]
	return "%s%s's turn." % [feedback, seats[rules.turn - 1].display_name]


func _snapshot(viewer: int) -> Dictionary:
	var state: Dictionary = rules.view_for(viewer)
	state.players = seats.map(func(player: Dictionary) -> Dictionary: return {"id": str(player.id), "display_name": str(player.display_name), "color": str(player.get("color", "#58d6ff"))})
	state.paused = not missing.is_empty()
	state.animating = animating
	state.reduced_motion = session.reduced_motion
	state.status = _status(viewer)
	state.history = _history_text()
	return state


func _render_host() -> void:
	if seats.size() != 2 or stopped:
		return
	var state := _snapshot(1 if host_plays else 0)
	screen.status.text = state.status
	var win_labels: Array[String] = []
	for wins in rules.session_wins:
		win_labels.append("%d %s" % [wins, "WIN" if wins == 1 else "WINS"])
	setup_toolbar.visible = host_plays and rules.phase == "setup"
	var setup_active: bool = host_plays and rules.phase == "setup" and not rules.ready[0] and missing.is_empty()
	ship_choice.select(selected_ship)
	ship_choice.disabled = not setup_active
	auto_button.disabled = not setup_active
	clear_button.disabled = not setup_active or rules.fleets[0].is_empty()
	ready_button.disabled = not setup_active or rules.fleets[0].size() != 5
	for index in 2:
		var can_act: bool = host_plays and missing.is_empty() and not animating and ((index == 0 and setup_active) or (index == 1 and rules.phase == "battle" and rules.turn == 1))
		var caption := ("PLAYER FLEET" if index == 0 else "ENEMY FLEET") if host_plays else ("FLEET ONE" if index == 0 else "FLEET TWO")
		boards[index].set_view(state.fleets[index], state.incoming[index], caption, index == 1, can_act, setup_active and index == 0, selected_ship, vertical, session.reduced_motion, animating)
		fleet_consoles[index].set_view(state.fleets[index], state.incoming[index], caption, index == 1)
		score_cards[index].player.text = str(seats[index].display_name)
		score_cards[index].score.text = win_labels[index]
		screen.set_score_card_active(score_cards[index], rules.phase == "battle" and rules.turn == index + 1 and missing.is_empty())
	difficulty_choice.select(difficulty)
	mode_choice.select(1 if host_plays else 0)
	mode_choice.disabled = session_started or not missing.is_empty()
	settings_hint.text = ["Easy fires randomly.", "Medium hunts and follows hits.", "Hard uses shot probability; it never sees your ships."][difficulty] + " Changing difficulty clears this session." if session.players.is_empty() else ("Return to games to change opponents." if session_started else "Choose opponents before deploying your fleet.")
	if session.players.size() == 2:
		settings_hint.text = "Both captains deploy on their phones. Hidden ships stay off the shared display."
	history_log.text = _history_text()
	replay_button.visible = rules.phase == "finished"
	replay_button.disabled = animating or not missing.is_empty()
	if rules.outcome != 0 and not animating and shown_win != rules.outcome:
		shown_win = rules.outcome
		celebration.show_win([], "FLEET SUNK!", Color("ffce4c"), not session.reduced_motion)
		GameMotion.play(score_cards[rules.outcome - 1].score, session.reduced_motion, false, true)
		sounds.win.play()
	_resize_boards()


func _publish() -> void:
	if stopped or seats.size() != 2:
		return
	if rules.outcome != 0 and not result_sent:
		result_sent = true
		if session.players.size() == 2:
			for index in 2:
				report_result(str(seats[index].id), rules.outcome == index + 1)
				if rules.outcome == index + 1:
					award_points(str(seats[index].id), 1)
	_render_host()
	# Deliberately no broadcast: secrets only travel to their admitted owner.
	for player in session.players:
		send_state(str(player.id), _snapshot(_seat_for(str(player.id))))
