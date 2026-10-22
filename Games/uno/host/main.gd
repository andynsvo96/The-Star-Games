extends BaseGame

const Rules = preload("res://Games/uno/host/rules.gd")
const Table = preload("res://Games/uno/host/table.gd")
const Presentation = preload("res://Games/uno/host/presentation.gd")
const WildPicker = preload("res://Games/uno/host/wild_picker.gd")
const RULE_OPTIONS := [["allow_stacking", "STACKING"], ["allow_seven_zero", "7-0 RULE"], ["allow_jump_ins", "JUMP-INS"], ["draw_until_play", "DRAW TIL PLAY"], ["force_play", "FORCE PLAY"], ["allow_mercy", "MERCY RULE"]]
var rules = Rules.new()
var screen: GameScreen
var table: Control
var seats: Array = []
var host_plays := false
var missing: Dictionary = {}
var offline: Dictionary = {}
var stopped := false
var animating := false
var dealing := false
var deal_revision := -1
var pending_gamemode := "classic"
var gamemode_choice: OptionButton
var difficulty := Rules.Difficulty.MEDIUM
var pending_difficulty := Rules.Difficulty.MEDIUM
var pending_options: Dictionary = {}
var apply_options: Button
var addons_button: Button
var pending_addons: Dictionary = Rules.AddOns.defaults()
var addon_choices: Dictionary = {}
var settings_body: VBoxContainer
var addons_body: VBoxContainer
var addon_dialog: Dictionary = {}
var addon_close: Button
var addon_action_row: HFlowContainer
var addon_view_key := ""
var color_choice_key := ""
var result_sent := false
var ai_timer: Timer
var catch_timer: Timer
var jump_timer: Timer
var motion_timer: Timer
var auto_timer: Timer
var controls: VBoxContainer
var actions: Dictionary = {}
var replay: Button
var difficulty_choice: OptionButton
var rule_choices: Dictionary = {}
var history_text: RichTextLabel
var active_rules: GameRulesPanel
var rules_dialog: Dictionary = {}
var table_footer: Control
var player_focus: GamePlayerFocus
var settings_open := false
var color_dialog: Control
var selected_card := -1
var selected_revision := -1
var selected_color := ""
var celebration: GameCelebration
var sounds: Dictionary = {}
var queued_sounds: Array[Timer] = []
var place_sounds: Array[AudioStream] = [RuntimeAssets.audio("res://Games/uno/audio/card-place-1.ogg"),RuntimeAssets.audio("res://Games/uno/audio/card-place-2.ogg")]


func _ready() -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.configure("UNO")
	screen.use_playful_style("res://Games/uno/art/sunset-lounge", "party-table")
	screen.title_label.hide()
	screen.scores.hide()
	screen.status.hide()
	screen.exit_requested.connect(return_to_lobby)
	table = Table.new()
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	screen.content.add_child(table)
	table.card_pressed.connect(_select_card)
	table.swap_pressed.connect(func(target: int) -> void: _local_action({"action":"swap", "target":target}))
	table.player_pressed.connect(_choose_player)
	table.viewer_pressed.connect(_open_badge_viewer)
	table.discard_pressed.connect(_open_discard_choice)
	table.uno_pressed.connect(func() -> void: _local_action({"action":"uno"}))
	table.draw_pressed.connect(func() -> void: _local_action({"action": "draw"}))
	table.keep_pressed.connect(func() -> void: _local_action({"action": "pass"}))
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.content.add_child(controls)
	for definition in [["draw", "DRAW"]]:
		var button := Button.new()
		button.text = definition[1]
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		GameLook.party_action(button)
		controls.add_child(button)
		actions[definition[0]] = button
		var action: String = definition[0]
		button.pressed.connect(func() -> void: _local_action({"action": action}))
	table.draw_button = actions.draw
	actions.draw.reparent(table)
	GameLook.illustrated_control(actions.draw, RuntimeAssets.texture("res://ui/playful/table-cards.svg"), false, true)
	GameLook.party_action(actions.draw)
	actions.draw.custom_minimum_size = Vector2(0, 44)
	actions.draw.add_theme_constant_override("icon_max_width", 22)
	table_footer = Control.new()
	table_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table_footer)
	table_footer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_focus = GamePlayerFocus.new()
	add_child(player_focus)
	player_focus.confirmed.connect(func() -> void:
		if table.state.get("player_choice", {}).get("multiple", false): _local_action({"action":"addon_choose", "value":"done", "revision":table.state.revision})
	)
	player_focus.action_pressed.connect(_context_action)
	table.draw.connect(_update_player_focus)
	active_rules = GameRulesPanel.new()
	table_footer.add_child(active_rules)
	active_rules.layout_changed.connect(_fit_table_footer)
	screen.resized.connect(_fit_table_footer)
	table_footer.resized.connect(_fit_table_footer)
	rules_dialog = screen.add_phase_dialog(true, false, true, true, 520)
	rules_dialog.heading.hide()
	var close_rules := Button.new()
	close_rules.text = "CLOSE"
	GameLook.party_action(close_rules)
	rules_dialog.actions.add_child(close_rules)
	close_rules.pressed.connect(func() -> void: rules_dialog.overlay.hide())
	var escape_rules := InputEventKey.new()
	escape_rules.keycode = KEY_ESCAPE
	close_rules.shortcut = Shortcut.new()
	close_rules.shortcut.events = [escape_rules]
	rules_dialog.overlay.visibility_changed.connect(func() -> void:
		if not rules_dialog.overlay.visible:
			active_rules.expanded = false
			_fit_table_footer.call_deferred()
			active_rules.heading.grab_focus.call_deferred()
	)
	replay = Button.new()
	replay.text = "PLAY AGAIN"
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	GameLook.party_action(replay)
	controls.add_child(replay)
	replay.pressed.connect(func() -> void:
		if not stopped and not settings_open and not animating and missing.is_empty() and rules.play_again():
			result_sent = false
			celebration.clear()
			_start_deal()
			_publish()
	)
	screen.center_board(table, replay, controls, .5, true, false, false, true)
	var panels := screen.add_corner_details(["SETTINGS"], Callable(), true, false, false, true, true, true)
	panels[0].get_meta("toggle_button").toggled.connect(_settings_toggled)
	settings_body = VBoxContainer.new()
	panels[0].add_child(settings_body)
	addons_body = VBoxContainer.new()
	panels[0].add_child(addons_body)
	addons_body.hide()
	screen.add_sidebar_text(addons_body, "ADD-ONS")
	var addons_grid := GridContainer.new()
	addons_grid.columns = 2
	addons_body.add_child(addons_grid)
	var addon_buttons: Array[Button] = []
	for pack in Rules.AddOns.PACKS:
		var key: String = pack[0]
		var toggle := screen.add_toggle_control(addons_grid, str(pack[1]).to_upper(), false)
		GameLook.compact_control(toggle)
		addon_choices[key] = toggle
		addon_buttons.append(toggle)
		toggle.toggled.connect(func(enabled: bool) -> void: _set_addon(key, enabled))
	var back := Button.new()
	back.text = "BACK TO SETTINGS"
	GameLook.action(back)
	GameLook.compact_control(back)
	addons_body.add_child(back)
	back.pressed.connect(func() -> void:
		addons_body.hide()
		settings_body.show()
		addons_button.grab_focus()
	)
	difficulty_choice = screen.add_choice_control(settings_body, "AI DIFFICULTY", ["Easy", "Medium", "Hard"], true)
	difficulty_choice.select(difficulty)
	difficulty_choice.item_selected.connect(_set_difficulty)
	gamemode_choice = screen.add_choice_control(settings_body, "GAMEMODE", ["Classic", "Flip", "No Mercy"], true)
	gamemode_choice.item_selected.connect(_set_gamemode)
	var option_grid := GridContainer.new()
	option_grid.columns = 2
	settings_body.add_child(option_grid)
	var option_buttons: Array[Button] = []
	for definition in RULE_OPTIONS:
		var option: String = definition[0]
		pending_options[option] = bool(rules.get(option))
		var toggle := screen.add_toggle_control(option_grid, definition[1], pending_options[option])
		GameLook.compact_control(toggle)
		rule_choices[option] = toggle
		option_buttons.append(toggle)
		toggle.toggled.connect(func(enabled: bool) -> void: _set_rule(option, enabled))
	apply_options = Button.new()
	apply_options.text = "APPLY"
	GameLook.action(apply_options, true)
	GameLook.compact_control(apply_options)
	var footer := HBoxContainer.new()
	settings_body.add_child(footer)
	addons_button = Button.new()
	addons_button.text = "ADD-ONS"
	GameLook.table_action(addons_button, "end")
	GameLook.compact_control(addons_button)
	option_grid.add_child(addons_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(apply_options)
	addons_button.pressed.connect(func() -> void:
		if pending_gamemode != "classic" or addons_button.disabled: return
		settings_body.hide()
		addons_body.show()
		addon_choices.reverse.grab_focus()
	)
	option_buttons.append(addons_button)
	option_buttons.append(apply_options)
	GameLook.equal_control_sizes(option_buttons + addon_buttons)
	apply_options.pressed.connect(_apply_options)
	history_text = screen.add_history_log(screen.add_details(settings_body, "HISTORY"))
	addon_dialog = screen.add_phase_dialog(true, false, true, true, 520)
	addon_dialog.heading.text = "YOUR CHOICE"
	var close_choice := Button.new()
	addon_close = close_choice
	close_choice.text = "CLOSE"
	GameLook.party_action(close_choice)
	addon_action_row = HFlowContainer.new()
	addon_action_row.alignment = FlowContainer.ALIGNMENT_CENTER
	addon_dialog.actions.add_child(addon_action_row)
	addon_action_row.add_child(close_choice)
	close_choice.pressed.connect(func() -> void: addon_dialog.overlay.hide())
	var escape_choice := InputEventKey.new()
	escape_choice.keycode = KEY_ESCAPE
	close_choice.shortcut = Shortcut.new()
	close_choice.shortcut.events = [escape_choice]
	addon_dialog.scroll.resized.connect(_fit_private_cards)
	color_dialog = WildPicker.new()
	color_dialog.theme = screen.theme
	color_dialog.z_index = 100
	color_dialog.canceled.connect(_clear_selection)
	add_child(color_dialog)
	color_dialog.color_selected.connect(func(suit: String) -> void:
		color_dialog.hide()
		if rules.phase == "addon_choice" and rules.addons.choice.get("kind", "") == "combo_color":
			_local_action({"action":"addon_choose", "value":suit, "revision":selected_revision})
		elif selected_card < 0:
			_local_action({"action": "color", "color": suit, "revision": selected_revision})
		else:
			selected_color = suit
			_play_selected()
	)
	color_dialog.uno_pressed.connect(func() -> void: _local_action({"action":"uno"}))
	celebration = GameCelebration.new()
	celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table.add_child(celebration)
	ai_timer = _timer(_computer_turn)
	catch_timer = _timer(_computer_catch)
	jump_timer = _timer(_computer_jump)
	motion_timer = _timer(_settled)
	auto_timer = _timer(_automatic_turn)
	var audio_files := {"card":"card-place-1", "draw":"card-slide-1", "win":"victory", "shuffle":"card-shuffle"}
	for name in audio_files:
		var sound := AudioStreamPlayer.new()
		sound.stream = RuntimeAssets.audio("res://Games/uno/audio/%s.ogg" % audio_files[name])
		sound.bus = "Effects"
		sound.max_polyphony = 6
		sound.volume_db = -5
		add_child(sound)
		sounds[name] = sound
	screen.resized.connect(_resize_table)
	screen.board_space_changed.connect(_resize_table)


func _timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(callback)
	return timer


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"gamemode": "classic", "difficulty": Rules.Difficulty.MEDIUM, "addons": Rules.AddOns.defaults()})
	pending_gamemode = saved.gamemode if saved.gamemode in Rules.GAMEMODES else "classic"
	difficulty = saved.difficulty if saved.difficulty in [0, 1, 2] else Rules.Difficulty.MEDIUM
	pending_difficulty = difficulty
	pending_options = load_game_settings({"options": Rules.default_options(pending_gamemode)}).options
	pending_addons = saved.addons
	rules.set_gamemode(pending_gamemode)
	rules.enabled_addons = pending_addons.duplicate() if pending_gamemode == "classic" else Rules.AddOns.defaults()
	for option in pending_options:
		rules.set(option, pending_options[option])
	host_plays = context.players.is_empty()
	if host_plays:
		replay.reparent(table)
		table.replay_button = replay
	seats = [context.solo_profile.duplicate(true)] if host_plays else context.players.duplicate(true)
	for player in seats:
		player.ai = false
	var colors := ["#e53935", "#2463eb", "#08a750", "#f7cf05", "#ae39f2", "#f52191"]
	var computer_number := 1
	while seats.size() < 4:
		var index := seats.size()
		var used: Array = seats.map(func(player: Dictionary) -> String: return str(player.get("color", "")).to_lower())
		var available: Array = colors.filter(func(tint: String) -> bool: return not used.has(tint))
		seats.append({"id": "uno-ai-%d" % index, "display_name": "Computer %d" % computer_number, "color": available[0], "ai": true})
		computer_number += 1
	rules.start(seats.size())


func start_game() -> void:
	_start_deal()
	_publish()
	_resize_table.call_deferred()


func _start_deal() -> void:
	missing = offline.duplicate()
	_cancel_card_audio()
	deal_revision += 1
	dealing = not session.reduced_motion
	animating = dealing
	motion_timer.paused = false
	if dealing:
		motion_timer.paused = settings_open or not missing.is_empty()
		motion_timer.start(Rules.deal_duration(seats.size()))
		if missing.is_empty() and not settings_open:
			sounds.shuffle.play()
			_play_deal_audio()


func _deal_view() -> Dictionary:
	if deal_revision < 0: return {}
	var duration := Rules.deal_duration(seats.size())
	return {"revision":deal_revision,"active":dealing,"elapsed":duration - motion_timer.time_left if dealing else duration,"duration":duration,"dealer":rules.dealer,"seats":seats.size(),"shuffle":Rules.DEAL_SHUFFLE,"step":Rules.DEAL_STEP,"flight":Rules.DEAL_FLIGHT,"reveal":Rules.DEAL_REVEAL}


func _resize_table() -> void:
	var available := screen.available_size()
	GameLook.compact_control(difficulty_choice)
	GameLook.compact_control(gamemode_choice)
	var ratio := .60 if available.x < 600 and available.y > available.x else (3.0 if available.y < 560 else 1.75 if host_plays else 1.95)
	var width := maxf(180, available.x - 64)
	controls.custom_minimum_size.x = width
	controls.custom_minimum_size.y = 0
	var height := maxf(90, minf(screen.board_height_limit(), width / ratio))
	table.custom_minimum_size = Vector2(minf(width, height * ratio), height)
	table.queue_redraw()
	_fit_table_footer.call_deferred()


func _fit_table_footer() -> void:
	if table_footer == null or active_rules == null: return
	if not rules_dialog.is_empty():
		var expanded: bool = active_rules.expanded and host_plays and controls.visible
		var destination: Node = rules_dialog.body if expanded else table_footer
		if active_rules.get_parent() != destination: active_rules.reparent(destination)
		rules_dialog.overlay.visible = expanded
		if expanded:
			# The shared dialog owns scrolling, including the section headings.
			active_rules.fit(minf(460, maxf(100, screen.available_size().x - 96)), INF, true)
			return
	var available := maxf(100, table_footer.size.x)
	var small := screen.available_size().x < 1000 or screen.available_size().y < 560
	var rule_scale := 1.0 if small else clampf(screen.available_size().x / 1280.0, 1, 1.65)
	var rules_width := minf(300 * rule_scale, available if available < 600 else available * .29)
	active_rules.fit(rules_width, minf(240 * rule_scale, screen.available_size().y * .44), true, rule_scale)
	active_rules.position = Vector2(24, table_footer.size.y - active_rules.size.y - 20)


func _set_gamemode(index: int) -> void:
	if stopped or not missing.is_empty() or index < 0 or index >= Rules.GAMEMODES.size():
		gamemode_choice.select(Rules.GAMEMODES.find(pending_gamemode))
		return
	if pending_gamemode != Rules.GAMEMODES[index]:
		pending_gamemode = Rules.GAMEMODES[index]
		pending_options = Rules.default_options(pending_gamemode)
	_refresh_options()


func _set_difficulty(index: int) -> void:
	if stopped or index not in [0, 1, 2] or not missing.is_empty() or not seats.any(func(player: Dictionary) -> bool: return player.ai):
		difficulty_choice.select(difficulty)
		return
	pending_difficulty = index
	_refresh_options()


func _set_rule(option: String, enabled: bool) -> void:
	if not stopped and missing.is_empty() and pending_options.has(option):
		pending_options[option] = enabled
	_refresh_options()


func _set_addon(key: String, enabled: bool) -> void:
	if not stopped and missing.is_empty() and pending_gamemode == "classic" and pending_addons.has(key): pending_addons[key] = enabled
	_refresh_options()


func _options_changed() -> bool:
	return pending_gamemode != rules.gamemode or pending_difficulty != difficulty or pending_options.keys().any(func(option: String) -> bool: return pending_options[option] != bool(rules.get(option))) or (pending_gamemode == "classic" and Rules.AddOns.signature(pending_addons) != Rules.AddOns.signature(rules.enabled_addons))


func _refresh_options() -> void:
	gamemode_choice.select(Rules.GAMEMODES.find(pending_gamemode))
	gamemode_choice.disabled = stopped or not missing.is_empty()
	difficulty_choice.select(pending_difficulty)
	difficulty_choice.disabled = stopped or not seats.any(func(player: Dictionary) -> bool: return player.ai) or not missing.is_empty()
	for definition in RULE_OPTIONS:
		var option: String = definition[0]
		var toggle: Button = rule_choices[option]
		toggle.set_pressed_no_signal(pending_options[option])
		toggle.text = str(definition[1]) + (": ON" if toggle.button_pressed else ": OFF")
		toggle.visible = option != "allow_mercy" or pending_gamemode == "no_mercy"
		toggle.disabled = stopped or not missing.is_empty()
		GameLook.toggle_state(toggle, toggle.button_pressed)
	apply_options.disabled = stopped or not missing.is_empty() or not _options_changed()
	addons_button.visible = pending_gamemode == "classic"
	addons_button.disabled = stopped or not missing.is_empty()
	for pack in Rules.AddOns.PACKS:
		var toggle: Button = addon_choices[pack[0]]
		toggle.set_pressed_no_signal(pending_addons[pack[0]])
		toggle.text = str(pack[1]).to_upper() + (": ON" if toggle.button_pressed else ": OFF")
		toggle.disabled = stopped or not missing.is_empty() or pending_gamemode != "classic"
		GameLook.toggle_state(toggle, toggle.button_pressed)
	if pending_gamemode != "classic":
		addons_body.hide()
		settings_body.show()


func _apply_options() -> void:
	if stopped or not missing.is_empty() or not _options_changed(): return
	for timer in [ai_timer, catch_timer, jump_timer, motion_timer, auto_timer]: timer.stop()
	_cancel_card_audio()
	_clear_selection()
	celebration.clear()
	difficulty = pending_difficulty
	rules.set_gamemode(pending_gamemode)
	rules.enabled_addons = pending_addons.duplicate() if pending_gamemode == "classic" else Rules.AddOns.defaults()
	for option in pending_options: rules.set(option, pending_options[option])
	save_game_settings({"gamemode": rules.gamemode, "difficulty": difficulty, "options": pending_options.duplicate(), "addons": pending_addons.duplicate()})
	rules.restart_round()
	result_sent = false
	_start_deal()
	_publish()


func _status() -> String:
	if not missing.is_empty():
		return "Paused · waiting for " + ", ".join(seats.filter(func(player: Dictionary) -> bool: return missing.has(str(player.id))).map(func(player: Dictionary) -> String: return str(player.display_name)))
	if rules.winner >= 0:
		return "%s WINS!" % seats[rules.winner].display_name
	if dealing: return "Shuffling and dealing seven cards each…"
	var name: String = seats[rules.turn].display_name
	if rules.phase == "addon_choice": return name + " · " + str(rules.addons.choice.get("prompt", "Choose an add-on action."))
	if rules.phase == "addon_assist": return name + " · play for your coupled partner or let them draw"
	if rules.phase == "addon_response": return name + " · respond to the penalty or accept it"
	if rules.addons.active(rules) and rules.addons.speed > 1: return "%s · %d cards left this turn · speed %d" % [name, rules.addons.remaining, rules.addons.speed]
	if rules.phase == "flip_color": return "%s · choose the revealed Wild’s color" % name
	if rules.phase == "opening_color": return "%s · choose the starting color" % name
	if rules.phase == "drawn_color": return "%s · choose the drawn Wild's color" % name
	if rules.phase == "roulette_color": return "%s · choose a color for Color Roulette" % name
	if rules.phase == "swap": return "%s · choose a player to swap hands with" % name
	if rules.drawn >= 0: return "%s · playing the drawn card" % name if rules.force_play else "%s · play the drawn card or keep it" % name
	if rules.requires_turn_draw(): return "%s · drawing a card" % name
	if not rules.pending_color.is_empty(): return "%s · draws until %s" % [name, rules.pending_color.capitalize()]
	if rules.pending_draw > 0:
		var amount := int(Rules.DRAW_AMOUNTS[rules.cards[rules.discard.back()].kind])
		return "%s · stack a +%d or draw %d" % [name, amount, rules.pending_draw] if rules.allow_stacking else "%s · draws %d" % [name, rules.pending_draw]
	var feedback: String = rules.last_event if rules.last_event.begins_with("Draw Four") or rules.last_event.begins_with("Missed UNO") else ""
	return "%s's turn%s" % [name, " · " + feedback if not feedback.is_empty() else ""]


func _snapshot(seat: int) -> Dictionary:
	var view: Dictionary = rules.view_for(seat)
	view.players = seats.map(func(player: Dictionary) -> Dictionary: return {"id": str(player.id), "display_name": str(player.display_name), "color": str(player.get("color", "#58d6ff")), "ai": bool(player.ai), "pose":int(player.get("pose", 0))})
	view.paused = not missing.is_empty() or settings_open
	view.animating = animating
	view.reduced_motion = session.reduced_motion
	view.status = "Settings open" if settings_open else _status()
	view.difficulty = difficulty
	view.deal = _deal_view()
	view.active_addons = Rules.AddOns.PACKS.filter(func(pack: Array) -> bool: return rules.gamemode == "classic" and rules.enabled_addons.get(pack[0], false)).map(func(pack: Array) -> String: return pack[1])
	view.active_rule_items = Presentation.rule_items(view)
	view.player_choice = Presentation.player_choice(view)
	view.latest_play = {}
	if not rules.plays.is_empty():
		var play: Dictionary = rules.plays.back().duplicate(true)
		play.note = "Direction is now %s." % ("clockwise" if rules.direction > 0 else "counterclockwise") if play.card.kind.contains("reverse") else "Current color: %s" % str(play.color).capitalize() if play.card.color == "wild" else ""
		view.latest_play = play
	return view


func _publish() -> void:
	if stopped: return
	if not settings_open and not animating and missing.is_empty() and rules.requires_auto_draw():
		_action(rules.turn, {"action":"draw","revision":rules.revision})
		return
	var local := _snapshot(0 if host_plays else -1)
	if selected_revision != rules.revision or not missing.is_empty(): _clear_selection()
	local.selected_card = selected_card
	local.selection_ready = selected_card >= 0 and (rules.cards[selected_card].color != "wild" or not selected_color.is_empty())
	table.show_state(local)
	screen.status.text = _status()
	replay.visible = rules.phase == "finished"
	replay.disabled = not missing.is_empty() or animating
	controls.visible = rules.phase != "finished" or not host_plays
	active_rules.visible = host_plays
	active_rules.set_items(local.active_rule_items)
	_fit_table_footer.call_deferred()
	var active: bool = host_plays and rules.turn == 0 and missing.is_empty() and not animating and not settings_open
	var can_draw: bool = active and rules.phase == "play" and rules.drawn < 0 and not rules.requires_turn_draw() and (rules.pending_draw == 0 or not rules.legal_cards(0).is_empty()) and rules.pending_color.is_empty()
	if rules.addons.active(rules) and rules.addons.speed > 1: can_draw = false
	if active and local.get("addon_draw", false): can_draw = true
	GameLook.set_illustrated_control_disabled(actions.draw, not can_draw)
	actions.draw.visible = host_plays
	actions.draw.text = "DRAW %d" % rules.pending_draw if rules.pending_draw > 0 else "DRAW"
	_refresh_options()
	_update_addon_view(local)
	var lines: Array[String] = []
	if rules.winner >= 0 and not animating:
		lines.append("%s Wins!" % seats[rules.winner].display_name)
	for index in range(rules.plays.size() - 1, -1, -1):
		var entry: Dictionary = rules.plays[index]
		var name: String = seats[entry.seat].display_name
		var label: String = Rules.card_label(entry.card)
		if entry.card.color == "wild": label += " → " + str(entry.color).capitalize()
		lines.append("%d. %s · %s" % [entry.number, name, label])
	var log_text := "No cards played yet." if lines.is_empty() else "\n".join(lines)
	if history_text.text != log_text:
		history_text.text = log_text
		history_text.scroll_to_line(0)
		var history_scroll: Node = history_text.get_parent()
		while history_scroll != null and not history_scroll is ScrollContainer: history_scroll = history_scroll.get_parent()
		if history_scroll is ScrollContainer: history_scroll.scroll_vertical = 0
	if color_dialog.visible and (selected_revision != rules.revision or not missing.is_empty()):
		color_dialog.hide()
		selected_card = -1
	var needs_color: bool = active and (rules.phase in ["opening_color", "drawn_color", "flip_color", "roulette_color"] or local.get("addon_choice", {}).get("kind", "") == "combo_color")
	var color_key := "%s:%d" % [rules.phase, rules.revision] if needs_color else ""
	if color_key != color_choice_key:
		color_choice_key = color_key
		if needs_color: _open_color(-1)
	# Hands are public only during the explicit Reveal Hands effect.
	broadcast_state(_snapshot(-1))
	for player in session.players:
		send_state(str(player.id), _snapshot(_seat_for(str(player.id))))
	if rules.winner >= 0 and not animating and not result_sent:
		result_sent = true
		sounds.win.play()
		celebration.show_win([], "%s WINS!" % seats[rules.winner].display_name, Color(str(seats[rules.winner].color)), not session.reduced_motion)
		if not seats.any(func(player: Dictionary) -> bool: return player.ai) and not host_plays:
			for index in seats.size():
				var profile_id := str(seats[index].get("profile_id", seats[index].id))
				report_result(profile_id, index == rules.winner)
				if index == rules.winner: award_points(profile_id, 1)
	_schedule_ai()


func _seat_for(player_id: String) -> int:
	for index in seats.size():
		if str(seats[index].id) == player_id: return index
	return -1


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	if stopped or not session.players.any(func(player: Dictionary) -> bool: return str(player.id) == player_id): return
	var seat := _seat_for(player_id)
	if seat < 0: return
	if message.get("action") == "sync":
		send_state(player_id, _snapshot(seat))
		return
	_action(seat, message)


func _local_action(message: Dictionary) -> void:
	if not host_plays: return
	if not message.has("revision"): message.revision = rules.revision
	_action(0, message)


func _choose_player(target: int) -> void:
	if not table._player_target(target): return
	var choice: Dictionary = table.state.player_choice
	var input := {"action":choice.action, "target":target, "revision":table.state.revision}
	if choice.get("multiple", false): input.amount = (int(choice.amounts.get(target, 0)) + 1) % 5
	_local_action(input)


func _update_player_focus() -> void:
	if player_focus == null or stopped or table.state.is_empty():
		if player_focus != null: player_focus.hide()
		return
	var choice: Dictionary = table.state.get("player_choice", {})
	if not host_plays or table.state.paused or table.state.animating or table._dealing() or not table.flights.is_empty() or addon_dialog.overlay.visible or color_dialog.visible:
		player_focus.hide()
		return
	var rects: Array[Rect2] = []
	var colors: Array[Color] = []
	var captions: Array[String] = []
	var avoid: Array[Rect2] = []
	var protect: Array[Rect2] = []
	var transform := player_focus.get_global_transform_with_canvas().affine_inverse() * table.get_global_transform_with_canvas()
	for seat in table.seat_rects.size():
		avoid.append(transform * table.seat_rects[seat])
		if table._player_target(seat):
			rects.append(transform * table.seat_rects[seat])
			colors.append(Color(str(seats[seat].color)))
			captions.append("+%d" % int(choice.amounts.get(seat, 0)) if choice.get("multiple", false) else "")
	for seat in table.fan_rects.size():
		if seat != table.state.viewer: avoid.append(transform * table.fan_rects[seat])
	for bounds: Rect2 in [table.deck_rect, table.top_rect, table.hand_rect]: avoid.append(transform * bounds)
	for button: Button in [table.uno_button, table.sort_button, actions.draw]:
		protect.append(transform * Rect2(button.position, button.size))
	protect.append(transform * table.hand_rect)
	protect.append(screen.back_button.get_global_rect())
	protect.append(active_rules.get_global_rect())
	if settings_body != null: protect.append(settings_body.get_parent().get_meta("toggle_button").get_global_rect())
	if choice.is_empty():
		var context_view: Dictionary = Presentation.context_actions(table.state)
		player_focus.present_context(str(context_view.get("prompt", "")), context_view.get("actions", []), avoid, session.reduced_motion, protect)
		return
	var prompt := str(choice.get("compact_prompt", choice.get("prompt", "")) if size.y < 500 else choice.get("prompt", ""))
	player_focus.present(rects, colors, captions, prompt, avoid, session.reduced_motion, choice.get("multiple", false), protect)


func _valid_addon_input(message: Dictionary) -> bool:
	if message.has("target") and not _integer(message.target, 0, seats.size() - 1): return false
	if message.has("card") and not _integer(message.card, 0, rules.cards.size() - 1): return false
	if message.has("amount") and not _integer(message.amount, 0, 4): return false
	return not message.has("value") or message.value is String


func _addon_button(parent: Control, caption: String, input: Dictionary, disabled: bool) -> void:
	var button := Button.new()
	button.text = caption
	button.accessibility_name = caption
	GameLook.action(button)
	GameLook.compact_control(button)
	button.disabled = disabled
	parent.add_child(button)
	button.pressed.connect(func() -> void: _local_action(input))


func _context_action(id: String) -> void:
	if not Presentation.context_actions(table.state).get("actions", []).any(func(action: Dictionary) -> bool: return action.id == id): return
	var action: String = {"accept":"draw", "decline":"addon_decline", "combo":"addon_combo", "end_enemy":"addon_end_enemy"}.get(id, "")
	if not action.is_empty(): _local_action({"action":action, "revision":table.state.revision})


func _open_badge_viewer(seat: int) -> void:
	if table._badge_viewable(seat): addon_dialog.overlay.show()


func _open_discard_choice() -> void:
	if not table._discard_choice(): return
	if table.state.get("addon_choice", {}).get("kind", "") == "text": addon_dialog.overlay.show()
	else: _open_color(-1)


func _update_addon_view(view: Dictionary) -> void:
	if not host_plays or view.paused or view.animating or stopped or view.phase == "finished":
		addon_view_key = ""
		addon_dialog.overlay.hide()
		return
	var offered: Dictionary = view.get("addon_choice", {})
	var seen: Dictionary = view.get("revealed_cards", {})
	var kind: String = offered.get("kind", "") if offered.get("kind", "") in ["chat_take", "text"] else "proof" if not seen.is_empty() and offered.is_empty() else ""
	var key := JSON.stringify([kind, offered if kind in ["chat_take", "text"] else seen if kind == "proof" else {}])
	if key == addon_view_key: return
	addon_view_key = key
	addon_dialog.overlay.hide()
	for child in addon_dialog.body.get_children(): addon_dialog.body.remove_child(child); child.queue_free()
	for child in addon_action_row.get_children().slice(1): addon_action_row.remove_child(child); child.queue_free()
	if kind.is_empty(): return
	addon_dialog.heading.text = "COLOR CHALLENGE" if kind == "proof" else "CHOOSE A RULE" if kind == "text" else "EXCHANGE · %s" % seats[int(offered.target)].display_name
	if kind == "text":
		screen.add_sidebar_text(addon_dialog.body, str(offered.prompt))
		for option in [["draw","OTHERS DRAW 1"],["swap","SWAP HANDS"],["color","COLOR REVEAL"]]: _addon_button(addon_dialog.body, option[1], {"action":"addon_choose", "value":option[0]}, false)
	else:
		var groups: Dictionary = {offered.target:offered.cards} if kind == "chat_take" else seen
		for target in groups:
			if kind == "proof": screen.add_sidebar_text(addon_dialog.body, str(seats[int(target)].display_name))
			var grid := GameCardGrid.new()
			grid.preferred_width = 108
			grid.locked = kind == "proof"
			addon_dialog.body.add_child(grid)
			grid.set_items(groups[target].map(func(card: Dictionary) -> Dictionary:
				var face := card.duplicate(true)
				face.layout = "art"
				face.display_name = Rules.card_label(card)
				return {"card":face, "texture":table.card_texture(card)}
			))
			for tile in grid.get_children(): tile.accessibility_name = Rules.card_label(tile.get_meta("grid_entry").card)
			grid.card_pressed.connect(func(card: Dictionary) -> void:
				if table.state.get("addon_choice", {}).get("kind", "") == "chat_take": _local_action({"action":"addon_choose", "card":card.id})
			)
		if kind == "chat_take": _addon_button(addon_action_row, "SKIP EXCHANGE", {"action":"addon_choose", "value":"skip"}, false)
	addon_dialog.overlay.show()
	_fit_private_cards.call_deferred()


func _fit_private_cards() -> void:
	addon_dialog.heading.add_theme_font_size_override("font_size", 16 if screen.available_size().y < 420 else 22)
	var grids: Array = addon_dialog.body.get_children().filter(func(child: Node) -> bool: return child is GameCardGrid)
	if grids.is_empty(): return
	var has_names: bool = addon_dialog.body.get_child_count() > grids.size()
	var width := clampf((addon_dialog.scroll.size.y - (36 if has_names else 0)) / 1.5, 44, 108)
	for grid: GameCardGrid in grids:
		if not is_equal_approx(grid.preferred_width, width): grid.preferred_width = width; grid.queue_sort()


func _action(seat: int, message: Dictionary) -> void:
	if stopped or settings_open or not missing.is_empty() or not _integer(message.get("revision"), rules.revision, rules.revision): return
	var action: String = str(message.get("action", ""))
	if animating: return
	var changed := false
	match action:
		"addon_choose":
			if _valid_addon_input(message): changed = rules.addons.choose(rules, seat, message) if rules.addons.active(rules) else false
		"addon_combo": changed = rules.addons.combo(rules, seat) if rules.addons.active(rules) else false
		"addon_decline": changed = rules.addons.decline(rules, seat) if rules.addons.active(rules) else false
		"addon_end_enemy": changed = rules.addons.end_enemy(rules, seat) if rules.addons.active(rules) else false
		"play":
			if _integer(message.get("card"), 0, rules.cards.size() - 1) and message.get("color", "") is String and message.get("call_uno", false) is bool and not message.get("call_uno", false):
				changed = rules.play(seat, int(message.card), str(message.get("color", "")))
		"draw": changed = rules.draw(seat)
		"pass": changed = rules.pass_turn(seat)
		"uno": changed = rules.call_uno(seat)
		"catch":
			if _integer(message.get("target"), 0, seats.size() - 1): changed = rules.catch_uno(seat, int(message.target))
		"color":
			if message.get("color") is String and message.get("call_uno", false) is bool and not message.get("call_uno", false): changed = rules.choose_color(seat, message.color)
		"swap":
			if _integer(message.get("target"), 0, seats.size() - 1): changed = rules.swap_hands(seat, int(message.target))
		"play_again":
			changed = rules.play_again()
			if changed:
				result_sent = false
				celebration.clear()
				_start_deal()
	if not changed: return
	var color_play: bool = action == "color" and not rules.motion.is_empty() and rules.motion.revision == rules.revision
	var moving: bool = (action in ["play", "draw", "catch", "swap", "addon_choose"] or color_play) and rules.motion.get("revision", -1) == rules.revision
	if moving:
		_play_card_audio(rules.motion)
	if moving and not rules.motion.is_empty() and not session.reduced_motion:
		var remaining := motion_timer.time_left if animating else 0.0
		animating = true
		motion_timer.start(remaining + Rules.motion_duration(rules.motion))
	_publish()


func _play_deal_audio() -> void:
	var elapsed: float = _deal_view().elapsed
	for index in seats.size() * 7:
		var delay := Rules.DEAL_SHUFFLE + index * Rules.DEAL_STEP - elapsed
		if delay >= 0: _queue_sound(sounds.draw,delay)


func _queue_sound(sound: AudioStreamPlayer, delay: float) -> void:
	if delay <= 0:
		sound.play()
		return
	var timer := Timer.new()
	timer.one_shot = true
	add_child(timer)
	queued_sounds.append(timer)
	timer.timeout.connect(func() -> void:
		if not stopped and missing.is_empty(): sound.play()
		queued_sounds.erase(timer)
		timer.queue_free()
	)
	timer.start(delay)


func _play_card_audio(event: Dictionary) -> void:
	var delay := motion_timer.time_left if animating and not session.reduced_motion else 0.0
	for flight in Rules.motion_timeline(event).get("flights", []):
		var sound: AudioStreamPlayer = sounds.card if flight.kind == "play" else sounds.draw
		if flight.kind == "play": sound.stream = place_sounds.pick_random()
		var count := 1 if session.reduced_motion or flight.kind == "hand" else int(flight.count)
		for index in count:
			_queue_sound(sound, delay + (0.0 if session.reduced_motion else float(flight.start) + index * .10))


func _select_card(card_id: int) -> void:
	if host_plays and Presentation.hand_choice(table.state).has(card_id):
		_local_action({"action":"addon_choose", "card":card_id, "revision":table.state.revision})
		return
	if not host_plays or not rules.playable(0, card_id) or animating or not missing.is_empty(): return
	selected_card = card_id
	selected_revision = rules.revision
	selected_color = ""
	if rules.cards[card_id].color == "wild" and rules.cards[card_id].kind != "color_roulette": _open_color(card_id)
	else: _play_selected()


func _clear_selection() -> void:
	selected_card = -1
	selected_color = ""
	color_dialog.hide()


func _play_selected() -> void:
	if selected_card < 0: return
	_local_action({"action": "play", "card": selected_card, "color": selected_color, "revision": selected_revision})
	_clear_selection()


func _settings_toggled(open: bool) -> void:
	settings_open = open
	if session == null or stopped: return
	motion_timer.paused = open or not missing.is_empty()
	if open:
		for timer in [ai_timer, catch_timer, jump_timer, auto_timer]: timer.stop()
		_cancel_card_audio()
		color_dialog.hide()
	elif dealing and missing.is_empty(): _play_deal_audio()
	_publish()


func _color_picker_area() -> Rect2:
	var bounds := screen.available_size()
	var hand := Rect2(table.global_position - global_position + table.hand_rect.position, table.hand_rect.size)
	if bounds.y < 560 and bounds.x >= 650:
		return Rect2(Vector2(16,72), Vector2(maxf(120,hand.position.x - 32),maxf(100,bounds.y - 142)))
	return Rect2(Vector2(16,72), Vector2(bounds.x - 32,maxf(100,hand.position.y - 88)))


func _open_color(card_id: int) -> void:
	selected_card = card_id
	selected_revision = rules.revision
	var card: Dictionary = rules.cards[card_id] if card_id >= 0 else rules.cards[rules.drawn if rules.phase == "drawn_color" else rules.discard.back()]
	color_dialog.open(card, rules.phase == "drawn_color" and rules.hands[0].size() == 2 and not rules.armed[0], rules.phase not in ["drawn_color", "roulette_color"], _color_picker_area, rules.active_colors(), rules.gamemode)


func _settled() -> void:
	animating = false
	dealing = false
	_publish()


func _schedule_ai() -> void:
	ai_timer.stop()
	catch_timer.stop()
	jump_timer.stop()
	auto_timer.stop()
	if stopped or settings_open or animating or not missing.is_empty() or rules.phase == "finished": return
	if rules.requires_turn_draw() or rules.requires_forced_play(): auto_timer.start(.75)
	elif seats[rules.turn].ai: ai_timer.start(1.15)
	if rules.allow_jump_ins and seats.any(func(player: Dictionary) -> bool: return player.ai) and rules.phase == "play":
		for seat in seats.size():
			if seats[seat].ai and not rules.jump_cards(seat).is_empty():
				jump_timer.start(.65)
				break
	if rules.catch_target >= 0 and seats.any(func(player: Dictionary) -> bool: return player.ai):
		catch_timer.start(0.85)


func _computer_catch() -> void:
	if stopped or not missing.is_empty() or rules.catch_target < 0: return
	for index in seats.size():
		if seats[index].ai and index != rules.catch_target and (difficulty != Rules.Difficulty.EASY or randf() < 0.3):
			_action(index, {"action": "catch", "target": rules.catch_target, "revision": rules.revision})
			return


func _computer_turn() -> void:
	if stopped or animating or not missing.is_empty() or not seats[rules.turn].ai or rules.phase == "finished": return
	var seat: int = rules.turn
	var input: Dictionary = Rules.computer_action(rules.view_for(seat), difficulty)
	if (input.action in ["play", "addon_choose"] or (input.action == "color" and rules.phase == "drawn_color")) and rules.can_call_uno(seat) and (difficulty != Rules.Difficulty.EASY or randf() < 0.85):
		_action(seat, {"action":"uno", "revision":rules.revision})
	input.revision = rules.revision
	_action(seat, input)


func _computer_jump() -> void:
	if stopped or animating or not missing.is_empty(): return
	for seat in seats.size():
		var legal: Array = rules.jump_cards(seat)
		if seats[seat].ai and not legal.is_empty():
			if rules.hands[seat].size() == 2: _action(seat, {"action":"uno", "revision":rules.revision})
			_action(seat, {"action":"play", "card":legal.pick_random(), "revision":rules.revision})
			return


func _automatic_turn() -> void:
	if stopped or animating or not missing.is_empty(): return
	if rules.requires_turn_draw():
		_action(rules.turn, {"action":"draw", "revision":rules.revision})
	elif rules.requires_forced_play():
		if seats[rules.turn].ai and rules.hands[rules.turn].size() == 2: _action(rules.turn, {"action":"uno", "revision":rules.revision})
		_action(rules.turn, {"action":"play", "card":rules.drawn, "revision":rules.revision})


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	if not session.players.any(func(admitted: Dictionary) -> bool: return str(admitted.id) == str(player.get("id", ""))): return
	offline.erase(str(player.id))
	missing.erase(str(player.id))
	if dealing and missing.is_empty() and not settings_open:
		motion_timer.paused = false
		_play_deal_audio()
	_publish()


func player_disconnected(player_id: String) -> void:
	if not session.players.any(func(player: Dictionary) -> bool: return str(player.id) == player_id): return
	offline[player_id] = true
	if not rules.is_active(_seat_for(player_id)): return
	missing[player_id] = true
	if dealing: motion_timer.paused = true
	ai_timer.stop()
	catch_timer.stop()
	jump_timer.stop()
	auto_timer.stop()
	color_dialog.hide()
	_cancel_card_audio()
	_publish()


func _cancel_card_audio() -> void:
	for timer in queued_sounds:
		timer.stop()
		timer.queue_free()
	queued_sounds.clear()
	for sound in sounds.values(): sound.stop()


func shutdown_game() -> void:
	stopped = true
	player_focus.hide()
	rules_dialog.overlay.hide()
	addon_dialog.overlay.hide()
	table.stop_presentation()
	for timer in [ai_timer, catch_timer, jump_timer, motion_timer, auto_timer]: timer.stop()
	celebration.clear()
	color_dialog.hide()
	_cancel_card_audio()
	screen.background_media.set_active(false)
