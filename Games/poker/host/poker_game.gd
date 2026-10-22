extends BaseGame

const Rules = preload("res://Games/poker/host/rules.gd")
const Computer = preload("res://Games/poker/host/ai.gd")
const Store = preload("res://Games/poker/host/session_store.gd")
const Presentation = preload("res://Games/poker/host/ui.gd")
const HAND_REVIEW_SECONDS := 12.0
const UNCONTESTED_REVIEW_SECONDS := 6.0
const DEFAULTS := {"starting_chips": 2000, "small_blind": 10, "big_blind": 20, "ante": 0, "blind_interval": 10, "solo_ai": 1, "party_ai": 0, "difficulty": 1, "turn_timer": true, "turn_seconds": 30}
var rules = Rules.new()
var saved_game = Store.new()
var options: Dictionary = DEFAULTS.duplicate(true)
var seats: Array = []
var wins: Dictionary = {}
var missing: Dictionary = {}
var host_plays := false
var practice := false
var results_recorded := false
var awaiting_resume := false
var pending_save: Dictionary = {}
var run_id := ""
var variant := "texas"
var ui
var stopped := false
var manual_paused := false
var turn_remaining := 30.0
var phase_remaining := 0.0
var clock_serial := 0
var motion := GameCardMotion.new()
var motion_elapsed := 0.0
var motion_duration := 0.0
var chip_flights: Array = []
var ai_thread: Thread
var ai_revision := -1
var ai_reply: Dictionary = {}
var ai_delay := 0.0
var publish_elapsed := 0.0
var save_elapsed := 0.0
var first_dealer := 0
var audio := AudioStreamPlayer.new()
var money_audio := AudioStreamPlayer.new()
var sounds: Dictionary = {}
var card_sounds: Dictionary = {}
var card_cues: Array = []
var storage_error := ""


func _ready() -> void:
	ui = Presentation.new(self); add_child(audio); audio.bus = "Effects"
	add_child(money_audio); money_audio.bus = "Effects"; money_audio.volume_db = -6
	money_audio.stream = RuntimeAssets.audio("res://Games/poker/audio/all-in.ogg")
	for cue in ["chips", "win"]: sounds[cue] = RuntimeAssets.audio("res://Games/poker/audio/%s.wav" % cue)
	for cue in {"shuffle": "card-shuffle", "draw": "card-slide-1", "place": "card-place-1"}:
		var sound := AudioStreamPlayer.new(); sound.bus = "Effects"; sound.max_polyphony = 6; sound.volume_db = -5
		sound.stream = RuntimeAssets.audio("res://Games/poker/audio/%s.ogg" % {"shuffle": "card-shuffle", "draw": "card-slide-1", "place": "card-place-1"}[cue])
		add_child(sound); card_sounds[cue] = sound
	set_process(false)


func initialize_session(context: GameSessionContext) -> void:
	super.initialize_session(context)
	variant = "omaha" if context.game_id == "poker-omaha" else "texas"
	host_plays = context.players.is_empty(); options = normalize_options(load_game_settings(DEFAULTS))
	# Tests may inject a module-owned store before initialization.
	if saved_game.path.begins_with("user://"): saved_game.path = "user://%s/session.json" % context.game_id
	_make_seats(); ui.configure_mode(); ui.restore_settings()
	pending_save = saved_game.load_game()
	awaiting_resume = not pending_save.is_empty() and pending_save.rules.phase != "finished"


func start_game() -> void:
	set_process(true)
	if awaiting_resume: ui.show_resume(resume_problem()); _publish()
	else: new_tournament()


func normalize_options(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		if key == "turn_timer":
			if value.get(key) is bool: normalized[key] = value[key]
		elif Rules.whole(value.get(key), 0, 1000000): normalized[key] = int(value[key])
	for key in ["solo_ai", "party_ai"]: normalized[key] = clampi(int(normalized[key]), 1 if key == "solo_ai" else 0, 9)
	normalized.difficulty = clampi(int(normalized.difficulty), 0, 2); normalized.turn_seconds = clampi(int(normalized.turn_seconds), 5, 600)
	if not Rules.valid_options(normalized):
		for key in Rules.DEFAULTS: normalized[key] = Rules.DEFAULTS[key]
	return normalized


func _make_seats() -> void:
	seats = [session.solo_profile.duplicate(true)] if host_plays else session.players.duplicate(true)
	for seat in seats:
		seat.erase("reconnect_token"); seat.ai = false; seat.pose = int(seat.get("pose", 0))
		seat.color = "#" + Color(str(seat.get("color", "#58d6ff"))).to_html(false)
	var computers := clampi(int(options.solo_ai if host_plays else options.party_ai), 1 if seats.size() == 1 else 0, 10 - seats.size())
	var palette := ["#e53935", "#2463eb", "#08a750", "#ae39f2", "#f7cf05", "#f47b20", "#19bbc5", "#ec5a9d", "#8d6e63", "#cfd8dc", "#606c38", "#805ad5", "#059669", "#d97706", "#db2777", "#67e8f9"]
	for number in computers:
		var used: Array = seats.map(func(player: Dictionary) -> String: return str(player.get("color", "")).to_lower())
		var color: String = palette.filter(func(candidate: String) -> bool: return not used.has(candidate))[0]
		seats.append({"id": "poker-computer-%d" % number, "display_name": "Computer %d" % (number + 1), "color": color, "pose": number % 6, "ai": true})


func new_tournament(replay := false) -> void:
	if replay and (rules.phase != "finished" or phase_remaining > 0 or animating()): return
	_cancel_ai(); audio.stop(); money_audio.stop(); _clear_card_audio(); manual_paused = false; storage_error = ""
	if replay: first_dealer = (first_dealer + 1) % maxi(2, seats.size())
	_make_seats()
	if seats.size() < 2 or seats.size() > 10: return
	awaiting_resume = false; pending_save = {}; ui.resume_dialog.overlay.hide()
	ui.public_cards_dialog.overlay.hide()
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	practice = host_plays or seats.any(func(seat: Dictionary) -> bool: return seat.ai)
	if practice and not saved_game.mark_practice(run_id): storage_error = "Poker could not save its practice marker."
	results_recorded = false; clock_serial = 0; phase_remaining = 0
	rules.start(seats.size(), variant, options, first_dealer)
	_begin_motion({}, true); _reset_clock(); _save(); _publish()


func resume_problem() -> String:
	if pending_save.is_empty(): return ""
	if bool(pending_save.solo) != host_plays: return "Open this mode with the saved human lineup to resume."
	var saved_humans: Array = pending_save.seats.filter(func(seat: Dictionary) -> bool: return not seat.ai).map(func(seat: Dictionary) -> String: return str(seat.id))
	var available: Array = ([session.solo_profile] if host_plays else session.players).map(func(seat: Dictionary) -> String: return str(seat.id))
	saved_humans.sort(); available.sort()
	return "Rejoin the same human profiles in the lobby to resume this tournament." if saved_humans != available else ""


func resume_game() -> void:
	if not awaiting_resume or not resume_problem().is_empty() or not saved_game.valid(pending_save) or pending_save.rules.variant != variant: return
	_cancel_ai(); money_audio.stop(); _clear_card_audio(); var saved: Dictionary = pending_save.duplicate(true)
	if not rules.import_state(saved.rules): return
	options = normalize_options(saved.options); seats = saved.seats.duplicate(true)
	var available: Array = [session.solo_profile] if host_plays else session.players
	for seat in seats:
		for player in available:
			if seat.id == player.id:
				for key in ["display_name", "color", "pose"]: seat[key] = player.get(key, seat[key])
	run_id = saved.run_id; wins = saved.wins.duplicate(true); practice = bool(saved.practice) or saved_game.was_practice(run_id); results_recorded = bool(saved.results_recorded)
	turn_remaining = float(saved.turn_remaining); phase_remaining = float(saved.phase_remaining); clock_serial = int(saved.clock_serial)
	motion.flights = saved.motion.flights.duplicate(true); motion.revision = int(saved.motion.revision); motion.shuffle = float(saved.motion.get("shuffle", 0)); motion.effects = []
	motion_duration = float(saved.motion_duration); motion.duration = motion_duration; motion_elapsed = float(saved.motion_elapsed); chip_flights = saved.motion.get("chips", []).duplicate(true)
	awaiting_resume = false; pending_save = {}; ui.resume_dialog.overlay.hide(); ui.restore_settings(); _save(); _publish()


func apply_settings(candidate: Dictionary) -> bool:
	if stopped or not missing.is_empty() or not Rules.valid_options(candidate) or candidate != normalize_options(candidate): return false
	if not save_game_settings(candidate): return false
	options = candidate.duplicate(true); ui.close_settings(); new_tournament(); return true


func paused() -> bool:
	if stopped or awaiting_resume or ui.settings_open or ui.confirm_open or manual_paused or (ui.public_cards_dialog.overlay.visible and not ui.review_automatic): return true
	for id in missing:
		var seat := _seat_for(id)
		if seat >= 0 and (rules.players.is_empty() or not rules.players[seat].out): return true
	return false


func pause_reason() -> String:
	if awaiting_resume: return "Saved tournament available"
	if ui.settings_open: return "Host Settings is open"
	if ui.confirm_open: return "Host is leaving the table"
	if ui.public_cards_dialog.overlay.visible and not ui.review_automatic: return "Host is inspecting the showdown"
	if manual_paused: return "Paused by host"
	if paused() and not missing.is_empty(): return "Waiting for " + ", ".join(missing.values())
	return ""


func animating() -> bool: return motion_elapsed < motion_duration


func play_all_in_cue() -> bool:
	if not host_plays or paused() or animating() or rules.phase != "betting" or rules.turn != 0: return false
	var legal: Dictionary = rules.legal(0)
	if not legal.can_raise or not legal.all_in: return false
	money_audio.play(); return true


func _process(delta: float) -> void:
	if stopped: return
	# Worker jobs never touch the live rules or UI; only a matching reply may act.
	if ai_thread != null and not ai_thread.is_alive(): ai_reply = ai_thread.wait_to_finish(); ai_thread = null
	if paused() or rules.players.is_empty():
		audio.stream_paused = true
		money_audio.stream_paused = true
		for sound in card_sounds.values(): sound.stream_paused = true
		return
	audio.stream_paused = false
	money_audio.stream_paused = false
	for sound in card_sounds.values(): sound.stream_paused = false
	publish_elapsed += delta; save_elapsed += delta
	if animating():
		motion_elapsed = minf(motion_duration, motion_elapsed + delta)
		_play_card_cues()
		if not animating(): _record_result(); _save(); _publish()
	else:
		if rules.phase == "runout":
			phase_remaining -= delta
			if phase_remaining <= 0:
				var before: Dictionary = rules.view_for(-1); rules.advance_runout(); _after_action(before)
		elif rules.phase == "hand_over":
			phase_remaining = maxf(0, phase_remaining - delta)
			if phase_remaining <= 0:
				_next_hand()
		elif rules.phase == "finished":
			phase_remaining = maxf(0, phase_remaining - delta)
		elif rules.phase == "betting":
			_reset_clock()
			if seats[rules.turn].ai:
				ai_delay += delta
				if ai_delay >= .45 and ai_thread == null and ai_reply.is_empty():
					ai_revision = rules.revision; ai_thread = Thread.new(); ai_thread.start(Computer.choose.bind(rules.view_for(rules.turn), int(options.difficulty)))
				if not ai_reply.is_empty():
					var reply := ai_reply.duplicate(true); ai_reply.clear()
					if ai_revision == rules.revision: reply.revision = rules.revision; _action(rules.turn, reply)
			elif options.turn_timer:
				turn_remaining = maxf(0, turn_remaining - delta)
				if turn_remaining <= 0: _action(rules.turn, {"action": "check" if rules.legal(rules.turn).check else "fold", "revision": rules.revision})
	if publish_elapsed >= .2: publish_elapsed = 0; _publish()
	if save_elapsed >= 5: save_elapsed = 0; _record_result(); _save()


func _reset_clock() -> void:
	if clock_serial != rules.turn_serial: clock_serial = rules.turn_serial; turn_remaining = float(options.turn_seconds); ai_delay = 0


func _next_hand() -> void:
	rules.next_hand(); phase_remaining = 0; _begin_motion({}, true); _reset_clock(); _save(); _publish()


func continue_review() -> bool:
	# This is a host UI action; controller commands never route here.
	if paused() or animating() or rules.phase not in ["hand_over", "finished"]: return false
	if rules.phase == "hand_over": _next_hand()
	else:
		phase_remaining = 0; ui.public_cards_dialog.overlay.hide(); _save(); _publish()
	return true


func _action(seat: int, command: Dictionary) -> bool:
	if paused() or animating() or not Rules.whole(command.get("revision"), rules.revision, rules.revision) or not command.get("action") is String: return false
	var before: Dictionary = rules.view_for(-1)
	if not rules.act(seat, command.action, command.get("amount", -1)): return false
	_after_action(before); return true


func _after_action(before: Dictionary) -> void:
	ai_reply.clear(); ai_delay = 0; _reset_clock(); _begin_motion(before)
	phase_remaining = (HAND_REVIEW_SECONDS if rules.showdown else UNCONTESTED_REVIEW_SECONDS) if rules.phase in ["hand_over", "finished"] else 1.0
	if not animating(): _record_result()
	_save(); _publish()


func _begin_motion(before: Dictionary, deal := false) -> void:
	_clear_card_audio()
	var flights: Array = []; chip_flights.clear(); motion_elapsed = 0
	if deal:
		for index in (4 if variant == "omaha" else 2):
			for offset in seats.size():
				var seat: int = (rules.dealer + 1 + offset) % seats.size()
				if rules.players[seat].hand.is_empty(): continue
				flights.append({"from": {"zone": "deck"}, "to": {"zone": "hand", "seat": seat, "index": index}, "card": Rules.Evaluator.card_data(int(rules.players[seat].hand[index]))})
	else:
		for index in range(before.get("board", []).size(), rules.board.size()): flights.append({"from": {"zone": "deck"}, "to": {"zone": "board", "index": index}, "card": Rules.Evaluator.card_data(int(rules.board[index]))})
		for seat in seats.size():
			var change := int(rules.players[seat].stack) - int(before.players[seat].stack)
			if change != 0: chip_flights.append({"seat": seat, "amount": absi(change), "award": change > 0})
	motion.begin(flights, deal)
	motion.shuffle = .25 if deal else 0.0; motion.duration = motion.shuffle
	for index in motion.flights.size():
		motion.flights[index].delay = motion.shuffle + index * (.075 if deal else .13)
		motion.flights[index].duration = .52
		motion.duration = maxf(motion.duration, motion.flights[index].delay + .60)
	motion_duration = maxf(motion.duration, .6 if not chip_flights.is_empty() else 0)
	if session.reduced_motion: motion_duration = 0
	motion.duration = motion_duration
	if deal: card_cues.append({"cue": "shuffle", "at": 0.0})
	for index in motion.flights.size():
		if session.reduced_motion and index > 0: break
		var flight: Dictionary = motion.flights[index]
		card_cues.append({"cue": "draw", "at": 0.0 if session.reduced_motion else float(flight.delay)})
		if not deal: card_cues.append({"cue": "place", "at": 0.0 if session.reduced_motion else float(flight.delay) + float(flight.duration)})
	_play_card_cues()
	var cue := "win" if rules.phase in ["hand_over", "finished"] else "chips" if not chip_flights.is_empty() else ""
	if sounds.has(cue): audio.stream = sounds[cue]; audio.play()


func _play_card_cues() -> void:
	for index in range(card_cues.size() - 1, -1, -1):
		var event: Dictionary = card_cues[index]
		if float(event.at) > motion_elapsed: continue
		card_sounds[event.cue].play(); card_cues.remove_at(index)


func _clear_card_audio() -> void:
	card_cues.clear()
	for sound in card_sounds.values(): sound.stop()


func _record_result() -> void:
	if rules.phase != "finished" or results_recorded or animating(): return
	practice = practice or saved_game.was_practice(run_id)
	if not saved_game.mark_completed(run_id): storage_error = "Could not commit Poker results; free save space and retry."; return
	results_recorded = true
	var champion: Dictionary = seats[rules.winner]; wins[champion.id] = int(wins.get(champion.id, 0)) + 1
	_save()
	if not practice and session.is_party_game:
		for index in seats.size(): report_result(str(seats[index].id), index == rules.winner)
		award_points(str(champion.id), 1)


func _save() -> bool:
	if rules.players.is_empty() or awaiting_resume or stopped: return false
	var payload := {"run_id": run_id, "rules": rules.export_state(), "seats": seats.duplicate(true), "solo": host_plays, "practice": practice, "results_recorded": results_recorded, "options": options.duplicate(true), "wins": wins.duplicate(true), "turn_remaining": turn_remaining, "phase_remaining": phase_remaining, "clock_serial": clock_serial, "motion_elapsed": motion_elapsed, "motion_duration": motion_duration, "motion": {"revision": motion.revision, "flights": motion.flights.duplicate(true), "shuffle": motion.shuffle, "chips": chip_flights.duplicate(true)}}
	var saved: bool = saved_game.save_game(payload)
	if not saved: storage_error = saved_game.error
	else: storage_error = ""
	return saved


func _snapshot(viewer: int) -> Dictionary:
	if rules.players.is_empty(): return {"type": "waiting", "awaiting_resume": awaiting_resume, "paused": true, "pause_reason": pause_reason()}
	var view: Dictionary = rules.view_for(viewer)
	view.type = "state"; view.paused = paused(); view.pause_reason = pause_reason(); view.animating = animating(); view.reduced_motion = session.reduced_motion
	view.identities = seats.map(func(seat: Dictionary) -> Dictionary: return {"display_name": seat.display_name, "color": seat.color, "pose": seat.pose, "ai": seat.ai, "wins": int(wins.get(seat.id, 0))})
	view.clock = {"enabled": bool(options.turn_timer), "remaining": turn_remaining, "running": not paused() and not animating() and rules.phase == "betting" and not seats[rules.turn].ai, "serial": clock_serial}
	view.motion = motion.view(viewer, motion_elapsed, animating()); view.motion.chips = chip_flights.duplicate(true)
	view.phase_remaining = phase_remaining; view.storage_error = storage_error; view.awaiting_resume = awaiting_resume
	return view


func _publish() -> void:
	if stopped: return
	ui.render(_snapshot(0 if host_plays else -1))
	for player in session.players: send_state(str(player.id), _snapshot(_seat_for(str(player.id))))


func _seat_for(id: String) -> int:
	for index in seats.size():
		if str(seats[index].id) == id and not seats[index].ai: return index
	return -1


func handle_controller_message(id: String, command: Dictionary) -> void:
	var seat := _seat_for(id)
	if seat < 0: return
	if command.get("action") == "sync": send_state(id, _snapshot(seat)); return
	_action(seat, command)


func player_disconnected(id: String) -> void:
	var seat := _seat_for(id)
	if seat >= 0: missing[id] = str(seats[seat].display_name); _save(); _publish()


func player_joined(player: Dictionary) -> void:
	missing.erase(str(player.get("id", ""))); _save(); _publish()


func player_reconnected(player: Dictionary) -> void: player_joined(player)


func _cancel_ai() -> void:
	if ai_thread != null: ai_thread.wait_to_finish(); ai_thread = null
	ai_reply.clear(); ai_revision = -1


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"): return
	if ui.help_dialog.overlay.visible: ui.help_dialog.overlay.hide()
	elif ui.history_dialog.overlay.visible: ui.history_dialog.overlay.hide()
	elif ui.settings_open: ui.close_settings()
	elif ui.public_cards_dialog.overlay.visible:
		if not ui.review_automatic or phase_remaining <= 0: ui.public_cards_dialog.overlay.hide()
	elif ui.confirm_open: ui.confirm_open = false; ui.confirm_dialog.overlay.hide(); _publish()
	else: return
	get_viewport().set_input_as_handled()


func shutdown_game() -> void:
	_save(); stopped = true; _cancel_ai(); set_process(false); audio.stop(); money_audio.stop(); _clear_card_audio(); audio.stream = null; money_audio.stream = null; sounds.clear(); ui.shutdown()
