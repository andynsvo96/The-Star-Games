extends BaseGame

const Rules = preload("res://Games/mafia/host/rules.gd")
var rules = Rules.new()
var screen: GameScreen
var phase_label: Label
var event_label: Label
var progress_label: Label
var plan_label: Label
var start_button: Button
var replay: Button
var godfather_toggle: Button
var boxer_toggle: Button
var ejection_toggle: Button
var apply_button: Button
var staged_options := {"godfather": false, "boxer": false, "ejection": true}
var living_team: HFlowContainer
var suspicion_label: Label
var ejection_stage: Control
var roster_rows: Array = []
var history_log: RichTextLabel
var phase_dialog: Dictionary
var ballot_label: Label
var ballot_scroll: ScrollContainer
var result_team: HFlowContainer
var reveal_label: RichTextLabel
var option_controls: VBoxContainer
var settings_dialog: Dictionary
var background_daytime: Variant = null
var sky: Control
var active := false
var recorded_round := -1
var social_layout: Dictionary
var ballot_card: Control
var ballot_heading: Label
var settings_button: Button
var scores_button: Button
var suspicion_heading: Label


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("Mafia")
	screen.use_playful_style("res://Games/mafia/art/town-night", "noir")
	sky = preload("res://Games/mafia/host/sky.gd").new()
	screen.background_media.add_child(sky)
	screen.add_wordmark(["MAFIA"], [Color("ffefd2")])
	screen.exit_requested.connect(return_to_lobby)
	screen.scores.hide()
	screen.status.hide()
	phase_label = screen.add_text("MAFIA", 36)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 36)
	event_label = screen.add_text("")
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	living_team = screen.add_team_reveal(screen.content)
	progress_label = screen.add_text("", 24)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	social_layout = screen.add_social_layout(0.7)
	var card := screen.add_card(social_layout.primary)
	ballot_card = card.get_parent()
	ballot_heading = screen.add_sidebar_text(card, "Town voting")
	ballot_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ballot_heading.add_theme_font_size_override("font_size", 24)
	ballot_scroll = ScrollContainer.new()
	ballot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(ballot_scroll)
	ballot_label = screen.add_sidebar_text(ballot_scroll, "")
	ballot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button = _button(card, "START GAME", _replay, true)
	var suspects := screen.add_card(social_layout.primary)
	suspicion_heading = screen.add_section_heading(suspects, "SUSPECTED PLAYERS")
	suspicion_label = screen.add_sidebar_text(suspects, "")
	suspicion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay = _button(social_layout.footer, "PLAY AGAIN", _replay, true)
	settings_button = _button(social_layout.footer, "SETTINGS", _open_settings)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings_dialog = screen.add_phase_dialog(true)
	settings_dialog.heading.text = "SETTINGS"
	var settings: VBoxContainer = settings_dialog.body
	option_controls = VBoxContainer.new()
	settings.add_child(option_controls)
	var role_grid := GridContainer.new()
	role_grid.columns = 2
	option_controls.add_child(role_grid)
	godfather_toggle = screen.add_toggle_control(role_grid, "GODFATHER", false)
	boxer_toggle = screen.add_toggle_control(role_grid, "BOXER", false)
	ejection_toggle = screen.add_toggle_control(option_controls, "EJECTION REVEAL", true)
	godfather_toggle.toggled.connect(func(value: bool) -> void: _set_option("godfather", value))
	boxer_toggle.toggled.connect(func(value: bool) -> void: _set_option("boxer", value))
	ejection_toggle.toggled.connect(func(value: bool) -> void: _set_option("ejection", value))
	for toggle in [godfather_toggle, boxer_toggle, ejection_toggle]: GameLook.compact_control(toggle)
	GameLook.equal_control_sizes([godfather_toggle, boxer_toggle])
	plan_label = screen.add_sidebar_text(option_controls, "")
	apply_button = _button(settings_dialog.actions, "APPLY", _apply_options, true)
	var close_button := _button(settings_dialog.actions, "CLOSE", func() -> void: settings_dialog.overlay.hide())
	GameLook.compact_control(apply_button)
	GameLook.compact_control(close_button)
	var scores_body := screen.add_details(social_layout.footer, "SCORES", "", false)
	scores_button = scores_body.get_meta("toggle_button")
	scores_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scores_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	GameLook.action(scores_button, false)
	GameLook.equal_control_sizes([settings_button, scores_button])
	var roster := screen.add_card(scores_body)
	for seat in 16:
		var row := screen.add_session_score(roster, true)
		roster_rows.append(row)
		row.content.hide()
	history_log = screen.add_history_log(screen.add_card(social_layout.history))
	history_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_log.get_parent().get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	phase_dialog = screen.add_phase_dialog(true)
	ejection_stage = preload("res://Games/mafia/host/ejection.gd").new()
	phase_dialog.body.add_child(ejection_stage)
	result_team = screen.add_team_reveal(phase_dialog.body)
	reveal_label = screen.add_formatted_text(phase_dialog.body, true)
	replay.reparent(phase_dialog.actions)
	_button(phase_dialog.actions, "SETTINGS", _open_settings)
	screen.resized.connect(_fit_presentation)


func _button(parent: Control, text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	GameLook.action(button, primary)
	button.pressed.connect(callback)
	return button


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	rules.options = load_game_settings({"godfather": false, "boxer": false, "ejection": true})
	if context.players.size() < 7:
		rules.options.godfather = false
		rules.options.boxer = false
	staged_options = rules.options.duplicate()
	if not rules.setup(context.players):
		event_label.text = "Mafia requires 4–16 human browser players."
		start_button.disabled = true
		replay.hide()
		return
	_render()


func start_game() -> void:
	active = rules.phase != "idle"
	_publish()


func shutdown_game() -> void:
	active = false
	phase_dialog.overlay.hide()
	settings_dialog.overlay.hide()
	screen.background_media.set_active(false)
	sky.stop()


func _seat_for(id: String) -> int:
	for seat in rules.players.size():
		if str(rules.players[seat].get("id", "")) == id:
			return seat
	return -1


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_disconnected(id: String) -> void:
	if rules.set_disconnected(_seat_for(id)):
		_publish()


func player_reconnected(player: Dictionary) -> void:
	if _seat_for(str(player.get("id", ""))) < 0:
		return
	rules.reconnect(_seat_for(str(player.id)))
	_publish()


static func _integer(value: Variant, allow_pass := false) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < (-1 if allow_pass else 0) or float(value) > 2147483647:
		return -2
	return int(value)


func handle_controller_message(id: String, message: Dictionary) -> void:
	var seat := _seat_for(id)
	if not active or seat < 0 or rules.disconnected.has(seat):
		return
	var action: Variant = message.get("action")
	if not action is String:
		return
	if action == "sync":
		send_state(id, _snapshot(seat))
		return
	if _integer(message.get("revision")) != rules.revision or rules.paused():
		send_state(id, _snapshot(seat))
		return
	var changed := false
	match action:
		"night_action":
			changed = rules.night_action(seat, _integer(message.get("target"), true))
		"vote":
			changed = rules.vote(seat, _integer(message.get("target"), true))
		"begin_vote":
			changed = rules.begin_vote(seat)
		"suspect":
			changed = rules.suspect(seat, _integer(message.get("target"), true))
	if changed:
		_record_result()
		_publish()
	else:
		send_state(id, _snapshot(seat))


func _snapshot(seat: int) -> Dictionary:
	var state: Dictionary = rules.view_for(seat)
	state["reduced_motion"] = session.reduced_motion
	return state


func _publish() -> void:
	if session == null:
		return
	_render()
	broadcast_state(_snapshot(-1))
	for seat in rules.players.size():
		if not rules.disconnected.has(seat):
			send_state(str(rules.players[seat].id), _snapshot(seat))


func _record_result() -> void:
	if rules.phase != "finished" or recorded_round == rules.round_number:
		return
	recorded_round = rules.round_number
	for seat in rules.players.size():
		var profile := str(rules.players[seat].get("profile_id", rules.players[seat].id))
		var won: bool = rules.outcome.winners.has(seat)
		if won:
			award_points(profile, 1)
		report_result(profile, won)


func _set_option(key: String, value: bool) -> void:
	if active and rules.disconnected.is_empty() and staged_options.has(key) and (key == "ejection" or rules.players.size() >= 7):
		staged_options[key] = value
	_render_settings()


func _open_settings() -> void:
	_render_settings()
	settings_dialog.overlay.show()


func _apply_options() -> void:
	if active and rules.apply_options(staged_options):
		var preferences: Dictionary = rules.options.duplicate()
		if rules.players.size() < 7:
			preferences.erase("godfather")
			preferences.erase("boxer")
		save_game_settings(preferences)
		settings_dialog.overlay.hide()
		_publish()


func _process(delta: float) -> void:
	if not active or rules.phase != "ejection":
		return
	if rules.advance_ejection(delta):
		_record_result()
		_publish()
	else:
		ejection_stage.set_progress(float(rules.ejection.elapsed) / float(rules.ejection.duration))


func _replay() -> void:
	if active and rules.restart():
		_publish()


func _render() -> void:
	if rules.phase == "idle":
		return
	var state: Dictionary = rules.view_for()
	var finished: bool = rules.phase == "finished"
	var ejecting: bool = rules.phase == "ejection"
	phase_label.text = "GET READY" if rules.phase == "setup" else "%s %d" % ["NIGHT" if rules.phase == "night" else ("TOWN VOTE · DAY" if rules.phase == "vote" else "DAY"), rules.day]
	event_label.text = rules.event
	progress_label.text = "Paused: waiting for living players to reconnect." if state.paused else ("%d / %d voted" % [state.vote_count, state.alive_count] if rules.phase == "vote" else ("Choose privately on your phones." if rules.phase == "night" else ("%d players remain." % state.alive_count)))
	start_button.visible = rules.phase == "setup"
	start_button.disabled = state.paused
	_fit_presentation()
	if background_daytime != state.daytime:
		sky.set_daytime(state.daytime, background_daytime != null, session.reduced_motion)
		screen.background_media.transition_to("res://Games/mafia/art/town-day" if state.daytime else "res://Games/mafia/art/town-night", background_daytime != null)
		background_daytime = state.daytime
	_render_settings()
	screen.set_team_reveal(living_team, state.players, "", true, true, true)
	var suspect_lines := PackedStringArray()
	for suspicion in state.suspicions:
		suspect_lines.append(str(state.players[suspicion.target].display_name))
	suspicion_label.text = " · ".join(suspect_lines) if not suspect_lines.is_empty() else "No one is suspected."
	for seat in 16:
		var row: Dictionary = roster_rows[seat]
		row.content.visible = seat < rules.players.size()
		if not row.content.visible:
			continue
		var name_color := GameLook.RED if finished and rules.is_mafia(seat) else GameLook.readable_text_color(session.player_color(str(rules.players[seat].id)), screen.get_theme_color("panel", "GamePalette"), 5.0)
		screen.set_text_parts(row.player, [{"text": str(rules.players[seat].display_name), "color": name_color, "strikethrough": not rules.alive[seat]}, " · OFFLINE" if rules.disconnected.has(seat) else ""])
		row.score.text = "%d W" % rules.session_wins[seat]
	var log := PackedStringArray()
	for entry in rules.events:
		log.append(entry)
	for result in rules.history:
		log.append("Game %d: %s wins · day %d" % [result.round, "Mafia" if result.mafia_wins else "Town", result.day])
	screen.set_history_text(history_log, "\n\n".join(log) if not log.is_empty() else "No events yet.")
	phase_dialog.overlay.visible = finished or ejecting
	phase_dialog.heading.text = ("MAFIA WINS!" if rules.outcome.mafia_wins else "TOWN WINS!") if finished else ("VOTED OUT" if ejecting else "TOWN VOTE · DAY %d" % rules.day)
	screen.set_phase_dialog_tone(phase_dialog, ("danger" if rules.outcome.mafia_wins else "success") if finished else "")
	replay.visible = finished
	replay.disabled = state.paused
	result_team.visible = finished
	reveal_label.visible = finished
	ballot_scroll.visible = rules.phase == "vote"
	ballot_card.visible = rules.phase in ["setup", "vote"]
	ballot_heading.text = "GET READY" if rules.phase == "setup" else "Town voting"
	ballot_heading.visible = rules.phase != "setup"
	ejection_stage.visible = ejecting
	if ejecting:
		var player: Dictionary = state.players[rules.ejection.seat]
		ejection_stage.configure(player, session.reduced_motion, rules.ejection.get("mafia", false), rules.ejection.reveal)
		ejection_stage.set_progress(float(rules.ejection.elapsed) / float(rules.ejection.duration))
	elif finished:
		var team: Array = []
		var reveal: Array = ["ROLES REVEALED"]
		for seat in rules.players.size():
			var player: Dictionary = state.players[seat].duplicate()
			if rules.is_mafia(seat):
				player["name_color"] = GameLook.RED
			if rules.outcome.winners.has(seat):
				team.append(player)
			reveal.append("\n")
			reveal.append({"text": str(player.display_name), "strikethrough": not player.alive, "color": GameLook.RED if rules.is_mafia(seat) else GameLook.result_colors("danger" if rules.outcome.mafia_wins else "success").ink})
			reveal.append(" · %s%s" % [Rules.ROLE_NAMES[rules.roles[seat]], " +1 point" if rules.outcome.winners.has(seat) else ""])
		screen.set_team_reveal(result_team, team, "danger" if rules.outcome.mafia_wins else "success", false, true)
		screen.set_text_parts(reveal_label, reveal)
	else:
		screen.set_team_reveal(result_team, [])
		reveal_label.clear()
		var lines := PackedStringArray()
		for ballot in state.ballots:
			lines.append("%s → %s" % [state.players[ballot.voter].display_name, state.players[ballot.target].display_name if ballot.target >= 0 else "Skip"])
		ballot_label.text = "     ·     ".join(lines) if not lines.is_empty() else ("" if screen.available_size().y < 500 else "Waiting for ballots.")


func _fit_presentation() -> void:
	var short_view := screen.available_size().y < 500
	if suspicion_heading != null:
		suspicion_heading.add_theme_font_size_override("font_size", 16 if short_view else 18 if screen.available_size().x < 700 else 22)
	if ballot_heading != null:
		ballot_heading.add_theme_font_size_override("font_size", 18 if short_view else 24)
	phase_label.add_theme_font_size_override("font_size", (22 if rules.phase == "vote" else 28) if short_view else 36)
	if rules.phase == "vote":
		phase_label.text = "TOWN VOTE · DAY %d" % rules.day
		if short_view:
			phase_label.text += " · %d / %d VOTED" % [rules.votes.size(), rules.alive.count(true)]
		if rules.votes.is_empty():
			ballot_label.text = "" if short_view else "Waiting for ballots."
	event_label.visible = not (short_view and rules.phase == "setup")
	progress_label.visible = not short_view or rules.paused()
	ballot_scroll.custom_minimum_size.y = (0 if rules.votes.is_empty() else 24) if short_view else (56 if screen.available_size().x < 700 else 112)
	if history_log != null:
		history_log.custom_minimum_size.y = 84 if short_view else 196
	if living_team != null:
		screen.fit_assembly_reveal(living_team)
	for label in [phase_label, event_label, progress_label]:
		label.add_theme_color_override("font_outline_color", Color("211519"))
		label.add_theme_constant_override("outline_size", 3)
	GameLook.compact_control(start_button, short_view)


func _render_settings() -> void:
	for key in staged_options:
		var toggle: Button = {"godfather": godfather_toggle, "boxer": boxer_toggle, "ejection": ejection_toggle}[key]
		toggle.set_pressed_no_signal(staged_options[key])
		toggle.text = ("EJECTION REVEAL" if key == "ejection" else key.to_upper()) + (": ON" if staged_options[key] else ": OFF")
		toggle.disabled = not rules.disconnected.is_empty() or (key != "ejection" and rules.players.size() < 7)
		GameLook.toggle_state(toggle, staged_options[key])
	var plan := PackedStringArray()
	var current := Rules.role_plan(rules.players.size(), rules.options)
	for role in current:
		if current[role] > 0:
			plan.append("%d %s" % [current[role], Rules.ROLE_NAMES[role]])
	plan_label.text = "CURRENT ROLES\n" + " · ".join(plan)
	apply_button.disabled = staged_options == rules.options or not rules.disconnected.is_empty()
