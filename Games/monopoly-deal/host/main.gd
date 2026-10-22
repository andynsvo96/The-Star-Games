extends BaseGame

signal card_sound_played(cue: String)

const Rules = preload("res://Games/monopoly-deal/host/rules.gd")
const Computer = preload("res://Games/monopoly-deal/host/ai.gd")
const Table = preload("res://Games/monopoly-deal/host/table.gd")
var rules := Rules.new()
var skins := ThemePacks.new("monopoly-deal")
var skin: Dictionary = {}
var screen: GameScreen
var turn_strip := GameTurnStrip.new()
var feedback := Label.new()
var history_button: Button
var history_dialog: Dictionary
var table: Control
var replay: Button
var decision: Dictionary
var reader: GameCardReader
var focused_card := -1
var focused_side := 0
var card_motion := GameCardMotion.new()
var seats: Array = []
var missing: Array[String] = []
var host_plays := false
var stopped := false
var result_sent := false
var wins: Array = []
var completed_history: Array = []
var difficulty := 1
var computer_count := 2
var pending_difficulty := 1
var pending_count := 2
var pending_theme := "default"
var theme_choice: OptionButton
var difficulty_choice: OptionButton
var count_choice: OptionButton
var apply_button: Button
var theme_options: Array = []
var ai_timer := Timer.new()
var motion_timer := Timer.new()
var animating := false
var sounds: Dictionary = {}
var queued_sounds: Array[Dictionary] = []
var drawn_cards: Array[Dictionary] = []
var stock_reshuffled := false
var selected_payment: Array = []
var selected_revision := -1
var inspection: Dictionary
var inspected_seat := -1
var inspected_group := -1
var settings_button: Button
var settings_open := false
var turn_timer_enabled := true
var pending_turn_timer_enabled := true
var turn_timer_toggle: Button
var turn_seconds := 60.0
var pending_turn_seconds := 60.0
var turn_remaining := 60.0
var turn_length: SpinBox
var clock_key := ""
var clock_running := false
var clock_updated_usec := 0
var clock_second := -1
var notice_id := -1
var notice_text := ""
var notice_until := 0
var action_effect := GameCardEffect.new()
var celebration := GameCelebration.new()
var celebrated_round := -1
var action_highlights: Array = []
var parallel_ready := false
var decision_stamp := ""
var payment_stamp := ""


func _ready() -> void:
	rules.card_drawn.connect(func(id: int, seat: int) -> void: drawn_cards.append({"id": id, "seat": seat}))
	rules.stock_shuffled.connect(func() -> void: stock_reshuffled = true)
	screen = GameScreen.new(); add_child(screen); screen.configure("Monopoly Deal")
	screen.use_playful_style("res://Games/monopoly-deal/art/table", "modern-table")
	screen.use_table_header(RuntimeAssets.texture("res://Games/monopoly-deal/art/title.svg"))
	turn_strip.tracked = true
	screen.set_table_header_content(turn_strip)
	screen.exit_requested.connect(return_to_lobby); screen.scores.hide()
	var layout := screen.add_centered_layout()
	table = Table.new(); table.card_selected.connect(_select_card); table.end_turn.connect(func() -> void: _local({"action": "end"})); layout.playfield.add_child(table)
	table.card_inspected.connect(_inspect_card); table.public_requested.connect(_show_public); table.group_requested.connect(_inspect_group)
	replay = _button("Play Again", _replay); layout.playfield.add_child(replay); replay.hide()
	var footer := VBoxContainer.new(); footer.custom_minimum_size.y = 76; layout.playfield.add_child(footer)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; feedback.clip_text = true; feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	feedback.add_theme_font_size_override("font_size", 15); footer.add_child(feedback)
	var toolbar := HBoxContainer.new(); footer.add_child(toolbar); table.action_row.reparent(toolbar)
	table.action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_dialog = screen.add_phase_dialog(false, false, false, true); history_dialog.heading.text = "History"
	table.activity_log.show_heading = false; table.activity_log.bold_latest = true; table.activity_log.entry_font_size = 17
	history_dialog.body.add_child(table.activity_log); history_dialog.actions.add_child(_button("CLOSE", func() -> void: history_dialog.overlay.hide()))
	history_button = _button("HISTORY", func() -> void: history_dialog.overlay.visible = not history_dialog.overlay.visible)
	history_button.toggle_mode = true; GameLook.action(history_button, false); history_button.custom_minimum_size.x = 92; toolbar.add_child(history_button)
	history_dialog.overlay.visibility_changed.connect(func() -> void: history_button.set_pressed_no_signal(history_dialog.overlay.visible))
	screen.center_board(table, replay, footer, 0.5, true, true, true)
	replay.set_meta("permanent_action", true); replay.reparent(table.action_row)
	var panels := screen.add_corner_details(["SETTINGS"], Callable(), true, false, false, true, true)
	settings_button = panels[0].get_meta("toggle_button")
	settings_button.toggled.connect(_set_settings_open)
	theme_choice = screen.add_choice_control(panels[0], "Theme", ["Default"], true)
	theme_choice.item_selected.connect(func(index: int) -> void: pending_theme = theme_options[index].id; _refresh_options())
	difficulty_choice = screen.add_choice_control(panels[0], "AI Difficulty", ["Easy", "Medium", "Hard"], true)
	difficulty_choice.item_selected.connect(func(index: int) -> void: pending_difficulty = index; _refresh_options())
	count_choice = screen.add_choice_control(panels[0], "Computer Players", ["1", "2", "3", "4"], true)
	count_choice.item_selected.connect(func(index: int) -> void: pending_count = index + 1; _refresh_options())
	turn_timer_toggle = screen.add_toggle_control(panels[0], "Turn Timer", true)
	turn_timer_toggle.toggled.connect(func(on: bool) -> void: pending_turn_timer_enabled = on; _refresh_options())
	turn_length = screen.add_number_control(panels[0], "Turn time", 0.1, 60, 0.1, 1, " min")
	turn_length.value_changed.connect(func(value: float) -> void: pending_turn_seconds = value * 60; _refresh_options())
	apply_button = _button("Apply & New Game", _apply_options); panels[0].add_child(apply_button)
	decision = screen.add_phase_dialog(true, false, true, true)
	inspection = screen.add_phase_dialog(true, false, false, true)
	inspection.overlay.visibility_changed.connect(func() -> void: if not inspection.overlay.visible: table.clear_group_selection())
	inspection.actions.add_child(_button("Close", func() -> void: inspection.overlay.hide()))
	reader = GameCardReader.new(); reader.theme = screen.theme; add_child(reader)
	reader.preview.option_selected.connect(_preview_selected)
	add_child(action_effect); add_child(celebration); celebration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ai_timer.one_shot = true; ai_timer.wait_time = 0.65; add_child(ai_timer); ai_timer.timeout.connect(_computer_turn)
	motion_timer.one_shot = true; motion_timer.wait_time = 0.28; add_child(motion_timer); motion_timer.timeout.connect(func() -> void:
		animating = false
		_pump_card_audio()
		if not _finish_timeout(): _publish())
	screen.board_space_changed.connect(_resize_table); screen.resized.connect(_resize_table)


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new(); button.theme = screen.theme; button.text = caption; button.custom_minimum_size.y = 44; button.pressed.connect(callback); GameLook.action(button, true); return button


func _paused() -> bool:
	return settings_open or not missing.is_empty()


func _set_settings_open(open: bool) -> void:
	_settle_clock(); settings_open = open
	if open:
		reader.close(); inspection.overlay.hide(); decision.overlay.hide(); history_dialog.overlay.hide(); ai_timer.stop()
		for audio in sounds.values(): audio.stop()
	motion_timer.paused = _paused()
	if not rules.hands.is_empty(): _publish()


func _clock_active() -> bool:
	return turn_timer_enabled and not stopped and not _paused() and not animating and rules.winner < 0 and _actor() == rules.turn and turn_remaining > 0


func _settle_clock(now_usec := -1) -> void:
	if now_usec < 0: now_usec = Time.get_ticks_usec()
	if rules.hands.is_empty() or stopped:
		clock_updated_usec = now_usec; clock_running = false; return
	var current := "%d:%d" % [rules.round_number, rules.turn]
	if current != clock_key:
		clock_key = current; turn_remaining = turn_seconds
	elif turn_timer_enabled and clock_running and clock_updated_usec > 0:
		turn_remaining = maxf(0, turn_remaining - maxf(0, (now_usec - clock_updated_usec) / 1000000.0))
	clock_updated_usec = now_usec; clock_running = _clock_active()


func _clock_view() -> Dictionary:
	return {"key": clock_key, "enabled": turn_timer_enabled, "seconds": turn_seconds, "remaining": turn_remaining, "running": clock_running}


func _finish_timeout() -> bool:
	if not turn_timer_enabled or stopped or rules.hands.is_empty() or _paused() or animating or turn_remaining > 0: return false
	var before := _locations()
	drawn_cards.clear(); stock_reshuffled = false
	if not rules.end_timed_turn(): return false
	focused_card = -1; table.selected_card = -1; reader.close(); decision.overlay.hide(); selected_payment.clear(); table.armed_doubles.clear()
	_animate_changes(before); _publish(); return true


func _process(_delta: float) -> void:
	if stopped or rules.hands.is_empty(): return
	_pump_card_audio()
	_settle_clock()
	if _finish_timeout(): return
	var second := ceili(turn_remaining) if turn_timer_enabled else -2
	if notice_until > 0 and Time.get_ticks_msec() >= notice_until:
		notice_text = ""; notice_until = 0; _display_status(_status())
	if second == clock_second: return
	clock_second = second
	_display_status(_status())
	broadcast_state({"type": "turn_clock", "clock": _clock_view()})


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context); screen.background_media.reduced_motion = context.reduced_motion
	var saved := load_game_settings({"difficulty": 1, "computers": 2, "theme": "default", "turn_timer_enabled": true, "turn_seconds": 60.0})
	turn_timer_enabled = bool(saved.turn_timer_enabled); pending_turn_timer_enabled = turn_timer_enabled
	turn_seconds = float(saved.turn_seconds) if is_finite(float(saved.turn_seconds)) and float(saved.turn_seconds) >= 6 and float(saved.turn_seconds) <= 3600 else 60.0
	pending_turn_seconds = turn_seconds; turn_length.set_value_no_signal(turn_seconds / 60)
	difficulty = int(saved.difficulty) if saved.difficulty in [0, 1, 2] else 1; computer_count = int(saved.computers) if saved.computers in [1, 2, 3, 4] else 2
	pending_difficulty = difficulty; pending_count = computer_count; skin = skins.pin(str(saved.theme)); pending_theme = str(skin.id)
	host_plays = context.players.is_empty(); _make_seats(); wins.resize(seats.size()); wins.fill(0); rules.start(seats.size(), randi_range(0, seats.size() - 1) if host_plays else 0)
	theme_options = skins.list_packs(); theme_choice.clear()
	for pack in theme_options: theme_choice.add_item(pack.name)
	_load_sounds(); _refresh_options()


func _make_seats() -> void:
	seats = [session.solo_profile.duplicate(true)] if host_plays else session.players.duplicate(true)
	for player in seats: player.ai = false
	var count := 1 + computer_count if host_plays else 2 if seats.size() == 1 else seats.size()
	var palette := ["#2463eb", "#e53935", "#ae39f2", "#08a750", "#f7cf05"]
	while seats.size() < count:
		var index := seats.size(); var used: Array = seats.map(func(player: Dictionary) -> String: return str(player.get("color", "")).to_lower())
		var available: Array = palette.filter(func(tint: String) -> bool: return not used.has(tint))
		seats.append({"id": "deal-ai-%d" % index, "display_name": "Computer %d" % index, "color": available[0], "pose": index % 6, "ai": true})


func start_game() -> void:
	screen.background_media.transition_to("res://Games/monopoly-deal/art/table", false); _start_deal(); _publish(); _resize_table.call_deferred()


func _start_deal() -> void:
	var flights: Array = []
	for index in 5:
		for seat in seats.size(): flights.append({"from": {"zone": "deck", "seat": -1}, "to": {"zone": "hand", "seat": seat}, "card": rules.cards[rules.hands[seat][index]]})
	for index in range(5, rules.hands[rules.turn].size()): flights.append({"from": {"zone": "deck", "seat": -1}, "to": {"zone": "hand", "seat": rules.turn}, "card": rules.cards[rules.hands[rules.turn][index]]})
	_begin_motion(flights, true)


func _begin_motion(flights: Array, shuffle := false) -> void:
	var elapsed := card_motion.duration - motion_timer.time_left if animating and parallel_ready else 0.0
	if animating and parallel_ready: card_motion.append(flights, elapsed, action_highlights)
	else: card_motion.begin(flights, shuffle, action_highlights)
	action_highlights.clear(); animating = not session.reduced_motion and card_motion.duration > elapsed
	motion_timer.stop(); motion_timer.paused = _paused()
	if animating: motion_timer.start(card_motion.duration - elapsed)
	drawn_cards.clear(); stock_reshuffled = false
	_queue_card_audio(elapsed)


func _locations() -> Dictionary:
	var result: Dictionary = {}
	for id in rules.deck: result[id] = {"zone": "deck", "seat": -1}
	for id in rules.discard: result[id] = {"zone": "discard", "seat": -1}
	for seat in seats.size():
		for id in rules.hands[seat]: result[id] = {"zone": "hand", "seat": seat}
		for id in rules.banks[seat] + rules.loose[seat]: result[id] = {"zone": "bank", "seat": seat}
		for group in rules.properties[seat]:
			for id in group.cards + group.buildings: result[id] = {"zone": "property", "seat": seat, "group": group.id, "color": group.color}
	return result


func _animate_changes(before: Dictionary) -> void:
	var after := _locations(); var flights: Array = []; var reshuffled := stock_reshuffled
	var drawn_ids: Array = drawn_cards.map(func(draw: Dictionary) -> int: return int(draw.id))
	for id in after:
		if drawn_ids.has(id):
			if before.has(id) and not before[id].zone in ["deck", "discard"]:
				flights.append({"from": before[id], "to": {"zone": "discard", "seat": -1}, "card": rules.cards[id].duplicate(true)})
			continue
		if not before.has(id) or before[id] == after[id]: continue
		if after[id].zone == "deck":
			reshuffled = reshuffled or before[id].zone == "discard"; continue
		var card: Dictionary = rules.cards[id].duplicate(true)
		if card.kind == "wild" and card.colors.size() == 2 and after[id].get("color", "") == card.colors[1]: card.face_side = 1
		flights.append({"from": before[id], "to": after[id], "card": card})
	# Capture pickups even when a recycled card returns to the same player's hand.
	for draw in drawn_cards:
		flights.append({"from": {"zone": "deck", "seat": -1}, "to": {"zone": "hand", "seat": int(draw.seat)}, "card": rules.cards[int(draw.id)].duplicate(true)})
	# Resolve played/discarded cards before the following turn's pickup.
	flights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.from.zone != "deck" and b.from.zone == "deck")
	_begin_motion(flights, reshuffled)


func _load_sounds() -> void:
	screen.background_media.reload_assets()
	if screen.table_title_art != null: screen.table_title_art.texture = RuntimeAssets.texture("res://Games/monopoly-deal/art/title.svg")
	for child in screen.content.get_children():
		if child is TextureRect: child.texture = RuntimeAssets.texture("res://Games/monopoly-deal/art/title.svg")
	for child in sounds.values(): child.stop(); child.stream = null; child.queue_free()
	sounds.clear(); queued_sounds.clear()
	var files := {"deal": "card-shuffle.ogg", "play": "card-place-1.ogg", "bank": "card-place-2.ogg", "action": "card-slide-1.ogg", "cash": "cash-register.wav", "stop": "stop-buzzer.wav", "win": "win.wav"}
	for cue in files:
		var audio := AudioStreamPlayer.new(); audio.bus = "Effects"; audio.max_polyphony = 6
		audio.volume_db = -12 if cue == "deal" else -10 if cue == "action" else -4 if cue == "cash" else -7 if cue != "win" else 0
		audio.stream = RuntimeAssets.audio("res://Games/monopoly-deal/audio/" + files[cue]); add_child(audio); sounds[cue] = audio


func _queue_card_audio(elapsed := 0.0) -> void:
	queued_sounds.clear()
	for cue in sounds:
		if cue != "win": sounds[cue].stop()
	if card_motion.shuffle > 0: queued_sounds.append({"cue": "deal", "time": 0.0})
	for flight in card_motion.flights:
		var source: String = flight.from.zone; var destination: String = flight.to.zone
		if source == "deck" or source in ["bank", "property"]:
			queued_sounds.append({"cue": "action", "time": float(flight.delay)})
		if source != "deck":
			queued_sounds.append({"cue": "bank" if destination == "bank" else "play", "time": float(flight.delay) + float(flight.duration)})
		if destination == "bank" and source in ["bank", "property"] and int(flight.from.seat) != int(flight.to.seat):
			queued_sounds.append({"cue": "cash", "time": float(flight.delay) + float(flight.duration)})
	for effect in card_motion.effects:
		if effect.card.kind == "just-say-no": queued_sounds.append({"cue": "stop", "time": float(effect.get("start", 0))})
	queued_sounds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	if elapsed > 0: queued_sounds = queued_sounds.filter(func(event: Dictionary) -> bool: return float(event.time) >= elapsed)
	if session.reduced_motion:
		# Immediate placements need one compact cue per kind, without a delayed deal.
		var seen: Array[String] = []; var compact: Array[Dictionary] = []
		for event in queued_sounds:
			if event.cue in seen: continue
			seen.append(event.cue); compact.append({"cue": event.cue, "time": 0.0})
		queued_sounds = compact
	_pump_card_audio()


func _pump_card_audio() -> void:
	if stopped or _paused(): return
	var elapsed := card_motion.duration - motion_timer.time_left if animating else card_motion.duration
	# A stalled frame must not burst every overdue pickup sound at once.
	var due: Dictionary = {}
	while not queued_sounds.is_empty() and float(queued_sounds[0].time) <= elapsed:
		var event: Dictionary = queued_sounds.pop_front(); due[event.cue] = true
	for cue in due: _play_sound(cue)


func _play_sound(cue: String) -> void:
	if not stopped and not _paused() and sounds.has(cue) and sounds[cue].stream != null:
		sounds[cue].play(); card_sound_played.emit(cue)


func _resize_table() -> void:
	if not is_instance_valid(table): return
	table.activity_log.custom_minimum_size.y = maxf(100, minf(400, screen.available_size().y - 270))
	var width := minf(1800, screen.available_size().x - 40)
	var height := maxf(160, minf(screen.board_height_limit(), 1080))
	table.custom_minimum_size = Vector2(maxf(240, width), height); table.queue_redraw()


func _status() -> String:
	if settings_open: return "Paused · host Settings is open"
	if not missing.is_empty(): return "Paused · waiting for " + ", ".join(seats.filter(func(player: Dictionary) -> bool: return missing.has(str(player.id))).map(func(player: Dictionary) -> String: return str(player.display_name)))
	if rules.winner >= 0: return str(seats[rules.winner].display_name) + " WINS!"
	if rules.phase in ["response", "pay"]:
		if rules.parallel_pending(): return "%s used %s · waiting for %d players" % [seats[int(rules.pending.actor)].display_name, _card_name(rules.cards[int(rules.pending.card)]), rules.pending.branches.size()]
		return _action_caption(rules.action_details())
	if rules.phase == "discard": return str(seats[rules.turn].display_name) + " · discard to 7 cards"
	var seconds := ceili(turn_remaining)
	var text := "%d plays left" % maxi(0, 3 - rules.plays)
	if turn_timer_enabled: text += " · %d:%02d" % [seconds / 60, seconds % 60]
	if not notice_text.is_empty():
		if screen.available_size().x < 800: return notice_text
		text += "\n" + notice_text
	return text


func _card_name(card: Dictionary) -> String:
	return str(skin.labels.get(card.key, card.name))


func _card_entry(source: Dictionary, caption := "") -> Dictionary:
	var card := source.duplicate(true); card.display_name = _card_name(card)
	var entry := {"card": card, "texture": GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % card.key)}
	if not card.colors.is_empty(): entry.tint = Color(rules.colors[card.colors[int(card.get("face_side", 0))]].color)
	if not caption.is_empty(): entry.caption = caption
	return entry


func _preview_options(card: Dictionary, options: Array) -> Array:
	if card.kind in ["money", "property"] or (card.kind == "wild" and card.colors.size() == 2): return []
	if options.is_empty() and card.kind == "wild": return []
	if card.kind == "double-rent":
		var rentals: Array = []
		for candidate in rules.rent_cards_for_double(0, int(card.id), table.armed_doubles):
			rentals.append({"label": "Rent $%d" % candidate.amount, "summary": "Choose a Rent card", "players": [], "rent_card": candidate.card.id, "groups": [{"key": "rent-card", "value": candidate.card.id, "owner": 0, "label": "Rent $%d" % candidate.amount, "player": seats[0].duplicate(true), "items": [_card_entry(candidate.card)]}]})
		if rentals.is_empty(): rentals.append({"label": _card_name(card), "summary": "No applicable Rent cards", "players": [], "groups": []})
		return rentals
	var items: Array = []
	for choice in options:
		var preview: Dictionary = rules.preview_for(0, choice.payload)
		var item := {"label": choice.label, "summary": preview.summary, "players": [], "items": [], "note": "Just Say No may counter this action." if preview.counterable else ""}
		if choice.payload.has("target"): item.label += " · " + str(seats[int(choice.payload.target)].display_name)
		for seat in preview.targets:
			var player: Dictionary = seats[int(seat)].duplicate(true)
			if int(preview.amount) > 0: player.amount = preview.amount
			if card.kind == "debt-collector":
				player.bank_total = 0
				for id in rules.banks[int(seat)]:
					player.bank_total += int(rules.cards[id].value); item.items.append(_card_entry(rules.cards[id]))
			item.players.append(player)
		if card.kind == "debt-collector": item.summary = ""; item.note = ""
		for affected in preview.cards: item.items.append(_card_entry(affected))
		item.groups = []
		for group in preview.groups:
			var section: Dictionary = group.duplicate(true); section.player = seats[int(group.owner)].duplicate(true); section.items = []
			for affected in group.cards: section.items.append(_card_entry(affected))
			item.groups.append(section)
		items.append(item)
	if items.is_empty(): items.append({"label": _card_name(card), "summary": str(card.detail), "players": [], "items": []})
	return items


func _preview_selected(index: int) -> void:
	if focused_card < 0 or rules.cards[focused_card].kind != "double-rent" or stopped or _paused() or animating: return
	var rentals: Array = rules.rent_cards_for_double(0, focused_card, table.armed_doubles)
	if index < 0 or index >= rentals.size(): return
	table.armed_doubles = rentals[index].doubles.duplicate()
	_select_card(rentals[index].card)


func _activity_entries() -> Array:
	var entries: Array = []
	for event in rules.activity:
		var actor := str(seats[int(event.seat)].display_name)
		var target := str(seats[int(event.target)].display_name) if int(event.get("target", -1)) >= 0 else "everyone"
		var card := _card_name(rules.cards[int(event.card)]) if event.has("card") else ""
		var detail := ""
		match str(event.kind):
			"bank": detail = "banked $%d" % int(event.amount)
			"property": detail = "added " + card
			"go": detail = "played %s · drew %d cards" % [card, int(event.amount)]
			"building", "move-building": detail = "placed " + card
			"move": detail = "moved " + card
			"discard": detail = "discarded " + card
			"no", "double": detail = "played " + card
			"rent", "debt", "birthday": detail = "played %s · $%d from %s" % [card, int(event.amount), target]
			"sly-deal", "forced-deal", "deal-breaker": detail = "played %s against %s" % [card, target]
			"take": detail = "took %s from %s" % [card, target]
			"exchange": detail = "exchanged %s for %s with %s" % [_card_name(rules.cards[int(event.give)]), card, target]
			"take-set": detail = "took a set from " + target
			"pay": detail = "paid $%d to %s" % [int(event.amount), target]
			"draw": detail = "drew %d cards" % int(event.amount)
			"end": detail = "ended their turn"
		if not detail.is_empty(): entries.append({"id": event.id, "text": actor + " " + detail})
	return entries


func _action_caption(details: Dictionary, viewer := -1) -> String:
	if int(details.get("responder", -1)) >= 0:
		return "Just Say No · %s countered %s%s" % [seats[int(details.responder)].display_name, _card_name(details.card), " (canceled)" if details.canceled else " (action continues)"]
	var chosen := "You were chosen" if int(details.target) == viewer else str(seats[int(details.target)].display_name) + " chosen"
	return "%s · %s by %s" % [_card_name(details.card), chosen, seats[int(details.actor)].display_name]


func _action_summary(details: Dictionary, viewer := -1) -> String:
	if details.is_empty(): return ""
	var actor := str(seats[int(details.actor)].display_name)
	var target := "you" if int(details.target) == viewer else str(seats[int(details.target)].display_name)
	var text := "%s used %s — %s chosen." % [actor, _card_name(details.card), "You were" if int(details.target) == viewer else target + " was"]
	if not details.get("modifiers", []).is_empty(): text += " With " + ", ".join(details.modifiers.map(func(card: Dictionary) -> String: return _card_name(card))) + "."
	if int(details.get("responder", -1)) >= 0:
		text += " %s played Just Say No%s" % [seats[int(details.responder)].display_name, " to cancel it." if details.canceled else " as a counter; the action continues."]
	if details.get("canceled", false): return text
	if details.get("outcome", "") == "paid": return text + (" No payable assets." if int(details.paid) == 0 else " Paid $%d to %s." % [details.paid, actor])
	if int(details.get("amount", 0)) > 0: text += " Pay $%d to %s." % [details.amount, actor]
	elif details.has("take_card"):
		text += " %s takes %s" % [actor, _card_name(details.take_card)]
		if details.has("give_card"): text += " and gives %s" % _card_name(details.give_card)
		text += "."
	elif details.has("set_color"): text += " %s takes the %s set and its buildings." % [actor, rules.colors[details.set_color].name]
	return text


func _resolve_automatic_choices() -> void:
	# Acknowledgement is unnecessary when the host offers no real alternative.
	# Never choose payment assets or consume a Just Say No on a player's behalf.
	while rules.winner < 0:
		var progressed := false
		for actor: int in rules.decision_actors():
			var choice: Dictionary = rules.decision_for(actor); var command: Dictionary = {}
			if choice.is_empty(): continue
			if choice.phase == "response":
				var offered: Array = rules.legal_actions(actor).filter(func(option: Dictionary) -> bool: return not rules.parallel_pending() or int(option.payload.target) == int(choice.target))
				if offered.size() == 1: command = offered[0].payload.duplicate(true)
			elif choice.phase == "pay" and rules.payment_assets(actor).is_empty(): command = rules.payment_command(actor, [])
			if command.is_empty(): continue
			command.revision = rules.revision
			if rules.apply(actor, command): progressed = true; break
		if not progressed: break


func _refresh_action_notice() -> void:
	for details in rules.action_notices:
		if int(details.id) <= notice_id: continue
		if host_plays and int(details.target) != 0 and int(details.get("responder", -1)) != 0 and not (int(details.actor) == 0 and int(details.get("responder", -1)) >= 0): continue
		notice_id = int(details.id); notice_text = _action_caption(details, 0 if host_plays else -1); notice_until = Time.get_ticks_msec() + 8000


func _snapshot(seat: int) -> Dictionary:
	var view := rules.view_for(seat)
	view.players = seats.map(func(player: Dictionary) -> Dictionary: return {"id": str(player.id), "display_name": str(player.display_name), "color": str(player.get("color", "#58d6ff")), "pose": clampi(int(player.get("pose", 0)), 0, 5), "ai": bool(player.ai)})
	view.status = _status(); view.paused = _paused(); view.pause_reason = "Host Settings is open" if settings_open else "Waiting for players"; view.animating = animating; view.reduced_motion = session.reduced_motion
	view.clock = _clock_view()
	view.activity_entries = _activity_entries()
	view.decisions_ready = rules.parallel_pending() and parallel_ready
	view.motion = card_motion.view(seat, card_motion.duration - motion_timer.time_left if animating else card_motion.duration, animating)
	view.session_wins = wins.duplicate(); view.theme = {"id": skin.id, "name": skin.name, "revision": skin.revision, "labels": skin.labels.duplicate(true)}
	return view


func _publish() -> void:
	if stopped: return
	if not rules.parallel_pending(): parallel_ready = false
	elif not animating: parallel_ready = true
	_settle_clock()
	var local := _snapshot(0 if host_plays else -1)
	action_effect.update(local.motion, _paused(), session.reduced_motion)
	celebration.set_process(not _paused())
	if rules.winner < 0: celebration.clear(); celebrated_round = -1
	elif not animating and celebrated_round != rules.round_number:
		reader.close(); inspection.overlay.hide()
		celebrated_round = rules.round_number; celebration.show_win([], str(seats[rules.winner].display_name) + " WINS!", Color("ffd447"), not session.reduced_motion)
	table.state = local; table.queue_redraw(); _display_status(local.status); replay.visible = rules.winner >= 0; replay.disabled = _paused() or animating
	turn_strip.set_players(local.players, -1 if rules.winner >= 0 or _paused() else rules.turn)
	if _paused(): decision.overlay.hide(); decision_stamp = ""
	if selected_revision != rules.revision:
		table.armed_doubles.clear()
	selected_revision = rules.revision
	_refresh_reader(); _refresh_selection()
	if inspection.overlay.visible: _refresh_inspection()
	var local_decision: Dictionary = rules.decision_for(0) if host_plays else {}
	if local_decision.is_empty() and not (host_plays and rules.phase == "discard" and rules.turn == 0): decision.overlay.hide(); decision_stamp = ""; selected_payment.clear()
	elif not _paused() and (not animating or parallel_ready) and rules.winner < 0: _show_decision()
	_refresh_options(); broadcast_state(_snapshot(-1))
	for player in session.players:
		var seat := _seat_for(str(player.id))
		if seat >= 0: send_state(str(player.id), _snapshot(seat))
	ai_timer.stop()
	var actor := _computer_actor()
	if not _paused() and (not animating or parallel_ready) and actor >= 0: ai_timer.start()


func _actor() -> int:
	if rules.winner >= 0: return -1
	if rules.phase == "response": return int(rules.pending.ask)
	if rules.phase == "pay": return int(rules.pending.target)
	return rules.turn


func _display_status(text: String) -> void:
	screen.status.text = text; feedback.text = text.get_slice("\n", 0); feedback.accessibility_name = text


func _computer_actor() -> int:
	if rules.winner >= 0: return -1
	for seat: int in rules.decision_actors():
		if seats[seat].ai: return seat
	return -1


func _seat_for(id: String) -> int:
	for index in seats.size():
		if str(seats[index].id) == id and not seats[index].ai: return index
	return -1


func _action(seat: int, command: Dictionary) -> bool:
	_settle_clock()
	if _finish_timeout() or stopped or _paused() or (animating and not (parallel_ready and rules.parallel_pending() and command.get("action") in ["pay", "accept", "no"])): return false
	var before := _locations()
	drawn_cards.clear(); stock_reshuffled = false
	if not rules.apply(seat, command): return false
	var played_id := int(command.get("card", -1))
	if played_id >= 0 and command.get("action") in ["rent", "birthday", "debt", "sly-deal", "forced-deal", "deal-breaker", "no", "go", "building"]:
		var played: Dictionary = rules.cards[played_id]
		action_highlights = [{"card": played.duplicate(true), "art": "res://Games/monopoly-deal/art/%s.svg" % played.key, "display_name": _card_name(played), "label": str(seats[seat].display_name) + " used " + _card_name(played), "duration": 1.25 if played.kind == "just-say-no" else 1.05}]
	_resolve_automatic_choices(); _refresh_action_notice()
	table.armed_doubles.clear()
	if rules.winner >= 0 and not result_sent:
		result_sent = true; wins[rules.winner] += 1; completed_history.push_front("Game %d · %s wins" % [rules.round_number, seats[rules.winner].display_name])
		if not host_plays and seats.all(func(player: Dictionary) -> bool: return not player.ai):
			award_points(str(seats[rules.winner].id), 1)
			for index in seats.size(): report_result(str(seats[index].id), index == rules.winner)
		_play_sound("win")
	_animate_changes(before)
	_publish(); return true


func _local(command: Dictionary) -> void:
	var input := command.duplicate(true); input.revision = selected_revision; _action(0, input)


func _computer_turn() -> void:
	if stopped or _paused() or (animating and not parallel_ready): return
	var actors: Array = rules.decision_actors() if rules.parallel_pending() else [_computer_actor()]
	var decisions: Array = []
	for actor: int in actors:
		if actor < 0 or not seats[actor].ai: continue
		var command := Computer.choose(rules.view_for(actor), difficulty); command.revision = rules.revision
		if not command.is_empty(): decisions.append({"seat": actor, "command": command})
	for choice in decisions: _action(int(choice.seat), choice.command)


func handle_controller_message(player_id: String, message: Dictionary) -> void:
	var seat := _seat_for(player_id)
	if seat < 0 or stopped: return
	if message.get("action") == "sync": _settle_clock(); send_state(player_id, _snapshot(seat)); return
	_action(seat, message)


func player_disconnected(player_id: String) -> void:
	if _seat_for(player_id) < 0: return
	_settle_clock()
	if not missing.has(player_id): missing.append(player_id)
	ai_timer.stop(); motion_timer.paused = true
	for audio in sounds.values(): audio.stop()
	_publish()


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	_settle_clock(); missing.erase(str(player.get("id", ""))); motion_timer.paused = _paused(); _publish()


func _replay() -> void:
	if stopped or rules.winner < 0 or _paused() or animating: return
	focused_card = -1; table.selected_card = -1; table.selected_group_seat = -1; table.hand_scroll = 0; reader.close(); inspection.overlay.hide()
	notice_text = ""; notice_until = 0
	ai_timer.stop(); skin = skins.pin(str(skin.id)); rules.replay(); result_sent = false; _load_sounds(); _start_deal()
	screen.background_media.transition_to("res://Games/monopoly-deal/art/table", false); _publish()


func _refresh_options() -> void:
	if skin.is_empty(): return
	for index in theme_options.size():
		if theme_options[index].id == pending_theme: theme_choice.select(index)
	difficulty_choice.select(pending_difficulty); count_choice.select(pending_count - 1)
	turn_length.set_value_no_signal(pending_turn_seconds / 60)
	turn_timer_toggle.set_pressed_no_signal(pending_turn_timer_enabled)
	turn_timer_toggle.text = "Turn Timer: " + ("ON" if pending_turn_timer_enabled else "OFF")
	turn_length.get_parent().visible = pending_turn_timer_enabled
	count_choice.get_parent().visible = host_plays; difficulty_choice.get_parent().visible = seats.any(func(player: Dictionary) -> bool: return player.ai)
	for control in [theme_choice, difficulty_choice, count_choice]: control.disabled = not missing.is_empty() or stopped
	turn_timer_toggle.disabled = not missing.is_empty() or stopped
	turn_length.editable = pending_turn_timer_enabled and missing.is_empty() and not stopped
	apply_button.disabled = not missing.is_empty() or stopped or (pending_theme == skin.id and pending_difficulty == difficulty and pending_turn_timer_enabled == turn_timer_enabled and is_equal_approx(pending_turn_seconds, turn_seconds) and (not host_plays or pending_count == computer_count))


func _apply_options() -> void:
	if apply_button.disabled or pending_turn_seconds < 6 or pending_turn_seconds > 3600 or not is_finite(pending_turn_seconds) or not save_game_settings({"theme": pending_theme, "difficulty": pending_difficulty, "computers": pending_count, "turn_timer_enabled": pending_turn_timer_enabled, "turn_seconds": pending_turn_seconds}): return
	focused_card = -1; table.selected_card = -1; table.selected_group_seat = -1; table.hand_scroll = 0; reader.close(); inspection.overlay.hide()
	ai_timer.stop(); motion_timer.stop(); animating = false; decision.overlay.hide()
	difficulty = pending_difficulty; computer_count = pending_count; skin = skins.pin(pending_theme); turn_seconds = pending_turn_seconds; turn_timer_enabled = pending_turn_timer_enabled
	notice_text = ""; notice_until = 0
	var old := seats.duplicate(true); var old_wins := wins.duplicate(); _make_seats(); wins.clear()
	for player in seats:
		var found := -1
		for index in old.size():
			if old[index].id == player.id: found = index
		wins.append(old_wins[found] if found >= 0 else 0)
	rules.start(seats.size(), randi_range(0, seats.size() - 1) if host_plays else 0); result_sent = false; _load_sounds(); _start_deal()
	if settings_button.button_pressed: settings_button.button_pressed = false
	screen.background_media.transition_to("res://Games/monopoly-deal/art/table", false); _publish(); _resize_table()


func _clear_dialog() -> void:
	for parent in [decision.body, decision.actions]:
		for child in parent.get_children(): parent.remove_child(child); child.queue_free()


func _own_card(id: int) -> Dictionary:
	var view: Dictionary = rules.view_for(0)
	var owned: Array = view.hand.duplicate()
	for group in view.table[0].groups: owned.append_array(group.cards); owned.append_array(group.buildings)
	for card in owned:
		if int(card.id) == id: return card
	return {}


func _select_card(card: Dictionary) -> void:
	if not host_plays or stopped or _own_card(int(card.id)).is_empty(): return
	focused_card = int(card.id); focused_side = 0
	for group in rules.properties[0]:
		if group.cards.has(focused_card) and card.colors.size() == 2 and group.color == card.colors[1]: focused_side = 1
	table.selected_card = focused_card; table.selected_side = focused_side; table.queue_redraw(); _refresh_selection(); _open_selected()


func _open_selected() -> void:
	reader.stage.scroll_vertical = 0; _refresh_reader(true)


func _refresh_selection() -> void:
	var card := _own_card(focused_card) if host_plays and focused_card >= 0 else {}
	if card.is_empty(): focused_card = -1; table.selected_card = -1
	var commands: Array = [{"label": "Public Table", "kind": "bank", "callback": func() -> void: _show_public(-1)}]
	if host_plays: commands.append({"label": "Help", "kind": "bank", "callback": _help})
	var current: Dictionary = rules.decision_for(0) if host_plays else {}
	if not current.is_empty() or (host_plays and rules.phase == "discard" and rules.turn == 0): commands.append({"label": "Pay $%d" % rules.pending.amount if current.get("phase") == "pay" else "Resolve action", "callback": func() -> void: _show_decision(true)})
	if rules.winner >= 0: commands = []
	table.set_actions(commands, "%s:%s:%s:%s" % [host_plays, current.get("phase", ""), rules.revision if not current.is_empty() or rules.phase == "discard" else "", rules.winner])


func _refresh_reader(open := false, rotate := false) -> void:
	if focused_card < 0: return
	if not host_plays: reader.close(); return
	if not open and not reader.visible: return
	var card := _own_card(focused_card)
	if card.is_empty(): reader.close(); return
	card.display_name = skin.labels.get(card.key, card.name)
	var commands: Array = []
	if not _paused() and not animating and rules.phase == "play" and rules.turn == 0 and rules.winner < 0:
		var revision: int = rules.revision
		for choice in rules.legal_actions(0):
			if choice.payload.get("card", -1) == focused_card and choice.payload.action == "bank":
				var command: Dictionary = choice.payload
				commands.append({"label": "BANK" if card.kind == "money" else "Bank $%d" % card.value, "kind": "bank", "callback": func() -> void: _reader_submit(command, revision)})
		var options := rules.tap_choices(0, focused_card, false, table.armed_doubles)
		var action_card: bool = not card.kind in ["money", "property", "wild"]
		var paired_rent: bool = card.kind == "double-rent" and not rules.rent_cards_for_double(0, focused_card, table.armed_doubles).is_empty()
		if card.kind != "money" and (not options.is_empty() or (action_card and not paired_rent)): commands.append({"label": "Draw 2 cards" if card.kind == "pass-go" else "Add property" if card.kind in ["property", "wild"] and rules.hands[0].has(focused_card) else "Play card" if rules.hands[0].has(focused_card) else "Move card", "disabled": options.is_empty(), "callback": func() -> void:
			if rules.revision == revision and focused_card == int(card.id): _choose_card_play()})
	var preview_index := reader.preview.selected if reader.shown_id == int(card.id) else 0
	# The reader rotates its inner Control; public face metadata is for static
	# grids and must not apply a second rotation to this same wild.
	if card.kind == "wild" and card.colors.size() == 2: card.face_side = 0
	reader.show_card(card, GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % card.key), Color(rules.colors[card.colors[0]].color) if not card.colors.is_empty() else Color("17594d"), commands)
	if card.kind == "money": reader.heading.text = ""
	var previews := _preview_options(card, rules.tap_choices(0, focused_card, false, table.armed_doubles))
	reader.set_preview(previews, preview_index, "players" if card.kind == "debt-collector" and not previews[0].players.is_empty() else "cards")
	var reversible: bool = card.kind == "wild" and card.colors.size() == 2
	reader.set_rotation_options(reversible, focused_side, "Use as " + str(rules.colors[card.colors[focused_side]].name) if reversible else "", _rotate_card, session.reduced_motion, rotate)


func _rotate_card() -> void:
	if focused_card < 0: return
	focused_side = 1 - focused_side; table.selected_side = focused_side; table.queue_redraw(); _refresh_reader(false, true); _refresh_selection()


func _reader_submit(command: Dictionary, revision: int) -> void:
	if not host_plays or rules.revision != revision or stopped or animating or _paused(): return
	reader.close(); focused_card = -1; table.selected_card = -1; var input := command.duplicate(true); input.revision = revision; _action(0, input)


func _choose_card_play() -> void:
	if not host_plays or focused_card < 0 or rules.turn != 0 or rules.phase != "play" or animating or _paused(): return
	var options := rules.tap_choices(0, focused_card, false, table.armed_doubles)
	var card := _own_card(focused_card)
	if reader.preview.visible and not options.is_empty() and (not card.kind in ["property", "wild"] or (card.kind == "wild" and card.colors.size() > 2)):
		_reader_submit(options[clampi(reader.preview.selected, 0, options.size() - 1)].payload, rules.revision); return
	if card.get("kind") == "wild" and card.colors.size() == 2:
		options = options.filter(func(choice: Dictionary) -> bool: return choice.payload.get("color", "") == card.colors[focused_side])
	if options.size() == 1: _reader_submit(options[0].payload, rules.revision); return
	if not reader.visible: _refresh_reader(true)
	var commands: Array = []; var revision: int = rules.revision
	for choice in options:
		var command: Dictionary = choice.payload; var caption: String = choice.label
		if command.action == "property": caption = rules.colors[command.color].name
		if command.has("target"): caption += " - " + str(seats[int(command.target)].display_name)
		commands.append({"label": caption, "callback": func() -> void: _reader_submit(command, revision)})
	reader.set_actions(commands, _refresh_reader)


func _add_choices(actions: Array) -> void:
	for choice in actions:
		var command: Dictionary = choice.payload; var caption: String = choice.label
		if command.action == "discard":
			var card: Dictionary = rules.cards[int(command.card)]
			caption = "Discard %s · $%d" % [str(skin.labels.get(card.key, card.name)), card.value]
		if command.has("target"): caption += " · " + str(seats[int(command.target)].display_name)
		decision.body.add_child(_button(caption, func() -> void: _local(command)))


func _show_decision(force := false) -> void:
	var local: Dictionary = rules.view_for(0)
	var stamp := "%s:%s" % [local.phase, local.pending.get("effect", rules.revision)]
	if not force and stamp == decision_stamp: return
	decision_stamp = stamp
	reader.close(); inspection.overlay.hide(); _clear_dialog(); decision.heading.text = _status()
	if local.phase in ["response", "pay"]:
		decision.heading.text = str(seats[int(local.pending.actor)].display_name) + " used " + _card_name(local.pending.card) if local.phase == "pay" else "Just Say No response"
		if local.phase == "response":
			var context := Label.new(); context.text = _action_summary(local.pending, 0); context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; decision.body.add_child(context)
	if local.phase == "pay":
		if stamp != payment_stamp: selected_payment.clear(); payment_stamp = stamp
		var amount := int(local.payment.amount)
		var total_label := Label.new(); total_label.text = "Owed: $%d · Selected: $0" % amount; total_label.add_theme_color_override("font_color", GameLook.table_owed_color()); total_label.add_theme_font_size_override("font_size", 22); decision.body.add_child(total_label)
		var payment_request: Dictionary = rules.payment_command(0, [])
		var confirm := _button("Confirm payment", func() -> void:
			var command := payment_request.duplicate(true); command.cards = selected_payment.duplicate(); _local(command))
		var eligible := rules.payment_assets(0); confirm.disabled = not eligible.is_empty()
		var grid := GameCardGrid.new(); grid.selectable = true; grid.preferred_width = 108; grid.maximum_columns = 4; decision.body.add_child(grid)
		var items: Array = []
		for id: int in eligible:
			items.append(_card_entry(rules.public_card(id, 0), "$%d · %s" % [rules.cards[id].value, "Bank" if rules.banks[0].has(id) else "Property"]))
		grid.set_items(items); grid.set_selected(selected_payment)
		var update := func(ids: Array) -> void:
			selected_payment = ids
			var total: int = ids.reduce(func(sum: int, other: int) -> int: return sum + int(rules.cards[other].value), 0)
			total_label.text = "Owed: $%d · Selected: $%d" % [amount, total]; confirm.disabled = total < amount and ids.size() != eligible.size()
			total_label.add_theme_color_override("font_color", GameLook.table_owed_color() if total < amount else screen.get_theme_color("success", "GamePalette"))
		grid.selection_changed.connect(update); update.call(selected_payment)
		decision.actions.add_child(confirm)
	else:
		if local.phase == "response":
			var info := Label.new(); info.text = "Play Just Say No to restore the action, or keep the cancellation." if local.pending.canceled else "Play Just Say No to counter, or let the action continue."; info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; decision.body.add_child(info)
		_add_choices(local.actions)
	decision.overlay.show()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if inspection.overlay.visible: inspection.overlay.hide(); get_viewport().set_input_as_handled()
		elif decision.overlay.visible: decision.overlay.hide(); get_viewport().set_input_as_handled()


func _help() -> void:
	focused_card = -1
	reader.show_reference(GameCard.artwork("res://Games/monopoly-deal/art/help-front.svg"), GameCard.artwork("res://Games/monopoly-deal/art/help-back.svg"))


func _inspect_card(card: Dictionary) -> void:
	inspection.overlay.hide()
	if host_plays and not _own_card(int(card.id)).is_empty(): _select_card(card); return
	focused_card = -1
	_refresh_selection()
	reader.show_card(card, GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % card.key), Color("17594d"))
	if card.kind == "money": reader.heading.text = ""


func _show_public(seat: int) -> void:
	if decision.overlay.visible: return
	inspected_seat = seat; inspected_group = -1; _refresh_inspection(); inspection.overlay.show()


func _inspect_group(seat: int, _group_id: int) -> void:
	_show_public(seat)


func _refresh_inspection() -> void:
	for child in inspection.body.get_children(): inspection.body.remove_child(child); child.queue_free()
	if inspected_seat == -1:
		inspection.heading.text = "Public table"
		for index in seats.size():
			_add_public_cards(index)
		return
	if inspected_seat < 0 or inspected_seat >= seats.size(): inspection.overlay.hide(); return
	inspection.heading.text = str(seats[inspected_seat].display_name) + " · Public table"
	_add_public_cards(inspected_seat)


func _add_public_cards(seat: int) -> void:
	var data: Dictionary = rules.view_for(-1).table[seat]
	var name := Label.new(); name.text = str(seats[seat].display_name); name.add_theme_font_size_override("font_size", 21); inspection.body.add_child(name)
	for group in data.groups:
		var label := Label.new(); label.text = "%s · rent $%d" % [rules.colors[group.color].name, group.rent]; inspection.body.add_child(label)
		var detail: Dictionary = table.inspector_data(seat, group)
		var grid := GameCardGrid.new(); grid.fixed_columns = detail.slots; grid.preferred_width = 92; grid.card_pressed.connect(_inspect_card); inspection.body.add_child(grid); grid.set_items(detail.items)
	var bank := Label.new(); bank.text = "Bank · $%d" % data.total; inspection.body.add_child(bank)
	var items: Array = []
	for card in data.bank + data.loose: items.append(_card_entry(card))
	var bank_grid := GameCardGrid.new(); bank_grid.preferred_width = 92; bank_grid.card_pressed.connect(_inspect_card); inspection.body.add_child(bank_grid); bank_grid.set_items(items)


func shutdown_game() -> void:
	stopped = true; ai_timer.stop(); motion_timer.stop(); decision.overlay.hide(); inspection.overlay.hide(); history_dialog.overlay.hide(); reader.close()
	queued_sounds.clear(); drawn_cards.clear()
	for audio in sounds.values(): audio.stop(); audio.stream = null
	screen.background_media.set_active(false); ThemePacks.active.erase("monopoly-deal"); RuntimeAssets.textures.clear()
