extends RefCounted

const Board = preload("res://Games/monopoly-classic/host/board.gd")
const Effects = preload("res://Games/monopoly-classic/host/effects.gd")
var host
var screen := GameScreen.new()
var board = Board.new()
var frame := PanelContainer.new()
var actions := GameActionRow.new()
var turn_strip := GameTurnStrip.new()
var replay := Button.new()
var clock := Label.new()
var footer: VBoxContainer
var reader := GameCardReader.new()
var celebration := GameCelebration.new()
var activity := GameActivityLog.new()
var ledger: VBoxContainer
var right_ledger: VBoxContainer
var history_body: VBoxContainer
var history_panel: Control
var history_button: Button
var effects = Effects.new()
var player_cards: Array = []
var resume_dialog: Dictionary
var assets_dialog: Dictionary
var decision_dialog: Dictionary
var trade_dialog: Dictionary
var history_dialog: Dictionary
var view: Dictionary = {}
var selected_property := -1
var assets_owner := -1
var assets_revision := -1
var settings_open := false
var settings_body: VBoxContainer
var settings_toggle: Button
var pending: Dictionary = {}
var ai_count: SpinBox
var difficulty: OptionButton
var theme_choice: OptionButton
var packs: Array = []
var turn_toggle: Button
var turn_minutes: SpinBox
var game_toggle: Button
var game_minutes: SpinBox
var apply_button: Button
var decision_revision := -1
var opened_decision := ""
var displayed_win := -1


func _init(target) -> void:
	host = target
	host.add_child(screen); screen.configure("MONOPOLY CLASSIC")
	screen.use_playful_style("res://Games/monopoly-classic/art/table", "modern-table")
	screen.use_table_header(RuntimeAssets.texture("res://Games/monopoly-classic/art/title.svg"))
	screen.set_table_header_content(turn_strip)
	screen.exit_requested.connect(func() -> void: host.return_to_lobby())
	screen.back_button.accessibility_name = "Back to Monopoly"
	screen.scores.hide()
	var layout := screen.add_centered_layout(true, true, 0, 160)
	ledger = VBoxContainer.new()
	right_ledger = VBoxContainer.new()
	layout.left_sidebar.add_child(ledger); layout.sidebar.add_child(right_ledger)
	for column in [ledger, right_ledger]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation", 8)
	right_ledger.hide()
	board.definition = host.rules.definition; board.properties = host.rules.properties
	frame.add_theme_stylebox_override("panel", GameLook.box(Color("604532"), Color("bb955b"), 9, 5))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	layout.playfield.add_child(frame); frame.add_child(board)
	board.property_pressed.connect(show_property)
	board.add_child(celebration); celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var auxiliary := VBoxContainer.new(); auxiliary.custom_minimum_size.y = 76
	footer = auxiliary
	layout.playfield.add_child(auxiliary)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; clock.add_theme_font_size_override("font_size", 17)
	clock.clip_text = true; clock.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; auxiliary.add_child(clock)
	auxiliary.add_child(actions)
	replay.text = "PLAY AGAIN"; replay.theme = screen.theme; replay.custom_minimum_size = Vector2(180, 44)
	replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameLook.action(replay, true); layout.playfield.add_child(replay)
	replay.pressed.connect(func() -> void: host._new_round(true)); replay.hide()
	screen.center_board(frame, replay, auxiliary, .5, true, false, true)
	replay.reparent(actions)
	history_body = screen.add_card(layout.sidebar); history_panel = history_body.get_parent_control()
	screen.add_section_heading(history_body, "History", 18)
	activity.show_heading = false; activity.bold_latest = true
	activity.custom_minimum_size = Vector2(0, 300); history_body.add_child(activity)
	effects.ui = self; effects.motion = host.motion; host.add_child(effects)
	screen.board_space_changed.connect(_fit)
	screen.resized.connect(_fit)
	host.add_child(reader); reader.theme = screen.theme
	reader.closed.connect(func() -> void: selected_property = -1; board.selected = -1; board.queue_redraw())
	assets_dialog = screen.add_phase_dialog(true, true, false, true)
	decision_dialog = screen.add_phase_dialog(true, false, true, true)
	trade_dialog = screen.add_phase_dialog(true, false, false, true)
	resume_dialog = screen.add_phase_dialog(true, false, true)
	history_dialog = screen.add_phase_dialog(false, false, false, true)
	history_dialog.heading.text = "History"
	var close_history := _button(history_dialog.actions, "CLOSE", func() -> void: history_dialog.overlay.hide())
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE
	close_history.shortcut = Shortcut.new(); close_history.shortcut.events = [escape]
	history_dialog.overlay.visibility_changed.connect(func() -> void:
		if is_instance_valid(history_button): history_button.set_pressed_no_signal(history_dialog.overlay.visible))
	settings_body = screen.add_corner_details(["SETTINGS"], Callable(), true, false, false, true, true)[0]
	settings_toggle = settings_body.get_meta("toggle_button")
	settings_toggle.toggled.connect(func(open: bool) -> void: settings_open = open; host._save(); host._publish())
	_build_settings()
	_fit.call_deferred()


func _button(parent: Node, text: String, callback: Callable, primary := false, disabled := false) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 44; button.disabled = disabled; button.theme = screen.theme
	GameLook.action(button, primary); parent.add_child(button); button.pressed.connect(callback)
	return button


func _clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()


func _label(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(label)
	return label


func _build_settings() -> void:
	ai_count = screen.add_number_control(settings_body, "Computer players", 0, 5, 1, 1)
	difficulty = screen.add_choice_control(settings_body, "AI difficulty", ["Easy", "Medium", "Hard"], true)
	theme_choice = screen.add_choice_control(settings_body, "Skin", ["Classic"], true)
	turn_toggle = screen.add_toggle_control(settings_body, "Turn timer", true)
	turn_minutes = screen.add_number_control(settings_body, "Minutes per turn", .1, 60, .1, 1, " min")
	game_toggle = screen.add_toggle_control(settings_body, "Game timer", false)
	game_minutes = screen.add_number_control(settings_body, "Minutes per game", .1, 1440, 1, 60, " min")
	apply_button = _button(settings_body, "APPLY & NEW GAME", func() -> void: host.apply_settings(pending), true)
	ai_count.value_changed.connect(func(value: float) -> void: pending["solo_ai" if host.host_plays else "party_ai"] = int(value); _refresh_apply())
	difficulty.item_selected.connect(func(index: int) -> void: pending.difficulty = index; _refresh_apply())
	theme_choice.item_selected.connect(func(index: int) -> void: pending.theme = packs[index].id; _refresh_apply())
	turn_toggle.toggled.connect(func(value: bool) -> void: pending.turn_timer = value; _refresh_apply())
	game_toggle.toggled.connect(func(value: bool) -> void: pending.game_timer = value; _refresh_apply())
	turn_minutes.value_changed.connect(func(value: float) -> void: pending.turn_seconds = value * 60; _refresh_apply())
	game_minutes.value_changed.connect(func(value: float) -> void: pending.game_seconds = value * 60; _refresh_apply())


func restore_settings() -> void:
	pending = host.options.duplicate(true)
	ai_count.min_value = 1 if host.host_plays else 0
	ai_count.max_value = 5 if host.host_plays else maxi(0, 6 - host.session.players.size())
	ai_count.set_value_no_signal(int(pending.solo_ai if host.host_plays else pending.party_ai))
	pending["solo_ai" if host.host_plays else "party_ai"] = int(ai_count.value)
	difficulty.select(int(pending.difficulty))
	packs = host.skins.list_packs(); theme_choice.clear()
	for index in packs.size():
		theme_choice.add_item(str(packs[index].name))
		if packs[index].id == pending.theme: theme_choice.select(index)
	turn_toggle.set_pressed_no_signal(bool(pending.turn_timer)); game_toggle.set_pressed_no_signal(bool(pending.game_timer))
	turn_minutes.set_value_no_signal(float(pending.turn_seconds) / 60); game_minutes.set_value_no_signal(float(pending.game_seconds) / 60)
	_refresh_apply()


func _refresh_apply() -> void:
	if pending.is_empty(): return
	for pair in [[turn_toggle, pending.turn_timer], [game_toggle, pending.game_timer]]: GameLook.toggle_state(pair[0], bool(pair[1]))
	var active: Dictionary = host.options.duplicate(true)
	var count_key := "solo_ai" if host.host_plays else "party_ai"
	active[count_key] = clampi(int(active[count_key]), int(ai_count.min_value), int(ai_count.max_value))
	apply_button.disabled = pending == active or not host.missing.is_empty()
	turn_minutes.editable = bool(pending.turn_timer); game_minutes.editable = bool(pending.game_timer)
	GameLook.action(apply_button, true)


func _fit() -> void:
	if not is_instance_valid(board): return
	var available := maxf(160, screen.board_height_limit() - frame.get_theme_stylebox("panel").get_minimum_size().y)
	var edge := minf(available, screen.board_width_limit() - frame.get_theme_stylebox("panel").get_minimum_size().x)
	edge = maxf(160, edge)
	board.custom_minimum_size = Vector2(edge, edge)
	var rows := mini(3, player_cards.size())
	var panel_height := floorf((edge - maxi(0, rows - 1) * 8) / maxi(1, rows))
	for card: Dictionary in player_cards:
		var short_view := screen.available_size().y < 500
		var surface: StyleBox = card.panel.get_theme_stylebox("panel")
		surface.content_margin_top = 4 if short_view else 10; surface.content_margin_bottom = 4 if short_view else 10
		card.content.add_theme_constant_override("separation", 2 if short_view else 4)
		card.wealth.visible = not short_view
		card.icon.custom_minimum_size = Vector2(16, 14) if short_view else Vector2(22, 20)
		card.panel.custom_minimum_size.y = panel_height
		var wide: bool = card.panel.size.x >= 280
		card.player.add_theme_font_size_override("font_size", 11 if short_view else 17 if wide else 15)
		card.score.add_theme_font_size_override("font_size", 11 if short_view else 17 if wide else 15)
		var chrome: float = surface.get_minimum_size().y + card.row.get_combined_minimum_size().y + (card.wealth.get_combined_minimum_size().y if card.wealth.visible else 0) + card.content.get_theme_constant("separation") * (2 if card.wealth.visible else 1)
		card.portfolio.maximum_height = maxf(12, panel_height - chrome)
		card.portfolio._fit()
	activity.custom_minimum_size.y = maxf(120, minf(400, screen.available_size().y - 270)) if player_cards.size() > 3 else maxf(120, edge - 65)


func clear_round() -> void:
	reader.close(); selected_property = -1; board.selected = -1; board.moves = []; board.rolls = []; effects.clear(); celebration.clear(); displayed_win = -1
	for dialog in [assets_dialog, decision_dialog, trade_dialog, history_dialog]: dialog.overlay.hide()
	decision_revision = -1; opened_decision = ""


func render(value: Dictionary) -> void:
	effects.capture_sources()
	view = value
	screen.status.text = str(view.status)
	board.reduced_motion = host.session.reduced_motion; board.set_state(host.rules.s, host.seats, host.skin.get("labels", {}))
	render_clocks(view.clocks)
	var finished: bool = view.phase == "finished"
	turn_strip.set_players(view.players, -1 if finished else int(view.get("turn", -1)))
	footer.show()
	replay.visible = finished and not view.animating; replay.disabled = view.paused
	if player_cards.size() != view.players.size(): _make_player_cards()
	_place_history()
	for index in player_cards.size():
		var player: Dictionary = view.players[index]; var card: Dictionary = player_cards[index]
		card.player.text = str(player.display_name) + (" · WINNER" if finished and index == int(view.winner) else " · LOSS" if finished else " · OUT" if player.bankrupt else "")
		card.player.accessibility_name = card.player.text
		card.score.text = "$%d" % int(player.cash)
		card.wealth.text = "$%d wealth · %d deeds" % [int(player.wealth), view.properties.filter(func(property: Dictionary) -> bool: return int(property.owner) == index).size()]
		var owned: Array = view.properties.filter(func(property: Dictionary) -> bool: return int(property.owner) == index)
		var signature := JSON.stringify([owned, view.theme.revision])
		if card.signature != signature:
			var entries: Array = []
			owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.group) < str(b.group) if a.group != b.group else int(a.id) < int(b.id))
			for property in owned:
				entries.append({"card": _card_data(property), "texture": GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % property.key), "tint": Color(property.color)})
			card.portfolio.set_items(entries); card.signature = signature
		card.empty.visible = owned.is_empty()
		screen.set_score_card_active(card, index == int(view.get("actor", -1)) and not finished and not view.paused)
	effects.update(bool(view.paused))
	activity.set_entries(view.get("activity", []).filter(func(entry: Dictionary) -> bool: return not str(entry.text).is_empty()), host.session.reduced_motion, view.paused)
	_build_actions()
	_refresh_decision()
	if assets_dialog.overlay.visible and assets_revision != int(view.revision): show_assets(assets_owner)
	if reader.visible and selected_property >= 0: show_property(selected_property)
	if finished and not view.animating and displayed_win != int(view.revision):
		displayed_win = int(view.revision); celebration.show_win([], str(view.players[int(view.winner)].display_name) + " WINS!", Color("ffcf57"), not host.session.reduced_motion)
	_refresh_apply(); _fit.call_deferred()


func _make_player_cards() -> void:
	_clear(ledger); _clear(right_ledger); player_cards.clear()
	for index in view.players.size():
		var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", GameLook.modern_table_sheet())
		(ledger if index < 3 else right_ledger).add_child(panel)
		var card := screen.add_session_score(panel)
		card.panel = panel
		card.player.autowrap_mode = TextServer.AUTOWRAP_OFF; card.player.clip_text = true
		card.player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.player.add_theme_font_size_override("font_size", 15)
		card.score.add_theme_font_size_override("font_size", 15)
		var icon := TextureRect.new(); icon.texture = RuntimeAssets.texture("res://ui/playful/table-cash.svg"); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.custom_minimum_size = Vector2(22, 20); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.row.add_child(icon); card.row.move_child(icon, card.score.get_index())
		card.icon = icon
		card.wealth = _label(card.content, ""); card.wealth.add_theme_font_size_override("font_size", 12)
		card.empty = _label(card.content, "No properties yet"); card.empty.add_theme_font_size_override("font_size", 12)
		var portfolio := GameCardGrid.new(); portfolio.preferred_width = 108; portfolio.maximum_columns = 28; portfolio.left_aligned = true
		card.content.add_child(portfolio); portfolio.add_theme_constant_override("h_separation", 3); portfolio.add_theme_constant_override("v_separation", 3)
		portfolio.card_pressed.connect(func(property: Dictionary) -> void: show_property(int(property.id)))
		card.portfolio = portfolio; card.signature = ""
		panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: show_assets(index))
		card.player.add_theme_color_override("font_color", GameLook.readable_text_color(Color(str(view.players[index].color)), screen.get_theme_color("panel", "GamePalette")))
		player_cards.append(card)


func _place_history() -> void:
	var split: bool = view.get("players", []).size() > 3
	right_ledger.visible = split; history_panel.visible = not split
	var target: VBoxContainer = history_dialog.body if split else history_body
	if activity.get_parent() != target: activity.reparent(target)
	activity.entry_font_size = 17 if split else 13
	if not split: history_dialog.overlay.hide()


func render_clocks(value: Dictionary) -> void:
	var parts: Array[String] = []
	if view.get("phase", "") == "finished":
		clock.text = str(view.get("status", "")); clock.accessibility_name = clock.text; clock.modulate.a = 1; return
	if view.get("paused", false) or view.get("phase", "") in ["setup", "trade"]: parts.append(str(view.get("status", "")))
	if value.get("game_enabled", false): parts.append("GAME " + _time(float(value.game)))
	if value.get("turn_enabled", false): parts.append("TURN " + _time(float(value.turn)))
	clock.text = "   ·   ".join(parts)
	clock.accessibility_name = clock.text
	clock.modulate.a = 1 if value.get("running", false) else .65


static func _time(seconds: float) -> String:
	var whole := int(ceil(maxf(0, seconds)))
	return "%d:%02d" % [int(whole / 60), whole % 60]


func _locked() -> bool:
	return view.get("paused", true) or view.get("animating", false) or view.get("autoplay", false)


func _build_actions() -> void:
	for child in actions.get_children():
		if child != replay: actions.remove_child(child); child.queue_free()
	if view.get("phase", "") == "finished":
		_add_history_button(); return
	for choice in view.get("actions", []):
		var action: String = choice.payload.action
		if choice.payload.has("property") or action in ["offer_trade", "bid", "pass_bid", "keep_mortgage", "redeem_transfer", "accept_trade", "decline_trade", "pay_debt", "bankrupt"]: continue
		_button(actions, str(choice.label), func() -> void: host.local_action(choice.payload), action in ["roll", "buy", "end"], _locked())
	if host.host_plays and view.get("actions", []).any(func(choice: Dictionary) -> bool: return choice.payload.action == "offer_trade"):
		_button(actions, "TRADE", show_trade, false, _locked())
	if host.host_plays and view.get("actor", -1) == 0 and view.phase in ["auction", "debt", "transfer", "trade", "building_interest"]: _button(actions, "RESOLVE", func() -> void: _refresh_decision(true), true, _locked())
	_add_history_button()


func _add_history_button() -> void:
	if view.get("players", []).size() > 3:
		history_button = _button(actions, "HISTORY", func() -> void:
			history_dialog.overlay.visible = not history_dialog.overlay.visible)
		history_button.toggle_mode = true; history_button.set_pressed_no_signal(history_dialog.overlay.visible)


func _card_data(property: Dictionary) -> Dictionary:
	return host.CardFace.decorate(property, host.skin.get("labels", {}))


func show_property(id: int) -> void:
	if not host.rules.properties.has(id): return
	selected_property = id; board.selected = id; board.queue_redraw()
	var matches: Array = view.properties.filter(func(item: Dictionary) -> bool: return int(item.id) == id)
	var property: Dictionary = matches[0] if not matches.is_empty() else host.rules.properties[id].duplicate(true)
	if not property.has("owner"): property.owner = -1; property.owner_name = "Bank"
	var commands: Array = []
	if not _locked():
		for choice in view.get("actions", []):
			if choice.payload.get("property", -1) == id:
				commands.append({"label": str(choice.label), "callback": func() -> void: reader.close(); assets_dialog.overlay.hide(); host.local_action(choice.payload)})
	reader.show_card(_card_data(property), GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % property.key), Color(property.color), commands)
	reader.set_subtitle("Owned by " + str(property.owner_name) if int(property.owner) >= 0 else "Available from the Bank")


func show_assets(owner := -1) -> void:
	assets_owner = owner; assets_revision = int(view.get("revision", -1))
	decision_dialog.overlay.hide(); _clear(assets_dialog.body); _clear(assets_dialog.actions)
	assets_dialog.heading.text = "Properties" if owner < 0 else str(host.seats[owner].display_name) + "'s properties"
	for seat in view.get("players", []).size():
		if owner >= 0 and seat != owner: continue
		var player: Dictionary = view.players[seat]
		_label(assets_dialog.body, "%s · $%d cash · $%d total wealth" % [str(player.display_name), int(player.cash), int(player.wealth)])
		var entries: Array = []
		for property in view.properties:
			if int(property.owner) != seat: continue
			var caption := "MORTGAGED" if property.mortgaged else "HOTEL" if int(property.buildings) == 5 else "%d houses" % int(property.buildings) if int(property.buildings) > 0 else "Rent $%d" % int(property.rent)
			entries.append({"card": _card_data(property), "texture": GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % property.key), "tint": Color(property.color), "caption": caption})
		if entries.is_empty(): _label(assets_dialog.body, "No properties yet.")
		else:
			var grid := GameCardGrid.new(); grid.preferred_width = 128; grid.maximum_columns = 6; grid.left_aligned = true
			assets_dialog.body.add_child(grid); grid.set_items(entries); grid.card_pressed.connect(func(card: Dictionary) -> void: show_property(int(card.id)))
	_button(assets_dialog.actions, "BACK", func() -> void: assets_dialog.overlay.hide())
	assets_dialog.overlay.show()


func _refresh_decision(force := false) -> void:
	if view.get("animating", false): decision_dialog.overlay.hide(); return
	if not host.host_plays or view.get("actor", -1) != 0 or not view.phase in ["auction", "debt", "transfer", "trade", "building_interest"]:
		decision_dialog.overlay.hide(); return
	var key := str(view.get("decision_key", ""))
	var should_show := force or key != opened_decision
	if not force and decision_revision == int(view.revision): return
	decision_revision = int(view.revision); opened_decision = key
	_clear(decision_dialog.body); _clear(decision_dialog.actions)
	decision_dialog.heading.text = str(view.status)
	if view.phase == "auction":
		var auction: Dictionary = view.auction
		_label(decision_dialog.body, "Last %s auction" % str(auction.building).capitalize() if auction.get("kind") == "building" else host.property_name(int(auction.property)))
		_label(decision_dialog.body, "Highest bid: $%d" % int(auction.amount))
		var bid: Dictionary = host.Computer._find(view.actions, "bid")
		if not bid.is_empty():
			var amount := screen.add_number_control(decision_dialog.body, "Your bid", int(bid.amount), int(view.players[0].cash), 1, int(bid.amount), " dollars")
			var placement: OptionButton
			var destinations: Array = auction.get("eligible", {}).get("0", [])
			if auction.get("kind") == "building":
				var names: Array[String] = []
				for id in destinations: names.append(host.property_name(int(id)))
				placement = screen.add_choice_control(decision_dialog.body, "Place on", names, true)
			_button(decision_dialog.actions, "BID", func() -> void:
				var payload := {"action": "bid", "amount": int(amount.value)}
				if placement != null: payload.property = int(destinations[placement.selected])
				host.local_action(payload), true, _locked())
		_button(decision_dialog.actions, "PASS", func() -> void: host.local_action({"action": "pass_bid"}), false, _locked())
	elif view.phase == "building_interest":
		_label(decision_dialog.body, "The bank has one %s left. Request it for one of your eligible streets, or pass. Competing requests go to auction." % str(view.building_sale.kind))
		for choice in view.actions:
			var label: String = "Request for " + host.property_name(int(choice.payload.property)) if choice.payload.action == "claim_building" else str(choice.label)
			_button(decision_dialog.actions, label, func() -> void: host.local_action(choice.payload), choice.payload.action == "claim_building", _locked())
	elif view.phase == "debt":
		_label(decision_dialog.body, "Cash: $%d · Owed: $%d" % [int(view.players[0].cash), int(view.debt.amount)])
		_button(decision_dialog.body, "MANAGE PROPERTIES", func() -> void: show_assets(0))
		_button(decision_dialog.body, "OFFER TRADE", show_trade, false, _locked())
		for choice in view.actions:
			if choice.payload.action in ["pay_debt", "bankrupt"]: _button(decision_dialog.actions, str(choice.label), func() -> void: host.local_action(choice.payload), true, _locked())
	elif view.phase == "transfer":
		_label(decision_dialog.body, host.property_name(int(view.transfer.property)))
		for choice in view.actions: _button(decision_dialog.actions, str(choice.label), func() -> void: host.local_action(choice.payload), true, _locked())
	else:
		var offer: Dictionary = view.trade
		_trade_preview(decision_dialog.body, offer)
		for choice in view.actions: _button(decision_dialog.actions, str(choice.label), func() -> void: host.local_action(choice.payload), choice.payload.action == "accept_trade", _locked())
	if should_show and not reader.visible: decision_dialog.overlay.show()


func _trade_preview(parent: Control, offer: Dictionary) -> void:
	var columns := GridContainer.new(); columns.columns = 2; columns.add_theme_constant_override("h_separation", 14); parent.add_child(columns)
	for pair in [["give", "You receive", int(offer.from)], ["take", "You give", int(offer.to)]]:
		var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; columns.add_child(column)
		_label(column, str(pair[1]) + " · " + str(view.players[int(pair[2])].display_name))
		var amount := _label(column, "$%d" % int(offer.get(str(pair[0]) + "_cash", 0))); amount.add_theme_color_override("font_color", Color("73ed9a")); amount.add_theme_font_size_override("font_size", 22)
		var entries: Array = []
		for id in offer.get(str(pair[0]) + "_properties", []):
			var property: Dictionary = view.properties.filter(func(item: Dictionary) -> bool: return int(item.id) == int(id))[0]
			entries.append({"card":_card_data(property), "texture":GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % property.key), "tint":Color(property.color)})
		for deck in offer.get(str(pair[0]) + "_jail", []):
			var card: Dictionary = host.rules.definition[deck].filter(func(item: Dictionary) -> bool: return item.effect == "jail_free")[0]
			entries.append({"card":_card_data(card), "texture":GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % card.key)})
		var grid := GameCardGrid.new(); grid.preferred_width = 116; grid.left_aligned = true; column.add_child(grid); grid.set_items(entries)
	columns.resized.connect(func() -> void: columns.columns = 1 if parent.size.x < 440 else 2)


func show_trade() -> void:
	if _locked() or not host.host_plays: return
	reader.close(); decision_dialog.overlay.hide(); assets_dialog.overlay.hide()
	_clear(trade_dialog.body); _clear(trade_dialog.actions)
	trade_dialog.heading.text = "Offer a trade"
	var candidates: Array = view.players.filter(func(player: Dictionary) -> bool: return int(player.seat) != 0 and not player.bankrupt)
	if candidates.is_empty(): return
	var names: Array[String] = []
	for player in candidates: names.append(str(player.display_name))
	var opponent := screen.add_choice_control(trade_dialog.body, "Trade with", names, true)
	var contents := VBoxContainer.new(); trade_dialog.body.add_child(contents)
	var populate := func(index: int) -> void:
		_clear(contents); _clear(trade_dialog.actions)
		var other := int(candidates[index].seat)
		var numbers := GridContainer.new(); numbers.columns = 2; numbers.add_theme_constant_override("h_separation", 16); contents.add_child(numbers)
		var give_cash := screen.add_number_control(numbers, "You give", 0, int(view.players[0].cash), 1, 0, " dollars")
		var take_cash := screen.add_number_control(numbers, "You request", 0, int(view.players[other].cash), 1, 0, " dollars")
		give_cash.custom_minimum_size.x = 190; take_cash.custom_minimum_size.x = 190
		for field in [give_cash, take_cash]: field.get_parent_control().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var giving: Array = []; var taking: Array = []; var give_jail: Array = []; var take_jail: Array = []
		var portfolios := GridContainer.new(); portfolios.columns = 2; portfolios.add_theme_constant_override("h_separation", 16); contents.add_child(portfolios)
		for pair in [[0, giving, give_jail, "Your properties"], [other, taking, take_jail, "Their properties"]]:
			var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; portfolios.add_child(column)
			_label(column, str(pair[3]))
			var entries: Array = []
			for property in view.properties:
				if int(property.owner) != int(pair[0]): continue
				var developed: bool = view.properties.any(func(item: Dictionary) -> bool: return item.group == property.group and int(item.buildings) > 0)
				entries.append({"card":_card_data(property), "texture":GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % property.key), "tint":Color(property.color), "disabled":developed, "caption":"Sell buildings first" if developed else "Mortgaged" if property.mortgaged else "$%d" % int(property.price)})
			if entries.is_empty(): _label(column, "No properties")
			else:
				var grid := GameCardGrid.new(); grid.selectable = true; grid.preferred_width = 112; grid.left_aligned = true
				grid.name = "GiveProperties" if int(pair[0]) == 0 else "TakeProperties"
				column.add_child(grid); grid.set_items(entries)
				grid.selection_changed.connect(func(ids: Array) -> void: pair[1].assign(ids))
			var jail_entries: Array = []
			for deck in host.rules.s.held[int(pair[0])]:
				var jail: Dictionary = host.rules.definition[deck].filter(func(card: Dictionary) -> bool: return card.effect == "jail_free")[0].duplicate(true)
				jail.id = str(deck)
				jail_entries.append({"card":_card_data(jail), "texture":GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % jail.key), "caption":"Jail Free"})
			if not jail_entries.is_empty():
				var grid := GameCardGrid.new(); grid.selectable = true; grid.preferred_width = 112; grid.left_aligned = true
				column.add_child(grid); grid.set_items(jail_entries)
				grid.selection_changed.connect(func(ids: Array) -> void: pair[2].assign(ids))
		var fit_columns := func() -> void:
			numbers.columns = 1 if contents.size.x < 490 else 2; portfolios.columns = numbers.columns
		contents.resized.connect(fit_columns); fit_columns.call_deferred()
		var revision := int(view.revision)
		_button(trade_dialog.actions, "SEND OFFER", func() -> void:
			trade_dialog.overlay.hide(); host.local_action({"action": "offer_trade", "revision": revision, "to": other, "give_cash": int(give_cash.value), "take_cash": int(take_cash.value), "give_properties": giving, "take_properties": taking, "give_jail": give_jail, "take_jail": take_jail}), true)
		_button(trade_dialog.actions, "CANCEL", func() -> void: trade_dialog.overlay.hide())
	opponent.item_selected.connect(populate); populate.call(0); trade_dialog.overlay.show()


func show_resume(problem: String) -> void:
	_clear(resume_dialog.body); _clear(resume_dialog.actions)
	resume_dialog.heading.text = "Resume Monopoly Classic?"
	_label(resume_dialog.body, "An unfinished game is saved." if problem.is_empty() else problem)
	_button(resume_dialog.actions, "RESUME", func() -> void: host.resume_game(), true, not problem.is_empty())
	_button(resume_dialog.actions, "NEW GAME", func() -> void: host._new_round(false))
	resume_dialog.overlay.show()


func shutdown() -> void:
	reader.close(); effects.clear(); screen.background_media.set_active(false)
	for dialog in [assets_dialog, decision_dialog, trade_dialog, resume_dialog, history_dialog]: dialog.overlay.hide()
