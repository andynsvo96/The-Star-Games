extends BaseGame

const Rules = preload("res://Games/spyfall/host/rules.gd")
const Settings = preload("res://Games/spyfall/host/settings.gd")
var SOUND_STREAMS := {
	"timer_up": RuntimeAssets.audio("res://Games/spyfall/audio/timer_up.wav"),
	"vote": RuntimeAssets.audio("res://Games/spyfall/audio/vote.wav"),
	"spy_win": RuntimeAssets.audio("res://Games/spyfall/audio/spy_win.wav"),
	"non_spies_win": RuntimeAssets.audio("res://Games/spyfall/audio/non_spies_win.wav"),
}
var rules = Rules.new()
var settings = Settings.new()
var screen: GameScreen
var timer_label: Label
var round_label: Label
var clock_status: Label
var vote_timer_label: Label
var vote_clock_status: Label
var result_team: HFlowContainer
var reveal_label: RichTextLabel
var vote_label: Label
var replay: Button
var roster_rows: Array = []
var history_log: RichTextLabel
var timer_input: SpinBox
var vote_timer_input: SpinBox
var location_list: VBoxContainer
var location_input: LineEdit
var apply_button: Button
var save_locations_button: Button
var location_remove_buttons: Array[Button] = []
var locations_notice: Label
var settings_notice: Label
var staged_locations: Array = []
var recorded_round := -1
var last_tick := 0
var shown_second := -1
var rendered_revision := -1
var active := false
var dossier: Control
var voting_dialog: Dictionary
var voting_rows: Array = []
var points_label: RichTextLabel
var anonymous_toggle: Button
var countdown_sound: AudioStreamPlayer
var countdown_round := -1
var countdown_ticks: Array = []
var effect_sounds: Dictionary = {}
var sound_round := -1
var sound_cursor := 0
var social_layout: Dictionary
var roster_ribbon: HFlowContainer
var settings_toggle: Button
var locations_toggle: Button


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("Spyfall")
	screen.use_playful_style("res://Games/spyfall/art/spy-office", "dossier")
	screen.add_title_art(RuntimeAssets.texture("res://Games/spyfall/art/dossier-title.svg"), 90.0)
	screen.status.hide()
	screen.scores.hide()
	screen.exit_requested.connect(return_to_lobby)
	social_layout = screen.add_social_layout(0.56)
	var card := screen.add_card(social_layout.primary, "stacked")
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	dossier = card.get_parent()
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	round_label = screen.add_section_heading(card, "ROUND 1")
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label = screen.add_sidebar_text(card, "08:00")
	timer_label.theme_type_variation = "GameTimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 64)
	clock_status = screen.add_sidebar_text(card, "ROUND TIMER")
	clock_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var timer_rule := HSeparator.new()
	card.add_child(timer_rule)
	replay = _button(social_layout.footer, "PLAY AGAIN", _replay, true)
	replay.hide()
	_build_voting_dialog()
	countdown_sound = AudioStreamPlayer.new()
	countdown_sound.stream = RuntimeAssets.audio("res://Games/spyfall/audio/countdown.wav")
	countdown_sound.bus = "Effects"
	add_child(countdown_sound)
	for kind in SOUND_STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = SOUND_STREAMS[kind]
		player.bus = "Effects"
		add_child(player)
		effect_sounds[kind] = player
	screen.resized.connect(_fit_dossier)
	social_layout.primary.resized.connect(_fit_dossier)
	var settings_body := screen.add_details(social_layout.footer, "SETTINGS")
	settings_toggle = settings_body.get_meta("toggle_button")
	GameLook.action(settings_toggle, false)
	settings_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_build_settings(screen.add_card(settings_body))
	var locations_body := screen.add_details(social_layout.footer, "EDIT LOCATIONS")
	locations_toggle = locations_body.get_meta("toggle_button")
	GameLook.action(locations_toggle, false)
	locations_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_build_locations(screen.add_card(locations_body))
	var roster := screen.add_card(social_layout.body, "stacked")
	social_layout.body.move_child(roster.get_parent(), 1)
	screen.add_sidebar_text(roster, "PLAYERS")
	var ribbon := HFlowContainer.new()
	roster_ribbon = ribbon
	ribbon.alignment = FlowContainer.ALIGNMENT_CENTER
	ribbon.add_theme_constant_override("h_separation", 24)
	ribbon.add_theme_constant_override("v_separation", 10)
	roster.add_child(ribbon)
	for seat in 8:
		var entry := HBoxContainer.new()
		ribbon.add_child(entry)
		var accent := ColorRect.new()
		accent.custom_minimum_size = Vector2(12, 48)
		accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(accent)
		var row := screen.add_session_score(entry, false, true)
		row.content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row["entry"] = entry
		row["accent"] = accent
		var divider := VSeparator.new()
		entry.add_child(divider)
		row["divider"] = divider
		roster_rows.append(row)
		entry.hide()
	ribbon.resized.connect(_fit_dossier)
	var history_card := screen.add_card(social_layout.history, "clipboard")
	var history_panel: Control = history_card.get_meta("outer_panel")
	history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_log = screen.add_history_log(history_card)
	history_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fit_dossier.call_deferred()


func _fit_dossier() -> void:
	var bounds := screen.available_size()
	var short_view := bounds.y < 500
	var font_size := int(clampf(minf(bounds.y * 0.14 if short_view else bounds.y * 0.24, maxf(0, social_layout.primary.size.x - 60) / 3.4), 36, 192))
	timer_label.add_theme_font_size_override("font_size", font_size)
	round_label.add_theme_font_size_override("font_size", 16 if short_view else 20)
	clock_status.add_theme_font_size_override("font_size", 14 if short_view else 20)
	if history_log != null:
		history_log.custom_minimum_size.y = 64 if short_view else 140 if bounds.x < 700 else 176
	dossier.custom_minimum_size.y = 156 if short_view else 216 if bounds.x < 700 else maxf(292, font_size * 1.12 + 108)
	if settings_toggle != null and locations_toggle != null:
		for toggle in [settings_toggle, locations_toggle]:
			toggle.custom_minimum_size = Vector2(150 if bounds.x < 700 or short_view else 230, 44)
		GameLook.equal_control_sizes([settings_toggle, locations_toggle])
	if roster_ribbon != null:
		var columns := 2 if bounds.x < 700 else 4
		var entry_width := maxf(100, floorf((minf(1200, bounds.x - 48) - 36 - (columns - 1) * 24) / columns))
		for seat in roster_rows.size():
			var row: Dictionary = roster_rows[seat]
			row.entry.custom_minimum_size.x = entry_width
			row.player.add_theme_font_size_override("font_size", 13 if short_view else 18)
			row.score.add_theme_font_size_override("font_size", 12 if short_view else 16)
			row.accent.custom_minimum_size = Vector2(8 if short_view else 12, 28 if short_view else 48)
			row.divider.visible = (seat + 1) % columns != 0 and seat < rules.players.size() - 1


func _button(parent: Control, text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	GameLook.action(button, primary)
	button.pressed.connect(callback)
	return button


func _build_settings(body: VBoxContainer) -> void:
	timer_input = screen.add_number_control(body, "ROUND TIMER", Settings.MIN_MINUTES, Settings.MAX_MINUTES, 0.1, 8.0, "min")
	timer_input.value_changed.connect(func(_value: float) -> void: _settings_changed())
	vote_timer_input = screen.add_number_control(body, "VOTING TIMER", Settings.MIN_MINUTES, Settings.MAX_MINUTES, 0.1, 1.0, "min")
	vote_timer_input.value_changed.connect(func(_value: float) -> void: _settings_changed())
	anonymous_toggle = screen.add_toggle_control(body, "ANONYMOUS VOTING", false)
	GameLook.action(anonymous_toggle)
	GameLook.compact_control(anonymous_toggle)
	GameLook.toggle_state(anonymous_toggle, false)
	anonymous_toggle.toggled.connect(func(enabled: bool) -> void:
		GameLook.toggle_state(anonymous_toggle, enabled)
		_settings_changed())
	settings_notice = screen.add_sidebar_text(body, "")
	apply_button = _button(body, "APPLY", _apply_settings, true)


func _build_locations(body: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	location_list = VBoxContainer.new()
	location_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(location_list)
	location_input = LineEdit.new()
	location_input.placeholder_text = "New location"
	location_input.max_length = Settings.MAX_NAME
	body.add_child(location_input)
	location_input.text_submitted.connect(func(_value: String) -> void: _add_location())
	_button(body, "ADD", _add_location)
	locations_notice = screen.add_sidebar_text(body, "")
	save_locations_button = _button(body, "SAVE", _save_locations, true)


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	settings.load_data()
	staged_locations = settings.locations.duplicate()
	timer_input.set_value_no_signal(settings.minutes)
	vote_timer_input.set_value_no_signal(settings.vote_minutes)
	anonymous_toggle.set_pressed_no_signal(settings.anonymous_voting)
	anonymous_toggle.text = "ANONYMOUS VOTING: " + ("ON" if settings.anonymous_voting else "OFF")
	GameLook.toggle_state(anonymous_toggle, settings.anonymous_voting)
	rules.anonymous_voting = settings.anonymous_voting
	_refresh_locations()
	settings_notice.text = settings.last_error
	_settings_changed()
	if not rules.setup(context.players, settings.locations, settings.minutes * 60.0, settings.vote_minutes * 60.0):
		screen.status.text = "Spyfall requires 4–8 connected human players."
		return
	for seat in rules.players.size():
		if not bool(rules.players[seat].get("connected", true)):
			rules.set_disconnected(seat)
	_render()


func start_game() -> void:
	active = rules.phase != "idle"
	last_tick = Time.get_ticks_msec()
	_publish()


func shutdown_game() -> void:
	active = false
	countdown_sound.stop()
	_stop_effect_sounds()
	for player in effect_sounds.values():
		player.stream = null
	GameMotion.reset(timer_label)
	voting_dialog.overlay.hide()
	GameMotion.reset(vote_timer_label)
	screen.background_media.set_active(false)


func _process(_delta: float) -> void:
	if not active:
		return
	var changed := _advance_clock()
	var second := int(ceil(rules.remaining if rules.phase == "playing" else rules.vote_remaining))
	if changed or shown_second != second:
		shown_second = second
		_publish()


func _advance_clock() -> bool:
	var now := Time.get_ticks_msec()
	var elapsed := float(now - last_tick) / 1000.0 if last_tick > 0 else 0.0
	last_tick = now
	var changed: bool = rules.tick(elapsed)
	if changed:
		_record_result()
	return changed


func _seat_for(id: String) -> int:
	for seat in rules.players.size():
		if str(rules.players[seat].get("id", "")) == id:
			return seat
	return -1


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_disconnected(id: String) -> void:
	_advance_clock()
	if rules.set_disconnected(_seat_for(id)):
		_publish()


func player_reconnected(player: Dictionary) -> void:
	_advance_clock()
	var seat := _seat_for(str(player.get("id", "")))
	if seat < 0:
		return
	rules.reconnect(seat)
	_publish()


static func _integer(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < 0 or float(value) > 2147483647:
		return -1
	return int(value)


func handle_controller_message(id: String, message: Dictionary) -> void:
	var seat := _seat_for(id)
	if seat < 0 or not active:
		return
	if _advance_clock():
		_publish()
	var action: Variant = message.get("action")
	if not action is String:
		return
	if action == "sync":
		send_state(id, _snapshot(seat))
		return
	if _integer(message.get("revision")) != rules.revision or not rules.missing.is_empty():
		send_state(id, _snapshot(seat))
		return
	var changed := false
	match action:
		"accuse":
			changed = rules.accuse(seat, _integer(message.get("target")))
		"vote":
			if message.get("agree") is bool:
				changed = rules.vote(seat, message.agree)
		"final_vote":
			changed = rules.final_vote(seat, _integer(message.get("target")))
		"guess":
			if message.get("location") is String:
				changed = rules.guess(seat, message.location)
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
	_render()
	broadcast_state(_snapshot(-1))
	for seat in rules.players.size():
		if not rules.missing.has(seat):
			send_state(str(rules.players[seat].id), _snapshot(seat))


func _record_result() -> void:
	if rules.phase != "finished" or recorded_round == rules.round_number:
		return
	recorded_round = rules.round_number
	for seat in rules.players.size():
		var profile := str(rules.players[seat].get("profile_id", rules.players[seat].id))
		var points := int(rules.outcome.points[seat])
		if points > 0:
			award_points(profile, points)
		report_result(profile, rules.outcome.winners.has(seat))


func _render() -> void:
	if rules.phase == "idle":
		return
	var state: Dictionary = rules.view_for()
	_present_sounds(state)
	_update_countdown()
	dossier.visible = rules.phase == "playing"
	round_label.text = "ROUND %d" % rules.round_number
	replay.visible = rules.phase == "finished"
	replay.disabled = not rules.missing.is_empty()
	if rules.revision == rendered_revision:
		return
	rendered_revision = rules.revision
	_render_voting_dialog(state)
	for seat in rules.players.size():
		var row: Dictionary = roster_rows[seat]
		row.entry.show()
		row.player.text = str(rules.players[seat].display_name) + (" · OFFLINE" if rules.missing.has(seat) else "")
		row.player.add_theme_color_override("font_color", GameLook.RED if rules.phase == "finished" and seat == rules.spy else screen.get_theme_color("ink", "GamePalette"))
		row.accent.color = session.player_color(str(rules.players[seat].id))
		row.score.text = "%d PTS · %d W" % [rules.session_points[seat], rules.session_wins[seat]]
	var entries: Array = []
	for result in rules.history:
		entries.append({"heading": "Round %d: %s" % [result.round, "Spy wins" if result.spy_wins else "Non-spies win"], "detail": "Spy: %s · %s" % [rules.players[result.spy].display_name, result.location]})
	if entries.is_empty():
		screen.set_history_text(history_log, "No completed rounds yet.")
	else:
		screen.set_history_entries(history_log, entries)


func _build_voting_dialog() -> void:
	voting_dialog = screen.add_phase_dialog(true)
	vote_clock_status = screen.add_sidebar_text(voting_dialog.body, "VOTING TIMER")
	vote_clock_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vote_timer_label = screen.add_sidebar_text(voting_dialog.body, "")
	vote_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vote_timer_label.add_theme_font_size_override("font_size", 36)
	vote_label = screen.add_sidebar_text(voting_dialog.body, "")
	vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_team = screen.add_team_reveal(voting_dialog.body)
	result_team.hide()
	reveal_label = screen.add_formatted_text(voting_dialog.body, true)
	points_label = screen.add_formatted_text(voting_dialog.body, true)
	for seat in 8:
		var body := screen.add_card(voting_dialog.body)
		var name := screen.add_formatted_text(body)
		var voters := screen.add_formatted_text(body)
		voters.add_theme_font_size_override("normal_font_size", 16)
		voting_rows.append({"body": body.get_parent(), "name": name, "voters": voters})
		body.get_parent().hide()
	replay.reparent(voting_dialog.actions)


func _render_voting_dialog(state: Dictionary) -> void:
	var finished: bool = rules.phase == "finished"
	var voting: bool = rules.phase in ["vote", "final_vote"]
	voting_dialog.overlay.visible = voting or finished
	voting_dialog.heading.text = ("THE SPY WINS!" if rules.outcome.get("spy_wins", false) else "CIVILIANS WIN!") if finished else "WHO IS THE SPY?"
	screen.set_phase_dialog_tone(voting_dialog, ("danger" if rules.outcome.spy_wins else "success") if finished else "")
	vote_timer_label.visible = voting
	vote_clock_status.visible = voting
	result_team.visible = finished
	vote_label.visible = voting
	var total: int = rules.players.size() - (1 if rules.phase == "vote" else 0)
	vote_label.text = "%d / %d VOTED%s\n%s" % [rules.votes.size(), total, " · PAUSED" if not rules.missing.is_empty() else "", "Anonymous voting" if rules.anonymous_voting else "Live votes"]
	if rules.phase == "vote":
		vote_label.text += "\n%s accused %s" % [rules.players[rules.accuser].display_name, rules.players[rules.suspect].display_name]
	reveal_label.visible = finished
	points_label.visible = finished
	if finished:
		var team: Array = []
		for seat in rules.players.size():
			if (seat == rules.spy) == bool(rules.outcome.spy_wins):
				team.append(rules.players[seat])
		screen.set_team_reveal(result_team, team, "danger" if rules.outcome.spy_wins else "success")
		var reasons := {"caught": "The spy was caught.", "innocent": "An innocent player was convicted.", "escaped": "The final vote did not reach agreement.", "guessed": "The spy guessed correctly.", "wrong_guess": "The spy guessed incorrectly."}
		screen.set_text_parts(reveal_label, ["Spy: ", _player_name_part(rules.spy, true), "\nLocation: %s\n%s" % [rules.location, reasons.get(rules.outcome.reason, "")]])
		var earned: Array = ["POINTS AWARDED"]
		for seat in rules.players.size():
			if rules.outcome.points[seat] > 0:
				earned.append("\n")
				earned.append(_player_name_part(seat, true))
				earned.append(" +%d %s" % [rules.outcome.points[seat], "point" if rules.outcome.points[seat] == 1 else "points"])
		screen.set_text_parts(points_label, earned)
	else:
		screen.set_team_reveal(result_team, [])
		reveal_label.clear()
		points_label.clear()
	for seat in 8:
		var row: Dictionary = voting_rows[seat]
		row.body.visible = seat < rules.players.size() and voting
		if not row.body.visible:
			continue
		var ballot: Dictionary = state.voting[seat]
		screen.set_text_parts(row.name, [{"text": "● ", "color": session.player_color(str(rules.players[seat].id))}, _player_name_part(seat, finished), "  ·  %d %s" % [ballot.count, "vote" if ballot.count == 1 else "votes"]])
		var names: Array = ["Voted by: "]
		for voter in ballot.voters:
			if names.size() > 1:
				names.append(", ")
			names.append(_player_name_part(voter, finished))
		screen.set_text_parts(row.voters, ["Anonymous votes: %d" % ballot.count] if rules.anonymous_voting else names)
		row.voters.visible = ballot.count > 0


func _player_name_part(seat: int, finished: bool) -> Variant:
	var name := str(rules.players[seat].display_name)
	return {"text": name, "color": GameLook.RED} if finished and seat == rules.spy else name


func _stop_effect_sounds() -> void:
	for player in effect_sounds.values():
		player.stop()


func _present_sounds(state: Dictionary) -> void:
	if sound_round != rules.round_number:
		_stop_effect_sounds()
		sound_round = rules.round_number
		sound_cursor = state.sound_sequence
		return
	if state.paused:
		_stop_effect_sounds()
	else:
		for event in state.sound_events:
			if event.sequence > sound_cursor and effect_sounds.has(event.kind):
				effect_sounds[event.kind].play()
	sound_cursor = state.sound_sequence


func _update_countdown() -> void:
	if countdown_round != rules.round_number:
		countdown_sound.stop()
		GameMotion.reset(timer_label)
		GameMotion.reset(vote_timer_label)
		countdown_round = rules.round_number
		countdown_ticks.clear()
	var round_second := int(ceil(rules.remaining))
	var vote_second := int(ceil(rules.vote_remaining))
	var voting: bool = rules.phase in ["vote", "final_vote"]
	var label: Label = vote_timer_label if voting else timer_label
	var second := vote_second if voting else round_second
	var running: bool = rules.vote_clock_running() if voting else rules.clock_running()
	var urgent: bool = (not voting or rules.vote_timer_started) and second > 0 and second <= 10
	for clock in [timer_label, vote_timer_label]:
		var value := vote_second if clock == vote_timer_label else round_second
		clock.text = str(value) if clock == label and urgent else "%02d:%02d" % [value / 60, value % 60]
		clock.add_theme_color_override("font_color", GameLook.RED if clock == label and urgent else screen.get_theme_color("ink", "GamePalette"))
		if clock != label or session.reduced_motion:
			GameMotion.reset(clock)
	clock_status.text = "ROUND TIMER PAUSED" if not rules.missing.is_empty() else "ROUND TIMER"
	vote_clock_status.text = "VOTING TIMER · PAUSED" if not rules.missing.is_empty() else "VOTING DEADLINE" if rules.vote_timer_started else "VOTING · AWAITING FIRST VOTE"
	if voting:
		vote_clock_status.text += "\nROUND TIMER %s · %02d:%02d" % ["FINISHED" if rules.phase == "final_vote" else "PAUSED", round_second / 60, round_second % 60]
	var tick_key := ("vote:%d:" % rules.vote_number if voting else "round:") + str(second)
	if not running:
		countdown_sound.stop()
		GameMotion.reset(label)
	elif urgent and not countdown_ticks.has(tick_key):
		countdown_ticks.append(tick_key)
		GameMotion.countdown(label, session.reduced_motion)
		countdown_sound.play()
	elif not urgent:
		countdown_sound.stop()
		GameMotion.reset(label)


func _replay() -> void:
	_advance_clock()
	if rules.phase == "finished" and rules.missing.is_empty():
		rules.restart()
		_publish()


func _refresh_locations() -> void:
	for child in location_list.get_children():
		location_list.remove_child(child)
		child.queue_free()
	location_remove_buttons.clear()
	for index in staged_locations.size():
		var row := HBoxContainer.new()
		location_list.add_child(row)
		var label := screen.add_sidebar_text(row, str(staged_locations[index]))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove := _button(row, "×", _remove_location.bind(index))
		GameLook.compact_control(remove)
		remove.custom_minimum_size = Vector2(44, 44)
		location_remove_buttons.append(remove)
	_settings_changed()


func _add_location() -> void:
	var name := " ".join(location_input.text.strip_edges().split(" ", false))
	var updated := staged_locations.duplicate()
	updated.append(name)
	if Settings.validate_names(updated).is_empty():
		locations_notice.text = "Use a unique, nonempty location (up to 60 characters). Maximum: 200."
		return
	staged_locations = updated
	location_input.clear()
	_refresh_locations()
	locations_notice.text = ""
	_settings_changed()


func _remove_location(index: int) -> void:
	if index < 0 or index >= staged_locations.size() or staged_locations.size() <= 2:
		return
	staged_locations.remove_at(index)
	locations_notice.text = ""
	_refresh_locations()
	_settings_changed()


func _settings_changed() -> void:
	if apply_button == null:
		return
	for button in location_remove_buttons:
		button.disabled = staged_locations.size() <= 2
	save_locations_button.disabled = staged_locations == settings.locations
	GameLook.action(save_locations_button, not save_locations_button.disabled)
	apply_button.disabled = is_equal_approx(timer_input.value, settings.minutes) and is_equal_approx(vote_timer_input.value, settings.vote_minutes) and anonymous_toggle.button_pressed == settings.anonymous_voting
	GameLook.action(apply_button, not apply_button.disabled)


func _apply_settings() -> void:
	if apply_button.disabled:
		return
	if not settings.save_data(settings.locations, timer_input.value, anonymous_toggle.button_pressed, vote_timer_input.value):
		settings_notice.text = settings.last_error
		return
	settings_notice.text = "Saved."
	_restart_saved_settings()


func _save_locations() -> void:
	if save_locations_button.disabled:
		return
	if not settings.save_data(staged_locations, settings.minutes):
		locations_notice.text = settings.last_error
		return
	locations_notice.text = "Saved."
	_restart_saved_settings()


func _restart_saved_settings() -> void:
	rules.locations = settings.locations.duplicate()
	rules.duration = settings.minutes * 60.0
	rules.vote_duration = settings.vote_minutes * 60.0
	rules.anonymous_voting = settings.anonymous_voting
	rules.restart()
	last_tick = Time.get_ticks_msec()
	_settings_changed()
	_publish()
