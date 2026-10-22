extends BaseGame

const Rules = preload("res://Games/monopoly-classic/host/rules.gd")
const Computer = preload("res://Games/monopoly-classic/host/ai.gd")
const Store = preload("res://Games/monopoly-classic/host/session_store.gd")
const Presentation = preload("res://Games/monopoly-classic/host/ui.gd")
const Motion = preload("res://Games/monopoly-classic/host/motion.gd")
const CardFace = preload("res://Games/monopoly-classic/host/card_face.gd")
const DEFAULTS := {"solo_ai": 1, "party_ai": 0, "difficulty": 1, "theme": "default", "turn_timer": true, "turn_seconds": 60.0, "game_timer": false, "game_seconds": 3600.0}
var rules = Rules.new()
var saved_game = Store.new()
var skins := ThemePacks.new("monopoly-classic")
var skin: Dictionary = {}
var options: Dictionary = DEFAULTS.duplicate(true)
var seats: Array = []
var wins: Dictionary = {}
var missing: Dictionary = {}
var host_plays := false
var practice := false
var results_recorded := false
var awaiting_resume := false
var pending_save: Dictionary = {}
var ui
var stopped := false
var turn_remaining := 60.0
var response_remaining := 60.0
var game_remaining := 3600.0
var clock_turn_serial := 1
var clock_key := ""
var autoplay_turn := -1
var autoplay_decision := ""
var motion_elapsed := 0.0
var motion_duration := 0.0
var motion = Motion.new()
var sound_cursor := 0
var ai_elapsed := 0.0
var save_elapsed := 0.0
var publish_elapsed := 0.0
var ai_trade_serial := -1
var ai_rng := RandomNumberGenerator.new()
var sounds: Dictionary = {}
var round_seed := 0
var round_id := ""


func _ready() -> void:
	ui = Presentation.new(self)
	set_process(false)


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	host_plays = context.players.is_empty()
	options = _normalize_options(load_game_settings(DEFAULTS))
	_make_seats()
	ai_rng.randomize()
	_pin_theme()
	ui.restore_settings()
	pending_save = saved_game.load_game()
	if not pending_save.is_empty() and pending_save.rules.phase != "finished": awaiting_resume = true


func start_game() -> void:
	set_process(true)
	if awaiting_resume: ui.show_resume(resume_problem()); _publish()
	else: _new_round(false)


func _normalize_options(value: Dictionary) -> Dictionary:
	var normalized := DEFAULTS.duplicate(true)
	for key in ["solo_ai", "party_ai", "difficulty"]:
		var maximum := 5 if key != "difficulty" else 2
		if Rules.whole(value.get(key), 1 if key == "solo_ai" else 0, maximum): normalized[key] = int(value[key])
	for key in ["turn_timer", "game_timer"]:
		if value.get(key) is bool: normalized[key] = value[key]
	for key in ["turn_seconds", "game_seconds"]:
		if typeof(value.get(key)) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value[key])) and float(value[key]) >= 6 and float(value[key]) <= (3600 if key == "turn_seconds" else 86400): normalized[key] = float(value[key])
	if ThemePacks.valid_id(str(value.get("theme", ""))): normalized.theme = str(value.theme)
	return normalized


func _make_seats() -> void:
	seats = [session.solo_profile.duplicate(true)] if host_plays else session.players.duplicate(true)
	for player in seats:
		player.ai = false
		player.erase("reconnect_token")
	var count := mini(5 if host_plays else maxi(0, 6 - seats.size()), int(options.solo_ai if host_plays else options.party_ai))
	var palette := ["#e53935", "#2463eb", "#08a750", "#ae39f2", "#f7cf05", "#f47b20", "#19bbc5", "#ec5a9d"]
	for number in count:
		var used: Array = seats.map(func(player: Dictionary) -> String: return str(player.get("color", "")).to_lower())
		var color: String = palette.filter(func(candidate: String) -> bool: return not used.has(candidate))[0]
		seats.append({"id": "classic-computer-%d" % (number + 1), "display_name": "Computer %d" % (number + 1), "color": color, "pose": (number + 1) % 6, "ai": true})
	for player in seats:
		if not player.has("pose"): player.pose = 0


func _pin_theme() -> void:
	skin = skins.pin(str(options.theme)); options.theme = skin.id
	ui.screen.background_media.reduced_motion = session.reduced_motion
	ui.screen.background_media.reload_assets()
	ui.board.reload_assets()
	ui.screen.table_title_art.texture = RuntimeAssets.texture("res://Games/monopoly-classic/art/title.svg")
	for audio in sounds.values(): audio.queue_free()
	sounds.clear()
	for cue in ["roll", "move", "cash", "card", "card_draw", "chest", "doubles", "build", "jail", "win"]:
		var path := "res://Games/monopoly-classic/audio/card-draw.ogg" if cue == "card_draw" else "res://Games/monopoly-classic/audio/%s.wav" % cue
		var audio := AudioStreamPlayer.new(); audio.bus = "Effects"; audio.stream = RuntimeAssets.audio(path); add_child(audio); sounds[cue] = audio
	ui.effects.reload_assets()


func _new_round(keep_scores := true) -> void:
	for sound in sounds.values(): sound.stop()
	awaiting_resume = false; pending_save = {}; ui.resume_dialog.overlay.hide()
	var previous := int(rules.s.get("starter", -1))
	var previous_revision := int(rules.s.get("revision", 0))
	_make_seats()
	if seats.size() < 2:
		rules.s = {}; _publish(); return
	if not keep_scores: wins.clear()
	for player in seats:
		if not wins.has(player.id): wins[player.id] = 0
	var first := (previous + 1) % seats.size() if previous >= 0 else ai_rng.randi_range(0, seats.size() - 1)
	rules.start(seats.size(), first, round_seed)
	rules.s.revision = previous_revision + 1
	round_id = Crypto.new().generate_random_bytes(16).hex_encode()
	practice = seats.any(func(player: Dictionary) -> bool: return player.ai)
	if practice: saved_game.mark_practice(round_id)
	results_recorded = false; turn_remaining = float(options.turn_seconds); response_remaining = turn_remaining; game_remaining = float(options.game_seconds)
	clock_turn_serial = int(rules.s.turn_serial); clock_key = rules.decision_key(); autoplay_turn = -1; autoplay_decision = ""; ai_trade_serial = -1
	motion_duration = 0; motion_elapsed = 0; ai_elapsed = 0; motion.clear(); sound_cursor = 0
	ui.clear_round(); _save(); _publish()


func resume_problem() -> String:
	if pending_save.is_empty(): return "No saved game is available."
	if bool(pending_save.solo) != host_plays: return "Return to the lobby and rejoin the saved game's players." if not pending_save.solo else "Return to the lobby and open Classic without phone players to resume this solo game."
	var real: Array = pending_save.seats.filter(func(player: Dictionary) -> bool: return not player.ai)
	var available: Array = [session.solo_profile] if host_plays else session.players
	var required: Array = []
	for player in real:
		if not available.any(func(current: Dictionary) -> bool: return str(current.id) == str(player.id)): required.append(str(player.display_name))
	if not required.is_empty(): return "Rejoin in the lobby to resume: " + ", ".join(required)
	if available.size() != real.size(): return "The saved game needs its original human players. Return to the lobby to adjust the party."
	return ""


func resume_game() -> void:
	if not awaiting_resume or not resume_problem().is_empty() or not saved_game.valid(pending_save): return
	var saved: Dictionary = pending_save.duplicate(true)
	for sound in sounds.values(): sound.stop()
	if not rules.import_state(saved.rules): return
	options = _normalize_options(saved.options); seats = saved.seats.duplicate(true)
	var available: Array = [session.solo_profile] if host_plays else session.players
	for index in seats.size():
		if not seats[index].ai:
			for current in available:
				if str(current.id) == str(seats[index].id):
					for key in ["display_name", "color", "pose"]: seats[index][key] = current.get(key, seats[index][key])
	wins = saved.wins.duplicate(true); practice = bool(saved.practice); results_recorded = bool(saved.results_recorded)
	round_id = str(saved.round_id)
	if practice: saved_game.mark_practice(round_id)
	turn_remaining = float(saved.clocks.turn); response_remaining = float(saved.clocks.response); game_remaining = float(saved.clocks.game)
	clock_turn_serial = int(saved.clocks.turn_serial); clock_key = str(saved.clocks.decision_key); autoplay_turn = int(saved.autoplay_turn); autoplay_decision = str(saved.autoplay_decision)
	awaiting_resume = false; pending_save = {}; motion_duration = 0; motion_elapsed = 0; ai_elapsed = 0
	motion.clear(); sound_cursor = 0
	_pin_theme(); ui.restore_settings(); ui.resume_dialog.overlay.hide(); ui.clear_round(); _publish()


func apply_settings(value: Dictionary) -> void:
	if stopped or not missing.is_empty(): return
	var accepted := _normalize_options(value)
	var maximum := 5 if host_plays else maxi(0, 6 - session.players.size())
	var key := "solo_ai" if host_plays else "party_ai"
	if int(accepted[key]) > maximum or skins.load_pack(str(accepted.theme)).is_empty(): return
	if not save_game_settings(accepted): return
	options = accepted; _pin_theme(); ui.restore_settings(); _new_round(true)


func _paused() -> bool:
	if stopped or awaiting_resume or rules.s.is_empty() or ui.settings_open: return true
	for id in missing:
		var seat := _seat_for(id)
		if seat >= 0 and not rules.s.bankrupt[seat] and not options.turn_timer: return true
	return false


func _animating() -> bool:
	return motion_elapsed < motion_duration


func _autoplay(seat: int) -> bool:
	return (seat == int(rules.s.get("turn", -1)) and autoplay_turn == int(rules.s.get("turn_serial", -2))) or (seat == rules.actor() and autoplay_decision == rules.decision_key())


func _sync_clocks() -> void:
	if int(rules.s.turn_serial) != clock_turn_serial:
		clock_turn_serial = int(rules.s.turn_serial); turn_remaining = float(options.turn_seconds); autoplay_turn = -1; ai_trade_serial = -1
	var key := rules.decision_key()
	if key != clock_key: clock_key = key; response_remaining = float(options.turn_seconds); autoplay_decision = ""


func _process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if stopped or rules.s.is_empty() or awaiting_resume: return
	ui.board.paused = _paused()
	for sound in sounds.values(): sound.stream_paused = _paused()
	if _paused(): return
	if rules.s.phase != "finished" and options.game_timer:
		game_remaining = maxf(0, game_remaining - delta)
		if game_remaining <= 0:
			rules.events.clear(); rules.finish("time"); motion_duration = 0; motion_elapsed = 0; motion.clear(); ui.board.moves = []; ui.board.rolls = []
			for sound in sounds.values(): sound.stop()
			_record_results(); _publish(); return
	if _animating():
		motion_elapsed = minf(motion_duration, motion_elapsed + delta); ui.board.elapsed = motion_elapsed; ui.board.queue_redraw()
		_pump_audio(); ui.effects.update(false)
		if not _animating(): _record_results(); _publish()
	elif rules.s.phase != "finished":
		_sync_clocks()
		var seat := rules.actor()
		if options.turn_timer:
			if seat == int(rules.s.turn): turn_remaining = maxf(0, turn_remaining - delta)
			else: response_remaining = maxf(0, response_remaining - delta)
			var remaining := turn_remaining if seat == int(rules.s.turn) else response_remaining
			if remaining <= 0 and not _autoplay(seat):
				if seat == int(rules.s.turn): autoplay_turn = int(rules.s.turn_serial)
				else: autoplay_decision = rules.decision_key()
				practice = true; saved_game.mark_practice(round_id); _save(); _publish()
		if seat >= 0 and (bool(seats[seat].ai) or _autoplay(seat)):
			ai_elapsed += delta
			if ai_elapsed >= .4:
				ai_elapsed = 0
				var view := rules.view_for(seat)
				var input: Dictionary = {}
				if seats[seat].ai and int(options.difficulty) > 0 and rules.s.phase == "manage" and seat == int(rules.s.turn) and ai_trade_serial != int(rules.s.turn_serial):
					ai_trade_serial = int(rules.s.turn_serial); input = Computer.offer(view)
				if input.is_empty(): input = Computer.choose(view, 0 if _autoplay(seat) else int(options.difficulty), ai_rng)
				if not input.is_empty(): _act(seat, input, true)
		else: ai_elapsed = 0
	save_elapsed += delta; publish_elapsed += delta
	if save_elapsed >= 5: save_elapsed = 0; _save()
	if publish_elapsed >= .2: publish_elapsed = 0; _publish_clocks()


func _act(seat: int, input: Dictionary, computer := false) -> bool:
	if _paused() or _animating() or seat < 0 or seat >= seats.size() or (not computer and _autoplay(seat)): return false
	if computer: practice = true; saved_game.mark_practice(round_id)
	var command := input.duplicate(true)
	if computer or not command.has("revision"): command.revision = int(rules.s.revision)
	var before_cash: Array = rules.s.cash.duplicate()
	if not rules.apply(seat, command): return false
	_sync_clocks(); _begin_motion(before_cash); _save()
	if not _animating(): _record_results()
	_publish(); return true


func local_action(input: Dictionary) -> void:
	if not host_plays: return
	if input.get("action") == "replay":
		if not _paused() and not _animating() and rules.s.get("phase") == "finished": _new_round(true)
		return
	_act(0, input)


func _begin_motion(before_cash: Array = []) -> void:
	if before_cash.is_empty(): before_cash = ui.view.get("players", []).map(func(player: Dictionary) -> int: return int(player.cash))
	var events: Array = rules.events.duplicate(true)
	var properties: Array = view_for(-1).properties
	for event in events:
		if event.kind != "trade": continue
		event.transfers = []
		for pair in [["give", int(event.seat), int(event.target)], ["take", int(event.target), int(event.seat)]]:
			for id in event.get(str(pair[0]) + "_properties", []):
				var card: Dictionary = properties.filter(func(item: Dictionary) -> bool: return int(item.id) == int(id))[0]
				event.transfers.append({"from":int(pair[1]), "to":int(pair[2]), "card":card})
			for deck in event.get(str(pair[0]) + "_jail", []):
				var card: Dictionary = rules.definition[deck].filter(func(item: Dictionary) -> bool: return item.effect == "jail_free")[0]
				event.transfers.append({"from":int(pair[1]), "to":int(pair[2]), "card":card.duplicate(true)})
	motion.begin(events, before_cash, seats, skin.get("labels", {}))
	motion_elapsed = 0; motion_duration = 0 if session.reduced_motion else motion.duration; sound_cursor = 0
	ui.board.moves = [] if session.reduced_motion else motion.moves
	ui.board.rolls = [] if session.reduced_motion else motion.rolls; ui.board.elapsed = 0
	motion.cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.start) < float(b.start))
	if session.reduced_motion:
		var played: Array = []
		for cue in motion.cues:
			if cue.cue != "move" and not played.has(cue.cue) and sounds.has(cue.cue): sounds[cue.cue].play(); played.append(cue.cue)
		sound_cursor = motion.cues.size()
	else: _pump_audio()


func _pump_audio() -> void:
	while sound_cursor < motion.cues.size() and float(motion.cues[sound_cursor].start) <= motion_elapsed:
		var cue: String = motion.cues[sound_cursor].cue
		if sounds.has(cue): sounds[cue].play()
		sound_cursor += 1


func _record_results() -> void:
	if rules.s.is_empty() or rules.s.phase != "finished" or results_recorded or _animating(): return
	practice = practice or saved_game.was_practice(round_id)
	results_recorded = true
	var winner := int(rules.s.winner)
	wins[seats[winner].id] = int(wins.get(seats[winner].id, 0)) + 1
	# Persist this guard and the sticky practice flag before emitting any award.
	if not _save(): return
	if not saved_game.mark_completed(round_id): return
	if practice or not session.is_party_game or seats.any(func(player: Dictionary) -> bool: return player.ai): return
	for index in seats.size():
		report_result(str(seats[index].id), index == winner)
		if index == winner: award_points(str(seats[index].id), 1)


func _save() -> bool:
	if rules.s.is_empty() or awaiting_resume: return false
	var payload := {"round_id": round_id, "rules": rules.export_state(), "seats": seats.duplicate(true), "solo": host_plays, "practice": practice, "results_recorded": results_recorded, "options": options.duplicate(true), "wins": wins.duplicate(true), "clocks": {"turn": turn_remaining, "response": response_remaining, "game": game_remaining, "turn_serial": clock_turn_serial, "decision_key": clock_key}, "autoplay_turn": autoplay_turn, "autoplay_decision": autoplay_decision}
	return saved_game.save_game(payload)


func _seat_for(id: String) -> int:
	for index in seats.size():
		if str(seats[index].id) == id and not seats[index].ai: return index
	return -1


func player_joined(player: Dictionary) -> void:
	player_reconnected(player)


func player_reconnected(player: Dictionary) -> void:
	if _seat_for(str(player.get("id", ""))) < 0: return
	missing.erase(str(player.id)); _save(); _publish()


func player_disconnected(id: String) -> void:
	if _seat_for(id) < 0: return
	missing[id] = true
	for sound in sounds.values(): sound.stop()
	_save(); _publish()


func handle_controller_message(id: String, input: Dictionary) -> void:
	var seat := _seat_for(id)
	if seat < 0 or missing.has(id): return
	if input.get("action") == "sync": send_state(id, view_for(seat)); return
	if input.get("action") == "replay":
		if not _paused() and not _animating() and rules.s.get("phase") == "finished" and Rules.whole(input.get("revision"), 1) and int(input.revision) == int(rules.s.revision): _new_round(true)
		return
	if not input.has("revision"): return
	_act(seat, input)


func clocks() -> Dictionary:
	var actor := rules.actor()
	return {"turn_enabled": bool(options.turn_timer), "game_enabled": bool(options.game_timer), "turn": turn_remaining if actor == int(rules.s.get("turn", -1)) else response_remaining, "game": game_remaining, "owner": actor, "running": not _paused() and not _animating() and rules.s.get("phase") != "finished"}


func view_for(viewer: int) -> Dictionary:
	var view := rules.view_for(viewer)
	view.type = "state"; view.practice = practice; view.paused = _paused(); view.animating = _animating(); view.awaiting_resume = awaiting_resume
	view.building_sale = rules.s.get("building_sale", {}).duplicate(true)
	view.clocks = clocks(); view.theme = {"id": skin.get("id", "default"), "name": skin.get("name", "Classic"), "revision": skin.get("revision", ""), "labels": skin.get("labels", {}).duplicate(true)}
	view.reduced_motion = session.reduced_motion; view.autoplay = not rules.s.is_empty() and _autoplay(viewer)
	view.motion = motion.view(motion_elapsed, _animating())
	view.missing = seats.filter(func(player: Dictionary) -> bool: return missing.has(str(player.id))).map(func(player: Dictionary) -> String: return str(player.display_name))
	for index in view.players.size():
		view.players[index].display_name = str(seats[index].display_name); view.players[index].color = str(seats[index].color); view.players[index].pose = int(seats[index].pose); view.players[index].ai = bool(seats[index].ai); view.players[index].wins = int(wins.get(seats[index].id, 0))
	for index in view.properties.size():
		view.properties[index] = CardFace.decorate(view.properties[index], skin.get("labels", {}))
		var owner := int(view.properties[index].owner)
		view.properties[index].owner_name = str(seats[owner].display_name) if owner >= 0 else "Bank"
	view.status = status_text(view)
	view.activity = []
	for event in view.get("log", []):
		var text := event_text(event)
		if not text.is_empty(): view.activity.append({"id": int(event.id), "text": text})
	view.erase("log")
	return view


func status_text(view: Dictionary) -> String:
	if awaiting_resume: return "Saved game available"
	if rules.s.is_empty(): return "Add a computer in Settings to start with two players."
	if view.paused and not ui.settings_open: return "Waiting for " + ", ".join(view.missing)
	if ui.settings_open: return "Paused in Settings"
	if view.animating: return "Moving…"
	if rules.s.phase == "finished": return "%s wins · $%d total wealth" % [str(seats[int(rules.s.winner)].display_name), int(rules.s.result_wealth[int(rules.s.winner)])]
	var name := str(seats[rules.actor()].display_name)
	match str(rules.s.phase):
		"building_interest": return name + " is choosing whether to request the last building"
		"auction": return name + " is bidding"
		"debt": return "%s owes $%d" % [name, int(rules.s.debt.amount)]
		"transfer": return name + " is resolving a mortgage"
		"trade": return "Trade in progress · %s ↔ %s" % [str(seats[int(rules.s.trade.from)].display_name), str(seats[int(rules.s.trade.to)].display_name)]
	return name + (" · automatic play" if _autoplay(rules.actor()) else " · your turn" if host_plays and rules.actor() == 0 else "'s turn")


func property_name(id: int) -> String:
	if not rules.properties.has(id): return "Property"
	var property: Dictionary = rules.properties[id]
	return str(skin.get("labels", {}).get(property.key, property.name))


func event_text(event: Dictionary) -> String:
	var seat := int(event.get("seat", -1)); var name := str(seats[seat].display_name) if seat >= 0 and seat < seats.size() else "Bank"
	var id := int(event.get("property", -1))
	match str(event.kind):
		"start", "turn": return ""
		"roll": return "%s rolled %d + %d" % [name, int(event.dice[0]), int(event.dice[1])]
		"buy": return "%s bought %s for $%d" % [name, property_name(id), int(event.amount)]
		"pay": return "%s paid $%d · %s" % [name, int(event.amount), property_name(id) if id >= 0 else str(event.get("reason", "Payment"))]
		"receive", "go": return "%s received $%d" % [name, int(event.amount)]
		"mortgage", "unmortgage", "build", "sell", "sell_group": return "%s · %s · %s" % [name, str(event.kind).replace("_", " ").capitalize(), property_name(id)]
		"card": return name + " · " + str(event.card.name)
		"jail": return name + " went to Jail"
		"release": return name + " left Jail"
		"auction": return "Auction · " + property_name(id)
		"building_sale": return "Last building requested · " + property_name(id)
		"bid": return "%s bid $%d" % [name, int(event.amount)]
		"bankrupt": return name + " is bankrupt"
		"trade": return name + " completed a trade"
		"trade_declined": return name + "'s trade was declined"
		"win": return "%s wins with $%d" % [name, int(event.amount)]
	return ""


func _publish() -> void:
	if stopped: return
	ui.render(view_for(0 if host_plays else -1))
	for seat in seats.size():
		if not seats[seat].ai and not host_plays: send_state(str(seats[seat].id), view_for(seat))


func _publish_clocks() -> void:
	ui.render_clocks(clocks())
	for seat in seats.size():
		if not seats[seat].ai and not host_plays: send_state(str(seats[seat].id), {"type": "clock", "revision": int(rules.s.revision), "clocks": clocks()})


func shutdown_game() -> void:
	if stopped: return
	_save(); stopped = true; set_process(false)
	for sound in sounds.values(): sound.stop()
	motion.clear(); motion_duration = 0
	ui.shutdown(); ThemePacks.active.erase("monopoly-classic"); RuntimeAssets.textures.clear()
