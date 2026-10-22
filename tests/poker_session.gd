extends SceneTree

const Rules = preload("res://Games/poker/host/rules.gd")
const Computer = preload("res://Games/poker/host/ai.gd")
const Store = preload("res://Games/poker/host/session_store.gd")
const Settings = preload("res://tests/game_settings_fixture.gd")
var folder := "res://.test_data/poker-session-%d/" % Time.get_ticks_usec()
var checks := 0
var failures := 0
var awards: Array = []
var results: Array = []


func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)


func lineup(count: int) -> Array:
	var players: Array = []
	for index in count: players.append({"id": "human-%d" % index, "display_name": "Player [b]%d[/b]" % index, "color": Color.from_hsv(float(index) / 10, .8, .85).to_html(), "pose": index % 6})
	return players


func make_host(mode: String, humans: int, path: String, motion_reduced := true, preferences: GameSettingsStore = null):
	var id := "poker-omaha" if mode == "omaha" else "poker-texas-holdem"
	var host = load("res://Games/%s/host/main.tscn" % id).instantiate()
	host.settings_store = preferences if preferences != null else Settings.new(); host.saved_game.path = path
	root.add_child(host)
	var context := GameSessionContext.new(id, lineup(humans), {"id": "local-host", "display_name": "Host", "color": "#58d6ff", "pose": 0}, humans > 0); context.reduced_motion = motion_reduced
	host.initialize_session(context); host.start_game(); host.set_process(false)
	return host


func dispose(host) -> void: host.shutdown_game(); host.queue_free(); await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for mode: String in ["texas", "omaha"]:
		var path := folder + mode + "/session.json"
		var host = make_host(mode, 2, path)
		check(not host.host_plays and host.seats.size() == 2 and not host.practice, "Two phones use an all-human public host")
		var one: Dictionary = host._snapshot(0); var two: Dictionary = host._snapshot(1); var public: Dictionary = host._snapshot(-1)
		check(one.hand.size() == (4 if mode == "omaha" else 2) and one.hand != two.hand and public.hand.is_empty(), "Per-player views have distinct private hands")
		check(not JSON.stringify(public).contains("human-0") and not JSON.stringify(one).contains("reconnect_token") and not one.has("deck"), "Snapshots omit identifiers, reconnect tokens and deck")
		var revision: int = host.rules.revision
		host.handle_controller_message("unknown", {"action": "fold", "revision": revision})
		check(host.rules.revision == revision and not host._action(1, {"action": "fold", "revision": revision}), "Unknown and off-turn senders cannot act")
		host.ui.open_settings(); var remaining: float = host.turn_remaining; host._process(2)
		check(host.paused() and host.turn_remaining == remaining and not host._action(0, {"action": "fold", "revision": revision}), "Settings pause input and the clock")
		host.ui.close_settings(); host.player_disconnected("human-1"); host._process(2)
		check(host.paused() and host.turn_remaining == remaining, "Disconnect pauses the complete game")
		host.player_reconnected(lineup(2)[1]); check(not host.paused(), "Reconnection resumes the same table")
		host.animating()
		check(host._action(0, {"action": "call", "revision": revision}), "Accepts a current owned action")
		check(not host._action(0, {"action": "call", "revision": revision}), "Duplicate revisions are rejected")
		host.turn_remaining = 12.5; check(host._save(), "Saves a validated unfinished tournament")
		var deck: Array = host.rules.deck.duplicate(); var hand: Array = host.rules.players[0].hand.duplicate(); var turn: int = host.rules.turn
		await dispose(host)
		var probe_path := folder + mode + "/probe.json"; var output: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/poker_resume_probe.gd", "--", ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(probe_path)], output, true)
		var probe: Variant = JSON.parse_string(FileAccess.get_file_as_string(probe_path))
		check(probe is Dictionary and probe.get("ok", false), "Fresh Godot process restores the unfinished tournament")
		host = make_host(mode, 2, path); check(host.awaiting_resume, "Opening an unfinished game offers Resume/New")
		host.resume_game(); check(not host.awaiting_resume and host.rules.deck == deck and host.rules.players[0].hand == hand and host.rules.turn == turn and host.turn_remaining == 12.5, "Resume restores cards, random order, active turn and remaining clock")
		var saved_id: String = host.run_id; host.saved_game.mark_practice(saved_id)
		check(host.saved_game.load_game().practice, "Practice marker survives a checkpoint with an earlier flag")
		var bytes := FileAccess.get_file_as_string(path)
		var damaged := FileAccess.open(path, FileAccess.WRITE); damaged.store_string("corrupt"); damaged.close()
		check(not host.saved_game.load_game().is_empty(), "A corrupt primary recovers its validated previous checkpoint")
		var repair := FileAccess.open(path, FileAccess.WRITE); repair.store_string(bytes); repair.close()
		await dispose(host)
		var mismatch = make_host(mode, 3, path)
		check(mismatch.awaiting_resume and not mismatch.resume_problem().is_empty() and mismatch.ui.resume_button.disabled, "Resume requires matching human profiles")
		check(not mismatch._save(), "Resume prompt cannot overwrite the existing game")
		await dispose(mismatch)
		var solo = make_host(mode, 0, folder + mode + "/solo.json")
		check(solo.host_plays and solo.seats.size() == 2 and solo.practice and solo._snapshot(0).hand.size() == (4 if mode == "omaha" else 2), "Solo defaults to host plus one AI")
		for difficulty in 3:
			var view: Dictionary = solo.rules.view_for(solo.rules.turn)
			var command: Dictionary = Computer.choose(view, difficulty)
			var copied := Rules.new(); copied.import_state(solo.rules.export_state())
			check(copied.act(copied.turn, command.get("action", ""), command.get("amount", -1)), "Each AI difficulty returns a legal own-view action")
		solo._action(0, {"action": "call", "revision": solo.rules.revision}); var ai_revision: int = solo.rules.revision
		solo._process(.5); check(solo.ai_thread != null, "AI calculation runs on an isolated worker")
		solo.manual_paused = true
		var deadline := Time.get_ticks_msec() + 5000
		while solo.ai_thread != null and solo.ai_thread.is_alive() and Time.get_ticks_msec() < deadline: await create_timer(.02).timeout
		solo._process(.01); check(solo.rules.revision == ai_revision, "An AI reply cannot act during a host pause")
		solo.manual_paused = false; solo._process(.01); check(solo.rules.revision > ai_revision, "Unpause accepts the same current worker reply")
		await dispose(solo)
		var maximum = make_host(mode, 0, folder + mode + "/maximum-ai.json")
		var maximum_options: Dictionary = maximum.options.duplicate(true); maximum_options.solo_ai = 9
		check(maximum.apply_settings(maximum_options) and maximum.seats.size() == 10 and maximum.seats.filter(func(player: Dictionary) -> bool: return player.ai).size() == 9, "Host can configure nine AI opponents within ten total seats")
		await dispose(maximum)
		var phone = make_host(mode, 1, folder + mode + "/phone.json")
		check(not phone.host_plays and phone.seats.size() == 2 and phone.seats[1].ai, "One phone can play one AI while host stays public")
		await dispose(phone)
		var ten = make_host(mode, 10, folder + mode + "/ten.json")
		check(ten.seats.size() == 10 and not ten.seats.any(func(player: Dictionary) -> bool: return player.ai), "Ten humans occupy ten seats with no AI overfill")
		await dispose(ten)
		var timed = make_host(mode, 2, folder + mode + "/timed.json")
		timed.turn_remaining = .01; timed._process(.02)
		check(timed.rules.phase == "hand_over" and timed.rules.players[0].folded and not timed.practice, "Human expiry folds when facing a bet without inventing a saved win")
		check(timed.phase_remaining == 6 and timed.ui.public_cards_dialog.overlay.visible and timed.ui.review_automatic and not timed.paused(), "Uncontested wins open a six-second review")
		var cancel := InputEventAction.new(); cancel.action = "ui_cancel"; cancel.pressed = true; timed._unhandled_input(cancel)
		check(timed.ui.public_cards_dialog.overlay.visible, "Escape cannot dismiss the automatic uncontested review early")
		timed._process(3); check(timed.rules.hand_number == 1 and timed.phase_remaining == 3, "Uncontested results remain visible midway through review")
		timed.ui.open_settings(); timed._process(20); check(timed.phase_remaining == 3, "Settings freezes the results countdown")
		check(not timed.continue_review(), "Continue cannot advance a review while Settings pauses the table")
		timed.ui.close_settings(); timed._process(2.99); check(timed.rules.hand_number == 1, "Without host Continue, results retain the full six-second review")
		timed._process(.02); check(timed.rules.hand_number == 2 and not timed.ui.public_cards_dialog.overlay.visible and timed._save() and timed.storage_error.is_empty(), "Automatic next hand closes results and retains a valid save and nonnegative phase clock")
		timed._action(timed.rules.turn, {"action": "fold", "revision": timed.rules.revision})
		var review_revision: int = timed.rules.revision
		timed.handle_controller_message(str(timed.seats[0].id), {"action": "continue", "revision": review_revision})
		check(timed.rules.revision == review_revision and timed.rules.hand_number == 2, "Phones cannot skip the authoritative result countdown")
		check(timed.ui.review_close.text.contains("6") and not timed.ui.review_close.disabled and not timed.ui.review_countdown.visible, "The host Continue button includes the remaining countdown")
		timed.ui.review_close.pressed.emit()
		check(timed.rules.hand_number == 3 and not timed.ui.public_cards_dialog.overlay.visible and not timed.continue_review(), "Host Continue skips to one new hand and duplicate presses cannot advance again")
		await dispose(timed)
		var scored = make_host(mode, 2, folder + mode + "/scored.json")
		scored.points_awarded.connect(func(id: String, amount: int) -> void: awards.append({"id": id, "amount": amount}))
		scored.result_reported.connect(func(id: String, won: bool) -> void: results.append({"id": id, "won": won}))
		var decisions := 0
		while scored.rules.phase != "finished" and decisions < 10000:
			decisions += 1
			if scored.rules.phase in ["runout", "hand_over"]: scored._process(6)
			else:
				var legal: Dictionary = scored.rules.legal(scored.rules.turn)
				scored._action(scored.rules.turn, {"action": "raise" if legal.can_raise else "check" if legal.check else "call", "amount": legal.max_raise_to, "revision": scored.rules.revision})
		check(scored.rules.phase == "finished" and scored.results_recorded, "A complete all-human tournament records its result")
		check(awards[-1].id == scored.seats[scored.rules.winner].id and awards[-1].amount == 1, "Saved point belongs to the actual tournament champion")
		scored._record_result(); check(awards.size() == (1 if mode == "texas" else 2) and results.size() == (2 if mode == "texas" else 4), "Exactly one point and one result per human, once")
		check(scored.saved_game.load_game().is_empty(), "Completion marker prevents replaying results from an older checkpoint")
		var old_dealer: int = scored.first_dealer; var old_wins: Dictionary = scored.wins.duplicate()
		scored.new_tournament(true); check(scored.rules.phase == "finished" and scored.ui.replay.disabled, "Tournament replay waits for the twelve-second review")
		scored.ui.review_close.pressed.emit()
		check(scored.phase_remaining == 0 and not scored.ui.public_cards_dialog.overlay.visible and not scored.ui.replay.disabled and scored.wins == old_wins, "Final Continue skips review without starting a new tournament or recording results twice")
		scored.new_tournament(true); check(scored.first_dealer != old_dealer and scored.wins == old_wins, "Replay rotates starter and preserves session wins")
		await dispose(scored)
		var practice_host = make_host(mode, 1, folder + mode + "/practice-score.json")
		var saved_awards_before := awards.size(); var saved_results_before := results.size()
		practice_host.points_awarded.connect(func(id: String, amount: int) -> void: awards.append({"id": id, "amount": amount})); practice_host.result_reported.connect(func(id: String, won: bool) -> void: results.append({"id": id, "won": won}))
		for step in 1500:
			if practice_host.rules.phase == "finished": break
			if practice_host.rules.phase in ["runout", "hand_over"]: practice_host._process(6)
			else:
				var legal: Dictionary = practice_host.rules.legal(practice_host.rules.turn)
				practice_host._action(practice_host.rules.turn, {"action": "raise" if legal.can_raise else "check" if legal.check else "call", "amount": legal.max_raise_to, "revision": practice_host.rules.revision})
		check(practice_host.results_recorded and awards.size() == saved_awards_before and results.size() == saved_results_before and practice_host.wins.size() == 1, "Completed mixed AI tables retain session wins but never award saved points or results")
		await dispose(practice_host)
	var cue_host = make_host("texas", 0, folder + "all-in-cue.json", false)
	var full_stack: int = cue_host.rules.players[0].stack + cue_host.rules.players[0].street
	check(cue_host.money_audio.stream != null and cue_host.money_audio.bus == "Effects", "All In uses an offline money effect on the Effects bus")
	cue_host.ui._set_amount(full_stack)
	check(cue_host.ui.bet_button.text == "ALL IN" and not cue_host.money_audio.playing and cue_host.ui.bet_cue_pending, "All In selected during dealing waits for the playable host control")
	cue_host.motion_elapsed = cue_host.motion_duration; cue_host._publish()
	check(cue_host.money_audio.playing and not cue_host.ui.bet_cue_pending, "The money cue plays when the host's All In control becomes available")
	var playback: AudioStreamPlayback = cue_host.money_audio.get_stream_playback()
	for repeat in 4: cue_host._publish()
	check(cue_host.money_audio.get_stream_playback() == playback, "Clock publications cannot restart the All In cue")
	cue_host.ui.open_settings(); cue_host._process(.01)
	check(cue_host.money_audio.stream_paused, "Host settings pause the money effect")
	cue_host.ui.close_settings(); cue_host._process(.01)
	check(not cue_host.money_audio.stream_paused and cue_host.money_audio.get_stream_playback() == playback, "Closing Settings resumes the same effect without repeating it")
	cue_host.money_audio.stop(); cue_host.ui._set_amount(cue_host.rules.legal(0).min_raise_to)
	cue_host.ui.raise_amount.get_line_edit().text = str(full_stack); cue_host.ui.raise_amount.get_line_edit().text_changed.emit(str(full_stack))
	check(cue_host.ui.bet_button.text == "ALL IN" and cue_host.money_audio.playing, "Typing the full stack triggers the same cue after leaving All In")
	cue_host.new_tournament()
	check(not cue_host.money_audio.playing and not cue_host.ui.bet_cue_pending, "A fresh tournament stops the previous preview cue")
	cue_host.shutdown_game(); check(not cue_host.money_audio.playing and cue_host.money_audio.stream == null, "Clean exit stops and releases the money sound")
	cue_host.queue_free(); await process_frame
	var capped = make_host("omaha", 0, folder + "capped-cue.json")
	capped.ui._set_amount(capped.rules.legal(0).max_raise_to)
	check(capped.ui.bet_button.text == "BET" and not capped.money_audio.playing, "An Omaha pot-limit maximum below the full stack does not sound All In")
	await dispose(capped)
	var moving = make_host("omaha", 2, folder + "motion.json", false)
	for cue in {"shuffle": "card-shuffle", "draw": "card-slide-1", "place": "card-place-1"}:
		var filename: String = {"shuffle": "card-shuffle", "draw": "card-slide-1", "place": "card-place-1"}[cue]
		check(moving.card_sounds[cue].stream != null and moving.card_sounds[cue].bus == "Effects" and moving.card_sounds[cue].volume_db == -5 and FileAccess.get_file_as_bytes("res://Games/poker/audio/%s.ogg" % filename) == FileAccess.get_file_as_bytes("res://Games/uno/audio/%s.ogg" % filename), "Poker uses UNO's exact offline %s sound and Effects gain" % cue)
	check(moving.card_cues.size() == 8, "Each opening Omaha card has one pending slide after the shuffle")
	check(moving.animating() and not moving._action(0, {"action": "fold", "revision": moving.rules.revision}), "Opening movement rejects input")
	check(moving._snapshot(-1).motion.flights.all(func(flight: Dictionary) -> bool: return flight.card.get("back", false) and not flight.card.has("id")), "Public deal flights carry neutral backs without secret card IDs")
	var duration: float = moving.motion_duration; moving.manual_paused = true; moving._process(10)
	check(moving.motion_elapsed == 0 and moving.motion_duration == duration, "Pause freezes the movement timeline")
	check(moving.card_cues.size() == 8 and moving.card_sounds.shuffle.stream_paused, "Pause freezes pending and currently playing card sounds")
	moving.manual_paused = false; moving._process(duration + .1); check(not moving.animating(), "Unpausing settles the original movement")
	check(moving.card_cues.is_empty(), "Unpausing consumes each original deal cue once")
	moving._action(0, {"action": "call", "revision": moving.rules.revision}); moving._process(1)
	moving._action(1, {"action": "check", "revision": moving.rules.revision})
	check(moving.rules.board.size() == 3 and moving.card_cues.size() == 5, "Community reveals schedule slides and landing sounds for all three cards")
	var pending_cues: Array = moving.card_cues.duplicate(true); moving._publish(); moving._publish()
	check(moving.card_cues == pending_cues, "Repeated state publication cannot duplicate card sounds")
	moving.shutdown_game(); check(moving.card_cues.is_empty() and moving.card_sounds.values().all(func(sound: AudioStreamPlayer) -> bool: return not sound.playing), "Exit cancels pending and playing card sounds")
	await dispose(moving)
	var preferences := Settings.new()
	var configured = make_host("texas", 2, folder + "preferences.json", true, preferences)
	configured.ui.open_settings(); configured.ui.controls.starting_chips.value = 3000
	check(configured.ui.draft.small_blind == 15 and configured.ui.draft.big_blind == 30, "Starting chips suggest a stack-proportional pair of blinds")
	configured.ui.controls.small_blind.value = 20; configured.ui.controls.big_blind.value = 60
	check(configured.ui.draft.small_blind == 20 and configured.ui.draft.big_blind == 60 and not configured.ui.apply.disabled, "The host can override both suggested blinds")
	check(configured.options.starting_chips == 2000 and preferences.load_settings("poker-texas-holdem", configured.DEFAULTS).starting_chips == 2000, "Uncommitted settings do not affect gameplay or saved preferences")
	check(configured.apply_settings(configured.ui.draft) and configured.options.starting_chips == 3000, "Apply persists accepted settings and starts a new tournament")
	await dispose(configured)
	configured = make_host("texas", 2, folder + "preferences-reopen.json", true, preferences)
	check(configured.options.starting_chips == 3000 and configured.ui.controls.starting_chips.value == 3000, "Preferences restore without edit signals")
	check(configured.ui.controls.small_blind.value == 20 and configured.ui.controls.big_blind.value == 60, "Reopening Settings preserves accepted custom blinds instead of recalculating them")
	await dispose(configured)
	configured = make_host("omaha", 2, folder + "preferences-omaha.json", true, preferences)
	check(configured.options.starting_chips == 2000, "Omaha settings stay independent from Texas")
	await dispose(configured)
	preferences.save_settings("poker-texas-holdem", {"party_ai": 9})
	configured = make_host("texas", 10, folder + "preferences-ten.json", true, preferences)
	check(configured.seats.size() == 10 and configured.options.party_ai == 9 and configured.ui.controls.ai.value == 0 and configured.ui.apply.disabled, "A full human roster adapts AI controls without overwriting saved intent")
	await dispose(configured)
	await create_timer(.2).timeout
	print("Poker session: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
