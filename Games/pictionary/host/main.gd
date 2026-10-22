extends BaseGame

const Rules = preload("res://Games/pictionary/host/rules.gd")
const DrawingCanvas = preload("res://Games/pictionary/host/canvas.gd")
const WordBank = preload("res://Games/pictionary/host/word_bank.gd")
const WRONG_SOUND_INTERVAL := 0.4
var rules = Rules.new()
var screen: GameScreen
var canvas: Control
var layout: Dictionary
var turn_label: Label
var guess_notice: Label
var guess_scroll: ScrollContainer
var guess_table: GridContainer
var guess_rows: Array = []
var score_rows: Array = []
var settings_dialog: Dictionary
var settings_button: Button
var settings_columns: GridContainer
var word_categories: Array = []
var staged_categories: Array = []
var category_ids: Array = ["mixed"]
var edited_category := 0
var category_rows: VBoxContainer
var word_rows: VBoxContainer
var new_category_input: LineEdit
var category_name_input: LineEdit
var new_word_input: LineEdit
var word_difficulty: OptionButton
var save_words_button: Button
var words_notice: Label
var category_counter := 0
var replay: Button
var next_button: Button
var settings_seconds: SpinBox
var settings_laps: SpinBox
var settings_points: SpinBox
var weights_choice: OptionButton
var category_choice: OptionButton
var difficulty_choice: OptionButton
var hints_choice: OptionButton
var apply_button: Button
var settings_notice: Label
var active := false
var last_tick := 0
var shown_second := -1
var recorded_match := -1
var sound_sequence := 0
var wrong_sound_at := -1.0
var effect_sounds: Dictionary = {}
var countdown_turn := -1
var countdown_ticks: Array = []
var clock_alpha := 1.0


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("Pictionary")
	screen.use_playful_style("res://Games/pictionary/art/studio", "studio")
	screen.add_title_art(RuntimeAssets.texture("res://Games/pictionary/art/title.png"), 56.0, false, true)
	screen.reserve_status_plaque(520, 72)
	screen.scores.hide()
	var plaque := GameLook.paper_sheet()
	plaque.set_content_margin(SIDE_TOP, 7)
	plaque.set_content_margin(SIDE_BOTTOM, 7)
	plaque.set_content_margin(SIDE_LEFT, 14)
	plaque.set_content_margin(SIDE_RIGHT, 14)
	screen.status.add_theme_stylebox_override("normal", plaque)
	screen.status.add_theme_font_size_override("normal_font_size", 22)
	screen.exit_requested.connect(return_to_lobby)
	layout = screen.add_centered_layout(false, true)
	var frame := RuntimeAssets.texture("res://Games/pictionary/art/canvas-frame.png")
	var turn_card := screen.add_card(layout.left_sidebar, "framed", frame)
	turn_label = screen.add_section_heading(turn_card, "TURN 1 / 3", 22)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guess_notice = screen.add_sidebar_text(turn_card, "Waiting for correct guesses.")
	guess_scroll = ScrollContainer.new()
	guess_scroll.custom_minimum_size.y = 180
	guess_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	turn_card.add_child(guess_scroll)
	guess_table = GridContainer.new()
	guess_table.columns = 3
	guess_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guess_table.add_theme_constant_override("h_separation", 8)
	guess_table.add_theme_constant_override("v_separation", 12)
	guess_scroll.add_child(guess_table)
	for caption in ["NAME", "LAST GUESS", "TIME"]:
		var label := screen.add_sidebar_text(guess_table, caption)
		label.add_theme_font_size_override("font_size", 13)
	for index in 16:
		var row: Dictionary = {}
		for key in ["player", "guess", "duration"]:
			var label := screen.add_sidebar_text(guess_table, "")
			label.add_theme_font_size_override("font_size", 15)
			label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if key == "duration":
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row[key] = label
		guess_rows.append(row)
	canvas = DrawingCanvas.new()
	canvas.custom_minimum_size = Vector2(316, 316)
	canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.playfield.add_child(canvas)
	var scores_card := screen.add_card(layout.sidebar, "framed", frame)
	screen.add_section_heading(scores_card, "SCORES", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for seat in 16:
		var row := screen.add_session_score(scores_card)
		row.content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.player.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.player.add_theme_font_size_override("font_size", 19)
		row.score.add_theme_font_size_override("font_size", 19)
		row.row.add_theme_constant_override("separation", 10)
		row["bubble"] = screen.add_score_speech_bubble(row)
		row.content.hide()
		score_rows.append(row)
	var footer := VBoxContainer.new()
	footer.custom_minimum_size.y = 96
	footer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	footer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.playfield.add_child(footer)
	settings_button = _button(footer, "SETTINGS", _toggle_settings)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var next_row := CenterContainer.new()
	next_row.custom_minimum_size.y = 44
	footer.add_child(next_row)
	next_button = _button(next_row, "NEXT TURN", _next_turn, true)
	next_button.hide()
	replay = _button(layout.playfield, "PLAY AGAIN", _replay, true)
	replay.size_flags_vertical = Control.SIZE_SHRINK_END
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	replay.hide()
	screen.center_board(canvas, replay, footer, 0.5, true)
	settings_dialog = screen.add_phase_dialog(false, true)
	settings_dialog.heading.text = "SETTINGS"
	settings_columns = GridContainer.new()
	settings_columns.columns = 2
	settings_columns.add_theme_constant_override("h_separation", 24)
	settings_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_dialog.body.add_child(settings_columns)
	var options_body := screen.add_card(settings_columns)
	options_body.get_parent_control().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_settings(options_body)
	var words_body := screen.add_card(settings_columns)
	words_body.get_parent_control().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_word_editor(words_body)
	_button(settings_dialog.actions, "CLOSE", _close_settings, true)
	settings_dialog.overlay.get_child(0).gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not settings_dialog.panel.get_global_rect().has_point(event.global_position):
			_close_settings())
	screen.resized.connect(_fit_settings)
	_fit_settings.call_deferred()
	for kind in ["turn", "correct", "wrong", "countdown", "time_up", "match"]:
		var player := AudioStreamPlayer.new()
		player.stream = RuntimeAssets.audio("res://Games/pictionary/audio/%s.wav" % kind)
		player.bus = "Effects"
		player.max_polyphony = 1
		add_child(player)
		effect_sounds[kind] = player
	screen.resized.connect(_resize_board)
	screen.board_space_changed.connect(_resize_board)
	layout.playfield.resized.connect(_resize_board)
	_resize_board.call_deferred()


func _button(parent: Control, text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	GameLook.action(button, primary)
	button.pressed.connect(callback)
	return button


func _build_settings(parent: VBoxContainer) -> void:
	settings_seconds = screen.add_number_control(parent, "TURN LENGTH", 30, 180, 15, 60, "seconds")
	settings_laps = screen.add_number_control(parent, "DRAWING LAPS", 1, 3, 1, 1)
	settings_points = screen.add_number_control(parent, "POINTS PER TURN", 15, 10000, 1, 100, "points")
	weights_choice = screen.add_choice_control(parent, "RANK WEIGHTS", ["Linear", "Steeper"])
	screen.add_sidebar_text(parent, "Split the turn's points among correct guessers, fastest first. Every correct guesser gets points; incorrect or missing guesses get zero.")
	category_choice = screen.add_choice_control(parent, "CATEGORY", ["Mixed"])
	difficulty_choice = screen.add_choice_control(parent, "DIFFICULTY", ["Mixed", "Easy", "Medium", "Hard"])
	hints_choice = screen.add_choice_control(parent, "HINTS", ["None", "Word length", "Length + timed letters"])
	for input in [settings_seconds, settings_laps, settings_points]:
		input.value_changed.connect(func(_value: float) -> void: _settings_changed())
	for choice in [category_choice, difficulty_choice, hints_choice, weights_choice]:
		choice.item_selected.connect(func(_index: int) -> void: _settings_changed())
	settings_notice = screen.add_sidebar_text(parent, "")
	apply_button = _button(parent, "APPLY", _apply_settings, true)


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Games/pictionary/words.json"))
	if not data is Dictionary:
		return
	var defaults := Rules.DEFAULTS.duplicate()
	defaults["word_categories"] = WordBank.from_words(data.get("words", []))
	var saved := load_game_settings(defaults)
	word_categories = WordBank.validate(saved.word_categories)
	if word_categories.is_empty():
		word_categories = defaults.word_categories.duplicate(true)
	staged_categories = word_categories.duplicate(true)
	category_ids = WordBank.category_ids(word_categories)
	var preferences := Rules.validate_options(saved, category_ids)
	var bank := WordBank.flatten(word_categories)
	if not bank.any(func(word: Dictionary) -> bool: return (preferences.category == "mixed" or word.category == preferences.category) and (preferences.difficulty == "mixed" or word.difficulty == preferences.difficulty)):
		preferences.category = "mixed"
		preferences.difficulty = "mixed"
	_refresh_category_choices()
	if not rules.setup(context.players, bank, preferences, category_ids):
		screen.status.text = "Pictionary needs 3–16 human phone players."
		return
	for seat in context.players.size():
		if not bool(context.players[seat].get("connected", true)):
			rules.set_disconnected(seat)
	_restore_options()
	_refresh_word_editor()
	_render()


func _restore_options() -> void:
	settings_seconds.set_value_no_signal(rules.options.seconds)
	settings_laps.set_value_no_signal(rules.options.laps)
	settings_points.set_value_no_signal(rules.options.turn_points)
	weights_choice.select(Rules.RANK_WEIGHTS.find(rules.options.rank_weights))
	category_choice.select(category_ids.find(rules.options.category))
	difficulty_choice.select(Rules.DIFFICULTIES.find(rules.options.difficulty))
	hints_choice.select(Rules.HINTS.find(rules.options.hints))
	_settings_changed()


func _staged_options() -> Dictionary:
	return {"seconds": int(settings_seconds.value), "laps": int(settings_laps.value), "turn_points": int(settings_points.value), "rank_weights": Rules.RANK_WEIGHTS[weights_choice.selected], "category": category_ids[maxi(0, category_choice.selected)], "difficulty": Rules.DIFFICULTIES[difficulty_choice.selected], "hints": Rules.HINTS[hints_choice.selected]}


func _settings_changed() -> void:
	if apply_button == null:
		return
	var paused: bool = not rules.missing.is_empty()
	var selected := _staged_options()
	apply_button.disabled = paused or selected == rules.options or not _has_words(selected)
	for input in [settings_seconds, settings_laps, settings_points]:
		input.editable = not paused
	for choice in [category_choice, difficulty_choice, hints_choice, weights_choice]:
		choice.disabled = paused
	settings_notice.text = "Apply starts a fresh match. Completed history and session wins remain." if not apply_button.disabled else ""
	if not _has_words(selected):
		settings_notice.text = "No words match this category and difficulty."
	_update_word_save()


func _apply_settings() -> void:
	_advance_clock()
	if not active or not rules.missing.is_empty():
		return
	var preferences := Rules.validate_options(_staged_options(), category_ids)
	if preferences == rules.options or not _has_words(preferences):
		return
	if not save_game_settings(preferences):
		settings_notice.text = "Settings could not be saved."
		return
	if rules.apply_options(preferences):
		_sound("turn")
		_publish(true)
	_settings_changed()


func start_game() -> void:
	active = rules.phase != "idle"
	last_tick = Time.get_ticks_msec()
	_publish(true)


func shutdown_game() -> void:
	active = false
	for player in effect_sounds.values():
		player.stop()
	screen.background_media.set_active(false)
	settings_dialog.overlay.hide()


func _process(_delta: float) -> void:
	if not active:
		return
	if _advance_clock():
		_publish(true)
	_update_countdown()
	_render_bubbles()
	var second := int(ceil(rules.remaining))
	if shown_second != second:
		shown_second = second
		_render_clock()
		broadcast_state({"kind": "clock", "turn_id": rules.turn_id, "revision": rules.revision, "phase": rules.phase, "remaining": rules.remaining, "paused": not rules.missing.is_empty(), "hint": rules.hint()})
		canvas.set_drawing(rules.strokes, rules.hint())


func _advance_clock() -> bool:
	var now := Time.get_ticks_msec()
	var delta := float(now - last_tick) / 1000.0 if last_tick > 0 else 0.0
	last_tick = now
	var old_phase: String = rules.phase
	var changed: bool = rules.tick(delta)
	if changed:
		_sound("time_up" if old_phase == "drawing" else "match" if rules.phase == "finished" else "turn" if rules.phase == "drawing" else "")
		_record_result()
	return changed


func _seat_for(id: String) -> int:
	for seat in rules.players.size():
		if rules.players[seat].id == id:
			return seat
	return -1


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_disconnected(id: String) -> void:
	if not active:
		return
	_advance_clock()
	if rules.set_disconnected(_seat_for(id)):
		for player in effect_sounds.values():
			player.stop()
		_publish(true)


func player_reconnected(player: Dictionary) -> void:
	if not active:
		return
	_advance_clock()
	var seat := _seat_for(str(player.get("id", "")))
	if seat < 0:
		return
	rules.reconnect(seat)
	_publish(true)


func handle_controller_message(id: String, message: Dictionary) -> void:
	var seat := _seat_for(id)
	if seat < 0 or not active:
		return
	if _advance_clock():
		_publish(true)
	var action: Variant = message.get("action")
	if not action is String:
		return
	if action == "sync":
		send_state(id, _snapshot(seat, true))
		return
	if Rules.integer(message.get("revision")) != rules.revision or Rules.integer(message.get("turn_id")) != rules.turn_id or not rules.missing.is_empty():
		send_state(id, _snapshot(seat, true))
		return
	var changed := false
	var include_drawing := false
	var old_phase: String = rules.phase
	match action:
		"choose":
			changed = rules.choose(seat, message.get("choice"))
		"guess":
			var previous: int = rules.guessed.size()
			changed = rules.guess(seat, message.get("guess"))
			if rules.guessed.size() > previous:
				_sound("correct")
			elif changed:
				_sound("wrong")
		"ink":
			var delta: Dictionary = rules.ink(seat, message)
			if not delta.is_empty():
				canvas.set_drawing(rules.strokes, rules.hint())
				broadcast_state(delta)
				return
		"undo", "clear":
			changed = rules.edit_ink(seat, action == "clear")
			include_drawing = true
	if changed:
		if old_phase == "choosing" and rules.phase == "drawing":
			_sound("turn")
		_record_result()
		_publish(include_drawing or old_phase != rules.phase)
	else:
		if action == "ink":
			rules._close_stroke()
		var rejected := _snapshot(seat, true)
		rejected["ink_rejected"] = action == "ink"
		send_state(id, rejected)


func _snapshot(seat: int, drawing := false) -> Dictionary:
	var state: Dictionary = rules.view_for(seat, drawing)
	state["reduced_motion"] = session.reduced_motion
	state["sound_sequence"] = sound_sequence
	return state


func _publish(drawing := false) -> void:
	_render()
	broadcast_state(_snapshot(-1, false))
	for seat in rules.players.size():
		if not rules.missing.has(seat):
			send_state(str(rules.players[seat].id), _snapshot(seat, drawing))


func _record_result() -> void:
	if rules.phase != "finished" or recorded_match == rules.match_number:
		return
	recorded_match = rules.match_number
	if rules.outcome.draw:
		return
	for seat in rules.players.size():
		var profile := str(session.players[seat].get("profile_id", rules.players[seat].id))
		if int(rules.scores[seat]) > 0:
			award_points(profile, int(rules.scores[seat]))
		report_result(profile, rules.outcome.winners.has(seat))


func _sound(kind: String) -> void:
	if kind.is_empty() or not rules.missing.is_empty():
		return
	if kind == "wrong":
		if rules.clock - wrong_sound_at < WRONG_SOUND_INTERVAL or effect_sounds.values().any(func(player: AudioStreamPlayer) -> bool: return player.playing):
			return
		wrong_sound_at = rules.clock
		effect_sounds.wrong.play()
		# Shared speaker only: phones must not echo every player's wrong guess.
		return
	effect_sounds.wrong.stop()
	sound_sequence += 1
	effect_sounds[kind].play()
	broadcast_state({"kind": "sound", "sound": kind, "sequence": sound_sequence, "turn_id": rules.turn_id, "second": int(ceil(rules.remaining))})


func _update_countdown() -> void:
	if countdown_turn != rules.turn_id:
		countdown_turn = rules.turn_id
		countdown_ticks.clear()
	var second := int(ceil(rules.remaining))
	var urgent: bool = rules.phase == "drawing" and second > 0 and second <= 10
	var running: bool = active and rules.missing.is_empty()
	var alpha := GameMotion.countdown_alpha(rules.remaining, session.reduced_motion) if urgent and running else 1.0
	if not is_equal_approx(alpha, clock_alpha):
		clock_alpha = alpha
		_render_clock()
	if not urgent or not running:
		effect_sounds.countdown.stop()
	elif not countdown_ticks.has(second):
		countdown_ticks.append(second)
		_sound("countdown")


func _replay() -> void:
	_advance_clock()
	if active and rules.replay():
		_publish(true)


func _next_turn() -> void:
	_advance_clock()
	if active and rules.next_turn():
		_record_result()
		if rules.phase == "finished":
			_sound("match")
		_publish(true)


func _render_clock() -> void:
	if rules.players.is_empty():
		return
	var text := ""
	var name: String = rules.players[rules.drawer].display_name
	if not rules.missing.is_empty():
		text = "Paused · reconnecting"
	elif rules.phase == "choosing":
		text = name + " is choosing a word"
	elif rules.phase == "drawing":
		text = name + " is drawing"
	elif rules.phase == "reveal":
		text = "Turn complete"
	elif rules.phase == "finished":
		if rules.outcome.draw:
			text = "MATCH DRAW"
		else:
			var names := PackedStringArray()
			for seat in rules.outcome.winners:
				names.append(rules.players[seat].display_name)
			text = names[0] + " wins!" if names.size() == 1 else "SHARED WIN"
	screen.status.clear()
	var narrow := screen.available_size().x < 700
	screen.status.add_theme_font_size_override("normal_font_size", 17 if narrow else 22)
	screen.status.add_text(text)
	if rules.phase != "finished":
		var seconds := int(ceil(rules.remaining))
		screen.status.add_text("    ")
		screen.status.push_font_size(24 if narrow else 32)
		var urgent: bool = rules.phase == "drawing" and seconds > 0 and seconds <= 10
		if urgent:
			var color := GameLook.guess_color("wrong")
			color.a = GameMotion.countdown_alpha(rules.remaining, session.reduced_motion) if active and rules.missing.is_empty() else 1.0
			screen.status.push_color(color)
		screen.status.add_text("%02d:%02d" % [seconds / 60, seconds % 60])
		if urgent:
			screen.status.pop()
		screen.status.pop()


func _render() -> void:
	_render_clock()
	if rules.players.is_empty():
		return
	canvas.set_drawing(rules.strokes, rules.hint())
	var finished: bool = rules.phase == "finished"
	turn_label.text = "LAST GUESSES" if finished else "TURN %d / %d" % [mini(rules.turn_index + 1, rules.players.size() * int(rules.options.laps)), rules.players.size() * int(rules.options.laps)]
	guess_notice.visible = not finished
	var indications := PackedStringArray()
	for seat in rules.guessed:
		indications.append(rules.players[seat].display_name + " guessed it! ✓")
	guess_notice.text = "\n\n".join(indications) if not indications.is_empty() else "Waiting for correct guesses."
	guess_notice.add_theme_color_override("font_color", GameLook.guess_color("correct") if not indications.is_empty() else GameLook.INK)
	guess_scroll.visible = finished
	var entries: Array = rules.guess_results()
	guess_scroll.custom_minimum_size.y = minf(320, maxf(180, entries.size() * 48))
	for index in guess_rows.size():
		var row: Dictionary = guess_rows[index]
		for label in row.values():
			label.visible = index < entries.size()
			label.text = ""
		if index < entries.size():
			var entry: Dictionary = entries[index]
			row.player.text = rules.players[entry.seat].display_name
			row.guess.text = (entry.text if not entry.text.is_empty() else "No guess") + (" ✓" if entry.correct else " ×")
			row.duration.text = "%.1fs" % entry.seconds
			for label in row.values():
				label.add_theme_color_override("font_color", GameLook.guess_color(entry.quality))
	var order: Array = rules.score_order()
	for index in score_rows.size():
		var row: Dictionary = score_rows[index]
		row.content.visible = index < order.size()
		if index < order.size():
			var seat: int = order[index]
			row["seat"] = seat
			row.player.text = rules.players[seat].display_name + (" ★" if rules.phase == "finished" and rules.outcome.winners.has(seat) else " ✓" if rules.guessed.has(seat) else "")
			row.score.text = str(rules.scores[seat])
			screen.set_score_card_active(row, seat == rules.drawer and rules.phase in ["choosing", "drawing"] and rules.missing.is_empty())
	_render_bubbles()
	replay.visible = rules.phase == "finished"
	next_button.visible = rules.phase == "reveal"
	replay.disabled = not rules.missing.is_empty()
	next_button.disabled = not rules.missing.is_empty()
	_settings_changed()
	_resize_board.call_deferred()


func _render_bubbles() -> void:
	var bubbles: Dictionary = {}
	if rules.missing.is_empty():
		for bubble in rules.guess_bubbles():
			bubbles[bubble.seat] = bubble
	for row in score_rows:
		var entry: Dictionary = bubbles.get(row.get("seat", -1), {})
		screen.set_speech_bubble(row.bubble, str(entry.get("text", "")), str(entry.get("quality", "wrong")))


func _resize_board() -> void:
	if canvas == null:
		return
	var bounds := screen.available_size()
	var width_limit := bounds.x - 560.0 if bounds.x >= 900 else bounds.x - 48.0
	var width := maxf(160, minf(820, minf(width_limit, screen.board_height_limit())))
	canvas.custom_minimum_size = Vector2(width, width)



func _has_words(preferences: Dictionary) -> bool:
	return rules.words.any(func(word: Dictionary) -> bool: return (preferences.category == "mixed" or word.category == preferences.category) and (preferences.difficulty == "mixed" or word.difficulty == preferences.difficulty))


func _fit_settings() -> void:
	if settings_columns != null:
		settings_columns.columns = 2 if screen.available_size().x >= 900 else 1


func _toggle_settings() -> void:
	settings_dialog.overlay.visible = not settings_dialog.overlay.visible


func _close_settings() -> void:
	settings_dialog.overlay.hide()
	settings_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if settings_dialog.overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()


func _build_word_editor(parent: VBoxContainer) -> void:
	screen.add_section_heading(parent, "WORD CATEGORIES")
	var editor := GridContainer.new()
	editor.columns = 2
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("h_separation", 16)
	parent.add_child(editor)
	var category_body := VBoxContainer.new()
	category_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(category_body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 216
	category_body.add_child(scroll)
	category_rows = VBoxContainer.new()
	category_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(category_rows)
	new_category_input = LineEdit.new()
	new_category_input.placeholder_text = "New category"
	new_category_input.max_length = 40
	category_body.add_child(new_category_input)
	_button(category_body, "ADD CATEGORY", _add_category)
	new_category_input.text_submitted.connect(func(_text: String) -> void: _add_category())
	var word_body := VBoxContainer.new()
	word_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.add_child(word_body)
	var rename_row := HBoxContainer.new()
	word_body.add_child(rename_row)
	category_name_input = LineEdit.new()
	category_name_input.placeholder_text = "Category name"
	category_name_input.max_length = 40
	category_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(category_name_input)
	GameLook.compact_control(_button(rename_row, "RENAME", _rename_category))
	var word_scroll := ScrollContainer.new()
	word_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	word_scroll.custom_minimum_size.y = 160
	word_body.add_child(word_scroll)
	word_rows = VBoxContainer.new()
	word_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_scroll.add_child(word_rows)
	var add_row := HBoxContainer.new()
	word_body.add_child(add_row)
	new_word_input = LineEdit.new()
	new_word_input.placeholder_text = "New word"
	new_word_input.max_length = 40
	new_word_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(new_word_input)
	GameLook.compact_control(_button(add_row, "ADD WORD", _add_word))
	word_difficulty = screen.add_choice_control(word_body, "WORD DIFFICULTY", ["Easy", "Medium", "Hard"], true)
	new_word_input.text_submitted.connect(func(_text: String) -> void: _add_word())
	words_notice = screen.add_sidebar_text(parent, "")
	save_words_button = _button(parent, "SAVE WORDS", _save_words, true)
	var fit := func() -> void: editor.columns = 2 if screen.available_size().x >= 900 else 1
	screen.resized.connect(fit)
	fit.call_deferred()


func _refresh_category_choices() -> void:
	category_choice.clear()
	category_choice.add_item("Mixed")
	for category in word_categories:
		category_choice.add_item(category.name)


func _clear_rows(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _refresh_word_editor() -> void:
	_clear_rows(category_rows)
	_clear_rows(word_rows)
	edited_category = clampi(edited_category, 0, maxi(0, staged_categories.size() - 1))
	for index in staged_categories.size():
		var category: Dictionary = staged_categories[index]
		var row := HBoxContainer.new()
		category_rows.add_child(row)
		var select := _button(row, category.name, func() -> void:
			edited_category = index
			_refresh_word_editor())
		select.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.custom_minimum_size.x = 88
		if edited_category == index:
			select.text = "› " + category.name
		GameLook.compact_control(select)
		var remove := _button(row, "×", func() -> void:
			staged_categories.remove_at(index)
			_refresh_word_editor())
		GameLook.compact_control(remove)
		remove.custom_minimum_size = Vector2(44, 44)
	category_name_input.text = "" if staged_categories.is_empty() else staged_categories[edited_category].name
	if not staged_categories.is_empty():
		var words: Array = staged_categories[edited_category].words
		for index in words.size():
			var row := HBoxContainer.new()
			word_rows.add_child(row)
			var label := screen.add_sidebar_text(row, words[index].word)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.x = 88
			var remove := _button(row, "×", func() -> void:
				staged_categories[edited_category].words.remove_at(index)
				_refresh_word_editor())
			GameLook.compact_control(remove)
			remove.custom_minimum_size = Vector2(44, 44)
	_update_word_save()


func _update_word_save() -> void:
	if save_words_button == null:
		return
	var changed := staged_categories != word_categories
	var valid := not WordBank.validate(staged_categories).is_empty()
	save_words_button.disabled = not changed or not valid or not rules.missing.is_empty()
	words_notice.text = "Save starts a fresh match with the edited word bank." if changed and valid else "Keep at least three words in the bank." if changed else ""


func _add_category() -> void:
	var name := new_category_input.text.strip_edges()
	if not WordBank.valid_name(name) or staged_categories.size() >= WordBank.MAX_CATEGORIES:
		return
	if staged_categories.any(func(category: Dictionary) -> bool: return category.name.to_lower() == name.to_lower()):
		words_notice.text = "That category already exists."
		return
	var id := ""
	while id.is_empty() or staged_categories.any(func(category: Dictionary) -> bool: return category.id == id):
		category_counter += 1
		id = "custom-%d" % category_counter
	staged_categories.append({"id": id, "name": name, "words": []})
	edited_category = staged_categories.size() - 1
	new_category_input.clear()
	_refresh_word_editor()


func _rename_category() -> void:
	if staged_categories.is_empty():
		return
	var name := category_name_input.text.strip_edges()
	if not WordBank.valid_name(name):
		return
	for index in staged_categories.size():
		if index != edited_category and staged_categories[index].name.to_lower() == name.to_lower():
			words_notice.text = "That category already exists."
			return
	staged_categories[edited_category].name = name
	_refresh_word_editor()


func _add_word() -> void:
	if staged_categories.is_empty():
		return
	var text := new_word_input.text.strip_edges()
	if not WordBank.valid_name(text) or Rules.normalize(text).is_empty():
		return
	var words: Array = staged_categories[edited_category].words
	if words.any(func(word: Dictionary) -> bool: return Rules.normalize(word.word) == Rules.normalize(text)):
		words_notice.text = "That word already exists."
		return
	words.append({"word": text, "difficulty": ["easy", "medium", "hard"][word_difficulty.selected], "aliases": []})
	new_word_input.clear()
	_refresh_word_editor()


func _save_words() -> void:
	_advance_clock()
	if not active or not rules.missing.is_empty():
		return
	var accepted := WordBank.validate(staged_categories)
	if accepted.is_empty() or accepted == word_categories:
		return
	var ids := WordBank.category_ids(accepted)
	var staged_options := _staged_options()
	var bank := WordBank.flatten(accepted)
	var preferences := Rules.validate_options(rules.options, ids)
	if not bank.any(func(word: Dictionary) -> bool: return (preferences.category == "mixed" or word.category == preferences.category) and (preferences.difficulty == "mixed" or word.difficulty == preferences.difficulty)):
		preferences.category = "mixed"
		preferences.difficulty = "mixed"
	if not save_game_settings({"word_categories": accepted, "category": preferences.category, "difficulty": preferences.difficulty}):
		words_notice.text = "Words could not be saved."
		return
	word_categories = accepted.duplicate(true)
	staged_categories = accepted.duplicate(true)
	category_ids = ids
	rules.replace_word_bank(bank, ids)
	_refresh_category_choices()
	category_choice.select(category_ids.find(staged_options.category) if category_ids.has(staged_options.category) else category_ids.find(rules.options.category))
	_settings_changed()
	_refresh_word_editor()
	_publish(true)
