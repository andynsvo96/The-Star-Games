extends SceneTree

const Rules = preload("res://Games/spyfall/host/rules.gd")
const Settings = preload("res://Games/spyfall/host/settings.gd")
const Host = preload("res://Games/spyfall/host/main.tscn")
var checks := 0
var failures := 0
var awards: Dictionary = {}
var reports: Array = []
var public_state: Dictionary = {}
var private_states: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func roster(count := 4) -> Array:
	var result: Array = []
	for seat in count:
		result.append({"id": "p%d" % seat, "display_name": "Agent %d" % seat, "profile_id": "profile%d" % seat, "reconnect_token": "token%d" % seat, "color": "#2463eb"})
	return result


func begin(count := 4):
	var rules = Rules.new()
	check(rules.setup(roster(count), ["Beach", "Space Station", "Hospital"], 480), "Allowed human roster starts a round")
	check(rules.phase == "playing" and rules.remaining == 480 and rules.timer_started and not rules.vote_timer_started, "Each round starts its game clock with an unstarted voting clock")
	return rules


func expire(rules) -> void:
	rules.tick(rules.duration)


func _send(host: Node, seat: int, action: String, extra: Dictionary = {}) -> void:
	var message := {"action": action, "revision": host.rules.revision}
	message.merge(extra, true)
	host.handle_controller_message("p%d" % seat, message)


func _run() -> void:
	seed(4298)
	DirAccess.make_dir_recursive_absolute("res://.test_data/spyfall")
	for filename in ["host-settings.json", "host-settings.json.bak", "host-settings.json.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.test_data/spyfall/" + filename))
	var invalid = Rules.new()
	check(not invalid.setup(roster(3), ["Beach", "Train"], 480) and not invalid.setup(roster(9), ["Beach", "Train"], 480), "Only 4–8 human players are admitted, with no solo fallback")
	for count in range(4, 9):
		var rules = begin(count)
		check(rules.phase == "playing", "Conversation begins as soon as the game launches")
		var spies := 0
		for seat in count:
			var view: Dictionary = rules.view_for(seat)
			spies += int(view.secret.spy)
			check(view.secret.location == ("" if seat == rules.spy else rules.location), "Each private card contains only the information its owner may see")
			check(not JSON.stringify(view).contains("token") and not JSON.stringify(view).contains("profile"), "Snapshots strip identity secrets")
		check(spies == 1 and not rules.view_for().has("secret") and rules.view_for().outcome.is_empty(), "Exactly one spy and a secret-free shared host view")
		var civilian: int = (rules.spy + 1) % count
		var before_accuse: int = rules.revision
		check(not rules.view_for(rules.spy).can_accuse and not rules.accuse(rules.spy, civilian) and rules.revision == before_accuse and rules.used_accusations.is_empty(), "Spies cannot accuse through snapshots or direct host rules")
		check(not rules.guess(civilian, rules.location) and not rules.guess(rules.spy, "Invalid place"), "Only the spy may guess a configured location")
		rules.tick(15)
		var clock: float = rules.remaining
		check(clock == rules.duration - 15 and not rules.vote_timer_started and rules.view_for().timer_started, "Discussion consumes only round time")
		check(not rules.accuse(civilian, civilian) and not rules.vote_timer_started and rules.accuse(civilian, rules.spy), "Only a legal first accusation starts voting time")
		rules.tick(10)
		check(rules.vote_timer_started and rules.vote_remaining == 50 and rules.remaining == clock and not rules.guess(rules.spy, rules.location) and not rules.vote(rules.spy, true), "Voting consumes its own deadline, pauses round time and excludes the suspect")
		var dissenter: int = (civilian + 1) % count
		if dissenter == rules.spy:
			dissenter = (dissenter + 1) % count
		check(rules.vote(dissenter, false) and rules.phase == "playing" and not rules.accuse(civilian, rules.spy), "A No resumes play and consumes the initiator's one accusation")
		rules.tick(5)
		check(rules.remaining == clock - 5 and not rules.vote_timer_started, "Rejecting an accusation stops its vote deadline and resumes round time")
		check(rules.accuse(dissenter, rules.spy), "Other players retain their accusations")
		check(rules.remaining == clock - 5 and rules.vote_remaining == 60 and rules.vote_number == 2, "Each new accusation has a fresh independent voting deadline")
		for seat in count:
			if seat != rules.spy and seat != dissenter:
				rules.vote(seat, true)
		check(rules.phase == "finished" and not rules.outcome.spy_wins and rules.outcome.points[dissenter] == 2 and rules.outcome.points[rules.spy] == 0, "Unanimous capture awards non-spies and the early accuser bonus")
		var totals: Array = rules.session_points.duplicate()
		var previous_spy: int = rules.spy
		rules.restart()
		check(rules.phase == "playing" and rules.timer_started and not rules.vote_timer_started and rules.remaining == rules.duration and rules.session_points == totals and rules.history.size() == 1 and rules.starter == previous_spy and rules.used_accusations.is_empty(), "Replay resets both clocks, starts discussion and preserves totals/history")
	var guessed = begin()
	check(guessed.guess(guessed.spy, guessed.location) and guessed.outcome.points[guessed.spy] == 4, "Correct location guess gives the spy four points")
	check(not guessed.guess(guessed.spy, guessed.location) and guessed.history.size() == 1, "A completed round cannot be scored again")
	var wrong = begin()
	var other: String = wrong.locations.filter(func(name: String) -> bool: return name != wrong.location)[0]
	wrong.guess(wrong.spy, other)
	check(not wrong.outcome.spy_wins and wrong.outcome.points.count(1) == 3, "Wrong guess wins one point for each non-spy")
	var innocent = begin()
	var innocent_seat: int = (innocent.spy + 1) % 4
	var innocent_accuser: int = (innocent.spy + 2) % 4
	innocent.accuse(innocent_accuser, innocent_seat)
	for seat in 4:
		if seat != innocent_accuser and seat != innocent_seat:
			innocent.vote(seat, true)
	check(innocent.outcome.spy_wins and innocent.outcome.points[innocent.spy] == 4, "An innocent conviction still gives the spy four points")
	for mode in ["caught", "innocent", "escaped"]:
		var final = begin()
		expire(final)
		check(final.sound_events.size() == 1 and final.sound_events.back().kind == "timer_up" and final.votes.is_empty(), "Round expiry emits one cue and enters voting with an unstarted deadline")
		check(final.phase == "final_vote" and not final.guess(final.spy, final.location) and not final.accuse(0, 1), "Time expiry locks conversation actions and starts final voting")
		var target: int = final.spy if mode == "caught" else (final.spy + 1) % 4
		for seat in 4:
			var choice: int = ((seat + 1) % 4) if mode == "escaped" else (target if seat != target else (target + 1) % 4)
			final.final_vote(seat, choice)
		check(final.sound_events.size() == 6 and final.sound_events.slice(1, 5).all(func(event: Dictionary) -> bool: return event.kind == "vote") and final.sound_events.back().kind == ("non_spies_win" if mode == "caught" else "spy_win"), "Each accepted ballot emits a vote cue followed by the correct team fanfare")
		check(final.outcome.reason == mode and final.outcome.points[final.spy] == (0 if mode == "caught" else (4 if mode == "innocent" else 2)), "Final vote evaluates unanimity excluding the suspect and awards the right points")
	var paused = begin()
	var saved: Dictionary = paused.view_for(paused.spy)
	paused.set_disconnected(2)
	paused.tick(999)
	check(paused.remaining == 480 and not paused.accuse(0, 1) and not paused.guess(paused.spy, paused.location), "Disconnect freezes authoritative time and actions")
	paused.reconnect(2)
	check(paused.view_for(paused.spy).secret == saved.secret and paused.phase == "playing", "Reconnect retains the assigned secret and phase")
	paused.accuse((paused.spy + 1) % 4, paused.spy)
	paused.tick(7)
	paused.set_disconnected(2)
	paused.tick(999)
	check(paused.remaining == 480 and paused.vote_remaining == 53 and paused.vote_timer_started, "Disconnect freezes an already running vote countdown")
	paused.reconnect(2)
	paused.tick(3)
	check(paused.remaining == 480 and paused.vote_remaining == 50, "Reconnect resumes only the same voting deadline without resetting it")
	_test_vote_timers()
	_test_settings()
	var identified = begin()
	expire(identified)
	identified.final_vote(0, 1)
	check(identified.view_for().voting[1] == {"target": 1, "count": 1, "voters": [0]} and identified.view_for(2).voting[1].voters == [0], "Default voting snapshots identify each voter and their chosen suspect")
	identified.anonymous_voting = true
	for seat in range(1, 4):
		identified.final_vote(seat, (seat + 1) % 4)
	check(identified.view_for().voting.all(func(ballot: Dictionary) -> bool: return ballot.voters.is_empty()) and identified.view_for().vote_count == 4 and identified.phase == "finished", "Anonymous vote totals and identities remain protected in the final conclusion")
	check(identified.view_for().sound_events.all(func(event: Dictionary) -> bool: return event.keys().size() == 2 and event.has("sequence") and event.has("kind")), "Public sounds reveal no voter identity, target or private card")
	var sound_count: int = identified.sound_sequence
	identified.final_vote(0, 1)
	identified.finish(true, "escaped")
	check(identified.sound_sequence == sound_count, "Rejected duplicate ballots and completion cannot repeat sound events")
	identified.restart()
	check(identified.sound_events.is_empty() and identified.sound_sequence == sound_count, "Restart clears old cues while preserving monotonic event IDs")
	var host = Host.instantiate()
	host.settings = Settings.new("res://.test_data/spyfall/host-settings.json")
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("spyfall", roster(), {}, true))
	host.points_awarded.connect(func(id: String, amount: int) -> void: awards[id] = int(awards.get(id, 0)) + amount)
	host.result_reported.connect(func(id: String, won: bool) -> void: reports.append([id, won]))
	host.controller_state_updated.connect(func(state: Dictionary) -> void: public_state = state)
	host.controller_private_state_updated.connect(func(id: String, state: Dictionary) -> void: private_states[id] = state)
	host.start_game()
	check(host.rules.phase == "playing" and host.save_locations_button.disabled and not host.screen.status.visible and not host.reveal_label.visible and not host.voting_dialog.overlay.visible, "Host starts immediately, conceals secrets, and removes the status banner")
	check(not host.rules.anonymous_voting and not host.anonymous_toggle.button_pressed, "Anonymous voting defaults off")
	check(host.rules.duration == 480 and host.rules.vote_duration == 60 and host.rules.timer_started and not host.rules.vote_timer_started and host.clock_status.text == "ROUND TIMER" and host.screen.get_theme_constant("story", "GamePalette") == 1, "New hosts default to eight round minutes and one voting minute with shared dossier chrome")
	check(host._player_name_part(host.rules.spy, false) is String and host.reveal_label.get_parsed_text().is_empty(), "Live play has no public spy-name highlighting")
	host.rules.timer_started = true
	host.rules.remaining = 10
	host._publish()
	check(host.timer_label.text == "10" and host.timer_label.get_theme_color("font_color") == GameLook.RED and host.countdown_ticks == ["round:10"], "Last ten seconds use red numbers and one countdown cue per tick")
	host._publish()
	check(host.countdown_ticks == ["round:10"], "Duplicate snapshots do not replay a countdown tick")
	host.session.reduced_motion = true
	host.rules.remaining = 9
	host._publish()
	check(host.timer_label.scale == Vector2.ONE and host.countdown_ticks == ["round:10", "round:9"], "Reduced motion keeps the countdown static while preserving its sound ticks")
	host.rules.remaining = 480
	host._publish()
	var before_tick: float = host.rules.remaining
	host.rules.tick(1)
	check(host.rules.remaining == before_tick - 1 and not host.rules.vote_timer_started, "Discussion consumes round time while the vote clock waits")
	var revision: int = host.rules.revision
	for message in [{"action":"ready", "revision":revision}, {"action":"accuse", "target":1}, {"action":"accuse", "revision":revision - 1, "target":1}, {"action":"accuse", "revision":revision, "target":true}, {"action":"accuse", "revision":revision, "target":1.5}, {"action":"vote", "revision":revision, "agree":"yes"}, {"action":"apply", "revision":revision, "locations":["Injected", "Secrets"]}]:
		host.handle_controller_message("p0", message)
	host.handle_controller_message("outsider", {"action":"accuse", "revision":revision, "target":1})
	check(host.rules.revision == revision, "Malformed, stale, unknown-player and controller-supplied settings inputs cannot mutate state")
	check(host.rules.sound_events.is_empty(), "Invalid controller requests do not produce vote or result sounds")
	_send(host, host.rules.spy, "accuse", {"target":(host.rules.spy + 1) % 4})
	check(host.rules.revision == revision, "An authenticated spy cannot bypass its hidden accusation button")
	_send(host, host.rules.spy, "guess", {"location":host.rules.location})
	check(reports.size() == 4 and awards.size() == 1 and awards.values()[0] == 4 and public_state.outcome.location == host.rules.location, "Host records exactly one result per player and publishes the reveal only at completion")
	check(host._player_name_part(host.rules.spy, true) == {"text": str(host.rules.players[host.rules.spy].display_name), "color": GameLook.RED} and host.reveal_label.get_parsed_text().contains(str(host.rules.players[host.rules.spy].display_name)) and host.points_label.get_parsed_text().contains("+4 points"), "The entire spy name uses a red text run in conclusion and point awards")
	check(host.sound_cursor == host.rules.sound_sequence and host.effect_sounds.spy_win.playing, "Native host plays the authoritative spy-win cue")
	check(host.result_team.get_child_count() == 1 and host.voting_dialog.shade.color == GameLook.result_colors("danger").shade and host.result_team.get_child(0).get_child(1).text == host.rules.players[host.rules.spy].display_name, "Spy victory reveals exactly the spy in a dark red result")
	host._record_result()
	check(reports.size() == 4, "Duplicate result handling is idempotent")
	_send(host, 0, "replay")
	_send(host, 1, "next")
	check(host.rules.phase == "finished" and host.rules.round_number == 1 and host.voting_dialog.overlay.visible and not host.dossier.visible and host.points_label.get_parsed_text().contains("+4 points"), "Controller replay aliases cannot restart; the conclusion displays winners, points and secrets until host replay")
	host._replay()
	check(host.rules.phase == "playing" and host.rules.timer_started and not host.rules.vote_timer_started and not host.voting_dialog.overlay.visible and host.dossier.visible and host.countdown_ticks.is_empty() and host.result_team.get_child_count() == 0, "Host replay starts a fresh round clock and resets the vote timer")
	check(host.reveal_label.get_parsed_text().is_empty() and host.points_label.get_parsed_text().is_empty() and host._player_name_part(host.rules.spy, false) is String and not host.effect_sounds.spy_win.playing, "Restart clears revealed names, red highlighting and result audio")
	var before: Array = host.rules.session_points.duplicate()
	host.location_input.text = "Observatory"
	host._add_location()
	check(not host.save_locations_button.disabled and not host.rules.locations.has("Observatory"), "Location edits enable Save and remain staged until saved")
	var removed_name: String = host.staged_locations[0]
	host.location_remove_buttons[0].pressed.emit()
	check(not host.staged_locations.has(removed_name) and host.location_list.get_child_count() == host.staged_locations.size(), "Each location has an x that removes its own row")
	host.timer_input.value = 2.5
	var restarted_round: int = host.rules.round_number + 1
	host._save_locations()
	check(host.rules.round_number == restarted_round and host.rules.phase == "playing" and host.rules.timer_started and not host.rules.vote_timer_started and host.rules.duration == 480 and host.rules.locations.has("Observatory") and not host.rules.locations.has(removed_name) and host.rules.session_points == before and reports.size() == 4 and host.save_locations_button.disabled, "Save applies only locations, resets both clocks, retains scores and returns to grey")
	var saved_round: int = host.rules.round_number
	host._save_locations()
	check(host.rules.round_number == saved_round, "An unchanged location list cannot be saved or restart the round")
	host._apply_settings()
	check(host.rules.phase == "playing" and host.rules.duration == 150 and host.rules.locations.has("Observatory") and host.rules.session_points == before and reports.size() == 4, "Timer Apply remains separate from the location editor and preserves earned results")
	host.vote_timer_input.value = 0.4
	check(not host.apply_button.disabled and host.rules.vote_duration == 60, "Voting duration changes remain staged until Apply")
	host._apply_settings()
	check(host.rules.duration == 150 and host.rules.vote_duration == 24 and host.settings.vote_minutes == 0.4 and host.apply_button.disabled, "Apply saves separate round and voting durations")
	host.anonymous_toggle.button_pressed = true
	check(not host.apply_button.disabled and not host.rules.anonymous_voting, "Anonymous voting stays staged until host Apply")
	host._apply_settings()
	check(host.rules.anonymous_voting and host.settings.anonymous_voting and host.apply_button.disabled, "Apply saves anonymous voting and starts a new round without changing totals")
	expire(host.rules)
	host.rules.final_vote(0, 1)
	host._publish()
	check(host.voting_dialog.overlay.visible and not host.dossier.visible and host.vote_label.text.contains("1 / 4 VOTED") and host.voting_rows[1].voters.get_parsed_text() == "Anonymous votes: 1", "Time expiry replaces the middle section with a live anonymous voting popup")
	check(public_state.voting[1].count == 1 and public_state.voting[1].voters.is_empty() and private_states.p0.voting[1].voters.is_empty(), "Anonymous snapshots omit voter identities on both shared and private routes")
	host.rules.finish(false, "caught")
	host._publish()
	check(host.result_team.get_child_count() == 3 and host.voting_dialog.shade.color == GameLook.result_colors("success").shade and host.voting_rows.all(func(row: Dictionary) -> bool: return not row.body.visible), "Civilian victory shows the whole civilian team in teal without old vote rows")
	before = host.rules.session_points.duplicate()
	host._restart_saved_settings()
	host.staged_locations = host.settings.locations.duplicate()
	host._refresh_locations()
	check(host.save_locations_button.disabled, "Reverting all location edits disables Save")
	var saved_locations: Array = host.staged_locations.duplicate()
	host.staged_locations = ["Beach", "Hospital"]
	host._refresh_locations()
	host._remove_location(0)
	check(host.staged_locations.size() == 2 and host.location_remove_buttons.all(func(button: Button) -> bool: return button.disabled), "The last two locations cannot be removed")
	host.staged_locations = saved_locations
	host._refresh_locations()
	check(not public_state.has("secret") and private_states.size() == 4, "The launcher hooks emit public and correctly addressed private snapshots")
	_send(host, (host.rules.spy + 1) % 4, "accuse", {"target":host.rules.spy})
	host.player_disconnected("p2")
	host.timer_input.value = 6.5
	host._apply_settings()
	check(host.rules.phase == "playing" and host.rules.duration == 390 and host.rules.missing == [2] and host.rules.votes.is_empty() and reports.size() == 4 and host.rules.session_points == before, "Applying settings during a disconnected vote abandons it without scoring and retains the pause")
	host.player_reconnected({"id":"p2"})
	check(host.rules.missing.is_empty() and host.rules.phase == "playing", "Reconnection after a settings restart resumes the fresh round")
	expire(host.rules)
	_send(host, 0, "final_vote", {"target": 1})
	host.rules.vote_remaining = 0.01
	host.last_tick = Time.get_ticks_msec() - 100
	host._advance_clock()
	host._publish()
	check(host.rules.phase == "finished" and host.rules.outcome.reason == "escaped" and reports.size() == 8, "Host-monotonic voting expiry records one saved result per player without another controller action")
	host._advance_clock()
	host._record_result()
	check(reports.size() == 8, "Subsequent clock frames cannot duplicate voting-timeout awards")
	host.shutdown_game()
	check(not host.active and not host.screen.background_media.visible, "Shutdown stops gameplay and shared media")
	host.queue_free()
	var catalog := GameCatalog.new()
	var modules: Array = catalog.scan().filter(func(game: Dictionary) -> bool: return game.id == "spyfall")
	check(modules.size() == 1 and modules[0].min_players == 4 and modules[0].max_players == 8 and modules[0].modes == ["multiplayer"], "Automatic catalog discovers Spyfall once with its human-only limits")
	await process_frame
	# Let the audio mixer release stopped playback before terminating the engine.
	await create_timer(0.3).timeout
	print("Spyfall: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_vote_timers() -> void:
	var early = begin()
	early.tick(25)
	var accuser: int = (early.spy + 1) % 4
	early.accuse(accuser, early.spy)
	early.tick(59)
	check(early.phase == "vote" and early.remaining == 455 and early.vote_remaining == 1, "Early ballots use only voting time while the game clock freezes")
	check(not early.vote(accuser, true) and early.vote_remaining == 1, "Duplicate ballots never extend the voting deadline")
	early.tick(1)
	check(early.phase == "playing" and early.remaining == 455 and early.history.is_empty() and early.used_accusations.has(accuser), "Unfinished early accusations time out without scoring and consume the accusation")
	early.tick(2)
	check(early.remaining == 453, "The exact remaining round time resumes after early voting times out")
	for mode in ["caught", "innocent", "escaped"]:
		var final = begin()
		expire(final)
		final.tick(300)
		check(final.phase == "final_vote" and not final.vote_timer_started and final.vote_remaining == 60, "Final voting waits for an accepted first ballot before its deadline starts")
		check(not final.final_vote(0, 0) and not final.vote_timer_started, "Invalid ballots cannot start the voting clock")
		var target: int = final.spy if mode == "caught" else (final.spy + 1) % 4
		for seat in 4:
			if seat != target and (mode != "escaped" or final.votes.is_empty()):
				final.final_vote(seat, target)
				final.tick(1)
		check(final.phase == "final_vote" and final.vote_remaining == 60 - final.votes.size(), "Later ballots preserve the first ballot's deadline")
		final.tick(final.vote_remaining)
		check(final.phase == "finished" and final.outcome.reason == mode and final.history.size() == 1, "Voting timeout resolves submitted ballots using unanimity, including an absent suspect")
		final.tick(999)
		check(final.history.size() == 1, "A timed-out final vote cannot score twice")
	var custom = Rules.new()
	custom.setup(roster(), ["Beach", "Train"], 90, 12)
	custom.tick(90)
	custom.final_vote(0, 1)
	custom.tick(11)
	check(custom.vote_duration == 12 and custom.vote_remaining == 1 and custom.phase == "final_vote", "A custom voting duration is independent of the game duration")
	custom.set_disconnected(2)
	custom.tick(10)
	check(custom.vote_remaining == 1, "Disconnect freezes the final voting deadline")
	custom.reconnect(2)
	custom.tick(1)
	check(custom.phase == "finished", "The final voting deadline resumes after reconnect")


func _test_settings() -> void:
	check(Settings.validate_names([" Beach ", "Space   Station"]) == ["Beach", "Space Station"], "Location names trim and normalize spaces")
	for invalid in [["Beach"], ["Beach", "beach"], ["Beach", ""], ["Beach", "X".repeat(61)], ["Beach", 4], ["Beach", "bad\nname"]]:
		check(Settings.validate_names(invalid).is_empty(), "Empty, duplicate, invalid and insufficient location lists are rejected")
	var settings = Settings.new("res://.test_data/spyfall/settings.json")
	check(settings.minutes == 8 and settings.vote_minutes == 1, "Unsaved settings default to eight round minutes and one voting minute")
	check(settings.save_data(["Beach", "Observatory"], 3.5) and settings.save_data(["Library", "Train"], 7), "Settings save transactionally, including repeated updates")
	var loaded = Settings.new(settings.path)
	loaded.load_data()
	check(loaded.minutes == 7 and loaded.locations == ["Library", "Train"], "Customized location pool and timer survive relaunch")
	check(not loaded.anonymous_voting and loaded.save_data(["Library", "Train"], 7, true), "Existing settings default to identified votes and anonymous voting can be saved")
	var anonymous = Settings.new(settings.path)
	anonymous.load_data()
	check(anonymous.anonymous_voting and anonymous.save_data(["Library", "Train"], 8), "Anonymous voting survives relaunch and independent timer/location saves")
	check(not anonymous.save_data(["Library", "Train"], 8, "true"), "Anonymous voting requires a real boolean")
	check(not loaded.save_data(["Only One"], 8) and not loaded.save_data(["A", "B"], NAN) and loaded.locations == ["Library", "Train"], "Invalid settings leave the last valid saved configuration intact")
	check(loaded.save_data(["Library", "Train"], 5.5, false, 0.4), "Round and vote timer choices can be saved independently")
	var clocks = Settings.new(loaded.path)
	clocks.load_data()
	check(clocks.minutes == 5.5 and clocks.vote_minutes == 0.4, "Both custom durations survive relaunch")
	check(not clocks.save_data(clocks.locations, 5.5, false, NAN) and not clocks.save_data(clocks.locations, 5.5, false, true) and clocks.vote_minutes == 0.4, "Invalid voting durations cannot overwrite saved clocks")
	var legacy_path := "res://.test_data/spyfall/legacy-settings.json"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "timer_minutes": 3.5, "locations": ["A", "B"]}))
	file.close()
	var legacy = Settings.new(legacy_path)
	legacy.load_data()
	check(legacy.minutes == 3.5 and legacy.vote_minutes == 1, "Older settings preserve their round duration and add a one-minute voting default")
