extends RefCounted

const Table = preload("res://Games/poker/host/table.gd")
const Evaluator = preload("res://Games/poker/host/evaluator.gd")
var game
var screen := GameScreen.new()
var table := Table.new()
var toolbar := VBoxContainer.new()
var solo_panel := Panel.new()
var private_hand := Control.new()
var public_row := GameActionRow.new()
var local_row := VBoxContainer.new()
var raise_row := VBoxContainer.new()
var raise_panel := PanelContainer.new()
var replay := Button.new()
var info := Label.new()
var phase_track := GamePhaseTrack.new()
var summary := VBoxContainer.new()
var summary_panel := PanelContainer.new()
var stakes_info := Label.new()
var blind_info := Label.new()
var clock_info := Label.new()
var category := Label.new()
var fold := Button.new()
var call_button := Button.new()
var raise_amount := SpinBox.new()
var raise_slider := HSlider.new()
var bet_button := Button.new()
var settings_button := Button.new()
var results_button := Button.new()
var settings_dialog: Dictionary
var resume_dialog: Dictionary
var confirm_dialog: Dictionary
var help_dialog: Dictionary
var history_dialog: Dictionary
var public_cards_dialog: Dictionary
var settings_open := false
var confirm_open := false
var controls: Dictionary = {}
var settings_form := GridContainer.new()
var draft: Dictionary = {}
var apply := Button.new()
var resume_button: Button
var view: Dictionary = {}
var last_turn := -1
var amount_run := ""
var bet_cue_context := ""
var bet_was_all_in := false
var bet_cue_pending := false
var latest_revision := -1
var history: Label
var celebration := GameCelebration.new()
var celebration_run := ""
var review_automatic := false
var review_key := ""
var review_content_key := ""
var review_countdown := Label.new()
var review_close: Button
var settings_grids: Array[GridContainer] = []
var settings_notice: Label
var ranked_results := GameRankedResults.new()
var review_buttons := GameActionRow.new()


func _init(owner_game) -> void:
	game = owner_game; game.add_child(screen); screen.configure("POKER")
	screen.use_playful_style("res://Games/poker/art/lounge", "casino"); game.theme = screen.theme; screen.use_table_header(null, false, true); screen.scores.hide()
	screen.exit_requested.connect(game.return_to_lobby)
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; screen.content.add_child(table)
	table.add_child(celebration); celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_track.steps = ["Pre-Flop", "Flop", "Turn", "River", "Showdown"]; phase_track.compact = true
	screen.set_table_header_content(phase_track)
	summary.add_theme_constant_override("separation", 2)
	for label in [stakes_info, blind_info, clock_info, info]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", 13); summary.add_child(label)
	info.hide(); summary_panel.add_theme_stylebox_override("panel", GameLook.casino_sheet(false, true)); summary_panel.add_child(summary)
	settings_button.accessibility_name = "Table settings"; _icon(settings_button, "control-settings"); settings_button.pressed.connect(open_settings); screen.set_table_header_action(settings_button)
	replay.text = "PLAY AGAIN"; replay.custom_minimum_size.y = 44; replay.hide(); replay.pressed.connect(func() -> void: game.new_tournament(true))
	game.add_child(toolbar); toolbar.add_child(public_row); public_row.fit_icons = true
	solo_panel.add_theme_stylebox_override("panel", GameLook.casino_frame()); solo_panel.accessibility_name = "Solo poker controls and table information"; toolbar.add_child(solo_panel)
	private_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE; solo_panel.add_child(private_hand); private_hand.draw.connect(func() -> void: table.draw_private_hand(private_hand))
	results_button.text = "RESULTS"; results_button.hide(); public_row.add_child(results_button); results_button.pressed.connect(show_results); _icon(results_button, "table-cards")
	public_row.add_child(replay)
	solo_panel.add_child(local_row); local_row.add_theme_constant_override("separation", 6)
	for item in [[fold, "× FOLD", "fold"], [call_button, "✓ CHECK", "call"]]:
		item[0].text = item[1]; item[0].custom_minimum_size.y = 44; local_row.add_child(item[0]); GameLook.casino_action(item[0], item[2])
	fold.pressed.connect(func() -> void: _send("fold")); call_button.pressed.connect(func() -> void: _send("check" if view.get("legal", {}).get("check", false) else "call"))
	raise_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); solo_panel.add_child(raise_panel); raise_panel.add_child(raise_row); raise_row.add_theme_constant_override("separation", 4)
	raise_amount.step = 1; raise_amount.rounded = true; raise_amount.custom_minimum_size.y = 44; raise_amount.get_line_edit().accessibility_name = "Total bet for this betting round"; raise_row.add_child(raise_amount)
	raise_slider.step = 1; raise_slider.rounded = true; raise_slider.custom_minimum_size.y = 44; raise_slider.accessibility_name = "Raise total"; raise_row.add_child(raise_slider)
	raise_amount.value_changed.connect(_set_amount); raise_slider.value_changed.connect(_set_amount)
	raise_amount.get_line_edit().text_changed.connect(func(text: String) -> void:
		if view.get("type") != "state" or not text.is_valid_int(): return
		raise_slider.set_value_no_signal(int(text)); _update_bet_label(int(text)))
	bet_button.text = "BET"; bet_button.custom_minimum_size.y = 44; GameLook.casino_action(bet_button, "raise"); raise_row.add_child(bet_button); bet_button.pressed.connect(_commit_bet)
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; category.add_theme_font_size_override("font_size", 13); table.add_child(category)
	table.resized.connect(_fit_controls); screen.resized.connect(_fit); screen.board_space_changed.connect(_fit)
	toolbar.item_rect_changed.connect(_fit_controls); screen.content.item_rect_changed.connect(_fit_controls)
	settings_dialog = screen.add_phase_dialog(true); settings_dialog.heading.text = "♠  TABLE SETTINGS"
	settings_dialog.shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: close_settings())
	_build_settings()
	var settings_actions := GameActionRow.new(); settings_dialog.actions.add_child(settings_actions)
	_button(settings_actions, "CLOSE", close_settings)
	apply.text = "APPLY & NEW TOURNAMENT"; apply.custom_minimum_size.y = 44; settings_actions.add_child(apply); apply.pressed.connect(func() -> void: game.apply_settings(draft))
	resume_dialog = screen.add_phase_dialog(true); resume_dialog.heading.text = "UNFINISHED TOURNAMENT"
	resume_button = _button(resume_dialog.actions, "RESUME", game.resume_game); _button(resume_dialog.actions, "NEW TOURNAMENT", func() -> void: game.new_tournament())
	confirm_dialog = screen.add_phase_dialog(true)
	help_dialog = screen.add_phase_dialog(true); help_dialog.heading.text = "POKER HAND RANKINGS"
	_label(help_dialog.body, "Royal Flush · Straight Flush · Four of a Kind · Full House · Flush · Straight · Three of a Kind · Two Pair · One Pair · High Card")
	_label(help_dialog.body, "Texas: make the best five-card hand using any combination of your two cards and the board. Omaha: use exactly two of your four cards and exactly three board cards. Aces can be low in A–2–3–4–5. Suits never break ties. Raise to is your total bet for the current street.")
	_button(help_dialog.actions, "Close", func() -> void: help_dialog.overlay.hide())
	history_dialog = screen.add_phase_dialog(false, true); history_dialog.heading.text = "PUBLIC HAND HISTORY"; history = _label(history_dialog.body, ""); _button(history_dialog.actions, "Close", func() -> void: history_dialog.overlay.hide())
	public_cards_dialog = screen.add_phase_dialog(true, true, false, false, 1100)
	ranked_results.amount_icon = RuntimeAssets.texture("res://Games/poker/art/chip.svg"); public_cards_dialog.body.add_child(ranked_results)
	review_countdown.hide(); public_cards_dialog.actions.add_child(review_countdown)
	public_cards_dialog.actions.add_child(review_buttons)
	review_close = _button(review_buttons, "CONTINUE", func() -> void:
		if review_automatic: game.continue_review()
		else: public_cards_dialog.overlay.hide())
	public_cards_dialog.overlay.visibility_changed.connect(func() -> void:
		if not public_cards_dialog.overlay.visible and replay.get_parent() != public_row: replay.reparent(public_row)
		if game.session != null: game._publish())
	_fit.call_deferred()


func configure_mode() -> void:
	if game.host_plays:
		solo_panel.add_child(summary_panel); summary_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); summary.alignment = BoxContainer.ALIGNMENT_END
		public_row.reparent(solo_panel); table.private_canvas = private_hand
	else: screen.set_table_header_summary(summary_panel)
	screen.center_board(table, replay, toolbar, .5, true, false, true, true, game.host_plays)
	screen.title_label.text = "OMAHA HOLD’EM" if game.variant == "omaha" else "TEXAS HOLD’EM"
	screen.background_media.reduced_motion = game.session.reduced_motion
	screen.background_media.transition_to("res://Games/%s/art/lounge" % game.session.game_id, false)
	_fit()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 44; parent.add_child(button); button.pressed.connect(callback); return button


func _label(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label


func _icon(button: Button, name: String) -> void:
	button.icon = RuntimeAssets.texture("res://ui/playful/%s.svg" % name); button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22); button.add_theme_constant_override("h_separation", 8)


func _settings_section(caption: String) -> VBoxContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameLook.casino_sheet()); settings_form.add_child(panel)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); panel.add_child(column)
	var heading := _label(column, caption); heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", screen.get_theme_color("gold", "GamePalette"))
	return column


func _build_settings() -> void:
	settings_form.columns = 2; settings_form.add_theme_constant_override("h_separation", 12); settings_form.add_theme_constant_override("v_separation", 12); settings_dialog.body.add_child(settings_form)
	var stakes := _settings_section("♣  STAKES & BLINDS")
	var opponents := _settings_section("♠  TABLE & PACE")
	var stakes_grid := GridContainer.new(); stakes_grid.columns = 2; stakes.add_child(stakes_grid); settings_grids.append(stakes_grid)
	var table_grid := GridContainer.new(); table_grid.columns = 2; opponents.add_child(table_grid); settings_grids.append(table_grid)
	for grid in settings_grids: grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 10)
	for spec in [["starting_chips", "Starting chips", 20, 1000000], ["ante", "Ante · 0 = off", 0, 999999], ["small_blind", "Small blind", 1, 500000], ["big_blind", "Big blind", 2, 1000000], ["blind_interval", "Double every (hands)", 0, 100], ["ai", "Computers", 0, 9], ["turn_seconds", "Action time (sec)", 5, 600]]:
		var key: String = spec[0]; var control := screen.add_number_control(table_grid if key in ["ai", "turn_seconds"] else stakes_grid, spec[1], spec[2], spec[3], 1, spec[2]); controls[key] = control
		control.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL; control.get_parent().get_child(0).add_theme_font_size_override("font_size", 14)
		control.custom_minimum_size.y = 44; control.add_theme_font_size_override("font_size", 18); control.get_line_edit().accessibility_name = str(spec[1])
		control.value_changed.connect(func(value: float) -> void:
			if draft.is_empty(): return
			draft[("solo_ai" if game.host_plays else "party_ai") if key == "ai" else key] = int(value)
			if key == "starting_chips":
				draft.small_blind = maxi(1, int(value / 200)); draft.big_blind = int(draft.small_blind) * 2
				for blind in ["small_blind", "big_blind"]: controls[blind].set_value_no_signal(draft[blind])
			_validate_draft())
	var fixed := _label(stakes_grid, "0 = fixed blinds\nNo rebuys"); fixed.add_theme_font_size_override("font_size", 13); fixed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var blind_note := _label(stakes, "Blinds update with starting chips. Both remain editable."); blind_note.add_theme_font_size_override("font_size", 13)
	var difficulty := screen.add_choice_control(opponents, "Computer difficulty", ["Easy", "Medium", "Hard"], true); controls.difficulty = difficulty
	difficulty.custom_minimum_size.y = 44; difficulty.get_parent().get_child(0).add_theme_font_size_override("font_size", 14)
	difficulty.item_selected.connect(func(index: int) -> void: draft.difficulty = index; _validate_draft())
	var timer := screen.add_toggle_control(opponents, "◷  ACTION TIMER", true); controls.turn_timer = timer; timer.custom_minimum_size.y = 44
	timer.toggled.connect(func(enabled: bool) -> void: draft.turn_timer = enabled; _validate_draft())
	settings_notice = _label(settings_dialog.body, ""); settings_notice.add_theme_font_size_override("font_size", 13)
	var note := _label(settings_dialog.body, "Apply ends the current tournament without a result and starts a fresh one. Computer tables keep session results only."); note.add_theme_font_size_override("font_size", 13)


func restore_settings() -> void:
	draft = game.options.duplicate(true)
	for key in controls:
		if key == "ai":
			var humans: int = maxi(1, game.session.players.size()); controls.ai.min_value = 1 if humans == 1 else 0; controls.ai.max_value = 10 - humans
			controls.ai.set_value_no_signal(clampi(int(draft.solo_ai if game.host_plays else draft.party_ai), int(controls.ai.min_value), int(controls.ai.max_value)))
		elif key == "difficulty": controls[key].select(int(draft[key]))
		elif key == "turn_timer": controls[key].set_pressed_no_signal(bool(draft[key])); controls[key].text = "◷  ACTION TIMER: " + ("ON" if draft[key] else "OFF")
		else: controls[key].set_value_no_signal(draft[key])
	_validate_draft()


func _validate_draft() -> void:
	apply.disabled = draft == game.options or not game.Rules.valid_options(draft) or not game.missing.is_empty()
	controls.turn_seconds.editable = bool(draft.get("turn_timer", true))
	GameLook.toggle_state(controls.turn_timer, bool(draft.get("turn_timer", true)))
	settings_notice.text = "Big blind must be at least twice the small blind and fit the starting stack. Ante must be less than the starting stack." if not game.Rules.valid_options(draft) else ""
	settings_notice.visible = not settings_notice.text.is_empty()


func open_settings() -> void:
	restore_settings(); settings_open = true; settings_dialog.overlay.show(); game._publish()


func close_settings() -> void:
	settings_open = false; settings_dialog.overlay.hide(); help_dialog.overlay.hide(); history_dialog.overlay.hide(); game._publish()


func show_resume(problem: String) -> void:
	for child in resume_dialog.body.get_children(): child.queue_free()
	_label(resume_dialog.body, "A saved tournament is ready to continue." if problem.is_empty() else problem); resume_button.disabled = not problem.is_empty(); resume_dialog.overlay.show()


func _fit() -> void:
	settings_form.columns = 1 if screen.available_size().x < 680 else 2
	for grid in settings_grids: grid.columns = 1 if screen.available_size().x < 400 else 2
	for label in [stakes_info, blind_info, clock_info, info]: label.add_theme_font_size_override("font_size", 11 if screen.available_size().x < (848 if game.host_plays else 550) else 13)
	var narrow := screen.available_size().x < 760
	solo_panel.visible = game.host_plays
	solo_panel.custom_minimum_size.y = 350 if screen.available_size().x < 548 else 234 if screen.available_size().x < 848 else 152 if screen.available_size().y < 600 else 168
	var ratio := (1.15 if screen.available_size().x < 550 else 1.4) if game.host_plays and narrow else 2.35 if game.host_plays else 1.35 if narrow else 2.2
	var width := minf(screen.board_width_limit() * (1.0 if narrow else .86), screen.board_height_limit() * ratio)
	table.custom_minimum_size = Vector2(maxf(220, width), maxf(140, width / ratio))
	raise_panel.visible = game.host_plays; category.hide()
	toolbar.custom_minimum_size.y = 44
	_fit_controls(); _fit_review()


func _fit_controls() -> void:
	table.queue_redraw()
	if not game.host_plays: return
	table.dock_rect = Rect2(solo_panel.global_position - table.global_position, solo_panel.size)
	var layout: Dictionary = table.private_layout()
	var origin := table.dock_rect.position
	local_row.position = layout.left.position - origin; local_row.size = layout.left.size
	raise_panel.position = layout.right.position - origin; raise_panel.size = layout.right.size
	private_hand.position = layout.hand.position - origin; private_hand.size = layout.hand.size; private_hand.queue_redraw()
	summary_panel.position = layout.stats.position - origin; summary_panel.size = layout.stats.size
	var completed: bool = view.get("phase") in ["hand_over", "finished"]
	local_row.visible = not completed; public_row.visible = completed
	public_row.position = local_row.position; public_row.size = local_row.size


func _fit_review() -> void:
	if public_cards_dialog.is_empty(): return
	ranked_results.maximum_height = maxf(140, screen.available_size().y - 262)
	ranked_results.queue_sort()


func _set_amount(value: float) -> void:
	raise_amount.set_value_no_signal(value); raise_slider.set_value_no_signal(value)
	raise_amount.get_line_edit().text = str(int(value))
	_update_bet_label(value)


func _update_bet_label(value: float) -> void:
	if view.get("type") != "state" or int(view.viewer) < 0: return
	var player: Dictionary = view.players[int(view.viewer)]
	var all_in := int(value) == int(player.stack) + int(player.street) and bool(view.legal.all_in)
	bet_button.text = "ALL IN" if all_in else "BET"
	var context := "%s:%d:%d" % [game.run_id, int(view.hand_number), int(view.turn_serial)]
	if context != bet_cue_context:
		bet_cue_context = context; bet_was_all_in = false; bet_cue_pending = false
	if all_in and not bet_was_all_in: bet_cue_pending = true
	elif not all_in: bet_cue_pending = false
	bet_was_all_in = all_in
	if bet_cue_pending and game.play_all_in_cue(): bet_cue_pending = false


func _commit_bet() -> void:
	if view.get("type") != "state" or not view.legal.can_raise: return
	var text := raise_amount.get_line_edit().text.strip_edges()
	if not text.is_valid_int(): return
	var amount := int(text)
	if amount < int(view.legal.min_raise_to) or amount > int(view.legal.max_raise_to): return
	_set_amount(amount); _send("raise", amount)


func render(value: Dictionary) -> void:
	var roster_changed: bool = view.get("players", []).size() != value.get("players", []).size()
	view = value
	if value.get("type") != "state": screen.status.text = value.get("pause_reason", "Preparing table"); return
	table.set_view(value)
	if roster_changed: _fit()
	_fit_controls()
	if value.phase == "finished" and celebration_run != game.run_id:
		celebration_run = game.run_id; celebration.show_win([], "CHAMPION", Color(value.identities[int(value.winner)].color), not value.reduced_motion)
	elif value.phase != "finished": celebration.clear()
	if celebration.age < 3: celebration.set_process(not value.paused and not value.reduced_motion)
	screen.status.text = value.pause_reason
	stakes_info.text = "HAND %02d · ANTE %s" % [int(value.hand_number), "OFF" if int(value.options.ante) == 0 else str(int(value.options.ante))]
	var interval := int(value.options.blind_interval)
	blind_info.text = "BLINDS %d / %d" % [int(value.small_blind), int(value.big_blind)]
	blind_info.text += (" · " if screen.available_size().x < (848 if game.host_plays else 550) else "\n") + "↑ DOUBLE IN %d HANDS" % (interval - (int(value.hand_number) - 1) % interval) if interval > 0 else " · FIXED"
	clock_info.visible = value.clock.enabled and value.phase == "betting" and not value.identities[int(value.turn)].ai
	clock_info.text = "◷ %ds" % ceili(float(value.clock.remaining))
	if clock_info.visible: stakes_info.text += " · " + clock_info.text; clock_info.hide()
	info.text = value.storage_error if not value.storage_error.is_empty() else value.pause_reason
	info.visible = not info.text.is_empty()
	phase_track.set_current(["preflop", "flop", "turn", "river", "showdown"].find(str(value.stage)))
	replay.visible = value.phase == "finished"; replay.disabled = value.phase_remaining > 0 or value.animating
	results_button.visible = value.phase in ["hand_over", "finished"]
	_update_review()
	category.text = value.hand_category if value.board.size() >= 3 else ""
	if int(value.viewer) >= 0:
		var legal: Dictionary = value.legal; var locked: bool = value.paused or value.animating or int(value.turn) != int(value.viewer) or value.phase != "betting"
		fold.disabled = locked; call_button.disabled = locked; bet_button.disabled = locked or not legal.can_raise
		call_button.text = "CHECK" if legal.check else "CALL %d" % maxi(0, int(legal.call))
		if int(value.turn_serial) != last_turn or amount_run != game.run_id:
			last_turn = int(value.turn_serial); amount_run = game.run_id
			for control in [raise_amount, raise_slider]:
				control.min_value = int(legal.min_raise_to); control.max_value = maxi(int(legal.min_raise_to), int(legal.max_raise_to)); control.set_value_no_signal(int(legal.min_raise_to))
			raise_amount.get_line_edit().text = str(int(legal.min_raise_to))
		var text := raise_amount.get_line_edit().text.strip_edges()
		_update_bet_label(int(text) if text.is_valid_int() else raise_amount.value)
		raise_amount.editable = not locked and legal.can_raise; raise_slider.editable = not locked and legal.can_raise
	if latest_revision != int(value.revision):
		latest_revision = int(value.revision); var lines: PackedStringArray = []
		for event in value.events:
			var name := str(value.identities[int(event.seat)].display_name) if int(event.seat) >= 0 else "Table"
			lines.append("Hand %d · %s · %s%s" % [event.hand, name, event.action, " %d" % event.amount if int(event.amount) > 0 else ""])
		history.text = "\n".join(lines)


func _send(action: String, amount := -1) -> void:
	if view.get("type") == "state": game._action(0, {"action": action, "amount": amount, "revision": int(view.revision)})


func show_public_hand(seat: int) -> void:
	if view.get("type") != "state" or not view.showdown or view.players[seat].hand.is_empty(): return
	show_results(seat)


func _update_review() -> void:
	if view.phase not in ["hand_over", "finished"]:
		if review_automatic: public_cards_dialog.overlay.hide()
		review_automatic = false; review_content_key = ""
		return
	var key := "%s:%d" % [game.run_id, int(view.hand_number)]
	if not view.animating and not view.paused and review_key != key:
		review_key = key; show_results(-1, true)
	var remaining := ceili(float(view.phase_remaining))
	review_close.text = ("CONTINUE · %d s" % remaining if remaining > 0 else "CONTINUE") if review_automatic else "BACK TO TABLE"
	if view.paused and remaining > 0 and review_automatic: review_close.text += " · PAUSED"
	review_close.disabled = bool(view.animating) or (review_automatic and bool(view.paused))
	review_buttons.show()
	if view.phase == "finished" and public_cards_dialog.overlay.visible and replay.get_parent() != review_buttons: replay.reparent(review_buttons)


func show_results(only_seat := -1, automatic := false) -> void:
	if view.get("type") != "state" or view.phase not in ["hand_over", "finished"]: return
	review_automatic = automatic
	var key := "%s:%d:%d" % [game.run_id, int(view.hand_number), only_seat]
	if review_content_key != key:
		review_content_key = key
		var winners: Array = [view.winner] if view.phase == "finished" else view.hand_winners
		var headlines: PackedStringArray = []
		for seat: int in winners:
			var result: Array = view.hand_results.filter(func(entry: Dictionary) -> bool: return int(entry.seat) == seat)
			var name := str(view.identities[seat].display_name)
			headlines.append(name + (" with " + str(result[0].category) if view.showdown and not result.is_empty() else " wins uncontested"))
		public_cards_dialog.heading.text = " & ".join(headlines)
		public_cards_dialog.heading.max_lines_visible = 2
		var entries: Array = []
		for result in view.hand_results:
			if int(result.rank) <= 0 or (only_seat >= 0 and int(result.seat) != only_seat): continue
			var identity: Dictionary = view.identities[int(result.seat)]
			var delta := int(result.get("net", result.amount))
			var marked: Array = range(result.cards.size()).filter(func(index: int) -> bool: return view.players[int(result.seat)].hand.has(result.cards[index]))
			entries.append({"seat": int(result.seat), "rank": int(result.rank), "name": str(identity.display_name), "color": identity.color, "category": str(result.category), "amount": delta, "amount_text": ("+" if delta > 0 else "") + str(delta), "cards": result.cards.map(func(card: Variant) -> Dictionary: return Evaluator.card_data(int(card))), "marked_cards": marked, "card_mark": "HOLE"})
		screen.set_phase_dialog_width(public_cards_dialog, 740 if entries.size() <= 4 else 1100)
		ranked_results.set_entries(entries)
	_fit_review(); public_cards_dialog.overlay.show(); _update_review()


func shutdown() -> void:
	celebration.clear(); screen.background_media.set_active(false); table.set_process(false); view.clear()
